-- ==============================================================================
-- Migration: 20260918000024_soft_delete_and_security_hardening.sql
-- Module: Financial Ledger & Issues Soft Delete and Security Hardening
-- Description: Adds deleted columns to customer_issues and customer_payment_transactions,
--              updates payment recalculation trigger to honor soft-deletes & void states,
--              and configures robust RLS policies for payment transactions.
-- ==============================================================================

DO $$
BEGIN
    -- 1. Soft-delete column for customer_issues
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' AND table_name = 'customer_issues' AND column_name = 'deleted'
    ) THEN
        ALTER TABLE public.customer_issues 
            ADD COLUMN deleted BOOLEAN NOT NULL DEFAULT false;
    END IF;

    -- 2. Soft-delete column for customer_payment_transactions
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' AND table_name = 'customer_payment_transactions' AND column_name = 'deleted'
    ) THEN
        ALTER TABLE public.customer_payment_transactions 
            ADD COLUMN deleted BOOLEAN NOT NULL DEFAULT false;
    END IF;
END $$;

-- 3. Indexes for fast filtered queries
CREATE INDEX IF NOT EXISTS idx_customer_issues_deleted ON public.customer_issues(deleted);
CREATE INDEX IF NOT EXISTS idx_customer_payments_deleted ON public.customer_payment_transactions(deleted);

-- 4. Update recalculate_customer_payment_summary trigger function
CREATE OR REPLACE FUNCTION public.recalculate_customer_payment_summary()
RETURNS TRIGGER AS $$
DECLARE
    target_customer_id UUID;
    v_total NUMERIC(12, 2) := 0;
    v_paid NUMERIC(12, 2) := 0;
    v_pending NUMERIC(12, 2) := 0;
    v_status TEXT := 'Pending';
    v_due_date DATE;
BEGIN
    -- Determine target customer ID
    IF TG_OP = 'DELETE' THEN
        target_customer_id := OLD.customer_id;
    ELSE
        target_customer_id := NEW.customer_id;
    END IF;

    -- Fetch current total_amount and due_date from consumer_records
    SELECT COALESCE(total_amount, 0), payment_due_date
    INTO v_total, v_due_date
    FROM public.consumer_records
    WHERE id = target_customer_id;

    -- Sum all valid, non-deleted, non-rejected, non-void payment transactions
    SELECT COALESCE(SUM(amount), 0)
    INTO v_paid
    FROM public.customer_payment_transactions
    WHERE customer_id = target_customer_id 
      AND status = 'Valid'
      AND COALESCE(deleted, false) = false
      AND COALESCE(verification_status, 'Pending') NOT IN ('Rejected', 'Void');

    -- Pending balance
    v_pending := GREATEST(0, v_total - v_paid);

    -- Calculate Status
    IF v_total > 0 AND v_paid >= v_total THEN
        v_status := 'Paid';
    ELSIF v_due_date IS NOT NULL AND v_due_date < CURRENT_DATE AND v_pending > 0 THEN
        v_status := 'Overdue';
    ELSIF v_paid > 0 AND v_pending > 0 THEN
        v_status := 'Partially Paid';
    ELSE
        v_status := 'Pending';
    END IF;

    -- Update consumer_records
    UPDATE public.consumer_records
    SET paid_amount = v_paid,
        pending_amount = v_pending,
        payment_status = v_status,
        updated_at = timezone('utc'::text, now())
    WHERE id = target_customer_id;

    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- 5. RLS Policies on customer_payment_transactions
ALTER TABLE public.customer_payment_transactions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Authenticated full access to customer_payment_transactions" ON public.customer_payment_transactions;

-- Select policy: Authenticated users can view payments that are not soft-deleted, or admins can view all
CREATE POLICY "Authenticated users view payment transactions"
    ON public.customer_payment_transactions
    FOR SELECT
    TO authenticated
    USING (
        deleted = false OR 
        (EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin'))
    );

-- Insert policy: Authenticated staff can insert payments
CREATE POLICY "Authenticated users insert payment transactions"
    ON public.customer_payment_transactions
    FOR INSERT
    TO authenticated
    WITH CHECK (auth.uid() IS NOT NULL);

-- Update policy: Staff can update their own payments or admins can update any
CREATE POLICY "Authenticated users update payment transactions"
    ON public.customer_payment_transactions
    FOR UPDATE
    TO authenticated
    USING (
        created_by = auth.uid() OR
        (EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin'))
    )
    WITH CHECK (
        created_by = auth.uid() OR
        (EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin'))
    );

-- Delete policy: Only admins can hard-delete; staff use soft-delete via UPDATE
CREATE POLICY "Admin delete payment transactions"
    ON public.customer_payment_transactions
    FOR DELETE
    TO authenticated
    USING (
        EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
    );
