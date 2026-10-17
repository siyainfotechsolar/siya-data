-- ==============================================================================
-- Migration: 20261017000033_company_settings_and_bank_accounts.sql
-- Module: Centralized Settings Module
-- Description:
--   1. Creates company_settings table for centralized company master data,
--      GST tax configuration, document numbering prefixes, PDF settings,
--      and app preferences.
--   2. Creates company_bank_accounts table for managing company bank details,
--      default account flags, and active/inactive status.
--   3. Sets up Row Level Security (RLS) policies and performance indexes.
--   4. Seeds initial default company profile and primary bank account.
-- ==============================================================================

-- 1. Create company_settings table
CREATE TABLE IF NOT EXISTS public.company_settings (
    id TEXT PRIMARY KEY DEFAULT 'default',
    company_name TEXT NOT NULL DEFAULT 'SIYA INFOTECH & DIGITAL SOLUTIONS',
    brand_name TEXT DEFAULT 'Siya Solar Energy',
    tagline TEXT DEFAULT 'Complete Solar Solutions & EPC Contractor',
    address TEXT NOT NULL DEFAULT '21, Mudavad Road, Betawad, Tal. Shindkheda, Dist. Dhule - 425403',
    village_city TEXT DEFAULT 'Betawad',
    taluka TEXT DEFAULT 'Shindkheda',
    district TEXT DEFAULT 'Dhule',
    state TEXT DEFAULT 'Maharashtra',
    pincode TEXT DEFAULT '425403',
    mobile TEXT NOT NULL DEFAULT '7972143798',
    alternate_mobile TEXT DEFAULT '7588003220',
    email TEXT DEFAULT 'siyainfodigital@gmail.com',
    website TEXT DEFAULT 'https://siyainfotechsolar.com',
    business_reg_no TEXT DEFAULT '',
    signatory_name TEXT DEFAULT 'Manoj Kshirsagar',
    signatory_designation TEXT DEFAULT 'Managing Director / Partner',
    discom_name TEXT DEFAULT 'MSEDCL',
    
    -- GST & Tax Settings
    gstin TEXT DEFAULT '27CVTPK6358P1ZD',
    state_code TEXT DEFAULT '27',
    gst_pricing_mode TEXT DEFAULT 'inclusive', -- 'inclusive' or 'exclusive'
    is_split_gst_rule_enabled BOOLEAN DEFAULT true, -- 70% @ 5% + 30% @ 18%
    hsn_sac_code TEXT DEFAULT '8466',
    solar_system_gst_rate NUMERIC(5, 2) DEFAULT 13.80,
    standard_gst_rate NUMERIC(5, 2) DEFAULT 18.00,

    -- Branding Assets (URLs or base64 Data URIs)
    logo_url TEXT,
    stamp_url TEXT,
    signature_url TEXT,
    show_logo_on_pdf BOOLEAN DEFAULT true,
    show_stamp_on_pdf BOOLEAN DEFAULT true,
    show_signature_on_pdf BOOLEAN DEFAULT true,
    show_header_on_pdf BOOLEAN DEFAULT true,

    -- Quotation Settings
    quotation_prefix TEXT DEFAULT 'SIYA-Q-',
    quotation_validity_days INTEGER DEFAULT 30,
    quotation_terms TEXT DEFAULT '1. Rates are inclusive of Solar Panels, Inverter, Structure, and standard installation.\n2. Net Metering approval as per MSEDCL guidelines.\n3. Subsidy as per MNRE PM Surya Ghar scheme.',
    default_solar_description TEXT DEFAULT 'PM Surya Ghar Rooftop Solar PV System with High-Efficiency Mono PERC / TOPCon Modules and Grid-Tied Inverter.',

    -- Invoice Settings
    invoice_prefix TEXT DEFAULT 'SIYA-INV-',
    invoice_payment_terms TEXT DEFAULT '100% advance or bank loan disbursement on delivery.',
    invoice_terms TEXT DEFAULT '1. Goods once sold will not be taken back.\n2. Warranty as per manufacturer terms.\n3. Subject to Dhule Jurisdiction.',
    show_bank_details_on_invoice BOOLEAN DEFAULT true,
    show_qr_on_invoice BOOLEAN DEFAULT true,

    -- Payment Settings
    supported_payment_modes JSONB DEFAULT '["Cash", "UPI", "Bank Transfer", "Cheque", "Other"]'::jsonb,
    default_payment_mode TEXT DEFAULT 'Cash',
    receipt_prefix TEXT DEFAULT 'REC-',
    default_bank_account_id TEXT,

    -- Customer & Solar Settings
    solar_capacity_options JSONB DEFAULT '["2 kW", "3 kW", "4 kW", "5 kW", "6 kW", "10 kW", "15 kW"]'::jsonb,
    solar_system_types JSONB DEFAULT '["On-Grid Solar System", "Off-Grid Solar System", "Hybrid Solar System"]'::jsonb,
    document_categories JSONB DEFAULT '["Aadhar Card", "Electricity Bill", "Bank Passbook / Cheque", "Passport Photo", "Tax Receipt / Index-2"]'::jsonb,
    warranty_checklist JSONB DEFAULT '["Solar PV Modules (25 Years)", "Grid-Tied Inverter (5/10 Years)", "Module Mounting Structure (5 Years)", "Earthing & Lightning Arrester", "Net Meter Testing Certificate"]'::jsonb,
    bank_sticker_include_loan_app BOOLEAN DEFAULT true,
    bank_sticker_include_date BOOLEAN DEFAULT true,

    -- Document & PDF Settings
    default_page_size TEXT DEFAULT 'A4',
    default_orientation TEXT DEFAULT 'Portrait',

    -- App Preferences
    date_format TEXT DEFAULT 'dd/MM/yyyy',
    default_language TEXT DEFAULT 'English',

    -- Metadata
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_by UUID REFERENCES auth.users(id) ON DELETE SET NULL
);

-- Enable RLS on company_settings
ALTER TABLE public.company_settings ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Authenticated users can view company_settings" ON public.company_settings;
CREATE POLICY "Authenticated users can view company_settings"
    ON public.company_settings FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS "Anon users can view company_settings" ON public.company_settings;
CREATE POLICY "Anon users can view company_settings"
    ON public.company_settings FOR SELECT TO anon USING (true);

DROP POLICY IF EXISTS "Authenticated users can upsert company_settings" ON public.company_settings;
CREATE POLICY "Authenticated users can upsert company_settings"
    ON public.company_settings FOR ALL TO authenticated USING (true) WITH CHECK (true);


-- 2. Create company_bank_accounts table
CREATE TABLE IF NOT EXISTS public.company_bank_accounts (
    id TEXT PRIMARY KEY,
    bank_name TEXT NOT NULL,
    account_holder_name TEXT NOT NULL,
    account_no TEXT NOT NULL,
    ifsc_code TEXT NOT NULL,
    branch TEXT,
    account_type TEXT DEFAULT 'Current Account',
    upi_id TEXT,
    is_active BOOLEAN NOT NULL DEFAULT true,
    is_default BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE INDEX IF NOT EXISTS idx_company_bank_accounts_default ON public.company_bank_accounts(is_default);
CREATE INDEX IF NOT EXISTS idx_company_bank_accounts_active ON public.company_bank_accounts(is_active);

-- Enable RLS on company_bank_accounts
ALTER TABLE public.company_bank_accounts ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Authenticated users can view bank_accounts" ON public.company_bank_accounts;
CREATE POLICY "Authenticated users can view bank_accounts"
    ON public.company_bank_accounts FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS "Anon users can view bank_accounts" ON public.company_bank_accounts;
CREATE POLICY "Anon users can view bank_accounts"
    ON public.company_bank_accounts FOR SELECT TO anon USING (true);

DROP POLICY IF EXISTS "Authenticated users can manage bank_accounts" ON public.company_bank_accounts;
CREATE POLICY "Authenticated users can manage bank_accounts"
    ON public.company_bank_accounts FOR ALL TO authenticated USING (true) WITH CHECK (true);


-- 3. Seed default company profile and initial bank account (idempotent)
INSERT INTO public.company_settings (
    id,
    company_name,
    brand_name,
    tagline,
    address,
    village_city,
    taluka,
    district,
    state,
    pincode,
    mobile,
    alternate_mobile,
    email,
    website,
    gstin,
    state_code,
    signatory_name,
    signatory_designation,
    discom_name
) VALUES (
    'default',
    'SIYA INFOTECH & DIGITAL SOLUTIONS',
    'Siya Solar Energy',
    'Complete Solar Solutions & EPC Contractor',
    '21, Mudavad Road, Betawad, Tal. Shindkheda, Dist. Dhule - 425403',
    'Betawad',
    'Shindkheda',
    'Dhule',
    'Maharashtra',
    '425403',
    '7972143798',
    '7588003220',
    'siyainfodigital@gmail.com',
    'https://siyainfotechsolar.com',
    '27CVTPK6358P1ZD',
    '27',
    'Manoj Kshirsagar',
    'Managing Director / Partner',
    'MSEDCL'
) ON CONFLICT (id) DO NOTHING;

INSERT INTO public.company_bank_accounts (
    id,
    bank_name,
    account_holder_name,
    account_no,
    ifsc_code,
    branch,
    account_type,
    upi_id,
    is_active,
    is_default
) VALUES (
    'default-sbi',
    'STATE BANK OF INDIA',
    'SIYA INFOTECH & DIGITAL SOLUTIONS',
    '40662252403',
    'SBIN0004798',
    'Betawad',
    'Current Account',
    '40662252403@sbi',
    true,
    true
) ON CONFLICT (id) DO NOTHING;
