-- Migration: 20260927000031_customer_quotations.sql
-- Description: Create customer_quotations table for Bank Loan Solar Quotations

CREATE TABLE IF NOT EXISTS public.customer_quotations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    customer_id UUID REFERENCES public.consumer_records(id) ON DELETE CASCADE,
    consumer_no TEXT NOT NULL,
    quotation_no TEXT NOT NULL,
    customer_name TEXT NOT NULL,
    address TEXT,
    village_city TEXT,
    district TEXT,
    mobile_no TEXT,
    system_capacity TEXT NOT NULL DEFAULT '3 kW',
    system_type TEXT NOT NULL DEFAULT 'On-Grid Solar System',
    total_system_cost NUMERIC(12, 2) NOT NULL DEFAULT 0.0,
    gst_amount NUMERIC(12, 2) NOT NULL DEFAULT 0.0,
    grand_total NUMERIC(12, 2) NOT NULL DEFAULT 0.0,
    amount_in_words TEXT,
    bank_loan_amount NUMERIC(12, 2) NOT NULL DEFAULT 0.0,
    customer_contribution NUMERIC(12, 2) NOT NULL DEFAULT 0.0,
    bank_name TEXT DEFAULT 'STATE BANK OF INDIA',
    branch TEXT DEFAULT 'Betawad',
    account_no TEXT DEFAULT '40662252403',
    ifsc_code TEXT DEFAULT 'SBIN0004798',
    account_type TEXT DEFAULT 'Current Account',
    upi_id TEXT DEFAULT 'siyainfodigital@sbi',
    signatory_name TEXT DEFAULT 'Authorized Signatory',
    signatory_designation TEXT DEFAULT 'Managing Director / Partner',
    file_name TEXT,
    file_url TEXT,
    metadata JSONB,
    created_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    created_by_name TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE INDEX IF NOT EXISTS idx_customer_quotations_customer_id ON public.customer_quotations(customer_id);
CREATE INDEX IF NOT EXISTS idx_customer_quotations_consumer_no ON public.customer_quotations(consumer_no);
CREATE INDEX IF NOT EXISTS idx_customer_quotations_quotation_no ON public.customer_quotations(quotation_no);
CREATE INDEX IF NOT EXISTS idx_customer_quotations_created_at ON public.customer_quotations(created_at DESC);

-- Enable RLS
ALTER TABLE public.customer_quotations ENABLE ROW LEVEL SECURITY;

-- Policies
DROP POLICY IF EXISTS "Authenticated users can select customer_quotations" ON public.customer_quotations;
CREATE POLICY "Authenticated users can select customer_quotations"
    ON public.customer_quotations FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS "Authenticated users can insert customer_quotations" ON public.customer_quotations;
CREATE POLICY "Authenticated users can insert customer_quotations"
    ON public.customer_quotations FOR INSERT TO authenticated WITH CHECK (true);

DROP POLICY IF EXISTS "Authenticated users can update customer_quotations" ON public.customer_quotations;
CREATE POLICY "Authenticated users can update customer_quotations"
    ON public.customer_quotations FOR UPDATE TO authenticated USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Admins can delete customer_quotations" ON public.customer_quotations;
CREATE POLICY "Admins can delete customer_quotations"
    ON public.customer_quotations FOR DELETE TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.profiles
            WHERE profiles.id = auth.uid()
              AND profiles.role IN ('admin', 'super_admin', 'owner')
        )
    );
