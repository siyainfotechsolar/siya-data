-- ==============================================================================
-- Migration: Controlled 'No Action Required' (Hold) Customer State
-- Adds no_action / hold metadata columns and updates RPCs to exclude from active queues
-- ==============================================================================

-- 1. Add no_action and hold columns to public.consumer_records
ALTER TABLE public.consumer_records
    ADD COLUMN IF NOT EXISTS no_action_reason TEXT,
    ADD COLUMN IF NOT EXISTS no_action_date TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS no_action_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    ADD COLUMN IF NOT EXISTS no_action_by_name TEXT,
    ADD COLUMN IF NOT EXISTS hold_reason TEXT,
    ADD COLUMN IF NOT EXISTS hold_date TIMESTAMPTZ;

-- 2. Add reason column to public.audit_logs if not present
ALTER TABLE public.audit_logs
    ADD COLUMN IF NOT EXISTS reason TEXT;

-- 3. Composite and partial index for work state filtering
CREATE INDEX IF NOT EXISTS idx_consumer_records_work_state_active
ON public.consumer_records (customer_work_state)
WHERE deleted = false;

-- 4. Update Database RPC Function for Action Center counts
-- Active queues strictly count customer_work_state = 'ACTIVE'
-- Adds no_action_required_count
CREATE OR REPLACE FUNCTION get_action_center_counts()
RETURNS TABLE (
  agreement_pending_count BIGINT,
  loan_pending_count BIGINT,
  installation_pending_count BIGINT,
  rts_pending_count BIGINT,
  subsidy_processing_count BIGINT,
  completed_count BIGINT,
  no_action_required_count BIGINT
) LANGUAGE sql STABLE AS $$
  SELECT
    -- 1. Agreement Pending (Agreement not completed, work state strictly ACTIVE)
    COUNT(*) FILTER (
      WHERE deleted = false AND is_merged = false
        AND UPPER(COALESCE(customer_work_state, 'ACTIVE')) = 'ACTIVE'
        AND LOWER(COALESCE(subsidy_status, '')) NOT IN ('received', 'completed')
        AND LOWER(COALESCE(status, '')) NOT IN ('completed', 'cancelled')
        AND LOWER(COALESCE(agreement_status, 'pending')) NOT IN ('verified', 'completed')
    ) AS agreement_pending_count,

    -- 2. Loan Pending (Agreement completed, Loan required = YES, Loan not completed, work state strictly ACTIVE)
    COUNT(*) FILTER (
      WHERE deleted = false AND is_merged = false
        AND UPPER(COALESCE(customer_work_state, 'ACTIVE')) = 'ACTIVE'
        AND LOWER(COALESCE(subsidy_status, '')) NOT IN ('received', 'completed')
        AND LOWER(COALESCE(status, '')) NOT IN ('completed', 'cancelled')
        AND LOWER(COALESCE(agreement_status, 'pending')) IN ('verified', 'completed')
        AND LOWER(COALESCE(loan_required, 'no')) = 'yes'
        AND LOWER(COALESCE(loan_status, 'not required')) NOT IN ('approved', 'completed', 'not required')
    ) AS loan_pending_count,

    -- 3. Installation Pending (Agreement completed, Loan satisfied/skipped, Installation not completed, work state strictly ACTIVE)
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

    -- 4. RTS Pending (Installation completed, RTS not completed, work state strictly ACTIVE)
    COUNT(*) FILTER (
      WHERE deleted = false AND is_merged = false
        AND UPPER(COALESCE(customer_work_state, 'ACTIVE')) = 'ACTIVE'
        AND LOWER(COALESCE(subsidy_status, '')) NOT IN ('received', 'completed')
        AND LOWER(COALESCE(status, '')) NOT IN ('completed', 'cancelled')
        AND LOWER(COALESCE(installation_status, 'not started')) IN ('installation completed', 'completed')
        AND LOWER(COALESCE(rts_status, 'not started')) != 'completed'
    ) AS rts_pending_count,

    -- 5. Subsidy Processing (RTS completed, Subsidy not received, work state strictly ACTIVE)
    COUNT(*) FILTER (
      WHERE deleted = false AND is_merged = false
        AND UPPER(COALESCE(customer_work_state, 'ACTIVE')) = 'ACTIVE'
        AND LOWER(COALESCE(installation_status, 'not started')) IN ('installation completed', 'completed')
        AND LOWER(COALESCE(rts_status, 'not started')) = 'completed'
        AND LOWER(COALESCE(subsidy_status, 'not applied')) NOT IN ('received', 'completed')
        AND LOWER(COALESCE(status, '')) NOT IN ('completed', 'cancelled')
    ) AS subsidy_processing_count,

    -- 6. Completed (subsidy_status = Received OR customer_work_state = COMPLETED)
    COUNT(*) FILTER (
      WHERE deleted = false AND is_merged = false
        AND (
          UPPER(COALESCE(customer_work_state, 'ACTIVE')) = 'COMPLETED'
          OR LOWER(COALESCE(subsidy_status, '')) IN ('received', 'completed')
          OR LOWER(COALESCE(status, '')) = 'completed'
        )
    ) AS completed_count,

    -- 7. No Action Required / Hold (customer_work_state = NO_ACTION_REQUIRED)
    COUNT(*) FILTER (
      WHERE deleted = false AND is_merged = false
        AND UPPER(COALESCE(customer_work_state, 'ACTIVE')) = 'NO_ACTION_REQUIRED'
    ) AS no_action_required_count
  FROM public.consumer_records;
$$;

-- 5. Database RPC Function for Today's Work counts
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

-- 6. Update get_priority_summary_counts() RPC to exclude customer_work_state = 'COMPLETED' and 'NO_ACTION_REQUIRED'
CREATE OR REPLACE FUNCTION get_priority_summary_counts()
RETURNS TABLE (
  critical_count BIGINT,
  high_count BIGINT,
  medium_count BIGINT,
  normal_count BIGINT,
  total_active BIGINT
) LANGUAGE sql STABLE AS $$
  SELECT
    COUNT(*) FILTER (
      WHERE GREATEST(0, (CURRENT_DATE - (COALESCE(submit_date, created_at) AT TIME ZONE 'UTC')::date)) >= 31
    ) AS critical_count,
    COUNT(*) FILTER (
      WHERE GREATEST(0, (CURRENT_DATE - (COALESCE(submit_date, created_at) AT TIME ZONE 'UTC')::date)) BETWEEN 16 AND 30
    ) AS high_count,
    COUNT(*) FILTER (
      WHERE GREATEST(0, (CURRENT_DATE - (COALESCE(submit_date, created_at) AT TIME ZONE 'UTC')::date)) BETWEEN 8 AND 15
    ) AS medium_count,
    COUNT(*) FILTER (
      WHERE GREATEST(0, (CURRENT_DATE - (COALESCE(submit_date, created_at) AT TIME ZONE 'UTC')::date)) <= 7
    ) AS normal_count,
    COUNT(*) AS total_active
  FROM public.consumer_records
  WHERE deleted = false
    AND is_merged = false
    AND UPPER(COALESCE(customer_work_state, 'ACTIVE')) = 'ACTIVE'
    AND LOWER(COALESCE(status, '')) NOT IN ('completed', 'cancelled')
    AND LOWER(COALESCE(application_status, '')) NOT IN ('completed', 'cancelled')
    AND LOWER(COALESCE(subsidy_status, '')) NOT IN ('received', 'completed')
    AND LOWER(COALESCE(rts_status, '')) != 'completed';
$$;
