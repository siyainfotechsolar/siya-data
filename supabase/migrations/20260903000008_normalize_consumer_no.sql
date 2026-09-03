-- Migration 20260903000008: Consumer Number Normalization & Duplicate Matching Engine

-- 1. Create helper function to normalize consumer numbers in Postgres
CREATE OR REPLACE FUNCTION normalize_consumer_no(raw text)
RETURNS text AS $$
BEGIN
  IF raw IS NULL THEN
    RETURN '';
  END IF;
  
  -- Trim leading/trailing spaces, quotes, apostrophes, backticks, remove internal spaces & hyphens, strip trailing .0
  RETURN upper(
    regexp_replace(
      regexp_replace(
        trim(both '''' FROM trim(both '"' FROM trim(both '`' FROM trim(raw)))),
        '[\s\-]+', '', 'g'
      ),
      '\.0$', ''
    )
  );
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- 2. Create index on normalized consumer_no for high-performance duplicate detection
CREATE INDEX IF NOT EXISTS idx_consumer_records_normalized_no
ON consumer_records (normalize_consumer_no(consumer_no))
WHERE deleted = false;

-- 3. RPC function to query active consumer records matching any normalized consumer number
CREATE OR REPLACE FUNCTION match_consumer_records_by_normalized_no(normalized_nos text[])
RETURNS SETOF consumer_records AS $$
BEGIN
  RETURN QUERY
  SELECT *
  FROM consumer_records
  WHERE deleted = false
    AND normalize_consumer_no(consumer_no) = ANY(
      SELECT upper(
        regexp_replace(
          regexp_replace(
            trim(both '''' FROM trim(both '"' FROM trim(both '`' FROM trim(val)))),
            '[\s\-]+', '', 'g'
          ),
          '\.0$', ''
        )
      )
      FROM unnest(normalized_nos) AS val
    );
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION normalize_consumer_no(text) TO authenticated, anon, service_role;
GRANT EXECUTE ON FUNCTION match_consumer_records_by_normalized_no(text[]) TO authenticated, anon, service_role;
