-- ==============================================================================
-- Migration: 20261120000042_site_team_expenses.sql
-- Module: SIYA INFOTECH – SITE-WISE TEAM EXPENSE & EXCEL REPORT MODULE
-- Description:
--   1. Creates public.site_team_expenses table to track customer/site-wise team expenses.
--   2. Enforces unique constraint on consumer_no to prevent duplicate records per site.
--   3. Calculates total_site_expense automatically (wiring + civil + structure).
--   4. Configures Row Level Security (RLS) for Admin full access and Staff operations.
--   5. Reloads PostgREST schema cache.
-- ==============================================================================

CREATE TABLE IF NOT EXISTS public.site_team_expenses (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    consumer_id UUID REFERENCES public.consumer_records(id) ON DELETE CASCADE,
    consumer_no TEXT NOT NULL,
    customer_name TEXT NOT NULL,
    site_location TEXT,
    solar_capacity TEXT,
    expense_date DATE NOT NULL DEFAULT CURRENT_DATE,

    -- Exactly 3 manual direct expense amounts:
    wiring_expense NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    civil_expense NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    structure_expense NUMERIC(12, 2) NOT NULL DEFAULT 0.00,

    -- Generated customer-wise total:
    total_site_expense NUMERIC(12, 2) GENERATED ALWAYS AS (wiring_expense + civil_expense + structure_expense) STORED,

    remarks TEXT,
    created_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- Indexes for performance and duplicate prevention
CREATE UNIQUE INDEX IF NOT EXISTS idx_site_team_expenses_consumer_no ON public.site_team_expenses (consumer_no);
CREATE INDEX IF NOT EXISTS idx_site_team_expenses_expense_date ON public.site_team_expenses (expense_date DESC);
CREATE INDEX IF NOT EXISTS idx_site_team_expenses_customer_name ON public.site_team_expenses (customer_name);
CREATE INDEX IF NOT EXISTS idx_site_team_expenses_consumer_id ON public.site_team_expenses (consumer_id);

-- Enable Row Level Security
ALTER TABLE public.site_team_expenses ENABLE ROW LEVEL SECURITY;

-- Policies for site_team_expenses
DROP POLICY IF EXISTS "site_team_expenses_select_all_authenticated" ON public.site_team_expenses;
CREATE POLICY "site_team_expenses_select_all_authenticated" ON public.site_team_expenses
    FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS "site_team_expenses_insert_authenticated" ON public.site_team_expenses;
CREATE POLICY "site_team_expenses_insert_authenticated" ON public.site_team_expenses
    FOR INSERT TO authenticated WITH CHECK (true);

DROP POLICY IF EXISTS "site_team_expenses_update_authenticated" ON public.site_team_expenses;
CREATE POLICY "site_team_expenses_update_authenticated" ON public.site_team_expenses
    FOR UPDATE TO authenticated USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "site_team_expenses_delete_admin_or_permitted" ON public.site_team_expenses;
CREATE POLICY "site_team_expenses_delete_admin_or_permitted" ON public.site_team_expenses
    FOR DELETE TO authenticated USING (
        EXISTS (
            SELECT 1 FROM public.profiles p
            WHERE p.id = auth.uid()
            AND (p.role IN ('admin', 'super_admin', 'owner') OR p.can_delete = true)
        )
    );

-- Reload PostgREST schema cache
NOTIFY pgrst, 'reload schema';
