-- Add application_date column to consumer_records table for application history/reporting
ALTER TABLE public.consumer_records ADD COLUMN IF NOT EXISTS application_date TIMESTAMPTZ;
