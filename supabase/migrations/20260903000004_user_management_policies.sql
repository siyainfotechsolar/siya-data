-- Migration: 20260903000004_user_management_policies.sql
-- Description: Ensures Admin can manage all user profiles and permissions

-- 1. Ensure RLS is active on profiles
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- 2. Allow Admins to update user profiles (role, is_active, can_delete)
DROP POLICY IF EXISTS "Admins can update profiles" ON public.profiles;
CREATE POLICY "Admins can update profiles"
  ON public.profiles
  FOR UPDATE
  TO authenticated
  USING ((SELECT public.is_admin()))
  WITH CHECK ((SELECT public.is_admin()));

-- 3. Ensure Admins can view all profiles
DROP POLICY IF EXISTS "Admins can read all profiles" ON public.profiles;
CREATE POLICY "Admins can read all profiles"
  ON public.profiles
  FOR SELECT
  TO authenticated
  USING ((SELECT public.is_admin()) OR (SELECT auth.uid()) = id);
