-- ==============================================================================
-- Migration: 20261018000034_commission_agent_module.sql
-- Module: Commission Agent Module & Bulk Manual Commission Entry
-- Description:
--   1. Creates public.agents table (Agent Master) for managing commission agents.
--   2. Creates public.commissions table for tracking manual commission entries,
--      approvals, workflow states, and duplicate detection.
--   3. Creates public.commission_payments table for tracking actual commission
--      payouts (preventing confusion with margin receipts or loan documents).
--   4. Creates triggers/functions for auto-calculating commission payment balances
--      (Pending Amount = Approved Amount - Total Payments).
--   5. Sets up Row Level Security (RLS) policies and performance indexes.
--   6. Seeds initial default agents into Agent Master.
-- ==============================================================================

-- 1. Create Agents Table (Agent Master)
CREATE TABLE IF NOT EXISTS public.agents (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    mobile TEXT,
    email TEXT,
    agency_name TEXT,
    address TEXT,
    pan_number TEXT,
    bank_name TEXT,
    account_number TEXT,
    ifsc_code TEXT,
    upi_id TEXT,
    is_active BOOLEAN NOT NULL DEFAULT true,
    deleted BOOLEAN NOT NULL DEFAULT false,
    deleted_at TIMESTAMPTZ,
    deleted_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    created_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    updated_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- 2. Create Commissions Table
CREATE TABLE IF NOT EXISTS public.commissions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    entry_number TEXT NOT NULL UNIQUE,
    agent_id UUID REFERENCES public.agents(id) ON DELETE SET NULL,
    agent_name TEXT NOT NULL,
    customer_id UUID REFERENCES public.consumer_records(id) ON DELETE SET NULL,
    customer_name TEXT NOT NULL,
    consumer_no TEXT,
    solar_capacity NUMERIC(10, 2), -- Optional reference only (Never used for auto formula)
    commission_date DATE NOT NULL,
    commission_amount NUMERIC(12, 2) NOT NULL CHECK (commission_amount > 0),
    approved_amount NUMERIC(12, 2),
    paid_amount NUMERIC(12, 2) NOT NULL DEFAULT 0.00 CHECK (paid_amount >= 0),
    status TEXT NOT NULL DEFAULT 'Pending Approval', -- 'Pending Approval', 'Approved', 'Rejected', 'Partially Paid', 'Paid'
    approved_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    approved_at TIMESTAMPTZ,
    approval_notes TEXT,
    remarks TEXT,
    deleted BOOLEAN NOT NULL DEFAULT false,
    deleted_at TIMESTAMPTZ,
    deleted_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    created_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    updated_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- 3. Create Commission Payments Table (Strict payment tracking)
CREATE TABLE IF NOT EXISTS public.commission_payments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    commission_id UUID NOT NULL REFERENCES public.commissions(id) ON DELETE CASCADE,
    payment_date DATE NOT NULL,
    amount NUMERIC(12, 2) NOT NULL CHECK (amount > 0),
    payment_mode TEXT NOT NULL DEFAULT 'Bank Transfer', -- 'Bank Transfer', 'UPI', 'Cash', 'Cheque'
    reference_number TEXT,
    bank_name TEXT,
    notes TEXT,
    created_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- 4. Unique Sequence & Helper for Commission Entry Numbers (SIYA-COM-YYYY-XXXX)
CREATE SEQUENCE IF NOT EXISTS public.seq_commission_entry_no START 1001;

CREATE OR REPLACE FUNCTION public.generate_commission_entry_number()
RETURNS TEXT
LANGUAGE plpgsql
AS $$
DECLARE
    v_year TEXT;
    v_seq BIGINT;
    v_number TEXT;
BEGIN
    v_year := to_char(CURRENT_DATE, 'YYYY');
    v_seq := nextval('public.seq_commission_entry_no');
    v_number := 'SIYA-COM-' || v_year || '-' || lpad(v_seq::text, 4, '0');
    RETURN v_number;
END;
$$;

-- 5. Trigger to update commission paid_amount and status on commission_payments changes
CREATE OR REPLACE FUNCTION public.sync_commission_payment_totals()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_comm_id UUID;
    v_total_paid NUMERIC(12, 2);
    v_approved_amt NUMERIC(12, 2);
    v_comm_amt NUMERIC(12, 2);
    v_target_amt NUMERIC(12, 2);
    v_curr_status TEXT;
    v_new_status TEXT;
BEGIN
    IF (TG_OP = 'DELETE') THEN
        v_comm_id := OLD.commission_id;
    ELSE
        v_comm_id := NEW.commission_id;
    END IF;

    -- Calculate total actual payments
    SELECT COALESCE(SUM(amount), 0)
    INTO v_total_paid
    FROM public.commission_payments
    WHERE commission_id = v_comm_id;

    -- Fetch current commission details
    SELECT approved_amount, commission_amount, status
    INTO v_approved_amt, v_comm_amt, v_curr_status
    FROM public.commissions
    WHERE id = v_comm_id;

    v_target_amt := COALESCE(v_approved_amt, v_comm_amt);

    -- Determine new status based on payout
    IF v_curr_status = 'Rejected' THEN
        v_new_status := 'Rejected';
    ELSIF v_total_paid >= v_target_amt AND v_target_amt > 0 THEN
        v_new_status := 'Paid';
    ELSIF v_total_paid > 0 THEN
        v_new_status := 'Partially Paid';
    ELSE
        -- If no payments made yet
        IF v_approved_amt IS NOT NULL THEN
            v_new_status := 'Approved';
        ELSE
            v_new_status := 'Pending Approval';
        END IF;
    END IF;

    UPDATE public.commissions
    SET paid_amount = v_total_paid,
        status = v_new_status,
        updated_at = timezone('utc'::text, now())
    WHERE id = v_comm_id;

    RETURN NULL;
END;
$$;

DROP TRIGGER IF EXISTS trg_sync_commission_payments ON public.commission_payments;
CREATE TRIGGER trg_sync_commission_payments
    AFTER INSERT OR UPDATE OR DELETE ON public.commission_payments
    FOR EACH ROW
    EXECUTE FUNCTION public.sync_commission_payment_totals();

-- 6. Indexes for High Performance Queries
CREATE INDEX IF NOT EXISTS idx_agents_name ON public.agents(name);
CREATE INDEX IF NOT EXISTS idx_agents_mobile ON public.agents(mobile);
CREATE INDEX IF NOT EXISTS idx_agents_is_active ON public.agents(is_active) WHERE deleted = false;

CREATE INDEX IF NOT EXISTS idx_commissions_entry_no ON public.commissions(entry_number);
CREATE INDEX IF NOT EXISTS idx_commissions_agent_id ON public.commissions(agent_id);
CREATE INDEX IF NOT EXISTS idx_commissions_agent_name ON public.commissions(agent_name);
CREATE INDEX IF NOT EXISTS idx_commissions_customer_id ON public.commissions(customer_id);
CREATE INDEX IF NOT EXISTS idx_commissions_consumer_no ON public.commissions(consumer_no);
CREATE INDEX IF NOT EXISTS idx_commissions_customer_name ON public.commissions(customer_name);
CREATE INDEX IF NOT EXISTS idx_commissions_date ON public.commissions(commission_date DESC);
CREATE INDEX IF NOT EXISTS idx_commissions_status ON public.commissions(status);
CREATE INDEX IF NOT EXISTS idx_commissions_deleted ON public.commissions(deleted);

-- Compound index for duplicate check
CREATE INDEX IF NOT EXISTS idx_commissions_dup_check ON public.commissions(agent_name, customer_name, commission_date) WHERE deleted = false;

CREATE INDEX IF NOT EXISTS idx_comm_payments_comm_id ON public.commission_payments(commission_id);
CREATE INDEX IF NOT EXISTS idx_comm_payments_date ON public.commission_payments(payment_date DESC);

-- 7. Enable Row Level Security (RLS)
ALTER TABLE public.agents ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.commissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.commission_payments ENABLE ROW LEVEL SECURITY;

-- Agents Policies
CREATE POLICY "Allow active users to view agents"
    ON public.agents FOR SELECT
    TO authenticated
    USING (deleted = false);

CREATE POLICY "Allow authenticated users to create agents"
    ON public.agents FOR INSERT
    TO authenticated
    WITH CHECK (true);

CREATE POLICY "Allow authenticated users to update agents"
    ON public.agents FOR UPDATE
    TO authenticated
    USING (true);

CREATE POLICY "Allow admins to delete agents"
    ON public.agents FOR DELETE
    TO authenticated
    USING (public.is_admin());

-- Commissions Policies
CREATE POLICY "Allow active users to view commissions"
    ON public.commissions FOR SELECT
    TO authenticated
    USING (deleted = false);

CREATE POLICY "Allow authenticated users to create commissions"
    ON public.commissions FOR INSERT
    TO authenticated
    WITH CHECK (true);

CREATE POLICY "Allow authenticated users to update commissions"
    ON public.commissions FOR UPDATE
    TO authenticated
    USING (true);

CREATE POLICY "Allow admins to delete commissions"
    ON public.commissions FOR DELETE
    TO authenticated
    USING (public.is_admin());

-- Commission Payments Policies
CREATE POLICY "Allow active users to view commission payments"
    ON public.commission_payments FOR SELECT
    TO authenticated
    USING (true);

CREATE POLICY "Allow authenticated users to record commission payments"
    ON public.commission_payments FOR INSERT
    TO authenticated
    WITH CHECK (true);

CREATE POLICY "Allow authenticated users to update commission payments"
    ON public.commission_payments FOR UPDATE
    TO authenticated
    USING (true);

CREATE POLICY "Allow admins to delete commission payments"
    ON public.commission_payments FOR DELETE
    TO authenticated
    USING (public.is_admin());

-- 8. Seed Initial Sample Agents in Agent Master
INSERT INTO public.agents (name, mobile, agency_name, address, pan_number, bank_name, account_number, ifsc_code)
VALUES
    ('Sunil Patil', '9822011223', 'Patil Solar Agency', 'Dhule, Maharashtra', 'ABCDE1234F', 'State Bank of India', '31234567890', 'SBIN0004798'),
    ('Ramesh Shinde', '9423188990', 'Shinde Energy Solutions', 'Betawad, Shindkheda', 'BCDEF2345G', 'Bank of Maharashtra', '60123456789', 'MAHB0000123'),
    ('Ganesh Pawar', '9890123456', 'Pawar Solar Tech', 'Nardana, Sindkheda', 'CDEFG3456H', 'HDFC Bank', '50100234567890', 'HDFC0001234'),
    ('Vikas More', '9765432109', 'More Green Energies', 'Dondaicha, Dhule', 'DEFGH4567I', 'ICICI Bank', '012305001234', 'ICIC0000123')
ON CONFLICT DO NOTHING;
