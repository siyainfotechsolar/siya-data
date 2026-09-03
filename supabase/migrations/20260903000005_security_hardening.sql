-- Migration: 20260903000005_security_hardening.sql
-- Description: Phase 10 - Security Hardening & SQL injection / RLS defense

-- 1. Tighten Search Path on Triggers & Functions
CREATE OR REPLACE FUNCTION public.handle_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    NEW.updated_at = timezone('utc'::text, now());
    RETURN NEW;
END;
$$;

-- 2. Audit log tampering protection: audit_logs cannot be UPDATED or DELETED by anyone
REVOKE UPDATE, DELETE ON public.audit_logs FROM authenticated, anon, PUBLIC;

-- 3. Ensure profiles cannot be deleted by non-admins
DROP POLICY IF EXISTS "Admins can delete profiles" ON public.profiles;
CREATE POLICY "Admins can delete profiles"
  ON public.profiles
  FOR DELETE
  TO authenticated
  USING ((SELECT public.is_admin()));

-- 4. Ensure non-empty status constraint
ALTER TABLE public.consumer_records 
DROP CONSTRAINT IF EXISTS chk_consumer_records_status_nonempty;

ALTER TABLE public.consumer_records 
ADD CONSTRAINT chk_consumer_records_status_nonempty 
CHECK (length(trim(status)) > 0);

-- 5. Additional index on audit_logs for user activity tracking
CREATE INDEX IF NOT EXISTS idx_audit_logs_changed_by_created 
ON public.audit_logs (changed_by, created_at DESC);
