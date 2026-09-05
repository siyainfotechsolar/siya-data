-- ==============================================================================
-- Migration: Mark as Complete — Customer Work State & Priority List Exclusion
-- Adds customer_work_state column and updates get_priority_summary_counts()
-- ==============================================================================

-- 1. Add customer_work_state column to public.consumer_records
ALTER TABLE public.consumer_records
    ADD COLUMN IF NOT EXISTS customer_work_state TEXT NOT NULL DEFAULT 'ACTIVE';

-- 2. Performance Index for active work state filtering
CREATE INDEX IF NOT EXISTS idx_consumer_records_work_state
ON public.consumer_records (customer_work_state)
WHERE deleted = false;

-- 3. Update get_priority_summary_counts() RPC to exclude customer_work_state = 'COMPLETED'
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
    AND UPPER(COALESCE(customer_work_state, 'ACTIVE')) != 'COMPLETED'
    AND LOWER(COALESCE(status, '')) NOT IN ('completed', 'cancelled')
    AND LOWER(COALESCE(application_status, '')) NOT IN ('completed', 'cancelled')
    AND LOWER(COALESCE(subsidy_status, '')) NOT IN ('received', 'completed')
    AND LOWER(COALESCE(rts_status, '')) != 'completed';
$$;
