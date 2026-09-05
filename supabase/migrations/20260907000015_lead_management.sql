-- ==============================================================================
-- Migration 015: Lead Management Module
-- Description: Creates leads, lead_followups, and lead_audit_logs tables
--              with RLS, audit indexes, and Supabase Realtime synchronization.
-- ==============================================================================

-- 1. Create Leads Table
CREATE TABLE IF NOT EXISTS public.leads (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    customer_name TEXT NOT NULL,
    mobile_no TEXT NOT NULL,
    whatsapp_no TEXT,
    village TEXT,
    taluka TEXT,
    district TEXT,
    lead_source TEXT NOT NULL DEFAULT 'Other', -- 'Call', 'Reference', 'Walk-in', 'WhatsApp', 'Facebook', 'Website', 'Other'
    interested_in TEXT NOT NULL DEFAULT 'On-Grid', -- 'On-Grid', 'Off-Grid', 'Hybrid', 'Solar Pump', 'Other'
    approx_system_size TEXT, -- e.g. '3 kW', '5 kW'
    monthly_electricity_bill NUMERIC(12,2),
    estimated_budget NUMERIC(12,2),
    consumer_no TEXT, -- optional at lead stage
    lead_status TEXT NOT NULL DEFAULT 'New', -- 'New', 'Contacted', 'Interested', 'Site Survey', 'Quotation', 'Follow-up', 'Converted', 'Lost', 'No Action Required'
    next_followup_date DATE,
    assigned_staff_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    assigned_staff_name TEXT,
    remarks TEXT,
    lost_reason TEXT, -- 'Not Interested', 'Price Issue', 'Competitor', 'No Response', 'Not Eligible', 'Other'
    lost_notes TEXT,
    no_action_reason TEXT,
    no_action_notes TEXT,
    converted_at TIMESTAMPTZ,
    converted_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    customer_id UUID REFERENCES public.consumer_records(id) ON DELETE SET NULL,
    deleted BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    created_by UUID REFERENCES auth.users(id) ON DELETE SET NULL
);

-- 2. Create Lead Follow-ups Table
CREATE TABLE IF NOT EXISTS public.lead_followups (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    lead_id UUID NOT NULL REFERENCES public.leads(id) ON DELETE CASCADE,
    followup_date TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    followup_type TEXT NOT NULL DEFAULT 'Call', -- 'Call', 'WhatsApp', 'Meeting', 'Site Visit', 'Email', 'Other'
    notes TEXT NOT NULL,
    result TEXT, -- 'Interested', 'Follow-up Required', 'Quotation Requested', 'Site Survey Scheduled', 'Not Reachable', 'Lost', 'Hold', 'Other'
    next_followup_date DATE,
    performed_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    performed_by_name TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- 3. Create Lead Audit Logs Table
CREATE TABLE IF NOT EXISTS public.lead_audit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    lead_id UUID NOT NULL REFERENCES public.leads(id) ON DELETE CASCADE,
    action TEXT NOT NULL, -- 'CREATED', 'UPDATED', 'STATUS_CHANGED', 'FOLLOWUP_ADDED', 'STAFF_REASSIGNED', 'CONVERTED', 'LOST', 'NO_ACTION', 'REOPENED'
    field_name TEXT,
    old_value TEXT,
    new_value TEXT,
    reason TEXT,
    changed_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    changed_by_name TEXT,
    source TEXT NOT NULL DEFAULT 'Admin Web',
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- 4. Create Indexes
CREATE INDEX IF NOT EXISTS idx_leads_mobile_no ON public.leads(mobile_no);
CREATE INDEX IF NOT EXISTS idx_leads_customer_name ON public.leads(customer_name);
CREATE INDEX IF NOT EXISTS idx_leads_status ON public.leads(lead_status);
CREATE INDEX IF NOT EXISTS idx_leads_next_followup ON public.leads(next_followup_date);
CREATE INDEX IF NOT EXISTS idx_leads_assigned_staff ON public.leads(assigned_staff_id);
CREATE INDEX IF NOT EXISTS idx_leads_deleted ON public.leads(deleted);
CREATE INDEX IF NOT EXISTS idx_leads_updated_at ON public.leads(updated_at DESC);
CREATE INDEX IF NOT EXISTS idx_lead_followups_lead_id ON public.lead_followups(lead_id);
CREATE INDEX IF NOT EXISTS idx_lead_followups_date ON public.lead_followups(followup_date DESC);
CREATE INDEX IF NOT EXISTS idx_lead_audit_logs_lead_id ON public.lead_audit_logs(lead_id);

-- 5. Enable Row Level Security
ALTER TABLE public.leads ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.lead_followups ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.lead_audit_logs ENABLE ROW LEVEL SECURITY;

-- 6. Leads RLS Policies
DROP POLICY IF EXISTS "Admins have full access to leads" ON public.leads;
CREATE POLICY "Admins have full access to leads"
    ON public.leads
    FOR ALL
    TO authenticated
    USING ((SELECT public.is_admin()))
    WITH CHECK ((SELECT public.is_admin()));

DROP POLICY IF EXISTS "Staff can view leads" ON public.leads;
CREATE POLICY "Staff can view leads"
    ON public.leads
    FOR SELECT
    TO authenticated
    USING ((SELECT public.is_active_user()));

DROP POLICY IF EXISTS "Staff can create leads" ON public.leads;
CREATE POLICY "Staff can create leads"
    ON public.leads
    FOR INSERT
    TO authenticated
    WITH CHECK ((SELECT public.is_active_user()));

DROP POLICY IF EXISTS "Staff can update leads" ON public.leads;
CREATE POLICY "Staff can update leads"
    ON public.leads
    FOR UPDATE
    TO authenticated
    USING ((SELECT public.is_active_user()))
    WITH CHECK ((SELECT public.is_active_user()));

-- 7. Lead Follow-ups RLS Policies
DROP POLICY IF EXISTS "Admins have full access to lead_followups" ON public.lead_followups;
CREATE POLICY "Admins have full access to lead_followups"
    ON public.lead_followups
    FOR ALL
    TO authenticated
    USING ((SELECT public.is_admin()))
    WITH CHECK ((SELECT public.is_admin()));

DROP POLICY IF EXISTS "Staff can view lead_followups" ON public.lead_followups;
CREATE POLICY "Staff can view lead_followups"
    ON public.lead_followups
    FOR SELECT
    TO authenticated
    USING ((SELECT public.is_active_user()));

DROP POLICY IF EXISTS "Staff can insert lead_followups" ON public.lead_followups;
CREATE POLICY "Staff can insert lead_followups"
    ON public.lead_followups
    FOR INSERT
    TO authenticated
    WITH CHECK ((SELECT public.is_active_user()));

-- 8. Lead Audit Logs RLS Policies
DROP POLICY IF EXISTS "Admins can view lead_audit_logs" ON public.lead_audit_logs;
CREATE POLICY "Admins can view lead_audit_logs"
    ON public.lead_audit_logs
    FOR SELECT
    TO authenticated
    USING ((SELECT public.is_admin()));

DROP POLICY IF EXISTS "Staff can view lead_audit_logs" ON public.lead_audit_logs;
CREATE POLICY "Staff can view lead_audit_logs"
    ON public.lead_audit_logs
    FOR SELECT
    TO authenticated
    USING ((SELECT public.is_active_user()));

DROP POLICY IF EXISTS "Authenticated users can create lead_audit_logs" ON public.lead_audit_logs;
CREATE POLICY "Authenticated users can create lead_audit_logs"
    ON public.lead_audit_logs
    FOR INSERT
    TO authenticated
    WITH CHECK ((SELECT auth.uid()) = changed_by OR changed_by IS NULL);

-- 9. Add to Supabase Realtime Publication
DO $$
BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.leads;
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

DO $$
BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.lead_followups;
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;
