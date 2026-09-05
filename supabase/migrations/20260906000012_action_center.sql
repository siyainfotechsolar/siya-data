-- ==============================================================================
-- Migration: Smart Action Center & Workflow Module Replacement
-- Adds assigned_staff column and RPCs for Action Center and Today's Work counts
-- ==============================================================================

-- 1. Add assigned_staff column to public.consumer_records if not present
ALTER TABLE public.consumer_records
    ADD COLUMN IF NOT EXISTS assigned_staff TEXT;

-- 2. Performance Indexes for assigned_staff and Action Center queries
CREATE INDEX IF NOT EXISTS idx_consumer_records_assigned_staff
ON public.consumer_records (assigned_staff)
WHERE deleted = false;

-- 3. Database RPC Function for aggregated Action Center counts
CREATE OR REPLACE FUNCTION get_action_center_counts()
RETURNS TABLE (
  agreement_pending_count BIGINT,
  loan_pending_count BIGINT,
  installation_pending_count BIGINT,
  rts_pending_count BIGINT,
  subsidy_processing_count BIGINT,
  completed_count BIGINT
) LANGUAGE sql STABLE AS $$
  SELECT
    -- 1. Agreement Pending (Agreement not completed, work state ACTIVE)
    COUNT(*) FILTER (
      WHERE deleted = false AND is_merged = false
        AND UPPER(COALESCE(customer_work_state, 'ACTIVE')) != 'COMPLETED'
        AND LOWER(COALESCE(subsidy_status, '')) NOT IN ('received', 'completed')
        AND LOWER(COALESCE(status, '')) NOT IN ('completed', 'cancelled')
        AND LOWER(COALESCE(agreement_status, 'pending')) NOT IN ('verified', 'completed')
    ) AS agreement_pending_count,

    -- 2. Loan Pending (Agreement completed, Loan required = YES, Loan not completed, work state ACTIVE)
    COUNT(*) FILTER (
      WHERE deleted = false AND is_merged = false
        AND UPPER(COALESCE(customer_work_state, 'ACTIVE')) != 'COMPLETED'
        AND LOWER(COALESCE(subsidy_status, '')) NOT IN ('received', 'completed')
        AND LOWER(COALESCE(status, '')) NOT IN ('completed', 'cancelled')
        AND LOWER(COALESCE(agreement_status, 'pending')) IN ('verified', 'completed')
        AND LOWER(COALESCE(loan_required, 'no')) = 'yes'
        AND LOWER(COALESCE(loan_status, 'not required')) NOT IN ('approved', 'completed', 'not required')
    ) AS loan_pending_count,

    -- 3. Installation Pending (Agreement completed, Loan satisfied/skipped, Installation not completed, work state ACTIVE)
    COUNT(*) FILTER (
      WHERE deleted = false AND is_merged = false
        AND UPPER(COALESCE(customer_work_state, 'ACTIVE')) != 'COMPLETED'
        AND LOWER(COALESCE(subsidy_status, '')) NOT IN ('received', 'completed')
        AND LOWER(COALESCE(status, '')) NOT IN ('completed', 'cancelled')
        AND LOWER(COALESCE(agreement_status, 'pending')) IN ('verified', 'completed')
        AND (
          LOWER(COALESCE(loan_required, 'no')) != 'yes'
          OR LOWER(COALESCE(loan_status, 'not required')) IN ('approved', 'completed', 'not required')
        )
        AND LOWER(COALESCE(installation_status, 'not started')) NOT IN ('installation completed', 'completed')
    ) AS installation_pending_count,

    -- 4. RTS Pending (Installation completed, RTS not completed, work state ACTIVE)
    COUNT(*) FILTER (
      WHERE deleted = false AND is_merged = false
        AND UPPER(COALESCE(customer_work_state, 'ACTIVE')) != 'COMPLETED'
        AND LOWER(COALESCE(subsidy_status, '')) NOT IN ('received', 'completed')
        AND LOWER(COALESCE(status, '')) NOT IN ('completed', 'cancelled')
        AND LOWER(COALESCE(installation_status, 'not started')) IN ('installation completed', 'completed')
        AND LOWER(COALESCE(rts_status, 'not started')) != 'completed'
    ) AS rts_pending_count,

    -- 5. Subsidy Processing (RTS completed, Subsidy not received, work state ACTIVE)
    COUNT(*) FILTER (
      WHERE deleted = false AND is_merged = false
        AND UPPER(COALESCE(customer_work_state, 'ACTIVE')) != 'COMPLETED'
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
    ) AS completed_count
  FROM public.consumer_records;
$$;

-- 4. Database RPC Function for Today's Work counts
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
