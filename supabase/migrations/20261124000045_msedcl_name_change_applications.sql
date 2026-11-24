-- Migration: 20261124000045_msedcl_name_change_applications.sql
-- Description: MSEDCL Change of Name Management & Stamp Paper Document Generator module
-- Features:
--   1. Full Application CRUD (Create, View, Update, Delete)
--   2. Old vs New Consumer Master linking & normalized consumer numbers
--   3. Configurable Stamp Paper Affidavit / Undertaking (₹100, ₹200, ₹500, margin, bilingual)
--   4. Form X Security Deposit (Transfer vs Refund bank accounts)
--   5. Annexure A Document checklist and file attachments
--   6. Status workflow tracking with chronological audit history

CREATE TABLE IF NOT EXISTS public.msedcl_name_change_applications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    application_no TEXT NOT NULL UNIQUE,
    application_date TIMESTAMPTZ NOT NULL DEFAULT now(),
    sub_division_office TEXT NOT NULL DEFAULT 'Nardana Sub-Division',
    circle_office TEXT NOT NULL DEFAULT 'Dhule Circle',
    village TEXT NOT NULL DEFAULT '',
    reason_for_change TEXT NOT NULL DEFAULT 'Purchase of Property / Flat / Land',
    assigned_employee TEXT NOT NULL DEFAULT 'Rahul',
    remarks TEXT DEFAULT '',
    status TEXT NOT NULL DEFAULT 'New Entry',
    status_history JSONB NOT NULL DEFAULT '[]'::jsonb,
    
    -- Old Consumer (Transferor / Seller / Ancestor)
    old_first_name TEXT NOT NULL,
    old_father_or_husband_name TEXT DEFAULT '',
    old_surname TEXT DEFAULT '',
    old_consumer_full_name TEXT NOT NULL,
    consumer_no TEXT NOT NULL,
    old_mobile_no TEXT DEFAULT '',
    old_meter_no TEXT DEFAULT '',

    -- New Consumer (Transferee / Purchaser / Legal Heir)
    new_first_name TEXT NOT NULL,
    new_father_or_husband_name TEXT DEFAULT '',
    new_surname TEXT DEFAULT '',
    new_consumer_full_name TEXT NOT NULL,
    new_age INT NOT NULL DEFAULT 35,
    new_mobile_no TEXT NOT NULL,
    new_phone_no TEXT DEFAULT '',
    new_email TEXT DEFAULT '',
    new_aadhaar_no TEXT DEFAULT '',
    property_address TEXT NOT NULL,

    -- Stamp Paper Affidavit Configuration
    stamp_paper_value NUMERIC(10,2) NOT NULL DEFAULT 100.00,
    stamp_paper_state TEXT NOT NULL DEFAULT 'Maharashtra',
    stamp_paper_language TEXT NOT NULL DEFAULT 'Marathi',
    stamp_top_margin_mm NUMERIC(6,2) NOT NULL DEFAULT 80.00,
    affidavit_custom_text TEXT,
    affidavit_place TEXT NOT NULL DEFAULT 'Dhule',

    -- Form X (Security Deposit) Configuration
    form_x_option TEXT NOT NULL DEFAULT 'transfer',
    old_consumer_consent BOOLEAN NOT NULL DEFAULT true,
    refund_account_holder_name TEXT DEFAULT '',
    refund_bank_name TEXT DEFAULT '',
    refund_branch TEXT DEFAULT '',
    refund_account_number TEXT DEFAULT '',
    refund_ifsc_code TEXT DEFAULT '',
    original_receipt_no TEXT DEFAULT '',
    receipt_status TEXT DEFAULT 'Available',
    indemnity_bond_details TEXT DEFAULT '',

    -- Annexure A Supporting Documents Checklist (JSONB)
    documents JSONB NOT NULL DEFAULT '[]'::jsonb,

    -- Signatures (Base64 transparent PNG)
    new_consumer_signature_base64 TEXT,
    old_consumer_signature_base64 TEXT,

    -- Audit meta
    created_by TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Fast Search & Filter Indexes
CREATE INDEX IF NOT EXISTS idx_msedcl_applications_app_no ON public.msedcl_name_change_applications (application_no);
CREATE INDEX IF NOT EXISTS idx_msedcl_applications_consumer_no ON public.msedcl_name_change_applications (consumer_no);
CREATE INDEX IF NOT EXISTS idx_msedcl_applications_sub_division ON public.msedcl_name_change_applications (sub_division_office);
CREATE INDEX IF NOT EXISTS idx_msedcl_applications_status ON public.msedcl_name_change_applications (status);
CREATE INDEX IF NOT EXISTS idx_msedcl_applications_date ON public.msedcl_name_change_applications (application_date DESC);
CREATE INDEX IF NOT EXISTS idx_msedcl_applications_assigned_emp ON public.msedcl_name_change_applications (assigned_employee);

-- Auto-update updated_at timestamp trigger
CREATE OR REPLACE FUNCTION public.set_msedcl_application_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_set_msedcl_application_updated_at ON public.msedcl_name_change_applications;
CREATE TRIGGER trigger_set_msedcl_application_updated_at
BEFORE UPDATE ON public.msedcl_name_change_applications
FOR EACH ROW
EXECUTE FUNCTION public.set_msedcl_application_updated_at();

-- Enable Row Level Security (RLS)
ALTER TABLE public.msedcl_name_change_applications ENABLE ROW LEVEL SECURITY;

-- Permissive policies for authenticated and anon users
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies WHERE tablename = 'msedcl_name_change_applications' AND policyname = 'msedcl_applications_select_policy'
    ) THEN
        CREATE POLICY msedcl_applications_select_policy ON public.msedcl_name_change_applications FOR SELECT USING (true);
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_policies WHERE tablename = 'msedcl_name_change_applications' AND policyname = 'msedcl_applications_insert_policy'
    ) THEN
        CREATE POLICY msedcl_applications_insert_policy ON public.msedcl_name_change_applications FOR INSERT WITH CHECK (true);
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_policies WHERE tablename = 'msedcl_name_change_applications' AND policyname = 'msedcl_applications_update_policy'
    ) THEN
        CREATE POLICY msedcl_applications_update_policy ON public.msedcl_name_change_applications FOR UPDATE USING (true) WITH CHECK (true);
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_policies WHERE tablename = 'msedcl_name_change_applications' AND policyname = 'msedcl_applications_delete_policy'
    ) THEN
        CREATE POLICY msedcl_applications_delete_policy ON public.msedcl_name_change_applications FOR DELETE USING (true);
    END IF;
END $$;
