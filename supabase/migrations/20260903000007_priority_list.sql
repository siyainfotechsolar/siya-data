-- ==============================================================================
-- Migration: Priority List Helper RPC & Indexes
-- Dynamic Application Days Based Priority List
-- ==============================================================================

-- 1. Performance index for sorting and filtering by submit_date & created_at
CREATE INDEX IF NOT EXISTS idx_consumer_records_submit_date_active 
ON public.consumer_records (submit_date ASC NULLS LAST, created_at ASC) 
WHERE deleted = false;

-- 2. Database RPC Function for aggregated priority summary counts
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
    AND LOWER(COALESCE(application_status, '')) NOT IN ('completed', 'cancelled');
$$;
