-- ==============================================================================
-- Complete Consolidated Database Setup Script for Siya Data System
-- Run this in your Supabase SQL Editor to apply Phase 2 Database & Security
-- ==============================================================================

-- 1. App Roles Enum
DO $$ BEGIN
    CREATE TYPE public.app_role AS ENUM ('admin', 'staff');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

-- 2. User Profiles Table (Linked to Supabase Auth)
CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    email TEXT NOT NULL,
    role public.app_role NOT NULL DEFAULT 'staff',
    full_name TEXT,
    is_active BOOLEAN NOT NULL DEFAULT true,
    can_delete BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- 3. Consumer Records Table (Strict Unique constraint on consumer_no)
CREATE TABLE IF NOT EXISTS public.consumer_records (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    consumer_no TEXT NOT NULL UNIQUE,
    name TEXT NOT NULL,
    mobile TEXT,
    address TEXT,
    application_id TEXT,
    status TEXT NOT NULL DEFAULT 'Pending',
    remarks TEXT,
    deleted BOOLEAN NOT NULL DEFAULT false,
    deleted_at TIMESTAMPTZ,
    deleted_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    created_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    updated_by UUID REFERENCES auth.users(id) ON DELETE SET NULL
);

-- 4. Audit Log Foundation Table
CREATE TABLE IF NOT EXISTS public.audit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    record_id UUID REFERENCES public.consumer_records(id) ON DELETE SET NULL,
    consumer_no TEXT,
    action TEXT NOT NULL, -- 'INSERT', 'UPDATE', 'DELETE', 'BULK_DELETE', 'RESTORE', 'PERMANENT_DELETE', 'IMPORT'
    field_name TEXT,
    old_value TEXT,
    new_value TEXT,
    changed_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    source TEXT NOT NULL DEFAULT 'Admin Web',
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- 5. Performance Indexes
CREATE INDEX IF NOT EXISTS idx_consumer_records_consumer_no ON public.consumer_records (consumer_no);
CREATE INDEX IF NOT EXISTS idx_consumer_records_application_id ON public.consumer_records (application_id);
CREATE INDEX IF NOT EXISTS idx_consumer_records_mobile ON public.consumer_records (mobile);
CREATE INDEX IF NOT EXISTS idx_consumer_records_status ON public.consumer_records (status);
CREATE INDEX IF NOT EXISTS idx_consumer_records_updated_at ON public.consumer_records (updated_at DESC);
CREATE INDEX IF NOT EXISTS idx_consumer_records_deleted_updated ON public.consumer_records (deleted, updated_at DESC);
CREATE INDEX IF NOT EXISTS idx_consumer_records_deleted_consumer_no ON public.consumer_records (consumer_no) WHERE deleted = false;
CREATE INDEX IF NOT EXISTS idx_audit_logs_consumer_no ON public.audit_logs (consumer_no);
CREATE INDEX IF NOT EXISTS idx_audit_logs_created_at ON public.audit_logs (created_at DESC);
CREATE INDEX IF NOT EXISTS idx_profiles_role ON public.profiles (role);

-- 6. Enable RLS
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.consumer_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.audit_logs ENABLE ROW LEVEL SECURITY;

-- 7. Security Helper Functions
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

CREATE OR REPLACE FUNCTION public.can_delete_records()
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
      AND (role = 'admin' OR can_delete = true)
  );
$$;

REVOKE EXECUTE ON FUNCTION public.is_admin() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.is_admin() TO authenticated;
REVOKE EXECUTE ON FUNCTION public.is_active_user() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.is_active_user() TO authenticated;
REVOKE EXECUTE ON FUNCTION public.can_delete_records() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.can_delete_records() TO authenticated;

-- 8. Policies
-- Profiles
DROP POLICY IF EXISTS "Users can read own profile" ON public.profiles;
CREATE POLICY "Users can read own profile" ON public.profiles FOR SELECT TO authenticated USING ((SELECT auth.uid()) = id);

DROP POLICY IF EXISTS "Admins can read all profiles" ON public.profiles;
CREATE POLICY "Admins can read all profiles" ON public.profiles FOR SELECT TO authenticated USING ((SELECT public.is_admin()));

DROP POLICY IF EXISTS "Admins can manage profiles" ON public.profiles;
CREATE POLICY "Admins can manage profiles" ON public.profiles FOR ALL TO authenticated USING ((SELECT public.is_admin()));

-- Consumer Records
DROP POLICY IF EXISTS "Admins have full access to consumer_records" ON public.consumer_records;
CREATE POLICY "Admins have full access to consumer_records" ON public.consumer_records FOR ALL TO authenticated USING ((SELECT public.is_admin())) WITH CHECK ((SELECT public.is_admin()));

DROP POLICY IF EXISTS "Staff can view consumer_records" ON public.consumer_records;
CREATE POLICY "Staff can view consumer_records" ON public.consumer_records FOR SELECT TO authenticated USING (
  (SELECT public.is_admin()) 
  OR ((SELECT public.is_active_user()) AND deleted = false)
);

DROP POLICY IF EXISTS "Staff can update consumer_records" ON public.consumer_records;
CREATE POLICY "Staff can update consumer_records" ON public.consumer_records FOR UPDATE TO authenticated USING (
  (SELECT public.is_admin())
  OR ((SELECT public.can_delete_records()) AND deleted = false)
  OR ((SELECT public.is_active_user()) AND deleted = false)
) WITH CHECK (
  (SELECT public.is_admin())
  OR ((SELECT public.can_delete_records()) AND deleted = true)
  OR ((SELECT public.is_active_user()) AND deleted = false)
);

DROP POLICY IF EXISTS "Staff can insert consumer_records" ON public.consumer_records;
CREATE POLICY "Staff can insert consumer_records" ON public.consumer_records FOR INSERT TO authenticated WITH CHECK ((SELECT public.is_active_user()));

-- Audit Logs
DROP POLICY IF EXISTS "Admins can view audit logs" ON public.audit_logs;
CREATE POLICY "Admins can view audit logs" ON public.audit_logs FOR SELECT TO authenticated USING ((SELECT public.is_admin()));

DROP POLICY IF EXISTS "Authenticated users can create audit logs" ON public.audit_logs;
CREATE POLICY "Authenticated users can create audit logs" ON public.audit_logs FOR INSERT TO authenticated WITH CHECK ((SELECT auth.uid()) = changed_by OR changed_by IS NULL);

-- 9. Automated Triggers
CREATE OR REPLACE FUNCTION public.handle_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.updated_at = timezone('utc'::text, now());
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_consumer_records_updated_at ON public.consumer_records;
CREATE TRIGGER trg_consumer_records_updated_at BEFORE UPDATE ON public.consumer_records FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

DROP TRIGGER IF EXISTS trg_profiles_updated_at ON public.profiles;
CREATE TRIGGER trg_profiles_updated_at BEFORE UPDATE ON public.profiles FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.profiles (id, email, full_name, role)
  VALUES (
    NEW.id,
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'full_name', NEW.email),
    COALESCE((NEW.raw_user_meta_data->>'role')::public.app_role, 'staff'::public.app_role)
  )
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created AFTER INSERT ON auth.users FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();
