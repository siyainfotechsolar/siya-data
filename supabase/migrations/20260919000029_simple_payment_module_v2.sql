-- ==============================================================================
-- Migration: 20260919000029_simple_payment_module_v2.sql
-- Module: Simple Payment Module (Android App + Admin Panel)
-- Description:
--   1. Ensures consumer_records has contract_amount column kept in sync with total_amount.
--   2. Ensures customer_payment_transactions adheres to the simple schema:
--      (id, customer_id, amount, payment_date, payment_mode, remarks, payment_type, created_by, created_at)
--   3. Automatic recalculation of:
--      - Total Payment = contract_amount (total_amount)
--      - Paid = Sum of all CONTRACT payments
--      - Pending = GREATEST(0, Total Payment - Paid)
--      - Additional = Sum of all ADDITIONAL payments
--      - RULE: Additional payments do NOT reduce the contract Pending balance!
-- ==============================================================================

-- 1. Ensure contract_amount column exists on consumer_records and sync with total_amount
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'public'
          AND table_name = 'consumer_records'
          AND column_name = 'contract_amount'
    ) THEN
        ALTER TABLE public.consumer_records
            ADD COLUMN contract_amount NUMERIC(12, 2) NOT NULL DEFAULT 0.00;
            
        -- Initialize contract_amount from existing total_amount
        UPDATE public.consumer_records
        SET contract_amount = COALESCE(total_amount, 0.00);
    END IF;
END $$;

-- 2. Trigger function to keep contract_amount and total_amount bidirectionally in sync
CREATE OR REPLACE FUNCTION public.trg_sync_consumer_contract_amount()
RETURNS TRIGGER AS $$
BEGIN
    -- If contract_amount was updated, sync total_amount
    IF NEW.contract_amount IS DISTINCT FROM OLD.contract_amount THEN
        NEW.total_amount := NEW.contract_amount;
    -- If total_amount was updated, sync contract_amount
    ELSIF NEW.total_amount IS DISTINCT FROM OLD.total_amount THEN
        NEW.contract_amount := NEW.total_amount;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_consumer_contract_amount_sync ON public.consumer_records;
CREATE TRIGGER trg_consumer_contract_amount_sync
    BEFORE INSERT OR UPDATE OF contract_amount, total_amount
    ON public.consumer_records
    FOR EACH ROW
    EXECUTE FUNCTION public.trg_sync_consumer_contract_amount();

-- 3. Update recalculate_customer_payment_summary() to guarantee clean, deterministic math:
--    Total Payment = contract_amount
--    Paid = Sum of CONTRACT payments
--    Pending = Total Payment - Paid
--    Additional = Sum of ADDITIONAL payments (never reduces Pending)
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

    IF target_customer_id IS NULL THEN
        RETURN NULL;
    END IF;

    -- Fetch current contract total_amount / contract_amount and due date
    SELECT COALESCE(contract_amount, total_amount, 0), payment_due_date
    INTO v_total, v_due_date
    FROM public.consumer_records
    WHERE id = target_customer_id;

    -- Sum CONTRACT Payments (only Valid, not deleted, not voided)
    SELECT COALESCE(SUM(amount), 0)
    INTO v_contract_paid
    FROM public.customer_payment_transactions
    WHERE customer_id = target_customer_id
      AND status = 'Valid'
      AND COALESCE(deleted, false) = false
      AND COALESCE(verification_status, 'Verified') NOT IN ('Rejected', 'Void')
      AND UPPER(COALESCE(payment_type, 'CONTRACT')) NOT IN ('ADDITIONAL');

    -- Sum ADDITIONAL Payments (only Valid, not deleted, not voided)
    SELECT COALESCE(SUM(amount), 0)
    INTO v_additional_paid
    FROM public.customer_payment_transactions
    WHERE customer_id = target_customer_id
      AND status = 'Valid'
      AND COALESCE(deleted, false) = false
      AND COALESCE(verification_status, 'Verified') NOT IN ('Rejected', 'Void')
      AND UPPER(COALESCE(payment_type, 'CONTRACT')) = 'ADDITIONAL';

    -- CRITICAL ACCOUNTING FORMULA:
    -- Pending = Total Payment - Paid
    -- Additional Payment does NOT reduce contract Pending!
    v_contract_pending := GREATEST(0, v_total - v_contract_paid);
    v_total_received := v_contract_paid + v_additional_paid;

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
        additional_paid_amount = v_additional_paid,
        total_received_amount = v_total_received,
        payment_status = v_status,
        updated_at = timezone('utc'::text, now())
    WHERE id = target_customer_id;

    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Reattach trigger
DROP TRIGGER IF EXISTS trg_recalculate_payment_summary ON public.customer_payment_transactions;
CREATE TRIGGER trg_recalculate_payment_summary
    AFTER INSERT OR UPDATE OR DELETE
    ON public.customer_payment_transactions
    FOR EACH ROW
    EXECUTE FUNCTION public.recalculate_customer_payment_summary();
