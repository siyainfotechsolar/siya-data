-- Migration 20260903000009: Duplicate Finder & Smart Merge Database Infrastructure

-- 1. Add Smart Merge columns to consumer_records table
ALTER TABLE consumer_records
ADD COLUMN IF NOT EXISTS is_merged BOOLEAN DEFAULT false,
ADD COLUMN IF NOT EXISTS merged_into_id UUID REFERENCES consumer_records(id) ON DELETE SET NULL,
ADD COLUMN IF NOT EXISTS merged_at TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS merged_by UUID REFERENCES auth.users(id) ON DELETE SET NULL;

-- 2. Partial index for active (un-deleted, un-merged) records
CREATE INDEX IF NOT EXISTS idx_consumer_records_active_unmerged
ON consumer_records (submit_date ASC NULLS LAST, created_at ASC)
WHERE deleted = false AND is_merged = false;

-- 3. Atomic Smart Merge RPC function executing inside a transaction
CREATE OR REPLACE FUNCTION execute_smart_merge(
  master_id UUID,
  duplicate_ids UUID[],
  merged_payload JSONB,
  conflicts_summary JSONB DEFAULT '{}'::jsonb,
  executing_user_id UUID DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
  dup_id UUID;
  affected_count INT := 0;
  audit_details JSONB;
BEGIN
  -- Validate master_id exists
  IF NOT EXISTS (SELECT 1 FROM consumer_records WHERE id = master_id) THEN
    RAISE EXCEPTION 'Master record % does not exist.', master_id;
  END IF;

  -- 1. Update Master Record with merged_payload
  UPDATE consumer_records
  SET
    consumer_no = COALESCE(merged_payload->>'consumer_no', consumer_no),
    name = COALESCE(merged_payload->>'name', name),
    mobile = COALESCE(merged_payload->>'mobile', mobile),
    address = COALESCE(merged_payload->>'address', address),
    application_id = COALESCE(merged_payload->>'application_id', application_id),
    status = COALESCE(merged_payload->>'status', status),
    remarks = COALESCE(merged_payload->>'remarks', remarks),
    application_status = COALESCE(merged_payload->>'application_status', application_status),
    agreement_required = COALESCE((merged_payload->>'agreement_required')::boolean, agreement_required),
    agreement_status = COALESCE(merged_payload->>'agreement_status', agreement_status),
    agreement_doc_url = COALESCE(merged_payload->>'agreement_doc_url', agreement_doc_url),
    loan_required = COALESCE(merged_payload->>'loan_required', loan_required),
    loan_status = COALESCE(merged_payload->>'loan_status', loan_status),
    installation_status = COALESCE(merged_payload->>'installation_status', installation_status),
    installer_team = COALESCE(merged_payload->>'installer_team', installer_team),
    installation_photos_url = COALESCE(merged_payload->>'installation_photos_url', installation_photos_url),
    rts_status = COALESCE(merged_payload->>'rts_status', rts_status),
    rts_application_id = COALESCE(merged_payload->>'rts_application_id', rts_application_id),
    subsidy_status = COALESCE(merged_payload->>'subsidy_status', subsidy_status),
    submit_date = CASE WHEN merged_payload->>'submit_date' IS NOT NULL THEN (merged_payload->>'submit_date')::timestamptz ELSE submit_date END,
    agreement_date = CASE WHEN merged_payload->>'agreement_date' IS NOT NULL THEN (merged_payload->>'agreement_date')::timestamptz ELSE agreement_date END,
    loan_applied_date = CASE WHEN merged_payload->>'loan_applied_date' IS NOT NULL THEN (merged_payload->>'loan_applied_date')::timestamptz ELSE loan_applied_date END,
    loan_approved_date = CASE WHEN merged_payload->>'loan_approved_date' IS NOT NULL THEN (merged_payload->>'loan_approved_date')::timestamptz ELSE loan_approved_date END,
    installation_date = CASE WHEN merged_payload->>'installation_date' IS NOT NULL THEN (merged_payload->>'installation_date')::timestamptz ELSE installation_date END,
    rts_date = CASE WHEN merged_payload->>'rts_date' IS NOT NULL THEN (merged_payload->>'rts_date')::timestamptz ELSE rts_date END,
    rts_completion_date = CASE WHEN merged_payload->>'rts_completion_date' IS NOT NULL THEN (merged_payload->>'rts_completion_date')::timestamptz ELSE rts_completion_date END,
    subsidy_applied_date = CASE WHEN merged_payload->>'subsidy_applied_date' IS NOT NULL THEN (merged_payload->>'subsidy_applied_date')::timestamptz ELSE subsidy_applied_date END,
    subsidy_approved_date = CASE WHEN merged_payload->>'subsidy_approved_date' IS NOT NULL THEN (merged_payload->>'subsidy_approved_date')::timestamptz ELSE subsidy_approved_date END,
    subsidy_received_date = CASE WHEN merged_payload->>'subsidy_received_date' IS NOT NULL THEN (merged_payload->>'subsidy_received_date')::timestamptz ELSE subsidy_received_date END,
    updated_at = NOW(),
    updated_by = executing_user_id
  WHERE id = master_id;

  -- 2. Mark Duplicate Records as merged (is_merged = true)
  FOREACH dup_id IN ARRAY duplicate_ids
  LOOP
    IF dup_id <> master_id THEN
      UPDATE consumer_records
      SET
        is_merged = true,
        merged_into_id = master_id,
        merged_at = NOW(),
        merged_by = executing_user_id,
        updated_at = NOW(),
        updated_by = executing_user_id
      WHERE id = dup_id;
      affected_count := affected_count + 1;
    END IF;
  END LOOP;

  -- 3. Write permanent Audit Log record
  audit_details := jsonb_build_object(
    'master_id', master_id,
    'duplicate_ids', duplicate_ids,
    'merged_count', affected_count,
    'conflicts_resolved', conflicts_summary,
    'merged_payload', merged_payload
  );

  INSERT INTO audit_logs (
    record_id,
    consumer_no,
    action,
    field_name,
    old_value,
    new_value,
    changed_by,
    source,
    created_at
  ) VALUES (
    master_id,
    COALESCE(merged_payload->>'consumer_no', 'MERGED'),
    'SMART_MERGE',
    'Smart Merge Execution',
    'Multiple Duplicates',
    audit_details::text,
    executing_user_id,
    'Admin Panel',
    NOW()
  );

  RETURN jsonb_build_object(
    'success', true,
    'master_id', master_id,
    'merged_count', affected_count
  );
EXCEPTION
  WHEN OTHERS THEN
    RAISE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION execute_smart_merge(UUID, UUID[], JSONB, JSONB, UUID) TO authenticated, anon, service_role;
