-- ==============================================================================
-- Migration: Customer Miscellaneous Actions (MISC)
-- Adds public.customer_misc_actions table, indexes, RLS, and Realtime publication
-- ==============================================================================

-- 1. Create public.customer_misc_actions table
CREATE TABLE IF NOT EXISTS public.customer_misc_actions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    record_id UUID NOT NULL REFERENCES public.consumer_records(id) ON DELETE CASCADE,
    consumer_no TEXT NOT NULL,
    customer_name TEXT NOT NULL,
    mobile TEXT,
    reason TEXT NOT NULL, -- 'Customer Details Correction', 'Document Request', 'Site Visit Required', 'Customer Callback', 'Mobile Number Update', 'Address Correction', 'Bank Related Other Request', 'MSEDCL Related Other Request', 'Material Related Request', 'Other Customer Request', 'Manual Staff Action'
    description TEXT,
    assigned_staff_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    assigned_staff_name TEXT,
    due_date DATE,
    priority TEXT NOT NULL DEFAULT 'Medium', -- 'Low', 'Medium', 'High', 'Urgent'
    status TEXT NOT NULL DEFAULT 'Pending', -- 'Pending', 'In Progress', 'Hold', 'Completed', 'Cancelled'
    remarks TEXT,
    hold_reason TEXT,
    created_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    created_by_name TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    completed_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    completed_by_name TEXT,
    completed_at TIMESTAMPTZ
);

-- 2. Indexes for performance
CREATE INDEX IF NOT EXISTS idx_customer_misc_record_id ON public.customer_misc_actions(record_id);
CREATE INDEX IF NOT EXISTS idx_customer_misc_consumer_no ON public.customer_misc_actions(consumer_no);
CREATE INDEX IF NOT EXISTS idx_customer_misc_status ON public.customer_misc_actions(status);
CREATE INDEX IF NOT EXISTS idx_customer_misc_due_date ON public.customer_misc_actions(due_date);
CREATE INDEX IF NOT EXISTS idx_customer_misc_assigned ON public.customer_misc_actions(assigned_staff_id);
CREATE INDEX IF NOT EXISTS idx_customer_misc_active_dup ON public.customer_misc_actions(record_id, reason) WHERE status IN ('Pending', 'In Progress');

-- 3. Enable Row Level Security (RLS)
ALTER TABLE public.customer_misc_actions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Admins and staff have full access to customer_misc_actions" ON public.customer_misc_actions;
CREATE POLICY "Admins and staff have full access to customer_misc_actions"
    ON public.customer_misc_actions
    FOR ALL
    TO authenticated
    USING (true)
    WITH CHECK (true);

DROP POLICY IF EXISTS "Anon read access for customer_misc_actions" ON public.customer_misc_actions;
CREATE POLICY "Anon read access for customer_misc_actions"
    ON public.customer_misc_actions
    FOR SELECT
    TO anon
    USING (true);

-- 4. Add customer_misc_actions to Realtime Publication
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.customer_misc_actions;
    END IF;
EXCEPTION
    WHEN duplicate_object THEN NULL;
END $$;

-- 5. Update Action Center counts RPC to include misc_count
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
  misc_count BIGINT
) LANGUAGE sql STABLE AS $$
  SELECT
    -- 1. Agreement Pending (Active only)
    COUNT(*) FILTER (
      WHERE deleted = false AND is_merged = false
        AND UPPER(COALESCE(customer_work_state, 'ACTIVE')) = 'ACTIVE'
        AND LOWER(COALESCE(subsidy_status, '')) NOT IN ('received', 'completed')
        AND LOWER(COALESCE(agreement_status, '')) NOT IN ('completed', 'verified', 'approved')
    ) AS agreement_pending_count,

    -- 2. Loan Pending (Active only)
    COUNT(*) FILTER (
      WHERE deleted = false AND is_merged = false
        AND UPPER(COALESCE(customer_work_state, 'ACTIVE')) = 'ACTIVE'
        AND LOWER(COALESCE(subsidy_status, '')) NOT IN ('received', 'completed')
        AND LOWER(COALESCE(agreement_status, '')) IN ('completed', 'verified', 'approved')
        AND LOWER(COALESCE(loan_required, '')) = 'yes'
        AND LOWER(COALESCE(loan_status, '')) NOT IN ('completed', 'approved', 'disbursed', 'not required')
    ) AS loan_pending_count,

    -- 3. Installation Pending (Active only)
    COUNT(*) FILTER (
      WHERE deleted = false AND is_merged = false
        AND UPPER(COALESCE(customer_work_state, 'ACTIVE')) = 'ACTIVE'
        AND LOWER(COALESCE(subsidy_status, '')) NOT IN ('received', 'completed')
        AND LOWER(COALESCE(agreement_status, '')) IN ('completed', 'verified', 'approved')
        AND (
          LOWER(COALESCE(loan_required, '')) != 'yes'
          OR LOWER(COALESCE(loan_status, '')) IN ('completed', 'approved', 'disbursed', 'not required')
        )
        AND LOWER(COALESCE(installation_status, '')) NOT IN ('completed', 'installed', 'done')
    ) AS installation_pending_count,

    -- 4. RTS Pending (Active only)
    COUNT(*) FILTER (
      WHERE deleted = false AND is_merged = false
        AND UPPER(COALESCE(customer_work_state, 'ACTIVE')) = 'ACTIVE'
        AND LOWER(COALESCE(subsidy_status, '')) NOT IN ('received', 'completed')
        AND LOWER(COALESCE(agreement_status, '')) IN ('completed', 'verified', 'approved')
        AND (
          LOWER(COALESCE(loan_required, '')) != 'yes'
          OR LOWER(COALESCE(loan_status, '')) IN ('completed', 'approved', 'disbursed', 'not required')
        )
        AND LOWER(COALESCE(installation_status, '')) IN ('completed', 'installed', 'done')
        AND LOWER(COALESCE(rts_status, '')) NOT IN ('completed', 'approved', 'done')
    ) AS rts_pending_count,

    -- 5. Subsidy Processing (Active only)
    COUNT(*) FILTER (
      WHERE deleted = false AND is_merged = false
        AND UPPER(COALESCE(customer_work_state, 'ACTIVE')) = 'ACTIVE'
        AND LOWER(COALESCE(subsidy_status, '')) NOT IN ('received', 'completed')
        AND LOWER(COALESCE(agreement_status, '')) IN ('completed', 'verified', 'approved')
        AND (
          LOWER(COALESCE(loan_required, '')) != 'yes'
          OR LOWER(COALESCE(loan_status, '')) IN ('completed', 'approved', 'disbursed', 'not required')
        )
        AND LOWER(COALESCE(installation_status, '')) IN ('completed', 'installed', 'done')
        AND LOWER(COALESCE(rts_status, '')) IN ('completed', 'approved', 'done')
        AND LOWER(COALESCE(subsidy_status, '')) NOT IN ('received', 'completed')
    ) AS subsidy_processing_count,

    -- 6. Completed
    COUNT(*) FILTER (
      WHERE deleted = false AND is_merged = false
        AND (
          UPPER(COALESCE(customer_work_state, '')) = 'COMPLETED'
          OR LOWER(COALESCE(subsidy_status, '')) IN ('received', 'completed')
        )
    ) AS completed_count,

    -- 7. On Hold / No Action Required
    COUNT(*) FILTER (
      WHERE deleted = false AND is_merged = false
        AND UPPER(COALESCE(customer_work_state, '')) = 'NO_ACTION'
    ) AS no_action_required_count,

    -- 8. Today's Follow-up (Active centralized followups where followup_date = CURRENT_DATE)
    (
      SELECT COUNT(*)
      FROM public.customer_followups
      WHERE status = 'PENDING'
        AND followup_date = CURRENT_DATE
    ) AS todays_followup_count,

    -- 9. Overdue Follow-up (Active centralized followups where followup_date < CURRENT_DATE)
    (
      SELECT COUNT(*)
      FROM public.customer_followups
      WHERE status = 'PENDING'
        AND followup_date < CURRENT_DATE
    ) AS overdue_followup_count,

    -- 10. Upcoming Follow-up (Active centralized followups where followup_date > CURRENT_DATE)
    (
      SELECT COUNT(*)
      FROM public.customer_followups
      WHERE status = 'PENDING'
        AND followup_date > CURRENT_DATE
    ) AS upcoming_followup_count,

    -- 11. Active MISC count
    (
      SELECT COUNT(*)
      FROM public.customer_misc_actions
      WHERE status IN ('Pending', 'In Progress')
    ) AS misc_count
  FROM public.consumer_records;
$$;
