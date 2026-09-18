-- ==============================================================================
-- Migration: 20260918000022_intelligent_payment_module.sql
-- Module: Intelligent Payment Management System
-- Description: Extends customer_payment_transactions with verification,
--              payment types, proof extraction, and stage rules.
-- ==============================================================================

DO $$
BEGIN
    -- 1. Add verification_status
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' AND table_name = 'customer_payment_transactions' AND column_name = 'verification_status'
    ) THEN
        ALTER TABLE public.customer_payment_transactions 
            ADD COLUMN verification_status TEXT NOT NULL DEFAULT 'Pending' 
            CHECK (verification_status IN ('Pending', 'Verified', 'Rejected'));
    END IF;

    -- 2. Add verified_by, verified_at, verification_remarks
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' AND table_name = 'customer_payment_transactions' AND column_name = 'verified_by'
    ) THEN
        ALTER TABLE public.customer_payment_transactions 
            ADD COLUMN verified_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
            ADD COLUMN verified_by_name TEXT,
            ADD COLUMN verified_at TIMESTAMPTZ,
            ADD COLUMN verification_remarks TEXT;
    END IF;

    -- 3. Add payment_type ('Online', 'Offline')
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' AND table_name = 'customer_payment_transactions' AND column_name = 'payment_type'
    ) THEN
        ALTER TABLE public.customer_payment_transactions 
            ADD COLUMN payment_type TEXT NOT NULL DEFAULT 'Offline' 
            CHECK (payment_type IN ('Online', 'Offline'));
    END IF;

    -- 4. Add extracted proof fields & mismatch tracking
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' AND table_name = 'customer_payment_transactions' AND column_name = 'extracted_amount'
    ) THEN
        ALTER TABLE public.customer_payment_transactions 
            ADD COLUMN extracted_amount NUMERIC(12, 2),
            ADD COLUMN extracted_date DATE,
            ADD COLUMN extracted_ref_no TEXT,
            ADD COLUMN proof_mismatch BOOLEAN NOT NULL DEFAULT FALSE;
    END IF;
END $$;

-- Indexes for fast querying & verification queues
CREATE INDEX IF NOT EXISTS idx_customer_payments_verify ON public.customer_payment_transactions(verification_status);
CREATE INDEX IF NOT EXISTS idx_customer_payments_type ON public.customer_payment_transactions(payment_type);
CREATE INDEX IF NOT EXISTS idx_customer_payments_mismatch ON public.customer_payment_transactions(proof_mismatch);
