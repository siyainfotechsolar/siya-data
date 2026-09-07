-- ==============================================================================
-- Migration: 20260907000019_user_management_expansion.sql
-- Description: Adds detailed staff attributes, status, granular permissions JSONB,
--              and updates handle_new_user() trigger to safely handle new roles.
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

-- 2. Convert profiles.role from app_role enum to TEXT so it can store any role
-- (super_admin, admin, office_staff, sales, loan_staff, installation_staff, accounts, viewer)
DO 
BEGIN
    -- Check if column data type is USER-DEFINED (app_role enum)
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
          AND table_name = 'profiles' 
          AND column_name = 'role' 
          AND data_type = 'USER-DEFINED'
    ) THEN
        ALTER TABLE public.profiles ALTER COLUMN role TYPE TEXT USING role::text;
    END IF;
END ;

-- 3. Replace handle_new_user() trigger function to safely accept TEXT role without enum crash
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS 
DECLARE
  v_role TEXT;
BEGIN
  v_role := COALESCE(NEW.raw_user_meta_data->>'role', 'staff');

  INSERT INTO public.profiles (
    id, 
    email, 
    full_name, 
    role, 
    mobile,
    status,
    is_active
  )
  VALUES (
    NEW.id,
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'full_name', NEW.email),
    v_role,
    NEW.raw_user_meta_data->>'mobile',
    'Active',
    true
  )
  ON CONFLICT (id) DO UPDATE SET
    email = EXCLUDED.email,
    full_name = COALESCE(EXCLUDED.full_name, profiles.full_name),
    role = COALESCE(EXCLUDED.role, profiles.role),
    mobile = COALESCE(EXCLUDED.mobile, profiles.mobile);

  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  -- Never abort auth.users signup on profile trigger error
  RAISE WARNING 'handle_new_user error: %', SQLERRM;
  RETURN NEW;
END;
;

-- Ensure trigger is connected to auth.users
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_new_user();

-- 4. Update is_admin function to recognize super_admin, owner, and admin roles
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
STABLE
AS 
  SELECT EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id = (SELECT auth.uid())
      AND role IN ('admin', 'super_admin', 'owner')
      AND is_active = true
  );
;

-- 5. Update is_active_user function to respect status as well
CREATE OR REPLACE FUNCTION public.is_active_user()
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
STABLE
AS 
  SELECT EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id = (SELECT auth.uid())
      AND is_active = true
      AND (status IS NULL OR status = 'Active')
  );
;

-- 6. Ensure profiles RLS allows admins full management and users self-view
DROP POLICY IF EXISTS "Admins can insert profiles" ON public.profiles;
CREATE POLICY "Admins can insert profiles"
  ON public.profiles
  FOR INSERT
  TO authenticated
  WITH CHECK ((SELECT public.is_admin()));

-- 7. Performance indexes
CREATE INDEX IF NOT EXISTS idx_profiles_employee_id ON public.profiles (employee_id);
CREATE INDEX IF NOT EXISTS idx_profiles_department ON public.profiles (department);
CREATE INDEX IF NOT EXISTS idx_profiles_status ON public.profiles (status);
CREATE INDEX IF NOT EXISTS idx_profiles_mobile ON public.profiles (mobile);
CREATE INDEX IF NOT EXISTS idx_consumer_records_assigned_staff ON public.consumer_records (assigned_staff) WHERE deleted = false;
CREATE INDEX IF NOT EXISTS idx_consumer_records_installer_team ON public.consumer_records (installer_team) WHERE deleted = false;
