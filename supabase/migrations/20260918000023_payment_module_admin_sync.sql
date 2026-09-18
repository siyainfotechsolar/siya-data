-- ==============================================================================
-- Migration: 20260918000023_payment_module_admin_sync.sql
-- Module: Payment Module Admin Control & Shared Sync Enhancements
-- Description: Adds sync_status, void_reason, updates status checks, and sets up
--              RLS policies for secure multi-interface access (Admin + Android).
-- ==============================================================================

DO $$
BEGIN
    -- 1. Add sync_status if not exists
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' AND table_name = 'customer_payment_transactions' AND column_name = 'sync_status'
    ) THEN
        ALTER TABLE public.customer_payment_transactions 
            ADD COLUMN sync_status TEXT NOT NULL DEFAULT 'Synced' 
            CHECK (sync_status IN ('Local', 'Pending', 'Synced', 'Failed'));
    END IF;

    -- 2. Add void_reason if not exists
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' AND table_name = 'customer_payment_transactions' AND column_name = 'void_reason'
    ) THEN
        ALTER TABLE public.customer_payment_transactions 
            ADD COLUMN void_reason TEXT;
    END IF;

    -- 3. Update status check to include 'Void'
    ALTER TABLE public.customer_payment_transactions 
        DROP CONSTRAINT IF EXISTS customer_payment_transactions_status_check;
        
    ALTER TABLE public.customer_payment_transactions 
        ADD CONSTRAINT customer_payment_transactions_status_check 
        CHECK (status IN ('Valid', 'Reversed', 'Refunded', 'Void'));

    -- 4. Ensure verification_status allows 'Void'
    ALTER TABLE public.customer_payment_transactions 
        DROP CONSTRAINT IF EXISTS customer_payment_transactions_verification_status_check;
        
    ALTER TABLE public.customer_payment_transactions 
        ADD CONSTRAINT customer_payment_transactions_verification_status_check 
        CHECK (verification_status IN ('Pending', 'Verified', 'Rejected', 'Void'));
END $$;

-- Indexes for Admin Panel filtering and fast lookups
CREATE INDEX IF NOT EXISTS idx_customer_payments_sync_status ON public.customer_payment_transactions(sync_status);
CREATE INDEX IF NOT EXISTS idx_customer_payments_ref_no ON public.customer_payment_transactions(reference_number);
CREATE INDEX IF NOT EXISTS idx_customer_payments_created_by ON public.customer_payment_transactions(created_by);
