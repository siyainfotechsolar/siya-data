-- ==============================================================================
-- Migration: 20261128000052_sub_vendor_audit_sync_and_guards.sql
-- Module: Sub-Vendor E2E Calculation Standardization, Outward-Ledger Atomic Sync,
--         Duplicate UTR/Reference Prevention, and Audit/Reconciliation Views
-- ==============================================================================
-- SAFETY GUARANTEES:
--   1. Idempotent & self-contained: safe CREATE TABLE IF NOT EXISTS / CREATE OR
--      REPLACE / DROP IF EXISTS so it runs cleanly even if prior scripts failed
--      or were partially applied.
--   2. Zero destructive edits to historical records: does NOT delete, overwrite,
--      or flip existing historical credit_amount/debit_amount columns blindly.
--      Instead, standardized read views & running-balance recalculation project
--      canonical Credit/Debit polarity cleanly and surface historical anomalies
--      in v_sub_vendor_audit_check for human review.
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- 1. ENSURE CORE OUTWARD & LEDGER TABLES EXIST (42P01 GUARD)
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.sub_vendor_material_outwards (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    outward_number TEXT NOT NULL UNIQUE,
    vendor_id UUID NOT NULL REFERENCES public.sub_vendors(id) ON DELETE RESTRICT,
    vendor_name TEXT NOT NULL,
    outward_date DATE NOT NULL DEFAULT CURRENT_DATE,
    total_items INT NOT NULL DEFAULT 0 CHECK (total_items >= 0),
    total_quantity NUMERIC(12, 2) NOT NULL DEFAULT 0.00 CHECK (total_quantity >= 0),
    subtotal NUMERIC(14, 2) NOT NULL DEFAULT 0.00,
    total_gst NUMERIC(14, 2) NOT NULL DEFAULT 0.00,
    total_value NUMERIC(14, 2) NOT NULL DEFAULT 0.00,
    remarks TEXT,
    status TEXT NOT NULL DEFAULT 'Active' CHECK (status IN ('Active', 'Cancelled')),
    cancelled_at TIMESTAMPTZ,
    cancelled_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    cancellation_reason TEXT,
    created_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE TABLE IF NOT EXISTS public.sub_vendor_material_outward_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    outward_id UUID NOT NULL REFERENCES public.sub_vendor_material_outwards(id) ON DELETE CASCADE,
    material_id UUID,
    material_name TEXT NOT NULL,
    unit TEXT NOT NULL DEFAULT 'NOS',
    quantity NUMERIC(12, 2) NOT NULL CHECK (quantity > 0),
    unit_rate NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    base_amount NUMERIC(14, 2) NOT NULL DEFAULT 0.00,
    gst_percentage NUMERIC(5, 2) NOT NULL DEFAULT 0.00,
    gst_amount NUMERIC(14, 2) NOT NULL DEFAULT 0.00,
    total_price NUMERIC(14, 2) NOT NULL DEFAULT 0.00,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE TABLE IF NOT EXISTS public.sub_vendor_material_outward_audit (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    outward_id UUID NOT NULL REFERENCES public.sub_vendor_material_outwards(id) ON DELETE CASCADE,
    outward_number TEXT NOT NULL,
    action TEXT NOT NULL CHECK (action IN ('CREATE', 'UPDATE', 'CANCEL')),
    description TEXT NOT NULL,
    details JSONB NOT NULL DEFAULT '{}'::jsonb,
    performed_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

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

CREATE INDEX IF NOT EXISTS idx_svmo_vendor_date ON public.sub_vendor_material_outwards (vendor_id, outward_date DESC);
CREATE INDEX IF NOT EXISTS idx_svmoi_outward_id ON public.sub_vendor_material_outward_items (outward_id);
CREATE INDEX IF NOT EXISTS idx_sval_vendor_date ON public.sub_vendor_account_ledger (vendor_id, transaction_date DESC);
CREATE INDEX IF NOT EXISTS idx_sval_ref_id ON public.sub_vendor_account_ledger (reference_id);

-- ------------------------------------------------------------------------------
-- 2. STANDARDIZED PASSBOOK RUNNING BALANCE RECALCULATION
-- Convention:
--   Credit (+ Cr): MATERIAL_PAYMENT, ADVANCE_REFUND
--   Debit  (- Dr): MATERIAL_OUTWARD, ADVANCE_GIVEN
-- Deterministic Sort: (transaction_date ASC, created_at ASC, id ASC)
-- Does NOT overwrite historical credit_amount/debit_amount columns; computes
-- normalized running_balance using transaction_type so historical & new entries align.
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.recalculate_sub_vendor_ledger_balances(p_vendor_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_entry RECORD;
    v_amt NUMERIC(14, 2);
    v_credit NUMERIC(14, 2);
    v_debit NUMERIC(14, 2);
    v_balance NUMERIC(14, 2) := 0.00;
BEGIN
    FOR v_entry IN
        SELECT id, transaction_type, credit_amount, debit_amount, status
        FROM public.sub_vendor_account_ledger
        WHERE vendor_id = p_vendor_id
        ORDER BY transaction_date ASC, created_at ASC, id ASC
    LOOP
        IF v_entry.status = 'Active' THEN
            v_amt := ROUND(GREATEST(COALESCE(v_entry.credit_amount, 0.00), COALESCE(v_entry.debit_amount, 0.00))::NUMERIC, 2);
            IF UPPER(v_entry.transaction_type) IN ('MATERIAL_PAYMENT', 'ADVANCE_REFUND') THEN
                v_credit := v_amt;
                v_debit := 0.00;
            ELSE
                v_credit := 0.00;
                v_debit := v_amt;
            END IF;
            v_balance := ROUND((v_balance + v_credit - v_debit)::NUMERIC, 2);
        END IF;

        UPDATE public.sub_vendor_account_ledger
        SET running_balance = v_balance
        WHERE id = v_entry.id;
    END LOOP;
END;
$$;

-- ------------------------------------------------------------------------------
-- 3. STANDARDIZED MANUAL LEDGER INSERT RPC (WITH DUPLICATE UTR/REF GUARD)
-- ------------------------------------------------------------------------------
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
SET search_path = public
AS $$
DECLARE
    v_vendor_name TEXT;
    v_category TEXT;
    v_credit NUMERIC(12, 2) := 0.00;
    v_debit NUMERIC(12, 2) := 0.00;
    v_entry_id UUID;
    v_clean_ref TEXT;
BEGIN
    SELECT name INTO v_vendor_name FROM public.sub_vendors WHERE id = p_vendor_id;
    IF v_vendor_name IS NULL THEN
        RAISE EXCEPTION 'Sub-Vendor with ID % not found.', p_vendor_id;
    END IF;
    IF p_amount <= 0 THEN
        RAISE EXCEPTION 'Transaction amount must be greater than zero.';
    END IF;

    v_clean_ref := TRIM(COALESCE(p_reference_number, ''));
    IF v_clean_ref = '' THEN
        RAISE EXCEPTION 'Reference / UTR number is required.';
    END IF;

    IF UPPER(p_transaction_type) = 'MATERIAL_OUTWARD' THEN
        v_category := 'MATERIAL';
        v_credit := 0.00;
        v_debit := ROUND(p_amount, 2);
    ELSIF UPPER(p_transaction_type) = 'MATERIAL_PAYMENT' THEN
        v_category := 'MATERIAL';
        v_credit := ROUND(p_amount, 2);
        v_debit := 0.00;
    ELSIF UPPER(p_transaction_type) = 'ADVANCE_GIVEN' THEN
        v_category := 'ADVANCE';
        v_credit := 0.00;
        v_debit := ROUND(p_amount, 2);
    ELSIF UPPER(p_transaction_type) = 'ADVANCE_REFUND' THEN
        v_category := 'ADVANCE';
        v_credit := ROUND(p_amount, 2);
        v_debit := 0.00;
    ELSE
        RAISE EXCEPTION 'Invalid transaction type: %', p_transaction_type;
    END IF;

    INSERT INTO public.sub_vendor_account_ledger (
        vendor_id, vendor_name, transaction_date, transaction_type, category,
        credit_amount, debit_amount, running_balance, reference_number, reference_id,
        payment_mode, particulars, remarks, status, created_by
    ) VALUES (
        p_vendor_id, v_vendor_name, p_transaction_date, UPPER(p_transaction_type), v_category,
        v_credit, v_debit, 0.00, v_clean_ref, p_reference_id,
        COALESCE(NULLIF(TRIM(p_payment_mode), ''), 'Bank Transfer'), p_particulars, p_remarks, 'Active', p_created_by
    ) RETURNING id INTO v_entry_id;

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

-- ------------------------------------------------------------------------------
-- 4. NON-RETROACTIVE DUPLICATE REFERENCE / UTR GUARD TRIGGERS
-- Protects NEW/MODIFIED active transactions without blocking existing migration.
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.trg_prevent_duplicate_ledger_ref()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_norm_ref TEXT;
BEGIN
    IF COALESCE(NEW.status, 'Active') <> 'Active' THEN
        RETURN NEW;
    END IF;
    v_norm_ref := UPPER(TRIM(COALESCE(NEW.reference_number, '')));
    IF v_norm_ref = '' OR v_norm_ref = '-' THEN
        RETURN NEW;
    END IF;

    IF EXISTS (
        SELECT 1
        FROM public.sub_vendor_account_ledger l
        WHERE l.id <> NEW.id
          AND l.vendor_id = NEW.vendor_id
          AND l.status = 'Active'
          AND UPPER(TRIM(COALESCE(l.reference_number, ''))) = v_norm_ref
    ) THEN
        RAISE EXCEPTION 'Duplicate active Reference / UTR "%" already exists for this Sub-Vendor.', TRIM(NEW.reference_number);
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_sval_prevent_duplicate_ref ON public.sub_vendor_account_ledger;
CREATE TRIGGER trg_sval_prevent_duplicate_ref
    BEFORE INSERT OR UPDATE ON public.sub_vendor_account_ledger
    FOR EACH ROW
    EXECUTE FUNCTION public.trg_prevent_duplicate_ledger_ref();

CREATE OR REPLACE FUNCTION public.trg_prevent_duplicate_payout_ref()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_norm_ref TEXT;
BEGIN
    IF UPPER(COALESCE(NEW.status, 'Paid')) IN ('CANCELLED', 'REJECTED') THEN
        RETURN NEW;
    END IF;
    v_norm_ref := UPPER(TRIM(COALESCE(NEW.reference_number, '')));
    IF v_norm_ref = '' OR v_norm_ref = '-' THEN
        RETURN NEW;
    END IF;

    IF EXISTS (
        SELECT 1
        FROM public.vendor_payouts vp
        WHERE vp.id <> NEW.id
          AND vp.vendor_id = NEW.vendor_id
          AND UPPER(COALESCE(vp.status, 'Paid')) NOT IN ('CANCELLED', 'REJECTED')
          AND UPPER(TRIM(COALESCE(vp.reference_number, ''))) = v_norm_ref
    ) THEN
        RAISE EXCEPTION 'Duplicate Transaction/UTR Reference "%" already exists in Vendor Payouts.', TRIM(NEW.reference_number);
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_vp_prevent_duplicate_ref ON public.vendor_payouts;
CREATE TRIGGER trg_vp_prevent_duplicate_ref
    BEFORE INSERT OR UPDATE ON public.vendor_payouts
    FOR EACH ROW
    EXECUTE FUNCTION public.trg_prevent_duplicate_payout_ref();

-- ------------------------------------------------------------------------------
-- 5. ATOMIC OUTWARD EDIT / CANCEL SYNC TO MIRRORED LEDGER ENTRIES
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.trg_sync_outward_to_mirrored_ledger()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    -- Update or cancel any mirrored row in sub_vendor_account_ledger
    UPDATE public.sub_vendor_account_ledger l
    SET
        vendor_id = NEW.vendor_id,
        vendor_name = NEW.vendor_name,
        transaction_date = NEW.outward_date,
        credit_amount = 0.00,
        debit_amount = ROUND(COALESCE(NEW.total_value, 0.00), 2),
        reference_number = NEW.outward_number,
        particulars = format('Material Outward Dispatch (%s items, Qty: %s)', COALESCE(NEW.total_items, 0), COALESCE(NEW.total_quantity, 0)),
        remarks = NEW.remarks,
        status = NEW.status,
        cancelled_at = CASE WHEN NEW.status = 'Cancelled' THEN COALESCE(NEW.cancelled_at, timezone('utc'::text, now())) ELSE NULL END,
        cancellation_reason = CASE WHEN NEW.status = 'Cancelled' THEN NEW.cancellation_reason ELSE NULL END,
        updated_at = timezone('utc'::text, now())
    WHERE l.reference_id = NEW.id
       OR (
            UPPER(l.transaction_type) = 'MATERIAL_OUTWARD'
            AND l.vendor_id = OLD.vendor_id
            AND UPPER(TRIM(l.reference_number)) = UPPER(TRIM(OLD.outward_number))
       );

    IF FOUND THEN
        PERFORM public.recalculate_sub_vendor_ledger_balances(NEW.vendor_id);
        IF OLD.vendor_id IS DISTINCT FROM NEW.vendor_id THEN
            PERFORM public.recalculate_sub_vendor_ledger_balances(OLD.vendor_id);
        END IF;
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_svmo_sync_mirrored_ledger ON public.sub_vendor_material_outwards;
CREATE TRIGGER trg_svmo_sync_mirrored_ledger
    AFTER UPDATE ON public.sub_vendor_material_outwards
    FOR EACH ROW
    EXECUTE FUNCTION public.trg_sync_outward_to_mirrored_ledger();

CREATE OR REPLACE FUNCTION public.update_sub_vendor_material_outward(
    p_outward_id UUID,
    p_vendor_id UUID,
    p_outward_date DATE,
    p_remarks TEXT,
    p_items JSONB,
    p_updated_by UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_existing RECORD;
    v_vendor_name TEXT;
    v_total_items INT := 0;
    v_total_qty NUMERIC(12, 2) := 0.00;
    v_subtotal NUMERIC(14, 2) := 0.00;
    v_total_gst NUMERIC(14, 2) := 0.00;
    v_grand_total NUMERIC(14, 2) := 0.00;
    v_item JSONB;
    v_material_id UUID;
    v_material_name TEXT;
    v_unit TEXT;
    v_qty NUMERIC(12, 2);
    v_rate NUMERIC(12, 2);
    v_base NUMERIC(14, 2);
    v_gst_pct NUMERIC(5, 2);
    v_gst_amt NUMERIC(14, 2);
    v_final_price NUMERIC(14, 2);
BEGIN
    SELECT * INTO v_existing FROM public.sub_vendor_material_outwards WHERE id = p_outward_id FOR UPDATE;
    IF NOT FOUND THEN RAISE EXCEPTION 'Material Outward entry not found.'; END IF;
    IF v_existing.status = 'Cancelled' THEN RAISE EXCEPTION 'Cannot edit a Cancelled Material Outward record.'; END IF;

    SELECT name INTO v_vendor_name FROM public.sub_vendors WHERE id = p_vendor_id;
    IF v_vendor_name IS NULL THEN RAISE EXCEPTION 'Sub-Vendor not found.'; END IF;

    DELETE FROM public.sub_vendor_material_outward_items WHERE outward_id = p_outward_id;

    FOR v_item IN SELECT * FROM jsonb_array_elements(p_items)
    LOOP
        BEGIN
            v_material_id := NULLIF(v_item->>'material_id', '')::UUID;
        EXCEPTION WHEN others THEN
            v_material_id := NULL;
        END;
        v_material_name := COALESCE(v_item->>'material_name', 'Unknown Material');
        v_unit := UPPER(COALESCE(v_item->>'unit', 'NOS'));
        v_qty := COALESCE((v_item->>'quantity')::NUMERIC, 0);
        v_rate := COALESCE((v_item->>'unit_rate')::NUMERIC, 0);
        v_gst_pct := COALESCE((v_item->>'gst_percentage')::NUMERIC, 0);

        IF v_qty <= 0 THEN RAISE EXCEPTION 'Quantity for "%" must be greater than zero.', v_material_name; END IF;
        IF v_rate < 0 THEN RAISE EXCEPTION 'Rate for "%" cannot be negative.', v_material_name; END IF;

        v_base := ROUND(v_qty * v_rate, 2);
        v_gst_amt := ROUND(v_base * v_gst_pct / 100.0, 2);
        v_final_price := ROUND(v_base + v_gst_amt, 2);

        INSERT INTO public.sub_vendor_material_outward_items (
            outward_id, material_id, material_name, unit, quantity,
            unit_rate, base_amount, gst_percentage, gst_amount, total_price
        ) VALUES (
            p_outward_id, v_material_id, v_material_name, v_unit, v_qty,
            v_rate, v_base, v_gst_pct, v_gst_amt, v_final_price
        );

        v_total_items := v_total_items + 1;
        v_total_qty := ROUND(v_total_qty + v_qty, 2);
        v_subtotal := ROUND(v_subtotal + v_base, 2);
        v_total_gst := ROUND(v_total_gst + v_gst_amt, 2);
        v_grand_total := ROUND(v_grand_total + v_final_price, 2);
    END LOOP;

    UPDATE public.sub_vendor_material_outwards
    SET vendor_id = p_vendor_id,
        vendor_name = v_vendor_name,
        outward_date = p_outward_date,
        total_items = v_total_items,
        total_quantity = v_total_qty,
        subtotal = v_subtotal,
        total_gst = v_total_gst,
        total_value = v_grand_total,
        remarks = p_remarks,
        updated_at = timezone('utc'::text, now())
    WHERE id = p_outward_id;

    INSERT INTO public.sub_vendor_material_outward_audit (
        outward_id, outward_number, action, description, details, performed_by
    ) VALUES (
        p_outward_id, v_existing.outward_number, 'UPDATE',
        format('Updated outward entry. New total qty: %s, subtotal: %s, gst: %s, grand total: %s', v_total_qty, v_subtotal, v_total_gst, v_grand_total),
        jsonb_build_object('vendor_id', p_vendor_id, 'subtotal', v_subtotal, 'total_gst', v_total_gst, 'grand_total', v_grand_total, 'items', p_items),
        p_updated_by
    );

    RETURN jsonb_build_object('success', true, 'id', p_outward_id, 'subtotal', v_subtotal, 'total_gst', v_total_gst, 'total_value', v_grand_total);
END;
$$;

DROP FUNCTION IF EXISTS public.cancel_sub_vendor_material_outward(UUID, TEXT, UUID);
CREATE OR REPLACE FUNCTION public.cancel_sub_vendor_material_outward(
    p_outward_id UUID,
    p_cancellation_reason TEXT DEFAULT 'Cancelled by Admin',
    p_cancelled_by UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_existing RECORD;
BEGIN
    SELECT * INTO v_existing FROM public.sub_vendor_material_outwards WHERE id = p_outward_id FOR UPDATE;
    IF NOT FOUND THEN RAISE EXCEPTION 'Material Outward entry not found.'; END IF;
    IF v_existing.status = 'Cancelled' THEN RAISE EXCEPTION 'Material Outward entry is already cancelled.'; END IF;

    UPDATE public.sub_vendor_material_outwards
    SET status = 'Cancelled',
        cancelled_at = timezone('utc'::text, now()),
        cancelled_by = p_cancelled_by,
        cancellation_reason = p_cancellation_reason,
        updated_at = timezone('utc'::text, now())
    WHERE id = p_outward_id;

    INSERT INTO public.sub_vendor_material_outward_audit (
        outward_id, outward_number, action, description, details, performed_by
    ) VALUES (
        p_outward_id, v_existing.outward_number, 'CANCEL',
        format('Cancelled outward entry. Reason: %s', COALESCE(p_cancellation_reason, 'None')),
        jsonb_build_object('cancellation_reason', p_cancellation_reason),
        p_cancelled_by
    );

    RETURN jsonb_build_object('success', true, 'id', p_outward_id, 'status', 'Cancelled');
END;
$$;

-- ------------------------------------------------------------------------------
-- 6. STANDARDIZED UNIFIED LEDGER VIEW (STANDARD PASSBOOK POLARITY)
-- Fixes Branch 1..7 Credit (+ Cr) / Debit (- Dr) polarity uniformly across SQL.
-- ------------------------------------------------------------------------------
DROP VIEW IF EXISTS public.v_sub_vendor_unified_ledger CASCADE;

CREATE VIEW public.v_sub_vendor_unified_ledger
WITH (security_invoker = true) AS

-- Branch 1: Explicit Manual & Synced rows in sub_vendor_account_ledger
-- Normalized by transaction_type so legacy rows project standard Passbook signs
SELECT
    'ledger'::TEXT                              AS source_table,
    l.id::TEXT                                  AS id,
    l.vendor_id::TEXT                           AS vendor_id,
    l.vendor_name                               AS vendor_name,
    l.transaction_date                          AS transaction_date,
    UPPER(l.transaction_type)                   AS transaction_type,
    l.category                                  AS category,
    CASE
        WHEN UPPER(l.transaction_type) IN ('MATERIAL_PAYMENT', 'ADVANCE_REFUND')
            THEN ROUND(GREATEST(COALESCE(l.credit_amount, 0.00), COALESCE(l.debit_amount, 0.00))::NUMERIC, 2)
        ELSE 0.00::NUMERIC(14, 2)
    END                                         AS credit_amount,
    CASE
        WHEN UPPER(l.transaction_type) IN ('MATERIAL_OUTWARD', 'ADVANCE_GIVEN')
            THEN ROUND(GREATEST(COALESCE(l.debit_amount, 0.00), COALESCE(l.credit_amount, 0.00))::NUMERIC, 2)
        ELSE 0.00::NUMERIC(14, 2)
    END                                         AS debit_amount,
    l.running_balance::NUMERIC(14, 2)           AS running_balance,
    l.reference_number                          AS reference_number,
    l.reference_id::TEXT                        AS reference_id,
    l.payment_mode                              AS payment_mode,
    l.particulars                               AS particulars,
    l.remarks                                   AS remarks,
    l.status                                    AS status,
    l.created_at                                AS created_at
FROM public.sub_vendor_account_ledger l

UNION ALL

-- Branch 2: Active Material Outward Dispatches not already mirrored in ledger (DEBIT)
SELECT
    'material_outward'::TEXT                    AS source_table,
    'mo_' || mo.id::TEXT                        AS id,
    mo.vendor_id::TEXT                          AS vendor_id,
    mo.vendor_name                              AS vendor_name,
    mo.outward_date                             AS transaction_date,
    'MATERIAL_OUTWARD'::TEXT                    AS transaction_type,
    'MATERIAL'::TEXT                            AS category,
    0.00::NUMERIC(14, 2)                        AS credit_amount,
    COALESCE(mo.total_value, 0.00)::NUMERIC(14, 2) AS debit_amount,
    0.00::NUMERIC(14, 2)                        AS running_balance,
    mo.outward_number                           AS reference_number,
    mo.id::TEXT                                 AS reference_id,
    'Inventory'::TEXT                           AS payment_mode,
    'Material Outward Dispatch (' || mo.total_items || ' items, Qty: ' || mo.total_quantity || ')' AS particulars,
    mo.remarks                                  AS remarks,
    mo.status                                   AS status,
    mo.created_at                               AS created_at
FROM public.sub_vendor_material_outwards mo
WHERE mo.status = 'Active'
  AND NOT EXISTS (
      SELECT 1 FROM public.sub_vendor_account_ledger l2
      WHERE l2.status = 'Active'
        AND (
            l2.reference_id = mo.id
            OR (
                UPPER(l2.transaction_type) = 'MATERIAL_OUTWARD'
                AND l2.vendor_id = mo.vendor_id
                AND UPPER(TRIM(l2.reference_number)) = UPPER(TRIM(mo.outward_number))
            )
        )
  )

UNION ALL

-- Branch 3: Site-wise Material Issues (DEBIT) & Returns (CREDIT)
SELECT
    'vendor_material_transaction'::TEXT         AS source_table,
    'vmt_' || vmt.id::TEXT                      AS id,
    vmt.vendor_id::TEXT                         AS vendor_id,
    COALESCE(sv.name, 'Sub-Vendor')             AS vendor_name,
    vmt.transaction_date                        AS transaction_date,
    CASE
        WHEN UPPER(COALESCE(vmt.transaction_type, 'ISSUE')) = 'RETURN' THEN 'MATERIAL_PAYMENT'
        ELSE 'MATERIAL_OUTWARD'
    END                                         AS transaction_type,
    'MATERIAL'::TEXT                            AS category,
    CASE
        WHEN UPPER(COALESCE(vmt.transaction_type, 'ISSUE')) = 'RETURN' THEN COALESCE(vmt.total_amount, 0.00)
        ELSE 0.00
    END::NUMERIC(14, 2)                         AS credit_amount,
    CASE
        WHEN UPPER(COALESCE(vmt.transaction_type, 'ISSUE')) = 'RETURN' THEN 0.00
        ELSE COALESCE(vmt.total_amount, 0.00)
    END::NUMERIC(14, 2)                         AS debit_amount,
    0.00::NUMERIC(14, 2)                        AS running_balance,
    COALESCE(
        NULLIF(TRIM(vmt.challan_number), ''),
        cr.consumer_no,
        'SITE-' || LEFT(vmt.assignment_id::TEXT, 8)
    )                                           AS reference_number,
    vmt.id::TEXT                                AS reference_id,
    'Inventory'::TEXT                           AS payment_mode,
    CASE
        WHEN UPPER(COALESCE(vmt.transaction_type, 'ISSUE')) = 'RETURN' THEN 'Site Material Return: '
        ELSE 'Site Material Given: '
    END || vmt.item_name || ' (' || vmt.quantity || ' ' || COALESCE(vmt.unit, 'Nos') ||
    CASE WHEN cr.name IS NOT NULL THEN ' | ' || cr.name ELSE '' END || ')' AS particulars,
    vmt.remarks                                 AS remarks,
    'Active'::TEXT                              AS status,
    vmt.created_at                              AS created_at
FROM public.vendor_material_transactions vmt
JOIN public.sub_vendors sv ON sv.id = vmt.vendor_id
LEFT JOIN public.consumer_records cr ON cr.id = vmt.customer_id
WHERE COALESCE(vmt.total_amount, 0.00) > 0
  AND NOT EXISTS (
      SELECT 1 FROM public.sub_vendor_account_ledger l_vmt
      WHERE l_vmt.reference_id = vmt.id AND l_vmt.status = 'Active'
  )

UNION ALL

-- Branch 4: Approved Customer Cash & Bank Loan Credits in vendor_customer_payments (CREDIT)
SELECT
    'customer_payment'::TEXT                    AS source_table,
    'cp_' || cp.id::TEXT                        AS id,
    cp.vendor_id::TEXT                          AS vendor_id,
    COALESCE(cp.vendor_name, sv.name, 'Sub-Vendor') AS vendor_name,
    cp.payment_date                             AS transaction_date,
    'MATERIAL_PAYMENT'::TEXT                    AS transaction_type,
    'MATERIAL'::TEXT                            AS category,
    cp.amount::NUMERIC(14, 2)                   AS credit_amount,
    0.00::NUMERIC(14, 2)                        AS debit_amount,
    0.00::NUMERIC(14, 2)                        AS running_balance,
    COALESCE(
        NULLIF(TRIM(cp.reference_number), ''),
        NULLIF(TRIM(cp.loan_application_id), ''),
        cr.consumer_no,
        '-'
    )                                           AS reference_number,
    cp.id::TEXT                                 AS reference_id,
    CASE
        WHEN cp.payment_mode IN ('Bank Transfer', 'NEFT/RTGS', 'UPI', 'Cheque', 'Cash', 'Inventory')
        THEN cp.payment_mode
        ELSE 'Bank Transfer'
    END                                         AS payment_mode,
    CASE
        WHEN cp.payment_type = 'BANK_LOAN'
            THEN 'Bank Loan Credited (' || COALESCE(NULLIF(TRIM(cp.bank_name), ''), 'Bank') ||
                 COALESCE(' - ' || COALESCE(cp.customer_name, cr.name), '') || ')'
        ELSE 'Customer Cash / Payment Received (' || COALESCE(cp.payment_stage, 'Payment') ||
             COALESCE(' - ' || COALESCE(cp.customer_name, cr.name), '') || ')'
    END                                         AS particulars,
    cp.remarks                                  AS remarks,
    'Active'::TEXT                              AS status,
    cp.created_at                               AS created_at
FROM public.vendor_customer_payments cp
JOIN public.sub_vendors sv ON sv.id = cp.vendor_id
LEFT JOIN public.consumer_records cr ON cr.id = cp.customer_id
WHERE cp.status = 'Approved'
  AND NOT EXISTS (
      SELECT 1 FROM public.sub_vendor_account_ledger l3
      WHERE l3.reference_id = cp.id AND l3.status = 'Active'
  )

UNION ALL

-- Branch 5: Valid Main CRM Customer / Loan Payments for assigned sites (CREDIT)
SELECT
    'crm_customer_payment'::TEXT                AS source_table,
    'cpt_' || cpt.id::TEXT || '_' || LEFT(vsa.id::TEXT, 8) AS id,
    vsa.vendor_id::TEXT                         AS vendor_id,
    COALESCE(sv.name, 'Sub-Vendor')             AS vendor_name,
    cpt.payment_date                            AS transaction_date,
    'MATERIAL_PAYMENT'::TEXT                    AS transaction_type,
    'MATERIAL'::TEXT                            AS category,
    cpt.amount::NUMERIC(14, 2)                  AS credit_amount,
    0.00::NUMERIC(14, 2)                        AS debit_amount,
    0.00::NUMERIC(14, 2)                        AS running_balance,
    COALESCE(NULLIF(TRIM(cpt.reference_number), ''), cr.consumer_no, cpt.consumer_no, '-') AS reference_number,
    cpt.id::TEXT                                AS reference_id,
    CASE
        WHEN cpt.payment_mode IN ('Bank Transfer', 'NEFT/RTGS', 'UPI', 'Cheque', 'Cash', 'Inventory')
        THEN cpt.payment_mode
        ELSE 'Bank Transfer'
    END                                         AS payment_mode,
    CASE
        WHEN LOWER(COALESCE(cpt.remarks, '') || ' ' || COALESCE(cpt.payment_type, '')) LIKE '%loan%'
            THEN 'Bank Loan / Finance Credited (' || COALESCE(cpt.payment_type, 'Loan') ||
                 CASE WHEN cr.name IS NOT NULL THEN ' - ' || cr.name ELSE '' END || ')'
        ELSE 'Customer Payment Received (' || COALESCE(cpt.payment_type, 'Payment') ||
             CASE WHEN cr.name IS NOT NULL THEN ' - ' || cr.name ELSE '' END || ')'
    END                                         AS particulars,
    cpt.remarks                                 AS remarks,
    'Active'::TEXT                              AS status,
    cpt.created_at                              AS created_at
FROM public.customer_payment_transactions cpt
JOIN public.vendor_site_assignments vsa ON vsa.customer_id = cpt.customer_id
JOIN public.sub_vendors sv ON sv.id = vsa.vendor_id
LEFT JOIN public.consumer_records cr ON cr.id = cpt.customer_id
WHERE vsa.status <> 'Cancelled'
  AND cpt.status = 'Valid'
  AND COALESCE(cpt.deleted, false) = false
  AND COALESCE(cpt.verification_status, 'Pending') NOT IN ('Rejected', 'Void')
  AND NOT EXISTS (
      SELECT 1 FROM public.sub_vendor_account_ledger l_cpt
      WHERE l_cpt.reference_id = cpt.id AND l_cpt.status = 'Active'
  )
  AND NOT EXISTS (
      SELECT 1 FROM public.vendor_customer_payments cp_dup
      WHERE cp_dup.assignment_id = vsa.id
        AND cp_dup.status = 'Approved'
        AND (
            (NULLIF(TRIM(cp_dup.reference_number), '') IS NOT NULL
             AND NULLIF(TRIM(cpt.reference_number), '') IS NOT NULL
             AND UPPER(TRIM(cp_dup.reference_number)) = UPPER(TRIM(cpt.reference_number)))
            OR (cp_dup.amount = cpt.amount AND ABS(cp_dup.payment_date::DATE - cpt.payment_date::DATE) <= 1)
        )
  )

UNION ALL

-- Branch 6: Assignment / Consumer Paid Residual Fallback (FIXED: CREDIT, NOT DEBIT)
SELECT
    'assignment_collection'::TEXT               AS source_table,
    'a_coll_' || vsa.id::TEXT                   AS id,
    vsa.vendor_id::TEXT                         AS vendor_id,
    COALESCE(sv.name, 'Sub-Vendor')             AS vendor_name,
    vsa.assigned_date                           AS transaction_date,
    'MATERIAL_PAYMENT'::TEXT                    AS transaction_type,
    'MATERIAL'::TEXT                            AS category,
    ROUND((
        GREATEST(COALESCE(vsa.total_customer_received, 0.00), COALESCE(cr.paid_amount, 0.00))
        - COALESCE((
            SELECT SUM(cp2.amount)
            FROM public.vendor_customer_payments cp2
            WHERE cp2.assignment_id = vsa.id AND cp2.status = 'Approved'
        ), 0.00)
        - COALESCE((
            SELECT SUM(cpt2.amount)
            FROM public.customer_payment_transactions cpt2
            WHERE cpt2.customer_id = vsa.customer_id
              AND cpt2.status = 'Valid'
              AND COALESCE(cpt2.deleted, false) = false
              AND COALESCE(cpt2.verification_status, 'Pending') NOT IN ('Rejected', 'Void')
              AND NOT EXISTS (
                  SELECT 1 FROM public.vendor_customer_payments cp_dup2
                  WHERE cp_dup2.assignment_id = vsa.id
                    AND cp_dup2.status = 'Approved'
                    AND (
                        (NULLIF(TRIM(cp_dup2.reference_number), '') IS NOT NULL
                         AND NULLIF(TRIM(cpt2.reference_number), '') IS NOT NULL
                         AND UPPER(TRIM(cp_dup2.reference_number)) = UPPER(TRIM(cpt2.reference_number)))
                        OR (cp_dup2.amount = cpt2.amount AND ABS(cp_dup2.payment_date::DATE - cpt2.payment_date::DATE) <= 1)
                    )
              )
        ), 0.00)
    )::NUMERIC, 2)                              AS credit_amount,
    0.00::NUMERIC(14, 2)                        AS debit_amount,
    0.00::NUMERIC(14, 2)                        AS running_balance,
    COALESCE(NULLIF(TRIM(vsa.loan_application_id), ''), cr.consumer_no, 'COLL-' || LEFT(vsa.id::TEXT, 8)) AS reference_number,
    vsa.id::TEXT                                AS reference_id,
    CASE WHEN COALESCE(vsa.total_loan_credited, 0.00) > 0 THEN 'Bank Transfer' ELSE 'Cash' END AS payment_mode,
    CASE
        WHEN COALESCE(vsa.total_loan_credited, 0.00) > 0
            THEN 'Site Loan & Customer Collection (' || COALESCE(cr.name, 'Site') || ' | Loan: Rs. ' || ROUND(vsa.total_loan_credited, 2) || ')'
        ELSE 'Site Customer Collection (' || COALESCE(cr.name, 'Site') || ')'
    END                                         AS particulars,
    'Auto-synced residual from Site Assignment / Consumer Paid Amount'::TEXT AS remarks,
    'Active'::TEXT                              AS status,
    vsa.created_at                              AS created_at
FROM public.vendor_site_assignments vsa
JOIN public.sub_vendors sv ON sv.id = vsa.vendor_id
LEFT JOIN public.consumer_records cr ON cr.id = vsa.customer_id
WHERE vsa.status <> 'Cancelled'
  AND NOT EXISTS (
      SELECT 1 FROM public.sub_vendor_account_ledger l_a
      WHERE l_a.reference_id = vsa.id AND l_a.status = 'Active'
  )
  AND (
      GREATEST(COALESCE(vsa.total_customer_received, 0.00), COALESCE(cr.paid_amount, 0.00))
      - COALESCE((
          SELECT SUM(cp2.amount)
          FROM public.vendor_customer_payments cp2
          WHERE cp2.assignment_id = vsa.id AND cp2.status = 'Approved'
      ), 0.00)
      - COALESCE((
          SELECT SUM(cpt2.amount)
          FROM public.customer_payment_transactions cpt2
          WHERE cpt2.customer_id = vsa.customer_id
            AND cpt2.status = 'Valid'
            AND COALESCE(cpt2.deleted, false) = false
            AND COALESCE(cpt2.verification_status, 'Pending') NOT IN ('Rejected', 'Void')
            AND NOT EXISTS (
                SELECT 1 FROM public.vendor_customer_payments cp_dup2
                WHERE cp_dup2.assignment_id = vsa.id
                  AND cp_dup2.status = 'Approved'
                  AND (
                      (NULLIF(TRIM(cp_dup2.reference_number), '') IS NOT NULL
                       AND NULLIF(TRIM(cpt2.reference_number), '') IS NOT NULL
                       AND UPPER(TRIM(cp_dup2.reference_number)) = UPPER(TRIM(cpt2.reference_number)))
                      OR (cp_dup2.amount = cpt2.amount AND ABS(cp_dup2.payment_date::DATE - cpt2.payment_date::DATE) <= 1)
                  )
            )
      ), 0.00)
  ) > 0.01

UNION ALL

-- Branch 7: Approved/Paid Vendor Payouts not already in sub_vendor_account_ledger (DEBIT)
SELECT
    'vendor_payout'::TEXT                       AS source_table,
    'vp_' || vp.id::TEXT                        AS id,
    vp.vendor_id::TEXT                          AS vendor_id,
    COALESCE(vp.vendor_name, sv2.name, 'Sub-Vendor') AS vendor_name,
    vp.payout_date                              AS transaction_date,
    'ADVANCE_GIVEN'::TEXT                       AS transaction_type,
    'ADVANCE'::TEXT                             AS category,
    0.00::NUMERIC(14, 2)                        AS credit_amount,
    vp.amount::NUMERIC(14, 2)                   AS debit_amount,
    0.00::NUMERIC(14, 2)                        AS running_balance,
    COALESCE(NULLIF(TRIM(vp.reference_number), ''), '-') AS reference_number,
    vp.id::TEXT                                 AS reference_id,
    CASE
        WHEN vp.payment_mode IN ('Bank Transfer', 'NEFT/RTGS', 'UPI', 'Cheque', 'Cash', 'Inventory')
        THEN vp.payment_mode
        ELSE 'Bank Transfer'
    END                                         AS payment_mode,
    'Payout / Advance to Sub-Vendor'            AS particulars,
    vp.remarks                                  AS remarks,
    'Active'::TEXT                              AS status,
    vp.created_at                               AS created_at
FROM public.vendor_payouts vp
JOIN public.sub_vendors sv2 ON sv2.id = vp.vendor_id
WHERE UPPER(COALESCE(vp.status, 'Paid')) IN ('APPROVED', 'PAID')
  AND NOT EXISTS (
      SELECT 1 FROM public.sub_vendor_account_ledger l_vp
      WHERE l_vp.reference_id = vp.id AND l_vp.status = 'Active'
  );

GRANT SELECT ON public.v_sub_vendor_unified_ledger TO authenticated, service_role;

-- ------------------------------------------------------------------------------
-- 7. PERIODIC OUTWARD RECONCILIATION VIEW (DAILY, MONTHLY, INDIAN FY Apr-Mar)
-- ------------------------------------------------------------------------------
DROP VIEW IF EXISTS public.v_sub_vendor_outward_period_summary CASCADE;
CREATE VIEW public.v_sub_vendor_outward_period_summary
WITH (security_invoker = true) AS
SELECT
    mo.vendor_id,
    mo.vendor_name,
    TO_CHAR(mo.outward_date, 'YYYY-MM-DD') AS day_key,
    TO_CHAR(mo.outward_date, 'YYYY-MM')    AS month_key,
    CASE
        WHEN EXTRACT(MONTH FROM mo.outward_date) >= 4
            THEN 'FY ' || EXTRACT(YEAR FROM mo.outward_date)::INT || '-' || RIGHT((EXTRACT(YEAR FROM mo.outward_date)::INT + 1)::TEXT, 2)
        ELSE 'FY ' || (EXTRACT(YEAR FROM mo.outward_date)::INT - 1) || '-' || RIGHT(EXTRACT(YEAR FROM mo.outward_date)::INT::TEXT, 2)
    END                                    AS financial_year_key,
    COUNT(*)                               AS outward_count,
    ROUND(SUM(COALESCE(mo.total_quantity, 0.00))::NUMERIC, 2) AS total_quantity,
    ROUND(SUM(COALESCE(mo.subtotal, 0.00))::NUMERIC, 2)       AS total_subtotal,
    ROUND(SUM(COALESCE(mo.total_gst, 0.00))::NUMERIC, 2)      AS total_gst,
    ROUND(SUM(COALESCE(mo.total_value, 0.00))::NUMERIC, 2)    AS total_value
FROM public.sub_vendor_material_outwards mo
WHERE mo.status = 'Active'
GROUP BY 1, 2, 3, 4, 5;

GRANT SELECT ON public.v_sub_vendor_outward_period_summary TO authenticated, service_role;

-- ------------------------------------------------------------------------------
-- 8. UPDATED CENTRAL RECONCILIATION RPC & NON-DESTRUCTIVE AUDIT CHECK VIEW
-- ------------------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.get_sub_vendor_central_reconciliation(UUID);
CREATE OR REPLACE FUNCTION public.get_sub_vendor_central_reconciliation(
    p_vendor_id UUID DEFAULT NULL
)
RETURNS TABLE (
    vendor_id                       TEXT,
    vendor_name                     TEXT,
    vendor_code                     TEXT,
    site_count                      BIGINT,
    total_site_quotation            NUMERIC(14, 2),
    total_customer_collection       NUMERIC(14, 2),
    total_loan_credited             NUMERIC(14, 2),
    total_site_material_cost        NUMERIC(14, 2),
    total_unallocated_outward_cost  NUMERIC(14, 2),
    total_direct_vendor_payments    NUMERIC(14, 2),
    total_direct_advances_given     NUMERIC(14, 2),
    total_direct_advance_refunds    NUMERIC(14, 2),
    total_vendor_payouts            NUMERIC(14, 2),
    total_siya_charges              NUMERIC(14, 2),
    total_other_expenses            NUMERIC(14, 2),
    material_receivable_balance     NUMERIC(14, 2),
    advance_balance                 NUMERIC(14, 2),
    ledger_total_credit             NUMERIC(14, 2),
    ledger_total_debit              NUMERIC(14, 2),
    ledger_net_balance              NUMERIC(14, 2)
)
LANGUAGE sql
STABLE
SECURITY INVOKER
AS $$
    WITH site_agg AS (
        SELECT
            vsa.vendor_id,
            COUNT(*) FILTER (WHERE vsa.status <> 'Cancelled') AS site_count,
            COALESCE(SUM(CASE WHEN vsa.status <> 'Cancelled'
                THEN GREATEST(COALESCE(vsa.total_customer_site_amount, 0.00), COALESCE(cr.total_amount, 0.00))
                ELSE 0.00 END), 0.00) AS total_site_quotation,
            COALESCE(SUM(CASE WHEN vsa.status <> 'Cancelled'
                THEN GREATEST(COALESCE(vsa.total_customer_received, 0.00), COALESCE(cr.paid_amount, 0.00))
                ELSE 0.00 END), 0.00) AS total_customer_collection,
            COALESCE(SUM(CASE WHEN vsa.status <> 'Cancelled' THEN COALESCE(vsa.total_loan_credited, 0.00) ELSE 0.00 END), 0.00) AS total_loan_credited,
            COALESCE(SUM(CASE WHEN vsa.status <> 'Cancelled' THEN COALESCE(vsa.vendor_charges, 0.00) ELSE 0.00 END), 0.00) AS total_siya_charges,
            COALESCE(SUM(CASE WHEN vsa.status <> 'Cancelled' THEN COALESCE(vsa.other_expenses, 0.00) ELSE 0.00 END), 0.00) AS total_other_expenses
        FROM public.vendor_site_assignments vsa
        LEFT JOIN public.consumer_records cr ON cr.id = vsa.customer_id
        GROUP BY vsa.vendor_id
    ),
    vmt_agg AS (
        SELECT
            vmt.vendor_id,
            COALESCE(SUM(
                CASE
                    WHEN UPPER(COALESCE(vmt.transaction_type, 'ISSUE')) = 'RETURN' THEN -COALESCE(vmt.total_amount, 0.00)
                    ELSE COALESCE(vmt.total_amount, 0.00)
                END
            ), 0.00) AS total_site_material_cost
        FROM public.vendor_material_transactions vmt
        GROUP BY vmt.vendor_id
    ),
    mo_agg AS (
        SELECT
            mo.vendor_id,
            COALESCE(SUM(CASE WHEN mo.status = 'Active' THEN COALESCE(mo.total_value, 0.00) ELSE 0.00 END), 0.00) AS total_unallocated_outward_cost
        FROM public.sub_vendor_material_outwards mo
        GROUP BY mo.vendor_id
    ),
    direct_ledger_agg AS (
        SELECT
            l.vendor_id,
            COALESCE(SUM(CASE WHEN l.status = 'Active' AND UPPER(l.transaction_type) = 'MATERIAL_PAYMENT' THEN GREATEST(l.credit_amount, l.debit_amount) ELSE 0.00 END), 0.00) AS total_direct_vendor_payments,
            COALESCE(SUM(CASE WHEN l.status = 'Active' AND UPPER(l.transaction_type) = 'ADVANCE_GIVEN'    THEN GREATEST(l.debit_amount, l.credit_amount) ELSE 0.00 END), 0.00) AS total_direct_advances_given,
            COALESCE(SUM(CASE WHEN l.status = 'Active' AND UPPER(l.transaction_type) = 'ADVANCE_REFUND'   THEN GREATEST(l.credit_amount, l.debit_amount) ELSE 0.00 END), 0.00) AS total_direct_advance_refunds
        FROM public.sub_vendor_account_ledger l
        GROUP BY l.vendor_id
    ),
    payout_agg AS (
        SELECT
            vp.vendor_id,
            COALESCE(SUM(CASE WHEN UPPER(COALESCE(vp.status, 'Paid')) IN ('APPROVED', 'PAID') THEN vp.amount ELSE 0.00 END), 0.00) AS total_vendor_payouts
        FROM public.vendor_payouts vp
        GROUP BY vp.vendor_id
    ),
    ledger_agg AS (
        SELECT
            u.vendor_id,
            COALESCE(SUM(CASE WHEN u.status = 'Active' THEN u.credit_amount ELSE 0.00 END), 0.00) AS total_credit,
            COALESCE(SUM(CASE WHEN u.status = 'Active' THEN u.debit_amount  ELSE 0.00 END), 0.00) AS total_debit,
            COALESCE(SUM(CASE WHEN u.status = 'Active' THEN u.credit_amount - u.debit_amount ELSE 0.00 END), 0.00) AS net_balance,
            COALESCE(SUM(CASE WHEN u.status = 'Active' AND u.transaction_type = 'MATERIAL_OUTWARD' THEN u.debit_amount ELSE 0.00 END), 0.00) AS outward_dr,
            COALESCE(SUM(CASE WHEN u.status = 'Active' AND u.transaction_type = 'MATERIAL_PAYMENT' THEN u.credit_amount ELSE 0.00 END), 0.00) AS payment_cr,
            COALESCE(SUM(CASE WHEN u.status = 'Active' AND u.transaction_type = 'ADVANCE_GIVEN'    THEN u.debit_amount ELSE 0.00 END), 0.00) AS advance_dr,
            COALESCE(SUM(CASE WHEN u.status = 'Active' AND u.transaction_type = 'ADVANCE_REFUND'   THEN u.credit_amount ELSE 0.00 END), 0.00) AS refund_cr
        FROM public.v_sub_vendor_unified_ledger u
        GROUP BY u.vendor_id
    )
    SELECT
        sv.id::TEXT                                                         AS vendor_id,
        sv.name                                                             AS vendor_name,
        sv.vendor_code                                                      AS vendor_code,
        COALESCE(sa.site_count, 0)                                          AS site_count,
        ROUND(COALESCE(sa.total_site_quotation, 0.00)::NUMERIC, 2)          AS total_site_quotation,
        ROUND(COALESCE(sa.total_customer_collection, 0.00)::NUMERIC, 2)     AS total_customer_collection,
        ROUND(COALESCE(sa.total_loan_credited, 0.00)::NUMERIC, 2)           AS total_loan_credited,
        ROUND(COALESCE(vm.total_site_material_cost, 0.00)::NUMERIC, 2)      AS total_site_material_cost,
        ROUND(COALESCE(mo.total_unallocated_outward_cost, 0.00)::NUMERIC, 2) AS total_unallocated_outward_cost,
        ROUND(COALESCE(dl.total_direct_vendor_payments, 0.00)::NUMERIC, 2)  AS total_direct_vendor_payments,
        ROUND(COALESCE(dl.total_direct_advances_given, 0.00)::NUMERIC, 2)   AS total_direct_advances_given,
        ROUND(COALESCE(dl.total_direct_advance_refunds, 0.00)::NUMERIC, 2)  AS total_direct_advance_refunds,
        ROUND(COALESCE(pa.total_vendor_payouts, 0.00)::NUMERIC, 2)          AS total_vendor_payouts,
        ROUND(COALESCE(sa.total_siya_charges, 0.00)::NUMERIC, 2)            AS total_siya_charges,
        ROUND(COALESCE(sa.total_other_expenses, 0.00)::NUMERIC, 2)          AS total_other_expenses,
        ROUND((COALESCE(la.outward_dr, 0.00) - COALESCE(la.payment_cr, 0.00))::NUMERIC, 2) AS material_receivable_balance,
        ROUND((COALESCE(la.advance_dr, 0.00) - COALESCE(la.refund_cr, 0.00))::NUMERIC, 2)  AS advance_balance,
        ROUND(COALESCE(la.total_credit, 0.00)::NUMERIC, 2)                  AS ledger_total_credit,
        ROUND(COALESCE(la.total_debit, 0.00)::NUMERIC, 2)                   AS ledger_total_debit,
        ROUND(COALESCE(la.net_balance, 0.00)::NUMERIC, 2)                   AS ledger_net_balance
    FROM public.sub_vendors sv
    LEFT JOIN site_agg sa         ON sa.vendor_id = sv.id
    LEFT JOIN vmt_agg vm          ON vm.vendor_id = sv.id
    LEFT JOIN mo_agg mo           ON mo.vendor_id = sv.id
    LEFT JOIN direct_ledger_agg dl ON dl.vendor_id = sv.id
    LEFT JOIN payout_agg pa       ON pa.vendor_id = sv.id
    LEFT JOIN ledger_agg la       ON la.vendor_id = sv.id::TEXT
    WHERE (p_vendor_id IS NULL OR sv.id = p_vendor_id)
    ORDER BY sv.name;
$$;

GRANT EXECUTE ON FUNCTION public.get_sub_vendor_central_reconciliation(UUID) TO authenticated, service_role;

-- Audit Check View: highlights anomalies for manual review WITHOUT modifying history
DROP VIEW IF EXISTS public.v_sub_vendor_audit_check CASCADE;
CREATE VIEW public.v_sub_vendor_audit_check
WITH (security_invoker = true) AS

-- 1. Historical legacy ledger polarity rows (flagged only, not overwritten)
SELECT
    'historical_inverted_polarity'::TEXT AS issue_type,
    l.id::TEXT                           AS record_id,
    l.vendor_id::TEXT                    AS vendor_id,
    NULL::TEXT                           AS customer_id,
    GREATEST(l.credit_amount, l.debit_amount) AS amount,
    l.transaction_date::TEXT             AS date_field,
    format('Row type %s stored under legacy Cr=%s/Dr=%s (normalized cleanly at query/UI layer)', l.transaction_type, l.credit_amount, l.debit_amount) AS description
FROM public.sub_vendor_account_ledger l
WHERE l.status = 'Active'
  AND (
      (UPPER(l.transaction_type) IN ('MATERIAL_OUTWARD', 'ADVANCE_GIVEN') AND l.credit_amount > 0 AND l.debit_amount = 0)
      OR (UPPER(l.transaction_type) IN ('MATERIAL_PAYMENT', 'ADVANCE_REFUND') AND l.debit_amount > 0 AND l.credit_amount = 0)
  )

UNION ALL

-- 2. Duplicate active UTR / reference numbers in ledger
SELECT
    'duplicate_ledger_ref'::TEXT         AS issue_type,
    MIN(l.id::TEXT)                      AS record_id,
    l.vendor_id::TEXT                    AS vendor_id,
    NULL::TEXT                           AS customer_id,
    SUM(GREATEST(l.credit_amount, l.debit_amount)) AS amount,
    MAX(l.transaction_date)::TEXT        AS date_field,
    format('Duplicate active Ref "%s" (%s rows)', UPPER(TRIM(l.reference_number)), COUNT(*)) AS description
FROM public.sub_vendor_account_ledger l
WHERE l.status = 'Active'
  AND NULLIF(TRIM(l.reference_number), '') IS NOT NULL
  AND TRIM(l.reference_number) <> '-'
GROUP BY l.vendor_id, UPPER(TRIM(l.reference_number))
HAVING COUNT(*) > 1

UNION ALL

-- 3. Outward header vs item sum mismatch
SELECT
    'outward_header_item_mismatch'::TEXT AS issue_type,
    mo.id::TEXT                          AS record_id,
    mo.vendor_id::TEXT                   AS vendor_id,
    NULL::TEXT                           AS customer_id,
    mo.total_value                       AS amount,
    mo.outward_date::TEXT                AS date_field,
    format('Outward %s header=%s vs items_sum=%s', mo.outward_number, mo.total_value, COALESCE(SUM(i.total_price), 0.00)) AS description
FROM public.sub_vendor_material_outwards mo
LEFT JOIN public.sub_vendor_material_outward_items i ON i.outward_id = mo.id
WHERE mo.status = 'Active'
GROUP BY mo.id, mo.vendor_id, mo.outward_number, mo.outward_date, mo.total_value
HAVING ABS(mo.total_value - COALESCE(SUM(i.total_price), 0.00)) > 0.05

UNION ALL

-- 4. Mirrored ledger active when outward is already Cancelled
SELECT
    'stale_cancelled_outward_ledger'::TEXT AS issue_type,
    l.id::TEXT                             AS record_id,
    l.vendor_id::TEXT                      AS vendor_id,
    NULL::TEXT                             AS customer_id,
    GREATEST(l.credit_amount, l.debit_amount) AS amount,
    l.transaction_date::TEXT               AS date_field,
    format('Outward %s is Cancelled but mirrored ledger row %s is still Active', mo.outward_number, l.id) AS description
FROM public.sub_vendor_account_ledger l
JOIN public.sub_vendor_material_outwards mo ON mo.id = l.reference_id
WHERE mo.status = 'Cancelled'
  AND l.status = 'Active'

UNION ALL

-- 5. Approved customer payments on Cancelled site assignments
SELECT
    'cancelled_assignment_payment'::TEXT AS issue_type,
    cp.id::TEXT                          AS record_id,
    cp.vendor_id::TEXT                   AS vendor_id,
    cp.customer_id::TEXT                 AS customer_id,
    cp.amount                            AS amount,
    cp.payment_date::TEXT                AS date_field,
    'Approved customer payment attached to a Cancelled site assignment' AS description
FROM public.vendor_customer_payments cp
JOIN public.vendor_site_assignments vsa ON vsa.id = cp.assignment_id
WHERE vsa.status = 'Cancelled'
  AND cp.status = 'Approved';

GRANT SELECT ON public.v_sub_vendor_audit_check TO authenticated, service_role;

GRANT ALL ON public.sub_vendor_material_outwards TO authenticated, anon, service_role;
GRANT ALL ON public.sub_vendor_material_outward_items TO authenticated, anon, service_role;
GRANT ALL ON public.sub_vendor_material_outward_audit TO authenticated, anon, service_role;
GRANT ALL ON public.sub_vendor_account_ledger TO authenticated, anon, service_role;
GRANT EXECUTE ON FUNCTION public.record_sub_vendor_ledger_entry TO authenticated, anon, service_role;
GRANT EXECUTE ON FUNCTION public.recalculate_sub_vendor_ledger_balances TO authenticated, anon, service_role;
GRANT EXECUTE ON FUNCTION public.update_sub_vendor_material_outward TO authenticated, anon, service_role;
GRANT EXECUTE ON FUNCTION public.cancel_sub_vendor_material_outward TO authenticated, anon, service_role;

NOTIFY pgrst, 'reload schema';
