-- ==============================================================================
-- Migration 002: Row Level Security (RLS) and Role-Based Permissions
-- Description: Enables RLS, configures optimized policies for Admin and Staff.
-- ==============================================================================

-- 1. Enable RLS on all tables
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.consumer_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.audit_logs ENABLE ROW LEVEL SECURITY;

-- 2. Helper function: Check if current user is Admin (Cached & High Performance)
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id = (SELECT auth.uid())
      AND role = 'admin'
      AND is_active = true
  );
$$;

-- Helper function: Check if current user is Active Staff/Admin
CREATE OR REPLACE FUNCTION public.is_active_user()
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id = (SELECT auth.uid())
      AND is_active = true
  );
$$;

-- Revoke dangerous direct execute permissions
REVOKE EXECUTE ON FUNCTION public.is_admin() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.is_admin() TO authenticated;
REVOKE EXECUTE ON FUNCTION public.is_active_user() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.is_active_user() TO authenticated;

-- ==============================================================================
-- PROFILES POLICIES
-- ==============================================================================

-- Users can read their own profile
CREATE POLICY "Users can read own profile"
  ON public.profiles
  FOR SELECT
  TO authenticated
  USING ((SELECT auth.uid()) = id);

-- Admins can read all profiles
CREATE POLICY "Admins can read all profiles"
  ON public.profiles
  FOR SELECT
  TO authenticated
  USING ((SELECT public.is_admin()));

-- Admins can insert/update/delete profiles
CREATE POLICY "Admins can manage profiles"
  ON public.profiles
  FOR ALL
  TO authenticated
  USING ((SELECT public.is_admin()));

-- ==============================================================================
-- CONSUMER RECORDS POLICIES
-- ==============================================================================

-- Admin: Full Authorized Access (SELECT, INSERT, UPDATE, DELETE)
CREATE POLICY "Admins have full access to consumer_records"
  ON public.consumer_records
  FOR ALL
  TO authenticated
  USING ((SELECT public.is_admin()))
  WITH CHECK ((SELECT public.is_admin()));

-- Staff: Read access to active consumer records
CREATE POLICY "Staff can view consumer_records"
  ON public.consumer_records
  FOR SELECT
  TO authenticated
  USING ((SELECT public.is_active_user()));

-- Staff: Permitted Update access (Status, Remarks)
CREATE POLICY "Staff can update consumer_records"
  ON public.consumer_records
  FOR UPDATE
  TO authenticated
  USING ((SELECT public.is_active_user()))
  WITH CHECK ((SELECT public.is_active_user()));

-- ==============================================================================
-- AUDIT LOGS POLICIES
-- ==============================================================================

-- Admins can view all audit logs
CREATE POLICY "Admins can view audit logs"
  ON public.audit_logs
  FOR SELECT
  TO authenticated
  USING ((SELECT public.is_admin()));

-- Authenticated users can insert audit logs for actions they perform
CREATE POLICY "Authenticated users can create audit logs"
  ON public.audit_logs
  FOR INSERT
  TO authenticated
  WITH CHECK ((SELECT auth.uid()) = changed_by OR changed_by IS NULL);
