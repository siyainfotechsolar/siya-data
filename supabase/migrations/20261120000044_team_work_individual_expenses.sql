-- Migration: 20261120000044_team_work_individual_expenses.sql
-- Description: Team Member Master and Individual Team Work Expense tracking tables
-- Features:
--   1. team_members: Team Member Master with seed members (Vishal, Yendeshwar, Samadhan, Eknath)
--   2. team_work_expenses: Individual person-wise site work expenses (Structure, Wiring, Civil)

-- 1. Create team_members table
CREATE TABLE IF NOT EXISTS public.team_members (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    phone TEXT,
    is_active BOOLEAN NOT NULL DEFAULT true,
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Index on name and is_active
CREATE INDEX IF NOT EXISTS idx_team_members_name ON public.team_members (name);
CREATE INDEX IF NOT EXISTS idx_team_members_is_active ON public.team_members (is_active);

-- Seed initial team members if not existing
INSERT INTO public.team_members (name, notes)
SELECT v.name, 'Default initial team member'
FROM (VALUES 
    ('Vishal'),
    ('Yendeshwar'),
    ('Samadhan'),
    ('Eknath')
) AS v(name)
WHERE NOT EXISTS (
    SELECT 1 FROM public.team_members tm WHERE LOWER(TRIM(tm.name)) = LOWER(TRIM(v.name))
);

-- 2. Create team_work_expenses table
CREATE TABLE IF NOT EXISTS public.team_work_expenses (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    consumer_id TEXT,
    consumer_no TEXT NOT NULL,
    customer_name TEXT NOT NULL,
    site_location TEXT,
    solar_capacity TEXT,
    work_date DATE NOT NULL DEFAULT CURRENT_DATE,
    work_category TEXT NOT NULL CHECK (work_category IN ('Structure', 'Wiring', 'Civil')),
    team_member_id UUID REFERENCES public.team_members(id) ON DELETE SET NULL,
    team_member_name TEXT NOT NULL,
    individual_expense NUMERIC(12,2) NOT NULL DEFAULT 0.00,
    remarks TEXT,
    created_by TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Indexes for lightning fast queries, filters, and reports
CREATE INDEX IF NOT EXISTS idx_team_work_expenses_consumer_no ON public.team_work_expenses (consumer_no);
CREATE INDEX IF NOT EXISTS idx_team_work_expenses_team_member ON public.team_work_expenses (team_member_name);
CREATE INDEX IF NOT EXISTS idx_team_work_expenses_category ON public.team_work_expenses (work_category);
CREATE INDEX IF NOT EXISTS idx_team_work_expenses_date ON public.team_work_expenses (work_date);

-- Enable RLS
ALTER TABLE public.team_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.team_work_expenses ENABLE ROW LEVEL SECURITY;

-- Permissive policies for team_members
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies WHERE tablename = 'team_members' AND policyname = 'team_members_select_policy'
    ) THEN
        CREATE POLICY team_members_select_policy ON public.team_members FOR SELECT USING (true);
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_policies WHERE tablename = 'team_members' AND policyname = 'team_members_all_policy'
    ) THEN
        CREATE POLICY team_members_all_policy ON public.team_members FOR ALL USING (true) WITH CHECK (true);
    END IF;
END $$;

-- Permissive policies for team_work_expenses
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies WHERE tablename = 'team_work_expenses' AND policyname = 'team_work_expenses_select_policy'
    ) THEN
        CREATE POLICY team_work_expenses_select_policy ON public.team_work_expenses FOR SELECT USING (true);
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_policies WHERE tablename = 'team_work_expenses' AND policyname = 'team_work_expenses_all_policy'
    ) THEN
        CREATE POLICY team_work_expenses_all_policy ON public.team_work_expenses FOR ALL USING (true) WITH CHECK (true);
    END IF;
END $$;
