-- ==============================================================================
-- Migration: 20260907000019_user_management_expansion.sql
-- Description: Adds detailed staff attributes, status, granular permissions JSONB,
--              and workload optimization indexes to profiles table.
-- ==============================================================================

-- 1. Add extended fields to profiles table
ALTER TABLE public.profiles
ADD COLUMN IF NOT EXISTS mobile TEXT,
ADD COLUMN IF NOT EXISTS employee_id TEXT,
ADD COLUMN IF NOT EXISTS department TEXT,
ADD COLUMN IF NOT EXISTS status TEXT NOT NULL DEFAULT 'Active',
ADD COLUMN IF NOT EXISTS permissions JSONB NOT NULL DEFAULT '{}'::jsonb,
ADD COLUMN IF NOT EXISTS remarks TEXT,
ADD COLUMN IF NOT EXISTS profile_photo_url TEXT;

-- 2. Indexes for fast filtering and staff searches
CREATE INDEX IF NOT EXISTS idx_profiles_employee_id ON public.profiles (employee_id);
CREATE INDEX IF NOT EXISTS idx_profiles_department ON public.profiles (department);
CREATE INDEX IF NOT EXISTS idx_profiles_status ON public.profiles (status);
CREATE INDEX IF NOT EXISTS idx_profiles_mobile ON public.profiles (mobile);

-- 3. Ensure profiles RLS allows admins full management and users self-view
DROP POLICY IF EXISTS "Admins can insert profiles" ON public.profiles;
CREATE POLICY "Admins can insert profiles"
  ON public.profiles
  FOR INSERT
  TO authenticated
  WITH CHECK ((SELECT public.is_admin()));

-- 4. Update is_active_user function to respect status as well
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
      AND (status IS NULL OR status = 'Active')
  );
$$;

-- 5. Performance index on consumer_records assigned_staff
CREATE INDEX IF NOT EXISTS idx_consumer_records_assigned_staff
  ON public.consumer_records (assigned_staff)
  WHERE deleted = false;

CREATE INDEX IF NOT EXISTS idx_consumer_records_installer_team
  ON public.consumer_records (installer_team)
  WHERE deleted = false;
