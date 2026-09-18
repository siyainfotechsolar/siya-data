-- ==============================================================================
-- Migration: 20260918000020_whatsapp_document_tasks.sql
-- Module: WhatsApp Native Share Intent & Document Tasks System
-- Description: Creates customer_tasks and customer_documents tables, indexes, RLS
-- ==============================================================================

-- 1. CUSTOMER TASKS TABLE (public.customer_tasks)
CREATE TABLE IF NOT EXISTS public.customer_tasks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    customer_id UUID REFERENCES public.consumer_records(id) ON DELETE CASCADE,
    customer_name TEXT NOT NULL,
    consumer_no TEXT NOT NULL,
    mobile_number TEXT,
    task_type TEXT NOT NULL DEFAULT 'Customer Document Update',
    title TEXT NOT NULL,
    document_type TEXT NOT NULL DEFAULT 'Other', -- 'Electricity Bill', 'Loan Document', 'Payment Proof', 'Agreement', 'RTS', 'Subsidy', 'Installation', 'Other'
    document_name TEXT NOT NULL,
    document_url TEXT,
    file_hash TEXT,
    file_size BIGINT DEFAULT 0,
    source TEXT NOT NULL DEFAULT 'WhatsApp Share', -- 'WhatsApp Share', 'Manual Upload', 'Action Center', 'Mobile App'
    status TEXT NOT NULL DEFAULT 'New' CHECK (status IN ('New', 'Document Review', 'Customer Data Update', 'Verification', 'Complete', 'Hold', 'Follow-up', 'Reopen')),
    priority TEXT NOT NULL DEFAULT 'Normal' CHECK (priority IN ('Normal', 'High', 'Urgent')),
    assigned_staff TEXT,
    due_date DATE,
    hold_reason TEXT,
    resolution_remarks TEXT,
    remarks TEXT,
    extracted_data JSONB,
    sync_status TEXT NOT NULL DEFAULT 'Synced', -- 'Synced', 'Pending Sync'
    created_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    created_by_name TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    updated_by_name TEXT,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    completed_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    completed_by_name TEXT,
    completed_at TIMESTAMPTZ
);

-- Performance Indexes
CREATE INDEX IF NOT EXISTS idx_customer_tasks_customer_id ON public.customer_tasks(customer_id);
CREATE INDEX IF NOT EXISTS idx_customer_tasks_consumer_no ON public.customer_tasks(consumer_no);
CREATE INDEX IF NOT EXISTS idx_customer_tasks_status ON public.customer_tasks(status);
CREATE INDEX IF NOT EXISTS idx_customer_tasks_source ON public.customer_tasks(source);
CREATE INDEX IF NOT EXISTS idx_customer_tasks_file_hash ON public.customer_tasks(file_hash);
CREATE INDEX IF NOT EXISTS idx_customer_tasks_created_at ON public.customer_tasks(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_customer_tasks_staff ON public.customer_tasks(assigned_staff);

-- 2. CUSTOMER DOCUMENTS TABLE (public.customer_documents)
CREATE TABLE IF NOT EXISTS public.customer_documents (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    customer_id UUID NOT NULL REFERENCES public.consumer_records(id) ON DELETE CASCADE,
    consumer_no TEXT NOT NULL,
    document_type TEXT NOT NULL,
    document_name TEXT NOT NULL,
    file_url TEXT NOT NULL,
    file_hash TEXT,
    file_size BIGINT DEFAULT 0,
    source TEXT NOT NULL DEFAULT 'WhatsApp Share',
    task_id UUID REFERENCES public.customer_tasks(id) ON DELETE SET NULL,
    extracted_data JSONB,
    uploaded_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    uploaded_by_name TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE INDEX IF NOT EXISTS idx_customer_documents_customer_id ON public.customer_documents(customer_id);
CREATE INDEX IF NOT EXISTS idx_customer_documents_consumer_no ON public.customer_documents(consumer_no);
CREATE INDEX IF NOT EXISTS idx_customer_documents_file_hash ON public.customer_documents(file_hash);
CREATE INDEX IF NOT EXISTS idx_customer_documents_created_at ON public.customer_documents(created_at DESC);

-- 3. ENABLE ROW LEVEL SECURITY (RLS)
ALTER TABLE public.customer_tasks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.customer_documents ENABLE ROW LEVEL SECURITY;

-- 4. RLS POLICIES FOR customer_tasks
DROP POLICY IF EXISTS "Authenticated users can select customer_tasks" ON public.customer_tasks;
CREATE POLICY "Authenticated users can select customer_tasks"
    ON public.customer_tasks FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS "Authenticated users can insert customer_tasks" ON public.customer_tasks;
CREATE POLICY "Authenticated users can insert customer_tasks"
    ON public.customer_tasks FOR INSERT TO authenticated WITH CHECK (true);

DROP POLICY IF EXISTS "Authenticated users can update customer_tasks" ON public.customer_tasks;
CREATE POLICY "Authenticated users can update customer_tasks"
    ON public.customer_tasks FOR UPDATE TO authenticated USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Admins can delete customer_tasks" ON public.customer_tasks;
CREATE POLICY "Admins can delete customer_tasks"
    ON public.customer_tasks FOR DELETE TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.profiles
            WHERE profiles.id = auth.uid()
              AND profiles.role IN ('admin', 'super_admin', 'owner')
        )
    );

-- 5. RLS POLICIES FOR customer_documents
DROP POLICY IF EXISTS "Authenticated users can select customer_documents" ON public.customer_documents;
CREATE POLICY "Authenticated users can select customer_documents"
    ON public.customer_documents FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS "Authenticated users can insert customer_documents" ON public.customer_documents;
CREATE POLICY "Authenticated users can insert customer_documents"
    ON public.customer_documents FOR INSERT TO authenticated WITH CHECK (true);

DROP POLICY IF EXISTS "Authenticated users can update customer_documents" ON public.customer_documents;
CREATE POLICY "Authenticated users can update customer_documents"
    ON public.customer_documents FOR UPDATE TO authenticated USING (true) WITH CHECK (true);

-- 6. STORAGE BUCKET FOR CUSTOMER DOCUMENTS
INSERT INTO storage.buckets (id, name, public)
VALUES ('customer-documents', 'customer-documents', true)
ON CONFLICT (id) DO NOTHING;

DROP POLICY IF EXISTS "Public access to customer-documents" ON storage.objects;
CREATE POLICY "Public access to customer-documents"
    ON storage.objects FOR SELECT TO authenticated, anon
    USING (bucket_id = 'customer-documents');

DROP POLICY IF EXISTS "Authenticated users can upload to customer-documents" ON storage.objects;
CREATE POLICY "Authenticated users can upload to customer-documents"
    ON storage.objects FOR INSERT TO authenticated
    WITH CHECK (bucket_id = 'customer-documents');

DROP POLICY IF EXISTS "Authenticated users can update customer-documents" ON storage.objects;
CREATE POLICY "Authenticated users can update customer-documents"
    ON storage.objects FOR UPDATE TO authenticated
    USING (bucket_id = 'customer-documents');
