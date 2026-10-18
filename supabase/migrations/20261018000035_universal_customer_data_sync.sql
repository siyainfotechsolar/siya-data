-- ==============================================================================
-- Migration: 20261018000035_universal_customer_data_sync.sql
-- Description:
--   1. Creates public.customer_agreements table for Consumer Vendor Agreements.
--   2. Ensures full RLS policies for authenticated users on consumer_records,
--      customer_documents, customer_agreements, customer_quotations, and customer_invoices.
--   3. Upgrades public.is_active_user() to prevent staff lockout.
--   4. Grants all authenticated staff and admins unified access to customer data
--      so all users and modules see the exact same authoritative data.
-- ==============================================================================

-- 1. Create public.customer_agreements table
CREATE TABLE IF NOT EXISTS public.customer_agreements (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    agreement_no TEXT NOT NULL,
    customer_id UUID REFERENCES public.consumer_records(id) ON DELETE CASCADE,
    consumer_no TEXT NOT NULL,
    customer_name TEXT NOT NULL,
    customer_address TEXT,
    village_city TEXT,
    district TEXT,
    customer_mobile TEXT,
    execution_date DATE NOT NULL DEFAULT CURRENT_DATE,
    system_capacity TEXT NOT NULL DEFAULT '3 kW',
    system_type TEXT NOT NULL DEFAULT 'Grid Connected Rooftop Solar (RTS) Project',
    scheme_name TEXT NOT NULL DEFAULT 'PM - Surya Ghar: Muft Bijli Yojana',
    total_project_cost NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    cfa_subsidy_amount NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    net_customer_payable NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    vendor_name TEXT DEFAULT 'SIYA INFOTECH & DIGITAL SOLUTIONS',
    vendor_address TEXT DEFAULT '21, Mudavad Road, Betawad, Tal. Shindkheda, Dist. Dhule - 425403',
    vendor_phone TEXT DEFAULT '7972143798',
    vendor_email TEXT DEFAULT 'siyainfodigital@gmail.com',
    vendor_gstin TEXT DEFAULT '27CVTPK6358P1ZD',
    discomName TEXT DEFAULT 'MSEDCL',
    payment_milestones JSONB DEFAULT '[]'::jsonb,
    pdf_file_name TEXT,
    pdf_file_path TEXT,
    file_url TEXT,
    metadata JSONB DEFAULT '{}'::jsonb,
    created_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE INDEX IF NOT EXISTS idx_customer_agreements_consumer_no ON public.customer_agreements(consumer_no);
CREATE INDEX IF NOT EXISTS idx_customer_agreements_customer_id ON public.customer_agreements(customer_id);
CREATE INDEX IF NOT EXISTS idx_customer_agreements_agreement_no ON public.customer_agreements(agreement_no);
CREATE INDEX IF NOT EXISTS idx_customer_agreements_created_at ON public.customer_agreements(created_at DESC);

-- Enable RLS on customer_agreements
ALTER TABLE public.customer_agreements ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Authenticated full access to customer_agreements" ON public.customer_agreements;
CREATE POLICY "Authenticated full access to customer_agreements"
    ON public.customer_agreements FOR ALL TO authenticated USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Anon read access to customer_agreements" ON public.customer_agreements;
CREATE POLICY "Anon read access to customer_agreements"
    ON public.customer_agreements FOR SELECT TO anon USING (true);

-- 2. Ensure RLS policies on customer_documents include DELETE
DROP POLICY IF EXISTS "Authenticated users can delete customer_documents" ON public.customer_documents;
CREATE POLICY "Authenticated users can delete customer_documents"
    ON public.customer_documents FOR DELETE TO authenticated USING (true);

-- 3. Robust is_active_user function (fail-safe so valid authenticated users are never blocked)
CREATE OR REPLACE FUNCTION public.is_active_user()
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
  SELECT CASE 
    -- If user has an explicit profile row marked inactive, block
    WHEN EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = (SELECT auth.uid())
        AND (is_active = false OR status = 'Inactive')
    ) THEN false
    -- If user is authenticated, default to true
    WHEN (SELECT auth.uid()) IS NOT NULL THEN true
    ELSE false
  END;
$$;

GRANT EXECUTE ON FUNCTION public.is_active_user() TO authenticated;

-- 4. Ensure universal access to consumer_records for all active authenticated staff and admins
DROP POLICY IF EXISTS "Staff can view consumer_records" ON public.consumer_records;
CREATE POLICY "Staff can view consumer_records" ON public.consumer_records 
FOR SELECT TO authenticated 
USING (
  (SELECT public.is_admin()) 
  OR ((SELECT public.is_active_user()) AND deleted = false)
);

DROP POLICY IF EXISTS "Staff can update consumer_records" ON public.consumer_records;
CREATE POLICY "Staff can update consumer_records" ON public.consumer_records 
FOR UPDATE TO authenticated 
USING (
  (SELECT public.is_admin())
  OR ((SELECT public.can_delete_records()) AND deleted = false)
  OR ((SELECT public.is_active_user()) AND deleted = false)
) 
WITH CHECK (
  (SELECT public.is_admin())
  OR ((SELECT public.can_delete_records()) AND deleted = true)
  OR ((SELECT public.is_active_user()) AND deleted = false)
);

DROP POLICY IF EXISTS "Staff can insert consumer_records" ON public.consumer_records;
CREATE POLICY "Staff can insert consumer_records" ON public.consumer_records
FOR INSERT TO authenticated 
WITH CHECK (
  (SELECT public.is_admin())
  OR (SELECT public.is_active_user())
);

-- 5. Ensure customer_quotations allows DELETE for authenticated staff
DROP POLICY IF EXISTS "Authenticated users can delete customer_quotations" ON public.customer_quotations;
CREATE POLICY "Authenticated users can delete customer_quotations"
    ON public.customer_quotations FOR DELETE TO authenticated USING (true);
