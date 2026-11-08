-- ==============================================================================
-- Migration: 20261108000038_sub_vendor_settlement_calculator.sql
-- Module: Sub-Vendor Final Settlement & Payout Calculator
-- SIYA INFOTECH & SOLAR ENERGY
-- Description:
--   1. Creates vendor_settlements table storing complete contractual settlements.
--   2. Supports Model A (Net Balance), Model B (Fixed Fee), and Model C (Profit Share).
--   3. Calculates output GST, input tax credit, dynamic materials, vendor charges,
--      expenses, previous payouts, and exact final amount payable / recoverable.
--   4. Links approval to vendor_site_assignments settlement status.
--   5. Enforces strict RLS: Admin Full Control, Sub-Vendor View Only.
-- ==============================================================================

-- 0. Ensure consumer_records has village_city and district columns
ALTER TABLE public.consumer_records ADD COLUMN IF NOT EXISTS village_city TEXT;
ALTER TABLE public.consumer_records ADD COLUMN IF NOT EXISTS district TEXT;

CREATE TABLE IF NOT EXISTS public.vendor_settlements (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    assignment_id UUID NOT NULL REFERENCES public.vendor_site_assignments(id) ON DELETE CASCADE,
    vendor_id UUID NOT NULL REFERENCES public.sub_vendors(id) ON DELETE CASCADE,
    customer_id UUID NOT NULL REFERENCES public.consumer_records(id) ON DELETE CASCADE,
    calculation_date DATE NOT NULL DEFAULT CURRENT_DATE,
    
    -- Quotation & Loan Planning
    total_quotation NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    expected_loan_percent NUMERIC(5, 2) NOT NULL DEFAULT 90.00,
    expected_loan_amount NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    loan_difference_percent NUMERIC(5, 2) NOT NULL DEFAULT 10.00,
    loan_difference_amount NUMERIC(12, 2) NOT NULL DEFAULT 0.00,

    -- Actual Collections
    actual_loan_credited NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    actual_customer_contribution NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    total_actual_collected NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    pending_customer_receivable NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    pending_loan_disbursement NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    pending_customer_contribution NUMERIC(12, 2) NOT NULL DEFAULT 0.00,

    -- GST Accounting (No Double Deduction)
    output_gst_rate NUMERIC(5, 2) NOT NULL DEFAULT 13.80,
    taxable_revenue NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    output_gst_liability NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    material_taxable NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    eligible_input_gst_credit NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    net_gst_liability NUMERIC(12, 2) NOT NULL DEFAULT 0.00,

    -- Dynamic Material & Operational Deductions
    material_cost NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    siya_vendor_charges NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    other_approved_expenses NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    total_deductions NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    gross_margin NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    net_profit NUMERIC(12, 2) NOT NULL DEFAULT 0.00,

    -- Settlement Mode: Model A (Net Balance), Model B (Fixed Fee), Model C (Profit Share)
    settlement_mode TEXT NOT NULL DEFAULT 'NET_BALANCE' CHECK (settlement_mode IN ('NET_BALANCE', 'FIXED_FEE', 'PROFIT_SHARE')),
    fixed_agreed_fee NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    vendor_profit_share_percent NUMERIC(5, 2) NOT NULL DEFAULT 70.00,
    sub_vendor_gross_entitlement NUMERIC(12, 2) NOT NULL DEFAULT 0.00,

    -- Previous Payments & Adjustments
    previous_payouts_paid NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    approved_adjustments NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    adjustment_remarks TEXT,

    -- Final Payout / Recovery
    final_payout_payable NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    is_recoverable BOOLEAN NOT NULL DEFAULT false,
    amount_payable_to_vendor NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    amount_recoverable_from_vendor NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    potential_future_payout NUMERIC(12, 2) NOT NULL DEFAULT 0.00,

    -- Approval & Audit Status
    status TEXT NOT NULL DEFAULT 'Draft' CHECK (status IN ('Draft', 'Pending_Approval', 'Approved', 'Settled')),
    is_approved BOOLEAN NOT NULL DEFAULT false,
    approved_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    approved_at TIMESTAMPTZ,
    notes TEXT,
    created_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),

    CONSTRAINT uq_vendor_site_settlement UNIQUE (assignment_id)
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_vendor_settlements_assignment_id ON public.vendor_settlements (assignment_id);
CREATE INDEX IF NOT EXISTS idx_vendor_settlements_vendor_id ON public.vendor_settlements (vendor_id);
CREATE INDEX IF NOT EXISTS idx_vendor_settlements_customer_id ON public.vendor_settlements (customer_id);
CREATE INDEX IF NOT EXISTS idx_vendor_settlements_status ON public.vendor_settlements (status);

-- Trigger: When a settlement is approved, sync with vendor_site_assignments
CREATE OR REPLACE FUNCTION public.sync_approved_vendor_settlement()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF NEW.is_approved = true AND (OLD.is_approved IS NULL OR OLD.is_approved = false) THEN
        UPDATE public.vendor_site_assignments
        SET
            settlement_approved = true,
            settlement_approved_by = COALESCE(NEW.approved_by, auth.uid()),
            settlement_approved_at = COALESCE(NEW.approved_at, timezone('utc'::text, now())),
            status = 'Settled',
            updated_at = timezone('utc'::text, now())
        WHERE id = NEW.assignment_id;
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_sync_approved_vendor_settlement ON public.vendor_settlements;
CREATE TRIGGER trg_sync_approved_vendor_settlement
AFTER INSERT OR UPDATE ON public.vendor_settlements
FOR EACH ROW
EXECUTE FUNCTION public.sync_approved_vendor_settlement();

-- Enable Row Level Security (RLS)
ALTER TABLE public.vendor_settlements ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Admin full control on vendor settlements" ON public.vendor_settlements;
DROP POLICY IF EXISTS "Sub-vendors view their own settlements" ON public.vendor_settlements;

-- Policy: Admin Full Access
CREATE POLICY "Admin full control on vendor settlements"
    ON public.vendor_settlements
    FOR ALL
    TO authenticated
    USING (
        (SELECT public.is_admin())
        OR (auth.jwt()->>'role') IN ('admin', 'super_admin')
    )
    WITH CHECK (
        (SELECT public.is_admin())
        OR (auth.jwt()->>'role') IN ('admin', 'super_admin')
    );

-- Policy: Sub-vendors can view only their own approved settlements
CREATE POLICY "Sub-vendors view their own settlements"
    ON public.vendor_settlements
    FOR SELECT
    TO authenticated
    USING (
        vendor_id IN (
            SELECT id FROM public.sub_vendors
            WHERE auth_user_id = auth.uid()
               OR mobile = (auth.jwt()->>'phone')
        )
    );

-- Grants
GRANT ALL ON public.vendor_settlements TO authenticated, anon, service_role;

-- Reload schema cache in PostgREST
NOTIFY pgrst, 'reload schema';
