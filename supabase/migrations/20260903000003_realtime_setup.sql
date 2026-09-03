-- Migration: 20260903000003_realtime_setup.sql
-- Enables Supabase Realtime for consumer_records and ensures full replication payload

-- 1. Set REPLICA IDENTITY FULL so UPDATE and DELETE events contain full record payloads
ALTER TABLE public.consumer_records REPLICA IDENTITY FULL;

-- 2. Add consumer_records table to supabase_realtime publication if not already present
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables 
    WHERE pubname = 'supabase_realtime' 
      AND schemaname = 'public' 
      AND tablename = 'consumer_records'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.consumer_records;
  END IF;
END $$;
