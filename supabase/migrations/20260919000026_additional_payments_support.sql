-- ==============================================================================
-- Migration: 20260919000026_additional_payments_support.sql
-- Module: Additional Payments Support (Contract vs Additional Separation)
-- Description:
--   1. Adds additional_category to customer_payment_transactions.
--   2. Adds additional_paid_amount & total_received_amount to consumer_records.
--   3. Updates recalculate_customer_payment_summary() to guarantee that
--      additional payments NEVER reduce Contract Pending balance.
--   4. Updates payment_transactions view and INSTEAD OF triggers.
-- ==============================================================================

DO $$
BEGIN
    -- 1. Add additional_category to customer_payment_transactions
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
          AND table_name = 'customer_payment_transactions' 
          AND column_name = 'additional_category'
    ) THEN
        ALTER TABLE public.customer_payment_transactions 
            ADD COLUMN additional_category TEXT 
            CHECK (additional_category IN (
                'EXTRA_MATERIAL',
                'EXTRA_WORK',
                'ADDITIONAL_INSTALLATION',
                'TRANSPORT',
                'SERVICE_CHARGE',
                'OTHER'
            ));
    END IF;

    -- 2. Ensure payment_type accepts CONTRACT and ADDITIONAL
    ALTER TABLE public.customer_payment_transactions 
        DROP CONSTRAINT IF EXISTS customer_payment_transactions_payment_type_check;

    ALTER TABLE public.customer_payment_transactions 
        ADD CONSTRAINT customer_payment_transactions_payment_type_check 
        CHECK (payment_type IN ('CONTRACT', 'ADDITIONAL', 'Contract', 'Additional', 'Online', 'Offline'));

    -- 3. Add additional_paid_amount and total_received_amount to consumer_records
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
          AND table_name = 'consumer_records' 
          AND column_name = 'additional_paid_amount'
    ) THEN
        ALTER TABLE public.consumer_records 
            ADD COLUMN additional_paid_amount NUMERIC(12, 2) NOT NULL DEFAULT 0.00;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
          AND table_name = 'consumer_records' 
          AND column_name = 'total_received_amount'
    ) THEN
        ALTER TABLE public.consumer_records 
            ADD COLUMN total_received_amount NUMERIC(12, 2) NOT NULL DEFAULT 0.00;
    END IF;
END $$;

-- Indexes for fast category reporting and filtering
CREATE INDEX IF NOT EXISTS idx_customer_payments_add_cat ON public.customer_payment_transactions(additional_category);
CREATE INDEX IF NOT EXISTS idx_customer_payments_type_clean ON public.customer_payment_transactions(payment_type);

-- 4. Update recalculate_customer_payment_summary trigger function
CREATE OR REPLACE FUNCTION public.recalculate_customer_payment_summary()
RETURNS TRIGGER AS $$
DECLARE
    target_customer_id UUID;
    v_total NUMERIC(12, 2) := 0;
    v_contract_paid NUMERIC(12, 2) := 0;
    v_additional_paid NUMERIC(12, 2) := 0;
    v_contract_pending NUMERIC(12, 2) := 0;
    v_total_received NUMERIC(12, 2) := 0;
    v_status TEXT := 'Pending';
    v_due_date DATE;
BEGIN
    IF TG_OP = 'DELETE' THEN
        target_customer_id := OLD.customer_id;
    ELSE
        target_customer_id := NEW.customer_id;
    END IF;

    -- Fetch current contract total_amount and due_date from consumer_records
    SELECT COALESCE(total_amount, 0), payment_due_date
    INTO v_total, v_due_date
    FROM public.consumer_records
    WHERE id = target_customer_id;

    -- Sum Contract Payments
    SELECT COALESCE(SUM(amount), 0)
    INTO v_contract_paid
    FROM public.customer_payment_transactions
    WHERE customer_id = target_customer_id 
      AND status = 'Valid'
      AND COALESCE(deleted, false) = false
      AND COALESCE(verification_status, 'Pending') NOT IN ('Rejected', 'Void')
      AND UPPER(COALESCE(payment_type, 'CONTRACT')) NOT IN ('ADDITIONAL');

    -- Sum Additional Payments
    SELECT COALESCE(SUM(amount), 0)
    INTO v_additional_paid
    FROM public.customer_payment_transactions
    WHERE customer_id = target_customer_id 
      AND status = 'Valid'
      AND COALESCE(deleted, false) = false
      AND COALESCE(verification_status, 'Pending') NOT IN ('Rejected', 'Void')
      AND UPPER(COALESCE(payment_type, 'CONTRACT')) = 'ADDITIONAL';

    -- CRITICAL ACCOUNTING FORMULA:
    -- Additional Payments do NOT reduce Contract Pending balance!
    v_contract_pending := GREATEST(0, v_total - v_contract_paid);
    v_total_received := v_contract_paid + v_additional_paid;

    -- Status logic for Contract
    IF v_total > 0 AND v_contract_paid >= v_total THEN
        v_status := 'Paid';
    ELSIF v_due_date IS NOT NULL AND v_due_date < CURRENT_DATE AND v_contract_pending > 0 THEN
        v_status := 'Overdue';
    ELSIF v_contract_paid > 0 AND v_contract_pending > 0 THEN
        v_status := 'Partially Paid';
    ELSE
        v_status := 'Pending';
    END IF;

    -- Update consumer_records
    UPDATE public.consumer_records
    SET paid_amount = v_contract_paid,
        pending_amount = v_contract_pending,
        additional_paid_amount = v_additional_paid,
        total_received_amount = v_total_received,
        payment_status = v_status,
        updated_at = timezone('utc'::text, now())
    WHERE id = target_customer_id;

    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- 5. Update payment_transactions view
CREATE OR REPLACE VIEW public.payment_transactions AS
SELECT
    id,
    customer_id,
    consumer_no,
    amount,
    payment_type,
    additional_category,
    payment_date,
    payment_mode,
    reference_number,
    remarks,
    received_by,
    status,
    sync_status,
    verification_status,
    deleted,
    created_by,
    created_at,
    updated_at
FROM public.customer_payment_transactions;

-- Update INSTEAD OF INSERT trigger
CREATE OR REPLACE FUNCTION public.trg_fn_insert_payment_transactions()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.customer_payment_transactions (
        id,
        customer_id,
        consumer_no,
        amount,
        payment_type,
        additional_category,
        payment_date,
        payment_mode,
        reference_number,
        remarks,
        received_by,
        status,
        sync_status,
        verification_status,
        deleted,
        created_by,
        created_at,
        updated_at
    ) VALUES (
        COALESCE(NEW.id, gen_random_uuid()),
        NEW.customer_id,
        NEW.consumer_no,
        NEW.amount,
        COALESCE(NEW.payment_type, 'CONTRACT'),
        NEW.additional_category,
        COALESCE(NEW.payment_date, CURRENT_DATE),
        COALESCE(NEW.payment_mode, 'Cash'),
        NEW.reference_number,
        NEW.remarks,
        NEW.received_by,
        COALESCE(NEW.status, 'Valid'),
        COALESCE(NEW.sync_status, 'Synced'),
        COALESCE(NEW.verification_status, 'Verified'),
        COALESCE(NEW.deleted, false),
        COALESCE(NEW.created_by, auth.uid()),
        COALESCE(NEW.created_at, timezone('utc'::text, now())),
        timezone('utc'::text, now())
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Update INSTEAD OF UPDATE trigger
CREATE OR REPLACE FUNCTION public.trg_fn_update_payment_transactions()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE public.customer_payment_transactions
    SET
        amount = COALESCE(NEW.amount, amount),
        payment_type = COALESCE(NEW.payment_type, payment_type),
        additional_category = NEW.additional_category,
        payment_date = COALESCE(NEW.payment_date, payment_date),
        payment_mode = COALESCE(NEW.payment_mode, payment_mode),
        reference_number = NEW.reference_number,
        remarks = NEW.remarks,
        received_by = NEW.received_by,
        status = COALESCE(NEW.status, status),
        sync_status = COALESCE(NEW.sync_status, sync_status),
        verification_status = COALESCE(NEW.verification_status, verification_status),
        deleted = COALESCE(NEW.deleted, deleted),
        updated_at = timezone('utc'::text, now())
    WHERE id = OLD.id;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
