-- ==============================================================================
-- Migration: 20260920000027_clean_payment_module.sql
-- Module: Clean Payment Module (1st Payment, 2nd Payment & Additional Payment)
-- Description:
--   1. Adds first_payment_amount, second_payment_amount, first_payment_received,
--      second_payment_received to consumer_records.
--   2. Updates check constraint on customer_payment_transactions.payment_type.
--   3. Updates recalculate_customer_payment_summary() trigger function to
--      calculate 1st/2nd received and pending accurately.
-- ==============================================================================

DO $$
BEGIN
    -- 1. Add first_payment_amount to consumer_records
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
          AND table_name = 'consumer_records' 
          AND column_name = 'first_payment_amount'
    ) THEN
        ALTER TABLE public.consumer_records 
            ADD COLUMN first_payment_amount NUMERIC(12, 2) NOT NULL DEFAULT 0.00;
    END IF;

    -- 2. Add second_payment_amount to consumer_records
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
          AND table_name = 'consumer_records' 
          AND column_name = 'second_payment_amount'
    ) THEN
        ALTER TABLE public.consumer_records 
            ADD COLUMN second_payment_amount NUMERIC(12, 2) NOT NULL DEFAULT 0.00;
    END IF;

    -- 3. Add first_payment_received to consumer_records
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
          AND table_name = 'consumer_records' 
          AND column_name = 'first_payment_received'
    ) THEN
        ALTER TABLE public.consumer_records 
            ADD COLUMN first_payment_received NUMERIC(12, 2) NOT NULL DEFAULT 0.00;
    END IF;

    -- 4. Add second_payment_received to consumer_records
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
          AND table_name = 'consumer_records' 
          AND column_name = 'second_payment_received'
    ) THEN
        ALTER TABLE public.consumer_records 
            ADD COLUMN second_payment_received NUMERIC(12, 2) NOT NULL DEFAULT 0.00;
    END IF;

    -- 5. Update payment_type check constraint on customer_payment_transactions
    ALTER TABLE public.customer_payment_transactions 
        DROP CONSTRAINT IF EXISTS customer_payment_transactions_payment_type_check;

    ALTER TABLE public.customer_payment_transactions 
        ADD CONSTRAINT customer_payment_transactions_payment_type_check 
        CHECK (payment_type IN (
            '1st Payment', '2nd Payment', 'Additional Payment', 'Payment',
            '1st Installment', '2nd Installment',
            'CONTRACT', 'ADDITIONAL', 'Contract', 'Additional', 'Online', 'Offline'
        ));
END $$;

-- 6. Trigger to recalculate payment summary automatically
CREATE OR REPLACE FUNCTION public.recalculate_customer_payment_summary()
RETURNS TRIGGER AS $$
DECLARE
    target_customer_id UUID;
    v_total NUMERIC(12, 2) := 0;
    v_first_received NUMERIC(12, 2) := 0;
    v_second_received NUMERIC(12, 2) := 0;
    v_additional_received NUMERIC(12, 2) := 0;
    v_general_received NUMERIC(12, 2) := 0;
    v_contract_paid NUMERIC(12, 2) := 0;
    v_contract_pending NUMERIC(12, 2) := 0;
    v_total_received NUMERIC(12, 2) := 0;
    v_is_loan BOOLEAN := false;
    v_status TEXT := 'Pending';
    v_due_date DATE;
BEGIN
    IF TG_OP = 'DELETE' THEN
        target_customer_id := OLD.customer_id;
    ELSE
        target_customer_id := NEW.customer_id;
    END IF;

    -- Fetch customer info
    SELECT 
        COALESCE(total_amount, 0),
        payment_due_date,
        (LOWER(COALESCE(loan_required, 'no')) = 'yes')
    INTO v_total, v_due_date, v_is_loan
    FROM public.consumer_records
    WHERE id = target_customer_id;

    -- 1st Payment sum
    SELECT COALESCE(SUM(amount), 0)
    INTO v_first_received
    FROM public.customer_payment_transactions
    WHERE customer_id = target_customer_id 
      AND status = 'Valid'
      AND COALESCE(deleted, false) = false
      AND COALESCE(verification_status, 'Pending') NOT IN ('Rejected', 'Void')
      AND LOWER(payment_type) IN ('1st payment', '1st_payment', '1st installment', 'contract');

    -- 2nd Payment sum
    SELECT COALESCE(SUM(amount), 0)
    INTO v_second_received
    FROM public.customer_payment_transactions
    WHERE customer_id = target_customer_id 
      AND status = 'Valid'
      AND COALESCE(deleted, false) = false
      AND COALESCE(verification_status, 'Pending') NOT IN ('Rejected', 'Void')
      AND LOWER(payment_type) IN ('2nd payment', '2nd_payment', '2nd installment');

    -- Additional Payment sum
    SELECT COALESCE(SUM(amount), 0)
    INTO v_additional_received
    FROM public.customer_payment_transactions
    WHERE customer_id = target_customer_id 
      AND status = 'Valid'
      AND COALESCE(deleted, false) = false
      AND COALESCE(verification_status, 'Pending') NOT IN ('Rejected', 'Void')
      AND LOWER(payment_type) IN ('additional', 'additional payment', 'additional_payment');

    -- General / Other non-additional Payment sum
    SELECT COALESCE(SUM(amount), 0)
    INTO v_general_received
    FROM public.customer_payment_transactions
    WHERE customer_id = target_customer_id 
      AND status = 'Valid'
      AND COALESCE(deleted, false) = false
      AND COALESCE(verification_status, 'Pending') NOT IN ('Rejected', 'Void')
      AND LOWER(payment_type) NOT IN (
          '1st payment', '1st_payment', '1st installment', 'contract',
          '2nd payment', '2nd_payment', '2nd installment',
          'additional', 'additional payment', 'additional_payment'
      );

    -- Accounting logic:
    IF v_is_loan THEN
        -- Loan Customer:
        -- 1st Received = v_first_received
        -- 2nd Received = v_second_received
        -- Total Pending = Total Payment - 1st Received - 2nd Received
        -- Total Received = 1st Received + 2nd Received + Additional Received
        v_contract_paid := v_first_received + v_second_received + v_general_received;
        v_contract_pending := GREATEST(0, v_total - v_first_received - v_second_received - v_general_received);
        v_total_received := v_contract_paid + v_additional_received;
    ELSE
        -- Normal Customer:
        -- Paid = Sum of payments
        -- Pending = Total Payment - Paid
        v_contract_paid := v_first_received + v_second_received + v_general_received;
        v_contract_pending := GREATEST(0, v_total - v_contract_paid);
        v_total_received := v_contract_paid + v_additional_received;
    END IF;

    -- Status determination
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
        first_payment_received = v_first_received,
        second_payment_received = v_second_received,
        additional_paid_amount = v_additional_received,
        total_received_amount = v_total_received,
        payment_status = v_status,
        updated_at = timezone('utc'::text, now())
    WHERE id = target_customer_id;

    RETURN NULL;
END;
$$ LANGUAGE plpgsql;
