-- ==============================================================================
-- Migration: 20261108000039_sub_vendor_quotation_and_gst_settlement.sql
-- Module: SIYA INFOTECH – FINAL SUB-VENDOR QUOTATION, LOAN & GST SETTLEMENT MODULE
-- Description:
--   1. Enhances vendor_material_transactions with supplier_name, invoice_number, and is_itc_eligible.
--   2. Enhances vendor_site_assignments with Quotation linkage, 70:30 GST configuration,
--      Expected Loan (90%), Remaining 10%, Customer Margin, and Loan Shortfall.
--   3. Creates vendor_gst_recoveries table for contractual Admin-controlled GST recovery.
--   4. Configures RLS: Admin Full Control, Sub-Vendor View Only.
--   5. Notifies PostgREST schema cache to reload.
-- ==============================================================================

-- 1. Enhance vendor_material_transactions
ALTER TABLE public.vendor_material_transactions
    ADD COLUMN IF NOT EXISTS supplier_name TEXT,
    ADD COLUMN IF NOT EXISTS invoice_number TEXT,
    ADD COLUMN IF NOT EXISTS is_itc_eligible BOOLEAN NOT NULL DEFAULT true;

-- 2. Enhance vendor_site_assignments
ALTER TABLE public.vendor_site_assignments
    ADD COLUMN IF NOT EXISTS ref_quotation_no TEXT,
    ADD COLUMN IF NOT EXISTS quotation_taxable_amount NUMERIC(12, 2),
    ADD COLUMN IF NOT EXISTS quotation_gst_amount NUMERIC(12, 2),
    ADD COLUMN IF NOT EXISTS quotation_total_amount NUMERIC(12, 2),
    ADD COLUMN IF NOT EXISTS quotation_date DATE,
    ADD COLUMN IF NOT EXISTS expected_loan_amount NUMERIC(12, 2),
    ADD COLUMN IF NOT EXISTS remaining_10_percent NUMERIC(12, 2),
    ADD COLUMN IF NOT EXISTS customer_margin_received NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    ADD COLUMN IF NOT EXISTS loan_shortfall NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    ADD COLUMN IF NOT EXISTS gst_ratio_goods NUMERIC(5, 2) NOT NULL DEFAULT 70.00,
    ADD COLUMN IF NOT EXISTS gst_ratio_services NUMERIC(5, 2) NOT NULL DEFAULT 30.00,
    ADD COLUMN IF NOT EXISTS gst_rate_goods NUMERIC(5, 2) NOT NULL DEFAULT 5.00,
    ADD COLUMN IF NOT EXISTS gst_rate_services NUMERIC(5, 2) NOT NULL DEFAULT 18.00,
    ADD COLUMN IF NOT EXISTS approved_gst_recovery_amount NUMERIC(12, 2) NOT NULL DEFAULT 0.00;

-- 3. Create vendor_gst_recoveries table
CREATE TABLE IF NOT EXISTS public.vendor_gst_recoveries (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    assignment_id UUID NOT NULL REFERENCES public.vendor_site_assignments(id) ON DELETE CASCADE,
    vendor_id UUID NOT NULL REFERENCES public.sub_vendors(id) ON DELETE CASCADE,
    taxable_value NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    gst_rate NUMERIC(5, 2) NOT NULL DEFAULT 18.00,
    gst_amount NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    total_recovery NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    invoice_number TEXT,
    recovery_status TEXT NOT NULL DEFAULT 'Approved' CHECK (recovery_status IN ('Pending', 'Approved', 'Collected')),
    recovery_date DATE NOT NULL DEFAULT CURRENT_DATE,
    payment_date DATE,
    remarks TEXT,
    created_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_vgr_assignment_id ON public.vendor_gst_recoveries (assignment_id);
CREATE INDEX IF NOT EXISTS idx_vgr_vendor_id ON public.vendor_gst_recoveries (vendor_id);
CREATE INDEX IF NOT EXISTS idx_vgr_recovery_status ON public.vendor_gst_recoveries (recovery_status);
CREATE INDEX IF NOT EXISTS idx_vgr_recovery_date ON public.vendor_gst_recoveries (recovery_date DESC);

-- 4. Automatic calculation trigger for GST Recovery total
CREATE OR REPLACE FUNCTION public.sync_vendor_gst_recovery_totals()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.gst_amount := ROUND((NEW.taxable_value * (NEW.gst_rate / 100.0)), 2);
    NEW.total_recovery := NEW.taxable_value + NEW.gst_amount;
    NEW.updated_at := timezone('utc'::text, now());
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_calc_vendor_gst_recovery ON public.vendor_gst_recoveries;
CREATE TRIGGER trg_calc_vendor_gst_recovery
BEFORE INSERT OR UPDATE ON public.vendor_gst_recoveries
FOR EACH ROW
EXECUTE FUNCTION public.sync_vendor_gst_recovery_totals();

-- 5. Enable Row Level Security (RLS)
ALTER TABLE public.vendor_gst_recoveries ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Admin full control on vendor gst recoveries" ON public.vendor_gst_recoveries;
DROP POLICY IF EXISTS "Sub-vendors view their own approved gst recoveries" ON public.vendor_gst_recoveries;

-- Policy: Admin full access
CREATE POLICY "Admin full control on vendor gst recoveries"
    ON public.vendor_gst_recoveries
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

-- Policy: Sub-vendors can view only their own approved recoveries
CREATE POLICY "Sub-vendors view their own approved gst recoveries"
    ON public.vendor_gst_recoveries
    FOR SELECT
    TO authenticated
    USING (
        recovery_status = 'Approved'
        AND vendor_id IN (
            SELECT id FROM public.sub_vendors
            WHERE auth_user_id = auth.uid()
               OR mobile = (auth.jwt()->>'phone')
        )
    );

-- 6. Grant permissions
GRANT ALL ON public.vendor_gst_recoveries TO authenticated, anon, service_role;
GRANT ALL ON public.vendor_material_transactions TO authenticated, anon, service_role;
GRANT ALL ON public.vendor_site_assignments TO authenticated, anon, service_role;

-- 7. Reload schema cache in PostgREST
NOTIFY pgrst, 'reload schema';
