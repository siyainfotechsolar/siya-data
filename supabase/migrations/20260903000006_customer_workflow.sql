-- ==============================================================================
-- Migration: Customer Application Workflow & Multi-Stage Lifecycle
-- Adds independent status tracking columns and indexes to public.consumer_records
-- ==============================================================================

-- 1. Add Workflow Columns to consumer_records
ALTER TABLE public.consumer_records
    -- Application Stage
    ADD COLUMN IF NOT EXISTS application_status TEXT NOT NULL DEFAULT 'Submitted',
    ADD COLUMN IF NOT EXISTS submit_date TIMESTAMPTZ DEFAULT timezone('utc'::text, now()),

    -- Agreement Stage
    ADD COLUMN IF NOT EXISTS agreement_required BOOLEAN NOT NULL DEFAULT true,
    ADD COLUMN IF NOT EXISTS agreement_status TEXT NOT NULL DEFAULT 'Pending',
    ADD COLUMN IF NOT EXISTS agreement_doc_url TEXT,
    ADD COLUMN IF NOT EXISTS agreement_date TIMESTAMPTZ,

    -- Loan Decision Stage
    ADD COLUMN IF NOT EXISTS loan_required TEXT NOT NULL DEFAULT 'No',
    ADD COLUMN IF NOT EXISTS loan_status TEXT NOT NULL DEFAULT 'Not Required',
    ADD COLUMN IF NOT EXISTS loan_applied_date TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS loan_approved_date TIMESTAMPTZ,

    -- Installation Stage
    ADD COLUMN IF NOT EXISTS installation_status TEXT NOT NULL DEFAULT 'Not Started',
    ADD COLUMN IF NOT EXISTS installation_date TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS installer_team TEXT,
    ADD COLUMN IF NOT EXISTS installation_photos_url TEXT,

    -- RTS / Net Meter Stage
    ADD COLUMN IF NOT EXISTS rts_status TEXT NOT NULL DEFAULT 'Not Started',
    ADD COLUMN IF NOT EXISTS rts_application_id TEXT,
    ADD COLUMN IF NOT EXISTS rts_date TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS rts_completion_date TIMESTAMPTZ,

    -- Subsidy Stage
    ADD COLUMN IF NOT EXISTS subsidy_status TEXT NOT NULL DEFAULT 'Not Applied',
    ADD COLUMN IF NOT EXISTS subsidy_applied_date TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS subsidy_approved_date TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS subsidy_received_date TIMESTAMPTZ;

-- 2. Performance Indexes for Dashboard Queues & Filtering
CREATE INDEX IF NOT EXISTS idx_consumer_records_agreement_status ON public.consumer_records (agreement_status) WHERE deleted = false;
CREATE INDEX IF NOT EXISTS idx_consumer_records_loan_status ON public.consumer_records (loan_status) WHERE deleted = false;
CREATE INDEX IF NOT EXISTS idx_consumer_records_installation_status ON public.consumer_records (installation_status) WHERE deleted = false;
CREATE INDEX IF NOT EXISTS idx_consumer_records_rts_status ON public.consumer_records (rts_status) WHERE deleted = false;
CREATE INDEX IF NOT EXISTS idx_consumer_records_subsidy_status ON public.consumer_records (subsidy_status) WHERE deleted = false;
CREATE INDEX IF NOT EXISTS idx_consumer_records_submit_date ON public.consumer_records (submit_date DESC) WHERE deleted = false;
