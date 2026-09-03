-- ==============================================================================
-- Migration: Add INSERT policy for staff users on consumer_records
-- Fixes: Staff users could not insert records via import (upsert requires INSERT)
-- ==============================================================================

-- Allow active staff users to insert new consumer records
DROP POLICY IF EXISTS "Staff can insert consumer_records" ON public.consumer_records;
CREATE POLICY "Staff can insert consumer_records" ON public.consumer_records
  FOR INSERT TO authenticated
  WITH CHECK ((SELECT public.is_active_user()));
