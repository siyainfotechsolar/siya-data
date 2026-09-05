-- ==============================================================================
-- Migration: Workflow-Aware Priority List Helper RPC
-- Excludes Completed, Subsidy Received, and Subsidy Processing records from Active Priority Counts
-- ==============================================================================

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
    AND LOWER(COALESCE(status, '')) NOT IN ('completed', 'cancelled')
    AND LOWER(COALESCE(application_status, '')) NOT IN ('completed', 'cancelled')
    AND LOWER(COALESCE(subsidy_status, '')) NOT IN ('received', 'completed')
    AND LOWER(COALESCE(rts_status, '')) != 'completed';
$$;
