-- ==============================================================================
-- Migration: 20261108000037_sub_vendor_customer_payments.sql
-- Module: Sub-Vendor Customer Payment Tracking & Bank Loan Credit Management
-- SIYA INFOTECH & SOLAR ENERGY
-- Description:
--   1. Expands vendor_site_assignments with Payment Type & Loan tracking fields.
--   2. Creates vendor_customer_payments table to record Cash installments and
--      Bank Loan Credits (with bank name, loan app ID, UTR, proof attachment).
--   3. Auto-calculates totals and updates loan status via trigger.
--   4. Enforces strict RLS: Admin Full Control, Sub-Vendor View Only.
--   5. Prevents duplicate transaction UTR entries.
-- ==============================================================================

-- 1. Add Payment Type & Loan tracking fields to vendor_site_assignments
ALTER TABLE public.vendor_site_assignments
    ADD COLUMN IF NOT EXISTS payment_type TEXT NOT NULL DEFAULT 'Cash Customer',
    ADD COLUMN IF NOT EXISTS total_customer_site_amount NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    ADD COLUMN IF NOT EXISTS loan_bank_name TEXT,
    ADD COLUMN IF NOT EXISTS loan_application_id TEXT,
    ADD COLUMN IF NOT EXISTS loan_applied_amount NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    ADD COLUMN IF NOT EXISTS loan_sanctioned_amount NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    ADD COLUMN IF NOT EXISTS loan_status TEXT NOT NULL DEFAULT 'Not Required',
    ADD COLUMN IF NOT EXISTS total_cash_received NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    ADD COLUMN IF NOT EXISTS total_loan_credited NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    ADD COLUMN IF NOT EXISTS total_customer_received NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    ADD COLUMN IF NOT EXISTS customer_outstanding NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    ADD COLUMN IF NOT EXISTS customer_payment_status TEXT NOT NULL DEFAULT 'Pending';

-- Add check constraints safely
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'chk_vsa_payment_type'
    ) THEN
        ALTER TABLE public.vendor_site_assignments
            ADD CONSTRAINT chk_vsa_payment_type
            CHECK (payment_type IN ('Cash Customer', 'Bank Loan Customer', 'Part Cash + Part Loan'));
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'chk_vsa_loan_status'
    ) THEN
        ALTER TABLE public.vendor_site_assignments
            ADD CONSTRAINT chk_vsa_loan_status
            CHECK (loan_status IN ('Not Required', 'Applied', 'Sanctioned', 'Partially Credited', 'Fully Credited'));
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'chk_vsa_customer_payment_status'
    ) THEN
        ALTER TABLE public.vendor_site_assignments
            ADD CONSTRAINT chk_vsa_customer_payment_status
            CHECK (customer_payment_status IN ('Pending', 'Partial', 'Paid'));
    END IF;
END $$;

-- 2. Create vendor_customer_payments table
CREATE TABLE IF NOT EXISTS public.vendor_customer_payments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    assignment_id UUID NOT NULL REFERENCES public.vendor_site_assignments(id) ON DELETE CASCADE,
    vendor_id UUID NOT NULL REFERENCES public.sub_vendors(id) ON DELETE CASCADE,
    customer_id UUID NOT NULL REFERENCES public.consumer_records(id) ON DELETE CASCADE,
    payment_type TEXT NOT NULL CHECK (payment_type IN ('CASH', 'BANK_LOAN')),
    payment_stage TEXT NOT NULL CHECK (payment_stage IN ('ADVANCE', 'PARTIAL', 'FINAL', 'LOAN_CREDIT')),
    amount NUMERIC(12, 2) NOT NULL CHECK (amount > 0),
    payment_date DATE NOT NULL DEFAULT CURRENT_DATE,
    payment_mode TEXT NOT NULL DEFAULT 'Bank Transfer',
    reference_number TEXT,
    bank_name TEXT,
    loan_application_id TEXT,
    attachment_url TEXT,
    remarks TEXT,
    status TEXT NOT NULL DEFAULT 'Approved' CHECK (status IN ('Pending', 'Approved', 'Rejected')),
    approved_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    approved_at TIMESTAMPTZ,
    created_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_vcp_assignment_id ON public.vendor_customer_payments (assignment_id);
CREATE INDEX IF NOT EXISTS idx_vcp_vendor_id ON public.vendor_customer_payments (vendor_id);
CREATE INDEX IF NOT EXISTS idx_vcp_customer_id ON public.vendor_customer_payments (customer_id);
CREATE INDEX IF NOT EXISTS idx_vcp_payment_type ON public.vendor_customer_payments (payment_type);
CREATE INDEX IF NOT EXISTS idx_vcp_payment_date ON public.vendor_customer_payments (payment_date DESC);
CREATE INDEX IF NOT EXISTS idx_vcp_reference_number ON public.vendor_customer_payments (reference_number);

-- Unique index to prevent duplicate transaction entries / UTR on the same assignment
CREATE UNIQUE INDEX IF NOT EXISTS uq_vendor_customer_payments_ref
    ON public.vendor_customer_payments (assignment_id, reference_number)
    WHERE reference_number IS NOT NULL AND TRIM(reference_number) <> '';

-- 3. Automatic calculation trigger for Site Assignment customer financials
CREATE OR REPLACE FUNCTION public.sync_vendor_site_customer_payments()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_assignment_id UUID;
    v_total_cash NUMERIC(12, 2) := 0.00;
    v_total_loan NUMERIC(12, 2) := 0.00;
    v_total_received NUMERIC(12, 2) := 0.00;
    v_site_amount NUMERIC(12, 2) := 0.00;
    v_loan_sanctioned NUMERIC(12, 2) := 0.00;
    v_loan_applied NUMERIC(12, 2) := 0.00;
    v_ptype TEXT;
    v_new_loan_status TEXT;
    v_new_payment_status TEXT;
BEGIN
    IF TG_OP = 'DELETE' THEN
        v_assignment_id := OLD.assignment_id;
    ELSE
        v_assignment_id := NEW.assignment_id;
    END IF;

    -- Fetch current assignment config
    SELECT
        payment_type,
        COALESCE(total_customer_site_amount, 0.00),
        COALESCE(loan_applied_amount, 0.00),
        COALESCE(loan_sanctioned_amount, 0.00)
    INTO
        v_ptype,
        v_site_amount,
        v_loan_applied,
        v_loan_sanctioned
    FROM public.vendor_site_assignments
    WHERE id = v_assignment_id;

    IF NOT FOUND THEN
        RETURN NULL;
    END IF;

    -- Aggregate approved payments
    SELECT
        COALESCE(SUM(CASE WHEN payment_type = 'CASH' THEN amount ELSE 0 END), 0.00),
        COALESCE(SUM(CASE WHEN payment_type = 'BANK_LOAN' THEN amount ELSE 0 END), 0.00)
    INTO
        v_total_cash,
        v_total_loan
    FROM public.vendor_customer_payments
    WHERE assignment_id = v_assignment_id
      AND status = 'Approved';

    v_total_received := v_total_cash + v_total_loan;

    -- Determine customer payment status
    IF v_site_amount > 0 AND v_total_received >= v_site_amount THEN
        v_new_payment_status := 'Paid';
    ELSIF v_total_received > 0 THEN
        v_new_payment_status := 'Partial';
    ELSE
        v_new_payment_status := 'Pending';
    END IF;

    -- Determine bank loan status
    IF v_ptype IN ('Bank Loan Customer', 'Part Cash + Part Loan') OR v_loan_sanctioned > 0 OR v_loan_applied > 0 THEN
        IF v_loan_sanctioned > 0 AND v_total_loan >= v_loan_sanctioned THEN
            v_new_loan_status := 'Fully Credited';
        ELSIF v_total_loan > 0 THEN
            v_new_loan_status := 'Partially Credited';
        ELSIF v_loan_sanctioned > 0 THEN
            v_new_loan_status := 'Sanctioned';
        ELSIF v_loan_applied > 0 THEN
            v_new_loan_status := 'Applied';
        ELSE
            v_new_loan_status := 'Not Required';
        END IF;
    ELSE
        v_new_loan_status := 'Not Required';
    END IF;

    -- Update vendor_site_assignments
    UPDATE public.vendor_site_assignments
    SET
        total_cash_received = v_total_cash,
        total_loan_credited = v_total_loan,
        total_customer_received = v_total_received,
        customer_outstanding = GREATEST(0.00, v_site_amount - v_total_received),
        customer_payment_status = v_new_payment_status,
        loan_status = v_new_loan_status,
        updated_at = timezone('utc'::text, now())
    WHERE id = v_assignment_id;

    RETURN NULL;
END;
$$;

DROP TRIGGER IF EXISTS trg_sync_vendor_customer_payments ON public.vendor_customer_payments;
CREATE TRIGGER trg_sync_vendor_customer_payments
AFTER INSERT OR UPDATE OR DELETE ON public.vendor_customer_payments
FOR EACH ROW
EXECUTE FUNCTION public.sync_vendor_site_customer_payments();

-- 4. Enable Row Level Security (RLS)
ALTER TABLE public.vendor_customer_payments ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Admin full control on vendor customer payments" ON public.vendor_customer_payments;
DROP POLICY IF EXISTS "Sub-vendors view their own customer payments" ON public.vendor_customer_payments;

-- Policy: Admin full access
CREATE POLICY "Admin full control on vendor customer payments"
    ON public.vendor_customer_payments
    FOR ALL
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.users u
            WHERE u.id = auth.uid()
              AND u.role IN ('admin', 'super_admin')
        )
        OR (auth.jwt()->>'role') IN ('admin', 'super_admin')
    )
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.users u
            WHERE u.id = auth.uid()
              AND u.role IN ('admin', 'super_admin')
        )
        OR (auth.jwt()->>'role') IN ('admin', 'super_admin')
    );

-- Policy: Sub-vendors can view only payments of their assigned sites
CREATE POLICY "Sub-vendors view their own customer payments"
    ON public.vendor_customer_payments
    FOR SELECT
    TO authenticated
    USING (
        vendor_id IN (
            SELECT id FROM public.sub_vendors
            WHERE auth_user_id = auth.uid()
               OR mobile = (auth.jwt()->>'phone')
        )
    );

-- 5. Grant access permissions for REST API & PostgREST
GRANT ALL ON public.vendor_customer_payments TO authenticated, anon, service_role;
GRANT ALL ON public.vendor_site_assignments TO authenticated, anon, service_role;

-- Reload schema cache in PostgREST
NOTIFY pgrst, 'reload schema';
