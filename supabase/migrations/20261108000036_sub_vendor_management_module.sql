-- ==============================================================================
-- Migration: 20261108000036_sub_vendor_management_module.sql
-- Module: Sub-Vendor Management & Dynamic Financial Calculation Dashboard
-- Description:
--   1. Creates public.sub_vendors (Sub-Vendor Master).
--   2. Creates public.vendor_site_assignments (Site assignment to sub-vendors).
--   3. Creates public.vendor_material_transactions (Dynamic material issues & returns with 5% & 18% GST).
--   4. Creates public.vendor_payouts (Sub-vendor payout & disbursement tracking).
--   5. Sets up Row Level Security (RLS) policies enforcing complete vendor data isolation.
--   6. Provides Admin RPCs for sub-vendor creation, status toggle, site assignment, material issue/return, and payout.
-- ==============================================================================

-- 1. Create Sub-Vendors Table (Sub-Vendor Master)
CREATE TABLE IF NOT EXISTS public.sub_vendors (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    vendor_code TEXT NOT NULL UNIQUE,
    name TEXT NOT NULL,
    contact_person TEXT,
    mobile TEXT NOT NULL,
    email TEXT NOT NULL,
    auth_user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    address TEXT,
    pan_number TEXT,
    gst_number TEXT,
    bank_name TEXT,
    account_number TEXT,
    ifsc_code TEXT,
    upi_id TEXT,
    default_rate_per_kw NUMERIC(12, 2) NOT NULL DEFAULT 1000.00 CHECK (default_rate_per_kw >= 0),
    is_active BOOLEAN NOT NULL DEFAULT true,
    status TEXT NOT NULL DEFAULT 'Active' CHECK (status IN ('Active', 'Inactive', 'Blocked')),
    notes TEXT,
    created_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    updated_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE INDEX IF NOT EXISTS idx_sub_vendors_vendor_code ON public.sub_vendors (vendor_code);
CREATE INDEX IF NOT EXISTS idx_sub_vendors_mobile ON public.sub_vendors (mobile);
CREATE INDEX IF NOT EXISTS idx_sub_vendors_auth_user_id ON public.sub_vendors (auth_user_id);
CREATE INDEX IF NOT EXISTS idx_sub_vendors_is_active ON public.sub_vendors (is_active);

-- 2. Create Vendor Site Assignments Table
CREATE TABLE IF NOT EXISTS public.vendor_site_assignments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    vendor_id UUID NOT NULL REFERENCES public.sub_vendors(id) ON DELETE CASCADE,
    customer_id UUID NOT NULL REFERENCES public.consumer_records(id) ON DELETE CASCADE,
    assigned_date DATE NOT NULL DEFAULT CURRENT_DATE,
    site_capacity_kw NUMERIC(10, 2) NOT NULL DEFAULT 3.00 CHECK (site_capacity_kw > 0),
    rate_per_kw NUMERIC(12, 2) NOT NULL DEFAULT 1000.00 CHECK (rate_per_kw >= 0),
    vendor_charges NUMERIC(12, 2) NOT NULL DEFAULT 3000.00 CHECK (vendor_charges >= 0),
    other_expenses NUMERIC(12, 2) NOT NULL DEFAULT 0.00 CHECK (other_expenses >= 0),
    expense_remarks TEXT,
    status TEXT NOT NULL DEFAULT 'Assigned' CHECK (status IN ('Assigned', 'In Progress', 'Completed', 'Settled', 'Cancelled')),
    completion_date DATE,
    notes TEXT,
    financial_approved BOOLEAN NOT NULL DEFAULT false,
    financial_approved_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    financial_approved_at TIMESTAMPTZ,
    settlement_approved BOOLEAN NOT NULL DEFAULT false,
    settlement_approved_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    settlement_approved_at TIMESTAMPTZ,
    created_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    updated_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    CONSTRAINT uq_vendor_customer_assignment UNIQUE (vendor_id, customer_id)
);

CREATE INDEX IF NOT EXISTS idx_vendor_site_assignments_vendor_id ON public.vendor_site_assignments (vendor_id);
CREATE INDEX IF NOT EXISTS idx_vendor_site_assignments_customer_id ON public.vendor_site_assignments (customer_id);
CREATE INDEX IF NOT EXISTS idx_vendor_site_assignments_status ON public.vendor_site_assignments (status);

-- 3. Create Vendor Material Transactions Table (Dynamic Material Issues & Returns)
CREATE TABLE IF NOT EXISTS public.vendor_material_transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    assignment_id UUID NOT NULL REFERENCES public.vendor_site_assignments(id) ON DELETE CASCADE,
    vendor_id UUID NOT NULL REFERENCES public.sub_vendors(id) ON DELETE CASCADE,
    customer_id UUID NOT NULL REFERENCES public.consumer_records(id) ON DELETE CASCADE,
    transaction_type TEXT NOT NULL CHECK (transaction_type IN ('ISSUE', 'RETURN')),
    transaction_date DATE NOT NULL DEFAULT CURRENT_DATE,
    item_name TEXT NOT NULL,
    item_category TEXT NOT NULL CHECK (item_category IN ('SOLAR_PANEL', 'INVERTER', 'BOS', 'OTHER')),
    gst_rate NUMERIC(5, 2) NOT NULL DEFAULT 5.00 CHECK (gst_rate >= 0),
    quantity NUMERIC(10, 2) NOT NULL CHECK (quantity > 0),
    unit TEXT NOT NULL DEFAULT 'Nos',
    unit_rate NUMERIC(12, 2) NOT NULL DEFAULT 0.00 CHECK (unit_rate >= 0),
    taxable_amount NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    gst_amount NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    total_amount NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    challan_number TEXT,
    serial_numbers TEXT,
    remarks TEXT,
    created_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE INDEX IF NOT EXISTS idx_vendor_material_assignment_id ON public.vendor_material_transactions (assignment_id);
CREATE INDEX IF NOT EXISTS idx_vendor_material_vendor_id ON public.vendor_material_transactions (vendor_id);
CREATE INDEX IF NOT EXISTS idx_vendor_material_customer_id ON public.vendor_material_transactions (customer_id);
CREATE INDEX IF NOT EXISTS idx_vendor_material_type ON public.vendor_material_transactions (transaction_type);
CREATE INDEX IF NOT EXISTS idx_vendor_material_category ON public.vendor_material_transactions (item_category);

-- 4. Create Vendor Payouts Table
CREATE TABLE IF NOT EXISTS public.vendor_payouts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    vendor_id UUID NOT NULL REFERENCES public.sub_vendors(id) ON DELETE CASCADE,
    assignment_id UUID REFERENCES public.vendor_site_assignments(id) ON DELETE SET NULL,
    payout_date DATE NOT NULL DEFAULT CURRENT_DATE,
    amount NUMERIC(12, 2) NOT NULL CHECK (amount > 0),
    payment_mode TEXT NOT NULL DEFAULT 'Bank Transfer' CHECK (payment_mode IN ('Bank Transfer', 'NEFT/RTGS', 'UPI', 'Cheque', 'Cash')),
    reference_number TEXT,
    bank_name TEXT,
    remarks TEXT,
    status TEXT NOT NULL DEFAULT 'Paid' CHECK (status IN ('Pending', 'Approved', 'Paid')),
    created_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE INDEX IF NOT EXISTS idx_vendor_payouts_vendor_id ON public.vendor_payouts (vendor_id);
CREATE INDEX IF NOT EXISTS idx_vendor_payouts_assignment_id ON public.vendor_payouts (assignment_id);
CREATE INDEX IF NOT EXISTS idx_vendor_payouts_payout_date ON public.vendor_payouts (payout_date DESC);

-- 5. Sequences for Auto-generating Vendor Code (SIYA-VND-XXXX)
CREATE SEQUENCE IF NOT EXISTS public.seq_sub_vendor_code START 101;

CREATE OR REPLACE FUNCTION public.generate_sub_vendor_code()
RETURNS TEXT
LANGUAGE plpgsql
AS $$
DECLARE
    v_seq BIGINT;
BEGIN
    v_seq := nextval('public.seq_sub_vendor_code');
    RETURN 'SIYA-VND-' || lpad(v_seq::text, 3, '0');
END;
$$;

-- 6. Helper Security Functions (STABLE, SECURITY DEFINER with explicit search_path)
CREATE OR REPLACE FUNCTION public.get_sub_vendor_id()
RETURNS UUID
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
  SELECT id FROM public.sub_vendors
  WHERE auth_user_id = (SELECT auth.uid())
    AND is_active = true
  LIMIT 1;
$$;

CREATE OR REPLACE FUNCTION public.is_sub_vendor()
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id = (SELECT auth.uid())
      AND role = 'sub_vendor'
      AND is_active = true
  );
$$;

REVOKE EXECUTE ON FUNCTION public.get_sub_vendor_id() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_sub_vendor_id() TO authenticated;

REVOKE EXECUTE ON FUNCTION public.is_sub_vendor() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.is_sub_vendor() TO authenticated;

-- 7. Enable RLS on all newly created tables
ALTER TABLE public.sub_vendors ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.vendor_site_assignments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.vendor_material_transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.vendor_payouts ENABLE ROW LEVEL SECURITY;

-- ==============================================================================
-- RLS POLICIES FOR SUB-VENDORS TABLE
-- ==============================================================================
DROP POLICY IF EXISTS "Admins have full access to sub_vendors" ON public.sub_vendors;
CREATE POLICY "Admins have full access to sub_vendors"
    ON public.sub_vendors
    FOR ALL
    TO authenticated
    USING ((SELECT public.is_admin()))
    WITH CHECK ((SELECT public.is_admin()));

DROP POLICY IF EXISTS "Sub-vendors can view own vendor profile" ON public.sub_vendors;
CREATE POLICY "Sub-vendors can view own vendor profile"
    ON public.sub_vendors
    FOR SELECT
    TO authenticated
    USING (auth_user_id = (SELECT auth.uid()));

-- ==============================================================================
-- RLS POLICIES FOR VENDOR SITE ASSIGNMENTS
-- ==============================================================================
DROP POLICY IF EXISTS "Admins have full access to vendor_site_assignments" ON public.vendor_site_assignments;
CREATE POLICY "Admins have full access to vendor_site_assignments"
    ON public.vendor_site_assignments
    FOR ALL
    TO authenticated
    USING ((SELECT public.is_admin()))
    WITH CHECK ((SELECT public.is_admin()));

DROP POLICY IF EXISTS "Sub-vendors can view own site assignments" ON public.vendor_site_assignments;
CREATE POLICY "Sub-vendors can view own site assignments"
    ON public.vendor_site_assignments
    FOR SELECT
    TO authenticated
    USING (vendor_id = (SELECT public.get_sub_vendor_id()));

DROP POLICY IF EXISTS "Sub-vendors can update status of own unapproved assignments" ON public.vendor_site_assignments;
CREATE POLICY "Sub-vendors can update status of own unapproved assignments"
    ON public.vendor_site_assignments
    FOR UPDATE
    TO authenticated
    USING (
        vendor_id = (SELECT public.get_sub_vendor_id())
        AND financial_approved = false
        AND settlement_approved = false
    )
    WITH CHECK (
        vendor_id = (SELECT public.get_sub_vendor_id())
        AND financial_approved = false
        AND settlement_approved = false
    );

-- ==============================================================================
-- RLS POLICIES FOR VENDOR MATERIAL TRANSACTIONS
-- ==============================================================================
DROP POLICY IF EXISTS "Admins have full access to vendor_material_transactions" ON public.vendor_material_transactions;
CREATE POLICY "Admins have full access to vendor_material_transactions"
    ON public.vendor_material_transactions
    FOR ALL
    TO authenticated
    USING ((SELECT public.is_admin()))
    WITH CHECK ((SELECT public.is_admin()));

DROP POLICY IF EXISTS "Sub-vendors can view own material transactions" ON public.vendor_material_transactions;
CREATE POLICY "Sub-vendors can view own material transactions"
    ON public.vendor_material_transactions
    FOR SELECT
    TO authenticated
    USING (vendor_id = (SELECT public.get_sub_vendor_id()));

-- ==============================================================================
-- RLS POLICIES FOR VENDOR PAYOUTS
-- ==============================================================================
DROP POLICY IF EXISTS "Admins have full access to vendor_payouts" ON public.vendor_payouts;
CREATE POLICY "Admins have full access to vendor_payouts"
    ON public.vendor_payouts
    FOR ALL
    TO authenticated
    USING ((SELECT public.is_admin()))
    WITH CHECK ((SELECT public.is_admin()));

DROP POLICY IF EXISTS "Sub-vendors can view own payouts" ON public.vendor_payouts;
CREATE POLICY "Sub-vendors can view own payouts"
    ON public.vendor_payouts
    FOR SELECT
    TO authenticated
    USING (vendor_id = (SELECT public.get_sub_vendor_id()));

-- ==============================================================================
-- RLS POLICY ON CONSUMER RECORDS (ALLOWS SUB-VENDORS TO VIEW ASSIGNED SITES ONLY)
-- ==============================================================================
DROP POLICY IF EXISTS "Sub-vendors can view assigned consumer records" ON public.consumer_records;
CREATE POLICY "Sub-vendors can view assigned consumer records"
    ON public.consumer_records
    FOR SELECT
    TO authenticated
    USING (
        (SELECT public.is_sub_vendor()) AND id IN (
            SELECT customer_id FROM public.vendor_site_assignments
            WHERE vendor_id = (SELECT public.get_sub_vendor_id())
        )
    );

-- ==============================================================================
-- RPC: Admin Create Sub-Vendor User
-- ==============================================================================
CREATE OR REPLACE FUNCTION public.admin_create_sub_vendor(
    p_vendor_code TEXT,
    p_name TEXT,
    p_mobile TEXT,
    p_password TEXT,
    p_contact_person TEXT DEFAULT NULL,
    p_email TEXT DEFAULT NULL,
    p_address TEXT DEFAULT NULL,
    p_pan_number TEXT DEFAULT NULL,
    p_gst_number TEXT DEFAULT NULL,
    p_bank_name TEXT DEFAULT NULL,
    p_account_number TEXT DEFAULT NULL,
    p_ifsc_code TEXT DEFAULT NULL,
    p_upi_id TEXT DEFAULT NULL,
    p_default_rate_per_kw NUMERIC DEFAULT 1000.00,
    p_notes TEXT DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, extensions
AS $$
DECLARE
    v_new_user_id UUID;
    v_vendor_id UUID;
    v_caller_role TEXT;
    v_caller_active BOOLEAN;
    v_clean_email TEXT;
    v_clean_mobile TEXT;
    v_code TEXT;
BEGIN
    -- 1. Authorization check: Admin only
    SELECT role, is_active INTO v_caller_role, v_caller_active
    FROM public.profiles
    WHERE id = auth.uid();

    IF v_caller_role != 'admin' OR v_caller_active != true THEN
        RAISE EXCEPTION 'Unauthorized: Only active administrators can create sub-vendors.';
    END IF;

    v_clean_mobile := TRIM(p_mobile);
    IF LENGTH(v_clean_mobile) < 10 THEN
        RAISE EXCEPTION 'Mobile number must be at least 10 digits.';
    END IF;

    IF LENGTH(p_password) < 6 THEN
        RAISE EXCEPTION 'Password must be at least 6 characters.';
    END IF;

    -- Format valid login email
    IF p_email IS NOT NULL AND TRIM(p_email) <> '' THEN
        v_clean_email := LOWER(TRIM(p_email));
    ELSE
        v_clean_email := LOWER(v_clean_mobile) || '@vendor.siyasolar.com';
    END IF;

    -- Format or generate vendor code
    IF p_vendor_code IS NOT NULL AND TRIM(p_vendor_code) <> '' THEN
        v_code := UPPER(TRIM(p_vendor_code));
    ELSE
        v_code := public.generate_sub_vendor_code();
    END IF;

    -- Check duplicate code or mobile
    IF EXISTS (SELECT 1 FROM public.sub_vendors WHERE vendor_code = v_code) THEN
        RAISE EXCEPTION 'Vendor code "%" is already in use.', v_code;
    END IF;

    IF EXISTS (SELECT 1 FROM public.sub_vendors WHERE mobile = v_clean_mobile) THEN
        RAISE EXCEPTION 'Vendor with mobile "%" already exists.', v_clean_mobile;
    END IF;

    -- Check if auth user exists
    SELECT id INTO v_new_user_id FROM auth.users WHERE LOWER(email) = v_clean_email;

    IF v_new_user_id IS NULL THEN
        v_new_user_id := gen_random_uuid();

        -- Insert into auth.users
        INSERT INTO auth.users (
            instance_id,
            id,
            aud,
            role,
            email,
            encrypted_password,
            email_confirmed_at,
            confirmed_at,
            raw_app_meta_data,
            raw_user_meta_data,
            created_at,
            updated_at
        ) VALUES (
            '00000000-0000-0000-0000-000000000000',
            v_new_user_id,
            'authenticated',
            'authenticated',
            v_clean_email,
            extensions.crypt(p_password, extensions.gen_salt('bf')),
            NOW(),
            NOW(),
            jsonb_build_object('provider', 'email', 'providers', jsonb_build_array('email')),
            jsonb_build_object('full_name', TRIM(p_name), 'mobile', v_clean_mobile, 'role', 'sub_vendor'),
            NOW(),
            NOW()
        );

        -- Insert into auth.identities
        INSERT INTO auth.identities (
            id,
            user_id,
            provider_id,
            identity_data,
            provider,
            last_sign_in_at,
            created_at,
            updated_at
        ) VALUES (
            gen_random_uuid(),
            v_new_user_id,
            v_new_user_id::text,
            jsonb_build_object('sub', v_new_user_id::text, 'email', v_clean_email, 'email_verified', true, 'phone_verified', false),
            'email',
            NOW(),
            NOW(),
            NOW()
        ) ON CONFLICT (provider, provider_id) DO NOTHING;
    ELSE
        -- Update password if already exists
        UPDATE auth.users
        SET encrypted_password = extensions.crypt(p_password, extensions.gen_salt('bf')),
            updated_at = NOW()
        WHERE id = v_new_user_id;
    END IF;

    -- Upsert profile with sub_vendor role
    INSERT INTO public.profiles (
        id,
        email,
        full_name,
        role,
        mobile,
        department,
        status,
        is_active,
        permissions,
        created_at,
        updated_at
    ) VALUES (
        v_new_user_id,
        v_clean_email,
        TRIM(p_name),
        'sub_vendor',
        v_clean_mobile,
        'Sub-Vendor Operations',
        'Active',
        true,
        jsonb_build_object('vendor_code', v_code),
        NOW(),
        NOW()
    )
    ON CONFLICT (id) DO UPDATE SET
        full_name = EXCLUDED.full_name,
        role = 'sub_vendor',
        mobile = EXCLUDED.mobile,
        is_active = true,
        status = 'Active',
        updated_at = NOW();

    -- Create sub_vendors record
    v_vendor_id := gen_random_uuid();
    INSERT INTO public.sub_vendors (
        id,
        vendor_code,
        name,
        contact_person,
        mobile,
        email,
        auth_user_id,
        address,
        pan_number,
        gst_number,
        bank_name,
        account_number,
        ifsc_code,
        upi_id,
        default_rate_per_kw,
        is_active,
        status,
        notes,
        created_by,
        created_at,
        updated_at
    ) VALUES (
        v_vendor_id,
        v_code,
        TRIM(p_name),
        NULLIF(TRIM(p_contact_person), ''),
        v_clean_mobile,
        v_clean_email,
        v_new_user_id,
        NULLIF(TRIM(p_address), ''),
        NULLIF(TRIM(p_pan_number), ''),
        NULLIF(TRIM(p_gst_number), ''),
        NULLIF(TRIM(p_bank_name), ''),
        NULLIF(TRIM(p_account_number), ''),
        NULLIF(TRIM(p_ifsc_code), ''),
        NULLIF(TRIM(p_upi_id), ''),
        COALESCE(p_default_rate_per_kw, 1000.00),
        true,
        'Active',
        NULLIF(TRIM(p_notes), ''),
        auth.uid(),
        NOW(),
        NOW()
    );

    RETURN v_vendor_id;
END;
$$;

-- ==============================================================================
-- RPC: Admin Toggle Sub-Vendor Status (Active / Blocked / Inactive)
-- ==============================================================================
CREATE OR REPLACE FUNCTION public.admin_set_vendor_status(
    p_vendor_id UUID,
    p_status TEXT -- 'Active', 'Inactive', 'Blocked'
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
    v_auth_user_id UUID;
    v_is_active BOOLEAN;
BEGIN
    IF NOT (SELECT public.is_admin()) THEN
        RAISE EXCEPTION 'Unauthorized: Only administrators can update vendor status.';
    END IF;

    IF p_status NOT IN ('Active', 'Inactive', 'Blocked') THEN
        RAISE EXCEPTION 'Invalid status: %', p_status;
    END IF;

    v_is_active := (p_status = 'Active');

    SELECT auth_user_id INTO v_auth_user_id
    FROM public.sub_vendors
    WHERE id = p_vendor_id;

    UPDATE public.sub_vendors
    SET status = p_status,
        is_active = v_is_active,
        updated_at = NOW(),
        updated_by = auth.uid()
    WHERE id = p_vendor_id;

    IF v_auth_user_id IS NOT NULL THEN
        UPDATE public.profiles
        SET status = p_status,
            is_active = v_is_active,
            updated_at = NOW()
        WHERE id = v_auth_user_id;
    END IF;

    RETURN true;
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_create_sub_vendor TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_set_vendor_status TO authenticated;
