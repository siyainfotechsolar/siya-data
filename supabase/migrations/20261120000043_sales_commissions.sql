-- ==============================================================================
-- Migration: 20261120000043_sales_commissions.sql
-- Module: SIYA INFOTECH – SALES PERSON COMMISSION MANAGEMENT MODULE
-- Description:
--   1. Creates public.sales_commissions table for tracking customer-wise and
--      sales-person-wise commissions based on solar installation capacity (kW).
--   2. Supports Customer Source: 'Sales Person' and 'Direct Customer'.
--   3. Direct customers always have ₹0 commission and 'Not Applicable' status.
--   4. Configures Row Level Security (RLS) and indexes for performance.
--   5. Reloads PostgREST schema cache.
-- ==============================================================================

CREATE TABLE IF NOT EXISTS public.sales_commissions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    consumer_id UUID REFERENCES public.consumer_records(id) ON DELETE CASCADE,
    consumer_no TEXT NOT NULL,
    customer_name TEXT NOT NULL,
    site_location TEXT,
    solar_capacity TEXT,
    capacity_kw NUMERIC(10, 2) NOT NULL DEFAULT 0.00,

    -- Customer Source: 'Sales Person' or 'Direct Customer'
    customer_source TEXT NOT NULL DEFAULT 'Sales Person' CHECK (customer_source IN ('Sales Person', 'Direct Customer')),

    -- Sales Person details (null for Direct Customer)
    sales_person_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    sales_person_name TEXT,

    -- Commission Rate per kW (₹)
    commission_rate_per_kw NUMERIC(12, 2) NOT NULL DEFAULT 0.00,

    -- Total Commission (₹): capacity_kw * commission_rate_per_kw for Sales Person; 0 for Direct
    total_commission NUMERIC(12, 2) NOT NULL DEFAULT 0.00,

    -- Commission Status: 'Pending', 'Completed', 'Not Applicable'
    commission_status TEXT NOT NULL DEFAULT 'Pending' CHECK (commission_status IN ('Pending', 'Completed', 'Not Applicable')),

    commission_date DATE NOT NULL DEFAULT CURRENT_DATE,
    remarks TEXT,
    created_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- Performance & duplicate prevention indexes
CREATE UNIQUE INDEX IF NOT EXISTS idx_sales_commissions_consumer_no ON public.sales_commissions (consumer_no);
CREATE INDEX IF NOT EXISTS idx_sales_commissions_sales_person ON public.sales_commissions (sales_person_name);
CREATE INDEX IF NOT EXISTS idx_sales_commissions_status ON public.sales_commissions (commission_status);
CREATE INDEX IF NOT EXISTS idx_sales_commissions_source ON public.sales_commissions (customer_source);
CREATE INDEX IF NOT EXISTS idx_sales_commissions_date ON public.sales_commissions (commission_date DESC);
CREATE INDEX IF NOT EXISTS idx_sales_commissions_consumer_id ON public.sales_commissions (consumer_id);

-- Enable Row Level Security
ALTER TABLE public.sales_commissions ENABLE ROW LEVEL SECURITY;

-- Policies
DROP POLICY IF EXISTS "sales_commissions_select_authenticated" ON public.sales_commissions;
CREATE POLICY "sales_commissions_select_authenticated" ON public.sales_commissions
    FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS "sales_commissions_insert_authenticated" ON public.sales_commissions;
CREATE POLICY "sales_commissions_insert_authenticated" ON public.sales_commissions
    FOR INSERT TO authenticated WITH CHECK (true);

DROP POLICY IF EXISTS "sales_commissions_update_authenticated" ON public.sales_commissions;
CREATE POLICY "sales_commissions_update_authenticated" ON public.sales_commissions
    FOR UPDATE TO authenticated USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "sales_commissions_delete_admin_or_permitted" ON public.sales_commissions;
CREATE POLICY "sales_commissions_delete_admin_or_permitted" ON public.sales_commissions
    FOR DELETE TO authenticated USING (
        EXISTS (
            SELECT 1 FROM public.profiles p
            WHERE p.id = auth.uid()
            AND (p.role IN ('admin', 'super_admin', 'owner') OR p.can_delete = true)
        )
    );

-- Reload PostgREST schema cache
NOTIFY pgrst, 'reload schema';
