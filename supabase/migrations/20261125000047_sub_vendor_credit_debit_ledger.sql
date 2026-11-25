-- ==============================================================================
-- Migration: 20261125000047_sub_vendor_credit_debit_ledger.sql
-- Module: SUB VENDOR ACCOUNT DASHBOARD & CREDIT / DEBIT LEDGER
-- Description:
--   1. Adds 'total_value' to sub_vendor_material_outwards and items.
--   2. Creates public.sub_vendor_account_ledger for double-entry bookkeeping:
--        - Material Outward Value (CREDIT - Receivable increases)
--        - Material Payment Received (DEBIT - Receivable decreases)
--        - Advance / Deposit Given (DEBIT - Advance payable increases)
--        - Advance / Deposit Refund (CREDIT - Advance payable decreases)
--   3. Maintains separate Material Receivable and Advance Payable balances.
--   4. Provides recalculation RPCs, RLS policies, and indexes.
-- ==============================================================================

-- 1. Ensure value columns exist on Outward Header & Items
ALTER TABLE public.sub_vendor_material_outwards 
ADD COLUMN IF NOT EXISTS total_value NUMERIC(12, 2) NOT NULL DEFAULT 0.00;

ALTER TABLE public.sub_vendor_material_outward_items 
ADD COLUMN IF NOT EXISTS unit_rate NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
ADD COLUMN IF NOT EXISTS total_value NUMERIC(12, 2) NOT NULL DEFAULT 0.00;

-- 2. Create Sub-Vendor Account Ledger Table
CREATE TABLE IF NOT EXISTS public.sub_vendor_account_ledger (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    vendor_id UUID NOT NULL REFERENCES public.sub_vendors(id) ON DELETE CASCADE,
    vendor_name TEXT NOT NULL,
    transaction_date DATE NOT NULL DEFAULT CURRENT_DATE,
    transaction_type TEXT NOT NULL CHECK (transaction_type IN ('MATERIAL_OUTWARD', 'MATERIAL_PAYMENT', 'ADVANCE_GIVEN', 'ADVANCE_REFUND')),
    category TEXT NOT NULL CHECK (category IN ('MATERIAL', 'ADVANCE')),
    credit_amount NUMERIC(12, 2) NOT NULL DEFAULT 0.00 CHECK (credit_amount >= 0),
    debit_amount NUMERIC(12, 2) NOT NULL DEFAULT 0.00 CHECK (debit_amount >= 0),
    running_balance NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    reference_number TEXT NOT NULL,
    reference_id UUID,
    payment_mode TEXT NOT NULL DEFAULT 'Bank Transfer' CHECK (payment_mode IN ('Bank Transfer', 'NEFT/RTGS', 'UPI', 'Cheque', 'Cash', 'Inventory')),
    particulars TEXT NOT NULL,
    remarks TEXT,
    status TEXT NOT NULL DEFAULT 'Active' CHECK (status IN ('Active', 'Cancelled')),
    cancelled_at TIMESTAMPTZ,
    cancellation_reason TEXT,
    created_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE INDEX IF NOT EXISTS idx_sval_vendor_id ON public.sub_vendor_account_ledger (vendor_id);
CREATE INDEX IF NOT EXISTS idx_sval_tx_date ON public.sub_vendor_account_ledger (transaction_date DESC);
CREATE INDEX IF NOT EXISTS idx_sval_tx_type ON public.sub_vendor_account_ledger (transaction_type);
CREATE INDEX IF NOT EXISTS idx_sval_category ON public.sub_vendor_account_ledger (category);
CREATE INDEX IF NOT EXISTS idx_sval_status ON public.sub_vendor_account_ledger (status);
CREATE INDEX IF NOT EXISTS idx_sval_ref_id ON public.sub_vendor_account_ledger (reference_id);

-- 3. RPC: Record Ledger Transaction
CREATE OR REPLACE FUNCTION public.record_sub_vendor_ledger_entry(
    p_vendor_id UUID,
    p_transaction_date DATE,
    p_transaction_type TEXT,
    p_amount NUMERIC(12, 2),
    p_reference_number TEXT,
    p_payment_mode TEXT,
    p_particulars TEXT,
    p_remarks TEXT DEFAULT NULL,
    p_reference_id UUID DEFAULT NULL,
    p_created_by UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_vendor_name TEXT;
    v_category TEXT;
    v_credit NUMERIC(12, 2) := 0.00;
    v_debit NUMERIC(12, 2) := 0.00;
    v_entry_id UUID;
BEGIN
    SELECT name INTO v_vendor_name FROM public.sub_vendors WHERE id = p_vendor_id;
    IF v_vendor_name IS NULL THEN
        RAISE EXCEPTION 'Sub-Vendor with ID % not found.', p_vendor_id;
    END IF;

    IF p_amount <= 0 THEN
        RAISE EXCEPTION 'Transaction amount must be greater than zero.';
    END IF;

    -- Classify Credit vs Debit according to SIYA Accounting Rules:
    -- MATERIAL_OUTWARD: Credit (Receivable increases)
    -- MATERIAL_PAYMENT: Debit (Receivable decreases)
    -- ADVANCE_GIVEN: Debit (Advance payable increases)
    -- ADVANCE_REFUND: Credit (Advance payable decreases)
    IF p_transaction_type = 'MATERIAL_OUTWARD' THEN
        v_category := 'MATERIAL';
        v_credit := p_amount;
        v_debit := 0.00;
    ELSIF p_transaction_type = 'MATERIAL_PAYMENT' THEN
        v_category := 'MATERIAL';
        v_credit := 0.00;
        v_debit := p_amount;
    ELSIF p_transaction_type = 'ADVANCE_GIVEN' THEN
        v_category := 'ADVANCE';
        v_credit := 0.00;
        v_debit := p_amount;
    ELSIF p_transaction_type = 'ADVANCE_REFUND' THEN
        v_category := 'ADVANCE';
        v_credit := p_amount;
        v_debit := 0.00;
    ELSE
        RAISE EXCEPTION 'Invalid transaction type: %', p_transaction_type;
    END IF;

    INSERT INTO public.sub_vendor_account_ledger (
        vendor_id,
        vendor_name,
        transaction_date,
        transaction_type,
        category,
        credit_amount,
        debit_amount,
        running_balance,
        reference_number,
        reference_id,
        payment_mode,
        particulars,
        remarks,
        status,
        created_by
    ) VALUES (
        p_vendor_id,
        v_vendor_name,
        p_transaction_date,
        p_transaction_type,
        v_category,
        v_credit,
        v_debit,
        0.00,
        p_reference_number,
        p_reference_id,
        COALESCE(p_payment_mode, 'Bank Transfer'),
        p_particulars,
        p_remarks,
        'Active',
        p_created_by
    ) RETURNING id INTO v_entry_id;

    -- Recalculate running balances for this vendor
    PERFORM public.recalculate_sub_vendor_ledger_balances(p_vendor_id);

    RETURN jsonb_build_object(
        'success', true,
        'id', v_entry_id,
        'vendor_id', p_vendor_id,
        'credit_amount', v_credit,
        'debit_amount', v_debit
    );
END;
$$;

-- 4. RPC: Recalculate Running Balances for a Sub-Vendor
CREATE OR REPLACE FUNCTION public.recalculate_sub_vendor_ledger_balances(p_vendor_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_entry RECORD;
    v_balance NUMERIC(12, 2) := 0.00;
BEGIN
    FOR v_entry IN
        SELECT id, credit_amount, debit_amount, status
        FROM public.sub_vendor_account_ledger
        WHERE vendor_id = p_vendor_id
        ORDER BY transaction_date ASC, created_at ASC
    LOOP
        IF v_entry.status = 'Active' THEN
            v_balance := v_balance + (v_entry.credit_amount - v_entry.debit_amount);
        END IF;

        UPDATE public.sub_vendor_account_ledger
        SET running_balance = v_balance
        WHERE id = v_entry.id;
    END LOOP;
END;
$$;

-- 5. Row Level Security (RLS)
ALTER TABLE public.sub_vendor_account_ledger ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Admin full control on sub_vendor_account_ledger" ON public.sub_vendor_account_ledger;
DROP POLICY IF EXISTS "Staff can read sub_vendor_account_ledger" ON public.sub_vendor_account_ledger;

CREATE POLICY "Admin full control on sub_vendor_account_ledger"
    ON public.sub_vendor_account_ledger FOR ALL TO authenticated
    USING ((SELECT public.is_admin()) OR (auth.jwt()->>'role') IN ('admin', 'super_admin'))
    WITH CHECK ((SELECT public.is_admin()) OR (auth.jwt()->>'role') IN ('admin', 'super_admin'));

CREATE POLICY "Staff can read sub_vendor_account_ledger"
    ON public.sub_vendor_account_ledger FOR SELECT TO authenticated
    USING (true);

-- 6. Grants & PostgREST Cache Reload
GRANT ALL ON public.sub_vendor_account_ledger TO authenticated, anon, service_role;
GRANT EXECUTE ON FUNCTION public.record_sub_vendor_ledger_entry TO authenticated, anon, service_role;
GRANT EXECUTE ON FUNCTION public.recalculate_sub_vendor_ledger_balances TO authenticated, anon, service_role;

NOTIFY pgrst, 'reload schema';
