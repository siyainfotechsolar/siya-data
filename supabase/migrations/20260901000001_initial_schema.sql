-- ==============================================================================
-- Migration 001: Initial Core Schema
-- Description: Creates profiles, consumer_records, and audit_logs tables.
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
    action TEXT NOT NULL, -- 'INSERT', 'UPDATE', 'DELETE', 'IMPORT'
    field_name TEXT,
    old_value TEXT,
    new_value TEXT,
    changed_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    source TEXT NOT NULL DEFAULT 'Admin Web', -- 'Admin Web', 'Excel Import', 'Mobile App'
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- 5. Performance Indexes
CREATE INDEX IF NOT EXISTS idx_consumer_records_consumer_no ON public.consumer_records (consumer_no);
CREATE INDEX IF NOT EXISTS idx_consumer_records_application_id ON public.consumer_records (application_id);
CREATE INDEX IF NOT EXISTS idx_consumer_records_mobile ON public.consumer_records (mobile);
CREATE INDEX IF NOT EXISTS idx_consumer_records_status ON public.consumer_records (status);
CREATE INDEX IF NOT EXISTS idx_consumer_records_updated_at ON public.consumer_records (updated_at DESC);
CREATE INDEX IF NOT EXISTS idx_audit_logs_consumer_no ON public.audit_logs (consumer_no);
CREATE INDEX IF NOT EXISTS idx_audit_logs_created_at ON public.audit_logs (created_at DESC);
CREATE INDEX IF NOT EXISTS idx_profiles_role ON public.profiles (role);
