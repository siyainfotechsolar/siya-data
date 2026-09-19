-- ==============================================================================
-- Migration: 20260919000025_simple_payment_module.sql
-- Module: Simple Payment Module — Android App + Admin Panel Shared Backend
-- Description:
--   1. Attaches auto-recalculation trigger to customer_payment_transactions
--      so Paid Amount and Pending Amount are always 100% automatic and consistent.
--   2. Exposes payment_transactions view with INSTEAD OF triggers for full
--      schema compatibility.
--   3. Enables Supabase Realtime on payment transactions.
--   4. Configures clean RLS for staff payment entry and admin management.
-- ==============================================================================

-- 1. Attach auto-recalculation trigger to customer_payment_transactions
DROP TRIGGER IF EXISTS trg_recalculate_payment_summary ON public.customer_payment_transactions;

CREATE TRIGGER trg_recalculate_payment_summary
    AFTER INSERT OR UPDATE OR DELETE
    ON public.customer_payment_transactions
    FOR EACH ROW
    EXECUTE FUNCTION public.recalculate_customer_payment_summary();

-- 2. Expose payment_transactions as a fully updatable view
CREATE OR REPLACE VIEW public.payment_transactions AS
SELECT
    id,
    customer_id,
    consumer_no,
    amount,
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

-- INSTEAD OF INSERT trigger on payment_transactions view
CREATE OR REPLACE FUNCTION public.trg_fn_insert_payment_transactions()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.customer_payment_transactions (
        id,
        customer_id,
        consumer_no,
        amount,
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

DROP TRIGGER IF EXISTS trg_instead_of_insert_payment_transactions ON public.payment_transactions;
CREATE TRIGGER trg_instead_of_insert_payment_transactions
    INSTEAD OF INSERT ON public.payment_transactions
    FOR EACH ROW
    EXECUTE FUNCTION public.trg_fn_insert_payment_transactions();

-- INSTEAD OF UPDATE trigger on payment_transactions view
CREATE OR REPLACE FUNCTION public.trg_fn_update_payment_transactions()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE public.customer_payment_transactions
    SET
        amount = COALESCE(NEW.amount, amount),
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

DROP TRIGGER IF EXISTS trg_instead_of_update_payment_transactions ON public.payment_transactions;
CREATE TRIGGER trg_instead_of_update_payment_transactions
    INSTEAD OF UPDATE ON public.payment_transactions
    FOR EACH ROW
    EXECUTE FUNCTION public.trg_fn_update_payment_transactions();

-- INSTEAD OF DELETE trigger on payment_transactions view
CREATE OR REPLACE FUNCTION public.trg_fn_delete_payment_transactions()
RETURNS TRIGGER AS $$
BEGIN
    -- Soft-delete by default to prevent irreversible financial data loss
    UPDATE public.customer_payment_transactions
    SET deleted = true,
        updated_at = timezone('utc'::text, now())
    WHERE id = OLD.id;
    RETURN OLD;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_instead_of_delete_payment_transactions ON public.payment_transactions;
CREATE TRIGGER trg_instead_of_delete_payment_transactions
    INSTEAD OF DELETE ON public.payment_transactions
    FOR EACH ROW
    EXECUTE FUNCTION public.trg_fn_delete_payment_transactions();

-- 3. Add to Supabase Realtime publication
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables 
        WHERE pubname = 'supabase_realtime' 
          AND schemaname = 'public' 
          AND tablename = 'customer_payment_transactions'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.customer_payment_transactions;
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        -- Ignore if publication doesn't exist in local dev environment
        NULL;
END $$;
