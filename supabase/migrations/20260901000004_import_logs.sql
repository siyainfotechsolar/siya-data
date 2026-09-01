-- ==============================================================================
-- Migration: Phase 6 - Import Logs & Batch Tracking Table
-- ==============================================================================

CREATE TABLE IF NOT EXISTS public.import_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    file_name TEXT NOT NULL,
    file_size_bytes BIGINT NOT NULL DEFAULT 0,
    total_rows INT NOT NULL DEFAULT 0,
    inserted_count INT NOT NULL DEFAULT 0,
    updated_count INT NOT NULL DEFAULT 0,
    skipped_count INT NOT NULL DEFAULT 0,
    failed_count INT NOT NULL DEFAULT 0,
    strategy TEXT NOT NULL DEFAULT 'updateNonEmptyOnly',
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    created_by UUID REFERENCES auth.users(id) ON DELETE SET NULL
);

-- Performance Indexes
CREATE INDEX IF NOT EXISTS idx_import_logs_created_at ON public.import_logs (created_at DESC);
CREATE INDEX IF NOT EXISTS idx_import_logs_created_by ON public.import_logs (created_by);

-- Enable RLS
ALTER TABLE public.import_logs ENABLE ROW LEVEL SECURITY;

-- Policies for import_logs
DROP POLICY IF EXISTS "Admins can view import logs" ON public.import_logs;
CREATE POLICY "Admins can view import logs" ON public.import_logs FOR SELECT TO authenticated USING ((SELECT public.is_admin()));

DROP POLICY IF EXISTS "Authenticated users can insert import logs" ON public.import_logs;
CREATE POLICY "Authenticated users can insert import logs" ON public.import_logs FOR INSERT TO authenticated WITH CHECK ((SELECT auth.uid()) = created_by OR created_by IS NULL);
