-- ==============================================================================
-- Migration: 030 - Non-Subsidy Site Support & System Specifications
-- Description: Adds site_type ('Subsidy' or 'Non-Subsidy'), system_capacity,
--              and system_type to consumer_records and leads.
-- ==============================================================================

-- 1. Add columns to consumer_records
ALTER TABLE public.consumer_records
    ADD COLUMN IF NOT EXISTS site_type TEXT NOT NULL DEFAULT 'Subsidy',
    ADD COLUMN IF NOT EXISTS system_capacity TEXT,
    ADD COLUMN IF NOT EXISTS system_type TEXT;

-- 2. Add site_type to leads table
ALTER TABLE public.leads
    ADD COLUMN IF NOT EXISTS site_type TEXT NOT NULL DEFAULT 'Subsidy';

-- 3. Performance Indexes for Dashboard Metrics & Queue Filtering
CREATE INDEX IF NOT EXISTS idx_consumer_records_site_type 
    ON public.consumer_records (site_type) 
    WHERE deleted = false;

CREATE INDEX IF NOT EXISTS idx_leads_site_type 
    ON public.leads (site_type) 
    WHERE deleted = false;
