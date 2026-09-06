-- ==============================================================================
-- Migration: 20260907000018_customer_issues_and_payments.sql
-- Modules 6 (General Issue) & 7 (Payment Tracking & Transactions)
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- 1. EXTEND consumer_records WITH PAYMENT SUMMARY COLUMNS
-- ------------------------------------------------------------------------------
ALTER TABLE public.consumer_records
    ADD COLUMN IF NOT EXISTS total_amount NUMERIC(12, 2) DEFAULT 0,
    ADD COLUMN IF NOT EXISTS paid_amount NUMERIC(12, 2) DEFAULT 0,
    ADD COLUMN IF NOT EXISTS pending_amount NUMERIC(12, 2) DEFAULT 0,
    ADD COLUMN IF NOT EXISTS payment_status TEXT DEFAULT 'Pending',
    ADD COLUMN IF NOT EXISTS payment_due_date DATE;

-- ------------------------------------------------------------------------------
-- 2. EXTEND customer_followups WITH RELATED ENTITY COLUMNS
-- ------------------------------------------------------------------------------
ALTER TABLE public.customer_followups
    ADD COLUMN IF NOT EXISTS related_type TEXT DEFAULT 'Customer', -- 'Customer', 'Issue', 'Payment', 'MISC'
    ADD COLUMN IF NOT EXISTS related_id UUID;

CREATE INDEX IF NOT EXISTS idx_customer_followups_related
    ON public.customer_followups(related_type, related_id);

-- ------------------------------------------------------------------------------
-- 3. GENERAL ISSUE SYSTEM (public.customer_issues)
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.customer_issues (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    customer_id UUID NOT NULL REFERENCES public.consumer_records(id) ON DELETE CASCADE,
    customer_name TEXT NOT NULL,
    consumer_no TEXT NOT NULL,
    mobile_number TEXT,
    issue_type TEXT NOT NULL,
    title TEXT NOT NULL,
    description TEXT,
    priority TEXT NOT NULL DEFAULT 'Normal' CHECK (priority IN ('Normal', 'High', 'Urgent')),
    status TEXT NOT NULL DEFAULT 'New' CHECK (status IN ('New', 'Assigned', 'In Progress', 'Hold', 'Resolved', 'Closed', 'Cancelled')),
    assigned_staff TEXT,
    assigned_date TIMESTAMPTZ,
    due_date DATE,
    hold_reason TEXT,
    resolution_remarks TEXT,
    remarks TEXT,
    created_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    created_by_name TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    updated_by_name TEXT,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    resolved_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    resolved_by_name TEXT,
    resolved_at TIMESTAMPTZ,
    closed_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    closed_by_name TEXT,
    closed_at TIMESTAMPTZ
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_customer_issues_customer_id ON public.customer_issues(customer_id);
CREATE INDEX IF NOT EXISTS idx_customer_issues_status ON public.customer_issues(status);
CREATE INDEX IF NOT EXISTS idx_customer_issues_due_date ON public.customer_issues(due_date);
CREATE INDEX IF NOT EXISTS idx_customer_issues_staff ON public.customer_issues(assigned_staff);
CREATE INDEX IF NOT EXISTS idx_customer_issues_type ON public.customer_issues(issue_type);
CREATE INDEX IF NOT EXISTS idx_customer_issues_priority ON public.customer_issues(priority);

-- ------------------------------------------------------------------------------
-- 4. GENERAL ISSUE HISTORY (public.customer_issue_history)
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.customer_issue_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    issue_id UUID NOT NULL REFERENCES public.customer_issues(id) ON DELETE CASCADE,
    action_type TEXT NOT NULL, -- 'CREATED', 'ASSIGNED', 'REASSIGNED', 'STATUS_CHANGED', 'PRIORITY_CHANGED', 'REMARK_ADDED', 'HOLD', 'RESOLVED', 'CLOSED', 'REOPENED'
    old_value TEXT,
    new_value TEXT,
    remarks TEXT,
    changed_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    changed_by_name TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE INDEX IF NOT EXISTS idx_customer_issue_history_issue_id ON public.customer_issue_history(issue_id);

-- ------------------------------------------------------------------------------
-- 5. PAYMENT TRANSACTIONS (public.customer_payment_transactions)
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.customer_payment_transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    customer_id UUID NOT NULL REFERENCES public.consumer_records(id) ON DELETE CASCADE,
    consumer_no TEXT NOT NULL,
    amount NUMERIC(12, 2) NOT NULL CHECK (amount > 0),
    payment_date DATE NOT NULL,
    payment_mode TEXT NOT NULL CHECK (payment_mode IN ('Cash', 'UPI', 'Bank Transfer', 'Cheque', 'Other')),
    reference_number TEXT,
    received_by TEXT,
    remarks TEXT,
    attachment_url TEXT,
    status TEXT NOT NULL DEFAULT 'Valid' CHECK (status IN ('Valid', 'Reversed', 'Refunded')),
    reversal_reason TEXT,
    created_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    created_by_name TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    updated_by_name TEXT,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE INDEX IF NOT EXISTS idx_customer_payments_customer_id ON public.customer_payment_transactions(customer_id);
CREATE INDEX IF NOT EXISTS idx_customer_payments_date ON public.customer_payment_transactions(payment_date);
CREATE INDEX IF NOT EXISTS idx_customer_payments_status ON public.customer_payment_transactions(status);
CREATE INDEX IF NOT EXISTS idx_customer_payments_mode ON public.customer_payment_transactions(payment_mode);

-- ------------------------------------------------------------------------------
-- 6. AUTOMATIC TRIGGER FOR LIVE PAYMENT BALANCE RECALCULATION
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.recalculate_customer_payment_summary()
RETURNS TRIGGER AS $$
DECLARE
    target_customer_id UUID;
    v_total NUMERIC(12, 2);
    v_paid NUMERIC(12, 2);
    v_pending NUMERIC(12, 2);
    v_due_date DATE;
    v_status TEXT;
BEGIN
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

    -- Sum all valid payment transactions
    SELECT COALESCE(SUM(amount), 0)
    INTO v_paid
    FROM public.customer_payment_transactions
    WHERE customer_id = target_customer_id AND status = 'Valid';

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

DROP TRIGGER IF EXISTS trg_recalculate_payment_summary ON public.customer_payment_transactions;
CREATE TRIGGER trg_recalculate_payment_summary
AFTER INSERT OR UPDATE OR DELETE ON public.customer_payment_transactions
FOR EACH ROW
EXECUTE FUNCTION public.recalculate_customer_payment_summary();

-- ------------------------------------------------------------------------------
-- 7. ENABLE ROW LEVEL SECURITY (RLS)
-- ------------------------------------------------------------------------------
ALTER TABLE public.customer_issues ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.customer_issue_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.customer_payment_transactions ENABLE ROW LEVEL SECURITY;

-- Issues policies
DROP POLICY IF EXISTS "Authenticated full access to customer_issues" ON public.customer_issues;
CREATE POLICY "Authenticated full access to customer_issues"
    ON public.customer_issues FOR ALL TO authenticated USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Anon read access to customer_issues" ON public.customer_issues;
CREATE POLICY "Anon read access to customer_issues"
    ON public.customer_issues FOR SELECT TO anon USING (true);

-- Issue History policies
DROP POLICY IF EXISTS "Authenticated full access to customer_issue_history" ON public.customer_issue_history;
CREATE POLICY "Authenticated full access to customer_issue_history"
    ON public.customer_issue_history FOR ALL TO authenticated USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Anon read access to customer_issue_history" ON public.customer_issue_history;
CREATE POLICY "Anon read access to customer_issue_history"
    ON public.customer_issue_history FOR SELECT TO anon USING (true);

-- Payments policies
DROP POLICY IF EXISTS "Authenticated full access to customer_payment_transactions" ON public.customer_payment_transactions;
CREATE POLICY "Authenticated full access to customer_payment_transactions"
    ON public.customer_payment_transactions FOR ALL TO authenticated USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Anon read access to customer_payment_transactions" ON public.customer_payment_transactions;
CREATE POLICY "Anon read access to customer_payment_transactions"
    ON public.customer_payment_transactions FOR SELECT TO anon USING (true);

-- ------------------------------------------------------------------------------
-- 8. REALTIME PUBLICATION
-- ------------------------------------------------------------------------------
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime') THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.customer_issues;
        ALTER PUBLICATION supabase_realtime ADD TABLE public.customer_issue_history;
        ALTER PUBLICATION supabase_realtime ADD TABLE public.customer_payment_transactions;
    END IF;
EXCEPTION
    WHEN duplicate_object THEN NULL;
END $$;

-- ------------------------------------------------------------------------------
-- 9. UPDATE get_action_center_counts() RPC TO INCLUDE ISSUES AND PAYMENTS
-- ------------------------------------------------------------------------------
DROP FUNCTION IF EXISTS get_action_center_counts();

CREATE OR REPLACE FUNCTION get_action_center_counts()
RETURNS TABLE (
  agreement_pending_count BIGINT,
  loan_pending_count BIGINT,
  installation_pending_count BIGINT,
  rts_pending_count BIGINT,
  subsidy_processing_count BIGINT,
  completed_count BIGINT,
  no_action_required_count BIGINT,
  todays_followup_count BIGINT,
  overdue_followup_count BIGINT,
  upcoming_followup_count BIGINT,
  misc_count BIGINT,
  issue_count BIGINT,
  payment_pending_count BIGINT
) LANGUAGE sql STABLE AS $$
  SELECT
    -- 1. Agreement Pending (Active only)
    COUNT(*) FILTER (
      WHERE deleted = false AND is_merged = false
        AND UPPER(COALESCE(customer_work_state, 'ACTIVE')) = 'ACTIVE'
        AND LOWER(COALESCE(subsidy_status, '')) NOT IN ('received', 'completed')
        AND (agreement_status IS NULL OR LOWER(agreement_status) IN ('pending', 'not started', 'in progress', 'draft', ''))
    ) AS agreement_pending_count,

    -- 2. Loan Pending (Active only)
    COUNT(*) FILTER (
      WHERE deleted = false AND is_merged = false
        AND UPPER(COALESCE(customer_work_state, 'ACTIVE')) = 'ACTIVE'
        AND LOWER(COALESCE(subsidy_status, '')) NOT IN ('received', 'completed')
        AND LOWER(COALESCE(agreement_status, '')) IN ('completed', 'uploaded', 'done', 'signed')
        AND (loan_required IS NULL OR LOWER(loan_required) IN ('yes', 'true', 'required', '1'))
        AND LOWER(COALESCE(loan_status, '')) NOT IN ('disbursed', 'approved', 'sanctioned', 'closed')
    ) AS loan_pending_count,

    -- 3. Installation Pending (Active only)
    COUNT(*) FILTER (
      WHERE deleted = false AND is_merged = false
        AND UPPER(COALESCE(customer_work_state, 'ACTIVE')) = 'ACTIVE'
        AND LOWER(COALESCE(subsidy_status, '')) NOT IN ('received', 'completed')
        AND LOWER(COALESCE(agreement_status, '')) IN ('completed', 'uploaded', 'done', 'signed')
        AND (
          LOWER(COALESCE(loan_required, '')) IN ('no', 'false', 'not required', '0')
          OR LOWER(COALESCE(loan_status, '')) IN ('disbursed', 'approved', 'sanctioned')
        )
        AND LOWER(COALESCE(installation_status, '')) NOT IN ('completed', 'installed', 'done')
    ) AS installation_pending_count,

    -- 4. RTS Pending (Active only)
    COUNT(*) FILTER (
      WHERE deleted = false AND is_merged = false
        AND UPPER(COALESCE(customer_work_state, 'ACTIVE')) = 'ACTIVE'
        AND LOWER(COALESCE(subsidy_status, '')) NOT IN ('received', 'completed')
        AND LOWER(COALESCE(installation_status, '')) IN ('completed', 'installed', 'done')
        AND LOWER(COALESCE(rts_status, '')) NOT IN ('completed', 'submitted', 'done', 'approved')
    ) AS rts_pending_count,

    -- 5. Subsidy Processing (Active only)
    COUNT(*) FILTER (
      WHERE deleted = false AND is_merged = false
        AND UPPER(COALESCE(customer_work_state, 'ACTIVE')) = 'ACTIVE'
        AND LOWER(COALESCE(rts_status, '')) IN ('completed', 'submitted', 'done', 'approved')
        AND LOWER(COALESCE(subsidy_status, '')) NOT IN ('received', 'completed')
    ) AS subsidy_processing_count,

    -- 6. Completed (Work State = COMPLETED or Subsidy Received)
    COUNT(*) FILTER (
      WHERE deleted = false AND is_merged = false
        AND (
          UPPER(COALESCE(customer_work_state, 'ACTIVE')) = 'COMPLETED'
          OR LOWER(COALESCE(subsidy_status, '')) IN ('received', 'completed')
        )
    ) AS completed_count,

    -- 7. On Hold / No Action Required
    COUNT(*) FILTER (
      WHERE deleted = false AND is_merged = false
        AND UPPER(COALESCE(customer_work_state, 'ACTIVE')) = 'HOLD'
    ) AS no_action_required_count,

    -- 8. Today's Follow-up (from single centralized customer_followups table)
    (
      SELECT COUNT(*)
      FROM public.customer_followups cf
      JOIN public.consumer_records cr ON cr.id = cf.record_id
      WHERE cr.deleted = false AND cr.is_merged = false
        AND cf.status = 'PENDING'
        AND cf.followup_date = CURRENT_DATE
    ) AS todays_followup_count,

    -- 9. Overdue Follow-up (from single centralized customer_followups table)
    (
      SELECT COUNT(*)
      FROM public.customer_followups cf
      JOIN public.consumer_records cr ON cr.id = cf.record_id
      WHERE cr.deleted = false AND cr.is_merged = false
        AND cf.status = 'PENDING'
        AND cf.followup_date < CURRENT_DATE
    ) AS overdue_followup_count,

    -- 10. Upcoming Follow-up (from single centralized customer_followups table)
    (
      SELECT COUNT(*)
      FROM public.customer_followups cf
      JOIN public.consumer_records cr ON cr.id = cf.record_id
      WHERE cr.deleted = false AND cr.is_merged = false
        AND cf.status = 'PENDING'
        AND cf.followup_date > CURRENT_DATE
    ) AS upcoming_followup_count,

    -- 11. MISC Actions Count (Active Pending / In Progress)
    (
      SELECT COUNT(*)
      FROM public.customer_misc_actions cma
      JOIN public.consumer_records cr ON cr.id = cma.consumer_id
      WHERE cr.deleted = false AND cr.is_merged = false
        AND cma.status IN ('Pending', 'In Progress')
    ) AS misc_count,

    -- 12. General Issues Count (Active New / Assigned / In Progress / Hold)
    (
      SELECT COUNT(*)
      FROM public.customer_issues ci
      JOIN public.consumer_records cr ON cr.id = ci.customer_id
      WHERE cr.deleted = false AND cr.is_merged = false
        AND ci.status IN ('New', 'Assigned', 'In Progress', 'Hold')
    ) AS issue_count,

    -- 13. Payment Pending Count (Active customers with pending balance > 0)
    COUNT(*) FILTER (
      WHERE deleted = false AND is_merged = false
        AND UPPER(COALESCE(customer_work_state, 'ACTIVE')) != 'HOLD'
        AND UPPER(COALESCE(customer_work_state, 'ACTIVE')) != 'CANCELLED'
        AND COALESCE(pending_amount, 0) > 0
    ) AS payment_pending_count

  FROM public.consumer_records;
$$;
