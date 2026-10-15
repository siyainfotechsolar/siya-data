-- ==============================================================================
-- Migration: 20261016000032_customer_invoices_and_hishob.sql
-- Module: Customer Hishob Management Module
-- Description:
--   1. Ensures customer_invoices table exists with full audit columns.
--   2. Adds invoice_number and invoice_id to customer_payment_transactions.
--   3. Sets up RLS policies for authenticated access.
-- ==============================================================================

-- 1. Ensure customer_invoices table exists
CREATE TABLE IF NOT EXISTS public.customer_invoices (
    id TEXT PRIMARY KEY,
    invoice_number TEXT NOT NULL UNIQUE,
    ref_invoice_no TEXT,
    ref_quotation_id TEXT,
    customer_id UUID REFERENCES public.consumer_records(id) ON DELETE SET NULL,
    consumer_no TEXT NOT NULL,
    customer_name TEXT NOT NULL,
    address TEXT,
    village_city TEXT,
    district TEXT,
    mobile_no TEXT,
    invoice_date DATE NOT NULL,
    system_capacity TEXT DEFAULT '3 kW',
    system_type TEXT DEFAULT 'On-Grid Solar System',
    items JSONB DEFAULT '[]'::jsonb,
    taxable_amount NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    gst_5 NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    gst_18 NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    total_gst NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    grand_total NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    amount_in_words TEXT,
    total_paid NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    total_pending NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    payment_status TEXT NOT NULL DEFAULT 'Pending',
    pdf_file_name TEXT,
    pdf_file_path TEXT,
    file_url TEXT,
    include_stamp_and_signature BOOLEAN DEFAULT false,
    created_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE INDEX IF NOT EXISTS idx_customer_invoices_consumer_no ON public.customer_invoices(consumer_no);
CREATE INDEX IF NOT EXISTS idx_customer_invoices_customer_id ON public.customer_invoices(customer_id);
CREATE INDEX IF NOT EXISTS idx_customer_invoices_invoice_no ON public.customer_invoices(invoice_number);
CREATE INDEX IF NOT EXISTS idx_customer_invoices_invoice_date ON public.customer_invoices(invoice_date);

-- Enable RLS on customer_invoices
ALTER TABLE public.customer_invoices ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Authenticated full access to customer_invoices" ON public.customer_invoices;
CREATE POLICY "Authenticated full access to customer_invoices"
    ON public.customer_invoices FOR ALL TO authenticated USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Anon read access to customer_invoices" ON public.customer_invoices;
CREATE POLICY "Anon read access to customer_invoices"
    ON public.customer_invoices FOR SELECT TO anon USING (true);

-- 2. Add invoice_number and invoice_id to customer_payment_transactions
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
          AND table_name = 'customer_payment_transactions' 
          AND column_name = 'invoice_number'
    ) THEN
        ALTER TABLE public.customer_payment_transactions 
            ADD COLUMN invoice_number TEXT;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
          AND table_name = 'customer_payment_transactions' 
          AND column_name = 'invoice_id'
    ) THEN
        ALTER TABLE public.customer_payment_transactions 
            ADD COLUMN invoice_id TEXT;
    END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_customer_payments_invoice_number ON public.customer_payment_transactions(invoice_number);
