-- ==============================================================================
-- Migration: Phase 7 - Soft Delete, Multi-Delete Permissions & Recycle Bin
-- ==============================================================================

-- 1. Add can_delete permission flag to user profiles
ALTER TABLE public.profiles 
ADD COLUMN IF NOT EXISTS can_delete BOOLEAN NOT NULL DEFAULT false;

-- 2. Add soft-delete fields to consumer_records
ALTER TABLE public.consumer_records 
ADD COLUMN IF NOT EXISTS deleted BOOLEAN NOT NULL DEFAULT false,
ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS deleted_by UUID REFERENCES auth.users(id) ON DELETE SET NULL;

-- 3. Performance Indexes for soft-delete filtering
CREATE INDEX IF NOT EXISTS idx_consumer_records_deleted_updated 
ON public.consumer_records (deleted, updated_at DESC);

CREATE INDEX IF NOT EXISTS idx_consumer_records_deleted_consumer_no 
ON public.consumer_records (consumer_no) 
WHERE deleted = false;

-- 4. Helper function to check if current user is authorized to delete
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

REVOKE EXECUTE ON FUNCTION public.can_delete_records() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.can_delete_records() TO authenticated;

-- 5. Updated RLS Policies for consumer_records

-- SELECT Policy: Staff can view non-deleted records; Admins can view all (including recycle bin)
DROP POLICY IF EXISTS "Staff can view consumer_records" ON public.consumer_records;
CREATE POLICY "Staff can view consumer_records" ON public.consumer_records 
FOR SELECT TO authenticated 
USING (
  (SELECT public.is_admin()) 
  OR ((SELECT public.is_active_user()) AND deleted = false)
);

-- UPDATE Policy:
-- - Regular updates require is_active_user()
-- - Soft-deleting (setting deleted = true) requires can_delete_records()
-- - Restoring (setting deleted = false when previously deleted) requires is_admin()
DROP POLICY IF EXISTS "Staff can update consumer_records" ON public.consumer_records;
CREATE POLICY "Staff can update consumer_records" ON public.consumer_records 
FOR UPDATE TO authenticated 
USING (
  (SELECT public.is_admin())
  OR ((SELECT public.can_delete_records()) AND deleted = false)
  OR ((SELECT public.is_active_user()) AND deleted = false)
) 
WITH CHECK (
  (SELECT public.is_admin())
  -- If soft deleting, must have can_delete_records permission
  OR ((SELECT public.can_delete_records()) AND deleted = true)
  -- If updating non-deleted fields, keep deleted false
  OR ((SELECT public.is_active_user()) AND deleted = false)
);

-- Hard DELETE Policy: Only Admins can permanently delete from database
DROP POLICY IF EXISTS "Admins have full access to consumer_records" ON public.consumer_records;
CREATE POLICY "Admins can delete consumer_records" ON public.consumer_records
FOR DELETE TO authenticated
USING ((SELECT public.is_admin()));

-- Full access policy for Admins covering INSERT, SELECT, UPDATE, DELETE
DROP POLICY IF EXISTS "Admins have full access to consumer_records" ON public.consumer_records;
CREATE POLICY "Admins have full access to consumer_records" ON public.consumer_records 
FOR ALL TO authenticated 
USING ((SELECT public.is_admin())) 
WITH CHECK ((SELECT public.is_admin()));
