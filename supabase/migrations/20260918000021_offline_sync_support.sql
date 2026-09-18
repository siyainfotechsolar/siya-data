-- ==============================================================================
-- Migration: 20260918000021_offline_sync_support.sql
-- Module: Whole App Offline-First Support & Idempotent Synchronization
-- Description: Adds idempotency keys, client transaction IDs, and payment modes
-- ==============================================================================

-- 1. Support NEFT, RTGS in customer_payment_transactions and add idempotency columns
DO $$
BEGIN
    -- Add client_tx_id if not exists
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' AND table_name = 'customer_payment_transactions' AND column_name = 'client_tx_id'
    ) THEN
        ALTER TABLE public.customer_payment_transactions ADD COLUMN client_tx_id UUID UNIQUE;
    END IF;

    -- Add idempotency_key if not exists
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' AND table_name = 'customer_payment_transactions' AND column_name = 'idempotency_key'
    ) THEN
        ALTER TABLE public.customer_payment_transactions ADD COLUMN idempotency_key TEXT UNIQUE;
    END IF;

    -- Update payment_mode check constraint to include NEFT, RTGS
    ALTER TABLE public.customer_payment_transactions 
        DROP CONSTRAINT IF EXISTS customer_payment_transactions_payment_mode_check;
        
    ALTER TABLE public.customer_payment_transactions 
        ADD CONSTRAINT customer_payment_transactions_payment_mode_check 
        CHECK (payment_mode IN ('Cash', 'UPI', 'Bank Transfer', 'Cheque', 'NEFT', 'RTGS', 'Other'));
END $$;

-- 2. Add client_operation_id to customer_tasks for duplicate protection
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' AND table_name = 'customer_tasks' AND column_name = 'client_operation_id'
    ) THEN
        ALTER TABLE public.customer_tasks ADD COLUMN client_operation_id UUID UNIQUE;
    END IF;
END $$;

-- 3. Add client_operation_id to audit_logs for idempotent activity tracking
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' AND table_name = 'audit_logs' AND column_name = 'client_operation_id'
    ) THEN
        ALTER TABLE public.audit_logs ADD COLUMN client_operation_id UUID UNIQUE;
    END IF;
END $$;

-- Indexes for idempotent lookups
CREATE INDEX IF NOT EXISTS idx_customer_payments_client_tx_id ON public.customer_payment_transactions(client_tx_id);
CREATE INDEX IF NOT EXISTS idx_customer_payments_idempotency_key ON public.customer_payment_transactions(idempotency_key);
CREATE INDEX IF NOT EXISTS idx_customer_tasks_client_op_id ON public.customer_tasks(client_operation_id);
CREATE INDEX IF NOT EXISTS idx_audit_logs_client_op_id ON public.audit_logs(client_operation_id);
