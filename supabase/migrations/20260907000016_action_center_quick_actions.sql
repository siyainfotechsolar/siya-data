-- ==============================================================================
-- Migration: Action Center 3 Quick Actions Only
-- Adds hold & followup columns, customer_followups table, and updates Action Center RPCs
-- ==============================================================================

-- 1. Add Hold & Follow-up tracking columns to public.consumer_records
ALTER TABLE public.consumer_records
    ADD COLUMN IF NOT EXISTS hold_remarks TEXT,
    ADD COLUMN IF NOT EXISTS expected_followup_date DATE,
    ADD COLUMN IF NOT EXISTS followup_date DATE,
    ADD COLUMN IF NOT EXISTS followup_reason TEXT,
    ADD COLUMN IF NOT EXISTS followup_remarks TEXT,
    ADD COLUMN IF NOT EXISTS last_followup_result TEXT,
    ADD COLUMN IF NOT EXISTS has_active_followup BOOLEAN NOT NULL DEFAULT false;

-- 2. Ensure public.audit_logs has metadata & remarks columns for follow-up details
ALTER TABLE public.audit_logs
    ADD COLUMN IF NOT EXISTS remarks TEXT,
    ADD COLUMN IF NOT EXISTS metadata JSONB;

-- 3. Create public.customer_followups table for tracking history of every call/follow-up
CREATE TABLE IF NOT EXISTS public.customer_followups (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    record_id UUID NOT NULL REFERENCES public.consumer_records(id) ON DELETE CASCADE,
    consumer_no TEXT NOT NULL,
    followup_date DATE NOT NULL,
    followup_reason TEXT NOT NULL, -- 'Customer Call', 'Bank Follow-up', 'Document Follow-up', 'Installation Follow-up', 'Other'
    remarks TEXT,
    status TEXT NOT NULL DEFAULT 'PENDING', -- 'PENDING', 'COMPLETED', 'CANCELLED'
    followup_result TEXT,
    result_remarks TEXT,
    next_followup_date DATE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    created_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    created_by_name TEXT,
    completed_at TIMESTAMPTZ,
    completed_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    completed_by_name TEXT
);

-- 4. Indexes for high performance querying
CREATE INDEX IF NOT EXISTS idx_customer_followups_record_id ON public.customer_followups(record_id);
CREATE INDEX IF NOT EXISTS idx_customer_followups_date ON public.customer_followups(followup_date);
CREATE INDEX IF NOT EXISTS idx_customer_followups_status ON public.customer_followups(status);
CREATE INDEX IF NOT EXISTS idx_consumer_records_followup_active ON public.consumer_records(followup_date) WHERE has_active_followup = true;
CREATE INDEX IF NOT EXISTS idx_consumer_records_work_state ON public.consumer_records(customer_work_state) WHERE deleted = false;

-- 5. Enable Row Level Security (RLS) on customer_followups
ALTER TABLE public.customer_followups ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Admins have full access to customer_followups" ON public.customer_followups;
CREATE POLICY "Admins have full access to customer_followups"
    ON public.customer_followups
    FOR ALL
    TO authenticated
    USING (true)
    WITH CHECK (true);

DROP POLICY IF EXISTS "Anon read access for customer_followups" ON public.customer_followups;
CREATE POLICY "Anon read access for customer_followups"
    ON public.customer_followups
    FOR SELECT
    TO anon
    USING (true);

-- 6. Add customer_followups to Realtime Publication
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.customer_followups;
    END IF;
EXCEPTION
    WHEN duplicate_object THEN NULL;
END $$;

-- 7. Drop and recreate Action Center counts RPC
DROP FUNCTION IF EXISTS get_todays_work_counts();
DROP FUNCTION IF EXISTS get_action_center_counts();

CREATE OR REPLACE FUNCTION get_action_center_counts()
RETURNS TABLE (
  agreement_pending_count BIGINT,
  loan_pending_count BIGINT,
  installation_pending_count BIGINT,
  rts_pending_count BIGINT,
  subsidy_processing_count BIGINT,
  completed_count BIGINT,
  no_action_required_count BIGINT,
  todays_followup_count BIGINT,
  overdue_followup_count BIGINT,
  upcoming_followup_count BIGINT
) LANGUAGE sql STABLE AS $$
  SELECT
    -- 1. Agreement Pending (Active only)
    COUNT(*) FILTER (
      WHERE deleted = false AND is_merged = false
        AND UPPER(COALESCE(customer_work_state, 'ACTIVE')) = 'ACTIVE'
        AND LOWER(COALESCE(subsidy_status, '')) NOT IN ('received', 'completed')
        AND LOWER(COALESCE(status, '')) NOT IN ('completed', 'cancelled')
        AND LOWER(COALESCE(agreement_status, 'pending')) NOT IN ('verified', 'completed')
    ) AS agreement_pending_count,

    -- 2. Loan Pending (Active only)
    COUNT(*) FILTER (
      WHERE deleted = false AND is_merged = false
        AND UPPER(COALESCE(customer_work_state, 'ACTIVE')) = 'ACTIVE'
        AND LOWER(COALESCE(subsidy_status, '')) NOT IN ('received', 'completed')
        AND LOWER(COALESCE(status, '')) NOT IN ('completed', 'cancelled')
        AND LOWER(COALESCE(agreement_status, 'pending')) IN ('verified', 'completed')
        AND LOWER(COALESCE(loan_required, 'no')) = 'yes'
        AND LOWER(COALESCE(loan_status, 'not required')) NOT IN ('approved', 'completed', 'not required')
    ) AS loan_pending_count,

    -- 3. Installation Pending (Active only)
    COUNT(*) FILTER (
      WHERE deleted = false AND is_merged = false
        AND UPPER(COALESCE(customer_work_state, 'ACTIVE')) = 'ACTIVE'
        AND LOWER(COALESCE(subsidy_status, '')) NOT IN ('received', 'completed')
        AND LOWER(COALESCE(status, '')) NOT IN ('completed', 'cancelled')
        AND LOWER(COALESCE(agreement_status, 'pending')) IN ('verified', 'completed')
        AND (
          LOWER(COALESCE(loan_required, 'no')) != 'yes'
          OR LOWER(COALESCE(loan_status, 'not required')) IN ('approved', 'completed', 'not required')
        )
        AND LOWER(COALESCE(installation_status, 'not started')) NOT IN ('installation completed', 'completed')
    ) AS installation_pending_count,

    -- 4. RTS Pending (Active only)
    COUNT(*) FILTER (
      WHERE deleted = false AND is_merged = false
        AND UPPER(COALESCE(customer_work_state, 'ACTIVE')) = 'ACTIVE'
        AND LOWER(COALESCE(subsidy_status, '')) NOT IN ('received', 'completed')
        AND LOWER(COALESCE(status, '')) NOT IN ('completed', 'cancelled')
        AND LOWER(COALESCE(installation_status, 'not started')) IN ('installation completed', 'completed')
        AND LOWER(COALESCE(rts_status, 'not started')) != 'completed'
    ) AS rts_pending_count,

    -- 5. Subsidy Processing (Active only)
    COUNT(*) FILTER (
      WHERE deleted = false AND is_merged = false
        AND UPPER(COALESCE(customer_work_state, 'ACTIVE')) = 'ACTIVE'
        AND LOWER(COALESCE(installation_status, 'not started')) IN ('installation completed', 'completed')
        AND LOWER(COALESCE(rts_status, 'not started')) = 'completed'
        AND LOWER(COALESCE(subsidy_status, 'not applied')) NOT IN ('received', 'completed')
        AND LOWER(COALESCE(status, '')) NOT IN ('completed', 'cancelled')
    ) AS subsidy_processing_count,

    -- 6. Completed
    COUNT(*) FILTER (
      WHERE deleted = false AND is_merged = false
        AND (
          UPPER(COALESCE(customer_work_state, 'ACTIVE')) = 'COMPLETED'
          OR LOWER(COALESCE(subsidy_status, '')) IN ('received', 'completed')
          OR LOWER(COALESCE(status, '')) = 'completed'
        )
    ) AS completed_count,

    -- 7. Hold / No Action Required
    COUNT(*) FILTER (
      WHERE deleted = false AND is_merged = false
        AND UPPER(COALESCE(customer_work_state, 'ACTIVE')) IN ('ON_HOLD', 'NO_ACTION_REQUIRED')
    ) AS no_action_required_count,

    -- 8. Today's Follow-up
    COUNT(*) FILTER (
      WHERE deleted = false AND is_merged = false
        AND has_active_followup = true
        AND followup_date = CURRENT_DATE
    ) AS todays_followup_count,

    -- 9. Overdue Follow-up
    COUNT(*) FILTER (
      WHERE deleted = false AND is_merged = false
        AND has_active_followup = true
        AND followup_date < CURRENT_DATE
    ) AS overdue_followup_count,

    -- 10. Upcoming Follow-up
    COUNT(*) FILTER (
      WHERE deleted = false AND is_merged = false
        AND has_active_followup = true
        AND followup_date > CURRENT_DATE
    ) AS upcoming_followup_count
  FROM public.consumer_records;
$$;

CREATE OR REPLACE FUNCTION get_todays_work_counts()
RETURNS TABLE (
  loan_followups_count BIGINT,
  installations_count BIGINT,
  rts_work_count BIGINT,
  agreements_count BIGINT,
  subsidy_processing_count BIGINT
) LANGUAGE sql STABLE AS $$
  SELECT
    loan_pending_count AS loan_followups_count,
    installation_pending_count AS installations_count,
    rts_pending_count AS rts_work_count,
    agreement_pending_count AS agreements_count,
    subsidy_processing_count AS subsidy_processing_count
  FROM get_action_center_counts();
$$;
