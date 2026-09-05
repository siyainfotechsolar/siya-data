-- ==============================================================================
-- Migration: Smart Loan Re-Apply Workflow & Bank Sub-Stages
-- Adds loan sub-stage tracking, rejection details, re-apply counters, and attempts history
-- ==============================================================================

-- 1. Add Smart Loan Workflow Columns to consumer_records
ALTER TABLE public.consumer_records
    ADD COLUMN IF NOT EXISTS loan_sub_stage TEXT NOT NULL DEFAULT 'Loan Applied',
    ADD COLUMN IF NOT EXISTS loan_reapply_count INTEGER NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS rejection_reason TEXT,
    ADD COLUMN IF NOT EXISTS bank_remarks TEXT,
    ADD COLUMN IF NOT EXISTS correction_required TEXT,
    ADD COLUMN IF NOT EXISTS rejection_date TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS last_reapply_date TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS loan_attempts JSONB NOT NULL DEFAULT '[]'::jsonb;

-- 2. Performance Index for Loan Sub-Stage Filtering
CREATE INDEX IF NOT EXISTS idx_consumer_records_loan_sub_stage ON public.consumer_records (loan_sub_stage) WHERE deleted = false;
CREATE INDEX IF NOT EXISTS idx_consumer_records_loan_reapply_count ON public.consumer_records (loan_reapply_count) WHERE deleted = false;
