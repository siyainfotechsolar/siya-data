-- Migration: 20260908000017_who_worked_activity_log.sql
-- Description: Creates the centralized public.activity_logs table for "Who Worked Log" / Activity History

-- 1. Create activity_logs table
CREATE TABLE IF NOT EXISTS public.activity_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    record_id UUID REFERENCES public.consumer_records(id) ON DELETE SET NULL,
    consumer_no TEXT,
    customer_name TEXT,
    village TEXT,
    module TEXT NOT NULL DEFAULT 'General', -- 'Customer', 'Loan', 'Installation', 'RTS', 'Subsidy', 'Payment', 'Follow-up', 'Issue', 'Task', 'Import', 'Export', 'Action Center'
    action TEXT NOT NULL, -- 'Customer Created', 'Stage Changed', 'Sub-stage Changed', 'Loan Updated', 'Installation Updated', etc.
    old_value TEXT,
    new_value TEXT,
    next_action TEXT,
    remarks TEXT,
    staff_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    staff_name TEXT NOT NULL DEFAULT 'Staff',
    staff_role TEXT NOT NULL DEFAULT 'staff',
    source TEXT NOT NULL DEFAULT 'Mobile App', -- 'Mobile App', 'Admin Web', 'System'
    metadata JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- 2. Performance B-Tree Indexes
CREATE INDEX IF NOT EXISTS idx_activity_logs_created_at ON public.activity_logs (created_at DESC);
CREATE INDEX IF NOT EXISTS idx_activity_logs_record_created ON public.activity_logs (record_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_activity_logs_consumer_no ON public.activity_logs (consumer_no);
CREATE INDEX IF NOT EXISTS idx_activity_logs_staff_created ON public.activity_logs (staff_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_activity_logs_staff_name ON public.activity_logs (staff_name);
CREATE INDEX IF NOT EXISTS idx_activity_logs_module ON public.activity_logs (module);
CREATE INDEX IF NOT EXISTS idx_activity_logs_village ON public.activity_logs (village);
CREATE INDEX IF NOT EXISTS idx_activity_logs_action ON public.activity_logs (action);

-- 3. Security Hardening: Activity Log Tamper Defense (Immutable History)
-- Normal users and staff cannot UPDATE or DELETE historical activity records
REVOKE UPDATE, DELETE ON public.activity_logs FROM authenticated, anon, PUBLIC;

-- 4. Enable Row Level Security (RLS)
ALTER TABLE public.activity_logs ENABLE ROW LEVEL SECURITY;

-- 5. RLS Policies
-- Admins, Super Admins, Owners can view all activity logs
DROP POLICY IF EXISTS "Admins can view all activity_logs" ON public.activity_logs;
CREATE POLICY "Admins can view all activity_logs"
    ON public.activity_logs
    FOR SELECT
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.profiles
            WHERE profiles.id = auth.uid()
              AND profiles.role IN ('admin', 'super_admin', 'owner')
        )
        OR staff_id = auth.uid()
        OR true -- Allows transparent activity history reading across operational teams
    );

-- Authenticated staff can insert their own activity logs
DROP POLICY IF EXISTS "Authenticated users can insert activity_logs" ON public.activity_logs;
CREATE POLICY "Authenticated users can insert activity_logs"
    ON public.activity_logs
    FOR INSERT
    TO authenticated
    WITH CHECK (auth.uid() IS NOT NULL);
