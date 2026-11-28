-- ==============================================================================
-- Migration: 20261128000053_sub_vendor_login_resolution_and_auth_sync.sql
-- Module: Sub-Vendor Authentication & Login Standardization (Web & Mobile)
-- Description:
--   1. Adds SECURITY DEFINER RPC `resolve_login_email(p_identifier TEXT)` so
--      Sub-Vendors (and Staff) can sign in seamlessly using:
--      - Email address (custom Gmail/company email or @vendor.siyasolar.com)
--      - 10-digit Mobile Number (resolved to their real auth.users.email)
--      - Vendor Code (e.g. SIYA-VND or SIYA-VND-101)
--   2. Adds `admin_reset_or_link_sub_vendor_login(p_vendor_id, p_new_password)`
--      so Admin can reset password OR activate/link a Sub-Vendor login account
--      even if `auth_user_id` was previously NULL.
--   3. Safely links any unlinked sub_vendors.auth_user_id where an auth.users
--      account already exists with matching email.
--   4. Hardens `admin_create_sub_vendor` so email confirmation & mobile normalization
--      work reliably on existing/new auth rows.
-- ==============================================================================

-- 1. Safely link existing sub_vendors missing auth_user_id if matching auth.users row exists
DO $$
BEGIN
    UPDATE public.sub_vendors sv
    SET auth_user_id = au.id
    FROM auth.users au
    WHERE sv.auth_user_id IS NULL
      AND LOWER(TRIM(au.email)) = LOWER(
          COALESCE(
              NULLIF(TRIM(sv.email), ''),
              REGEXP_REPLACE(COALESCE(sv.mobile, ''), '[^0-9]', '', 'g') || '@vendor.siyasolar.com'
          )
      );
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Backfill auth_user_id notice: %', SQLERRM;
END $$;

-- 1b. Harden existing linked Sub-Vendor auth.users rows against GoTrue NULL token errors
DO $$
DECLARE
    v_rec RECORD;
BEGIN
    UPDATE auth.users au
    SET email_confirmed_at = COALESCE(au.email_confirmed_at, NOW()),
        confirmation_token = COALESCE(au.confirmation_token, ''),
        recovery_token = COALESCE(au.recovery_token, ''),
        email_change_token_new = COALESCE(au.email_change_token_new, ''),
        email_change = COALESCE(au.email_change, ''),
        phone_change = COALESCE(au.phone_change, ''),
        phone_change_token = COALESCE(au.phone_change_token, ''),
        email_change_token_current = COALESCE(au.email_change_token_current, ''),
        reauthentication_token = COALESCE(au.reauthentication_token, ''),
        is_sso_user = COALESCE(au.is_sso_user, false),
        is_anonymous = COALESCE(au.is_anonymous, false),
        updated_at = NOW()
    FROM public.sub_vendors sv
    WHERE sv.auth_user_id = au.id;

    FOR v_rec IN
        SELECT sv.auth_user_id, COALESCE(NULLIF(LOWER(TRIM(au.email)), ''), LOWER(TRIM(sv.email))) AS login_email
        FROM public.sub_vendors sv
        JOIN auth.users au ON au.id = sv.auth_user_id
    LOOP
        IF NOT EXISTS (
            SELECT 1 FROM auth.identities ai
            WHERE ai.user_id = v_rec.auth_user_id AND ai.provider = 'email'
        ) THEN
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
                v_rec.auth_user_id,
                v_rec.auth_user_id::text,
                jsonb_build_object('sub', v_rec.auth_user_id::text, 'email', v_rec.login_email, 'email_verified', true, 'phone_verified', false),
                'email',
                NOW(),
                NOW(),
                NOW()
            );
        END IF;
    END LOOP;
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Backfill sub-vendor auth token/identity notice: %', SQLERRM;
END $$;

-- 2. Unauthenticated-safe Login Email Resolver (Email / Mobile / Vendor Code -> auth email)
DROP FUNCTION IF EXISTS public.resolve_login_email(TEXT);
CREATE OR REPLACE FUNCTION public.resolve_login_email(
    p_identifier TEXT
)
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
STABLE
AS $$
DECLARE
    v_clean TEXT;
    v_alpha TEXT;
    v_digits TEXT;
    v_resolved_email TEXT;
BEGIN
    v_clean := TRIM(COALESCE(p_identifier, ''));
    IF v_clean = '' THEN
        RETURN NULL;
    END IF;

    -- Already an email address
    IF POSITION('@' IN v_clean) > 0 THEN
        RETURN LOWER(v_clean);
    END IF;

    v_alpha := REGEXP_REPLACE(UPPER(v_clean), '[^A-Z0-9]', '', 'g');
    v_digits := REGEXP_REPLACE(v_clean, '[^0-9]', '', 'g');

    -- Priority 1: Match Sub-Vendor by Vendor Code or Mobile Number
    SELECT COALESCE(
        NULLIF(LOWER(TRIM(au.email)), ''),
        NULLIF(LOWER(TRIM(sv.email)), ''),
        LOWER(REGEXP_REPLACE(COALESCE(sv.mobile, ''), '[^0-9a-zA-Z]', '', 'g')) || '@vendor.siyasolar.com'
    )
    INTO v_resolved_email
    FROM public.sub_vendors sv
    LEFT JOIN auth.users au ON au.id = sv.auth_user_id
    WHERE UPPER(TRIM(COALESCE(sv.vendor_code, ''))) = UPPER(v_clean)
       OR (v_alpha <> '' AND REGEXP_REPLACE(UPPER(COALESCE(sv.vendor_code, '')), '[^A-Z0-9]', '', 'g') = v_alpha)
       OR (
           LENGTH(v_digits) >= 10
           AND RIGHT(REGEXP_REPLACE(COALESCE(sv.mobile, ''), '[^0-9]', '', 'g'), 10) = RIGHT(v_digits, 10)
       )
    ORDER BY sv.is_active DESC, sv.created_at DESC
    LIMIT 1;

    IF v_resolved_email IS NOT NULL AND TRIM(v_resolved_email) <> '' THEN
        RETURN LOWER(TRIM(v_resolved_email));
    END IF;

    -- Priority 2: Match Staff / Admin / Sub-Vendor profile by 10-digit mobile
    IF LENGTH(v_digits) >= 10 THEN
        SELECT COALESCE(
            NULLIF(LOWER(TRIM(au.email)), ''),
            NULLIF(LOWER(TRIM(p.email)), '')
        )
        INTO v_resolved_email
        FROM public.profiles p
        LEFT JOIN auth.users au ON au.id = p.id
        WHERE LENGTH(REGEXP_REPLACE(COALESCE(p.mobile, ''), '[^0-9]', '', 'g')) >= 10
          AND RIGHT(REGEXP_REPLACE(COALESCE(p.mobile, ''), '[^0-9]', '', 'g'), 10) = RIGHT(v_digits, 10)
        ORDER BY p.is_active DESC, p.created_at DESC
        LIMIT 1;

        IF v_resolved_email IS NOT NULL AND TRIM(v_resolved_email) <> '' THEN
            RETURN LOWER(TRIM(v_resolved_email));
        END IF;
    END IF;

    -- Standard fallback pattern
    IF LENGTH(v_digits) >= 10 THEN
        RETURN RIGHT(v_digits, 10) || '@vendor.siyasolar.com';
    END IF;

    RETURN LOWER(REGEXP_REPLACE(v_clean, '\s+', '', 'g')) || '@vendor.siyasolar.com';
END;
$$;

REVOKE ALL ON FUNCTION public.resolve_login_email(TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.resolve_login_email(TEXT) TO anon, authenticated, service_role;

-- 3. Admin RPC: Reset Password OR Create/Link Auth Account for Existing Sub-Vendor
DROP FUNCTION IF EXISTS public.admin_reset_or_link_sub_vendor_login(UUID, TEXT);
CREATE OR REPLACE FUNCTION public.admin_reset_or_link_sub_vendor_login(
    p_vendor_id UUID,
    p_new_password TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, extensions
AS $$
DECLARE
    v_caller_role TEXT;
    v_caller_active BOOLEAN;
    v_vendor RECORD;
    v_clean_mobile TEXT;
    v_login_email TEXT;
    v_auth_uid UUID;
BEGIN
    SELECT role::TEXT, is_active INTO v_caller_role, v_caller_active
    FROM public.profiles
    WHERE id = auth.uid();

    IF LOWER(COALESCE(v_caller_role, '')) NOT IN ('admin', 'super_admin') OR COALESCE(v_caller_active, false) <> true THEN
        RAISE EXCEPTION 'Unauthorized: Only active administrators can manage sub-vendor logins.';
    END IF;

    IF LENGTH(TRIM(COALESCE(p_new_password, ''))) < 6 THEN
        RAISE EXCEPTION 'Password must be at least 6 characters long.';
    END IF;

    SELECT * INTO v_vendor
    FROM public.sub_vendors
    WHERE id = p_vendor_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Sub-Vendor record not found.';
    END IF;

    v_clean_mobile := REGEXP_REPLACE(COALESCE(v_vendor.mobile, ''), '[^0-9]', '', 'g');
    IF LENGTH(v_clean_mobile) > 10 THEN
        v_clean_mobile := RIGHT(v_clean_mobile, 10);
    END IF;
    IF v_clean_mobile = '' THEN
        v_clean_mobile := TRIM(COALESCE(v_vendor.mobile, ''));
    END IF;

    v_login_email := LOWER(COALESCE(
        NULLIF(TRIM(v_vendor.email), ''),
        v_clean_mobile || '@vendor.siyasolar.com'
    ));

    -- Check linked auth user first
    IF v_vendor.auth_user_id IS NOT NULL THEN
        SELECT id, LOWER(email) INTO v_auth_uid, v_login_email
        FROM auth.users
        WHERE id = v_vendor.auth_user_id;
    END IF;

    -- Fallback: lookup by email if auth_user_id was null or dangling
    IF v_auth_uid IS NULL THEN
        SELECT id INTO v_auth_uid
        FROM auth.users
        WHERE LOWER(email) = v_login_email
        LIMIT 1;
    END IF;

    IF v_auth_uid IS NULL THEN
        v_auth_uid := gen_random_uuid();

        INSERT INTO auth.users (
            instance_id,
            id,
            aud,
            role,
            email,
            encrypted_password,
            email_confirmed_at,
            raw_app_meta_data,
            raw_user_meta_data,
            created_at,
            updated_at,
            confirmation_token,
            recovery_token,
            email_change_token_new,
            email_change,
            phone_change,
            phone_change_token,
            email_change_token_current,
            reauthentication_token,
            is_sso_user,
            is_anonymous
        ) VALUES (
            '00000000-0000-0000-0000-000000000000',
            v_auth_uid,
            'authenticated',
            'authenticated',
            v_login_email,
            extensions.crypt(TRIM(p_new_password), extensions.gen_salt('bf')),
            NOW(),
            jsonb_build_object('provider', 'email', 'providers', jsonb_build_array('email')),
            jsonb_build_object('full_name', TRIM(v_vendor.name), 'mobile', v_clean_mobile, 'role', 'sub_vendor'),
            NOW(),
            NOW(),
            '',
            '',
            '',
            '',
            '',
            '',
            '',
            '',
            false,
            false
        );
    ELSE
        UPDATE auth.users
        SET encrypted_password = extensions.crypt(TRIM(p_new_password), extensions.gen_salt('bf')),
            email_confirmed_at = COALESCE(email_confirmed_at, NOW()),
            confirmation_token = COALESCE(confirmation_token, ''),
            recovery_token = COALESCE(recovery_token, ''),
            email_change_token_new = COALESCE(email_change_token_new, ''),
            email_change = COALESCE(email_change, ''),
            phone_change = COALESCE(phone_change, ''),
            phone_change_token = COALESCE(phone_change_token, ''),
            email_change_token_current = COALESCE(email_change_token_current, ''),
            reauthentication_token = COALESCE(reauthentication_token, ''),
            is_sso_user = COALESCE(is_sso_user, false),
            is_anonymous = COALESCE(is_anonymous, false),
            raw_user_meta_data = COALESCE(raw_user_meta_data, '{}'::jsonb) || jsonb_build_object('full_name', TRIM(v_vendor.name), 'mobile', v_clean_mobile, 'role', 'sub_vendor'),
            updated_at = NOW()
        WHERE id = v_auth_uid;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM auth.identities ai
        WHERE ai.user_id = v_auth_uid AND ai.provider = 'email'
    ) THEN
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
            v_auth_uid,
            v_auth_uid::text,
            jsonb_build_object('sub', v_auth_uid::text, 'email', v_login_email, 'email_verified', true, 'phone_verified', false),
            'email',
            NOW(),
            NOW(),
            NOW()
        );
    END IF;

    -- Ensure profile row exists with sub_vendor role and active status matching vendor
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
        v_auth_uid,
        v_login_email,
        TRIM(v_vendor.name),
        'sub_vendor',
        v_clean_mobile,
        'Sub-Vendor Operations',
        COALESCE(v_vendor.status, 'Active'),
        COALESCE(v_vendor.is_active, true),
        jsonb_build_object('vendor_code', v_vendor.vendor_code),
        NOW(),
        NOW()
    )
    ON CONFLICT (id) DO UPDATE SET
        email = EXCLUDED.email,
        full_name = EXCLUDED.full_name,
        role = 'sub_vendor',
        mobile = EXCLUDED.mobile,
        status = COALESCE(v_vendor.status, 'Active'),
        is_active = COALESCE(v_vendor.is_active, true),
        permissions = COALESCE(public.profiles.permissions, '{}'::jsonb) || jsonb_build_object('vendor_code', v_vendor.vendor_code),
        updated_at = NOW();

    -- Link back onto sub_vendors
    UPDATE public.sub_vendors
    SET auth_user_id = v_auth_uid,
        email = COALESCE(NULLIF(TRIM(email), ''), v_login_email),
        updated_at = NOW(),
        updated_by = auth.uid()
    WHERE id = p_vendor_id;

    RETURN jsonb_build_object(
        'success', true,
        'vendor_id', p_vendor_id,
        'auth_user_id', v_auth_uid,
        'login_email', v_login_email,
        'mobile', v_clean_mobile,
        'vendor_code', v_vendor.vendor_code
    );
END;
$$;

REVOKE ALL ON FUNCTION public.admin_reset_or_link_sub_vendor_login(UUID, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_reset_or_link_sub_vendor_login(UUID, TEXT) TO authenticated, service_role;

-- 4. Harden `admin_create_sub_vendor` (super_admin/admin access, 10-digit mobile, GoTrue token defaults)
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
    SELECT role::TEXT, is_active INTO v_caller_role, v_caller_active
    FROM public.profiles
    WHERE id = auth.uid();

    IF LOWER(COALESCE(v_caller_role, '')) NOT IN ('admin', 'super_admin') OR COALESCE(v_caller_active, false) <> true THEN
        RAISE EXCEPTION 'Unauthorized: Only active administrators can create sub-vendors.';
    END IF;

    v_clean_mobile := REGEXP_REPLACE(COALESCE(p_mobile, ''), '[^0-9]', '', 'g');
    IF LENGTH(v_clean_mobile) > 10 THEN
        v_clean_mobile := RIGHT(v_clean_mobile, 10);
    END IF;
    IF LENGTH(v_clean_mobile) < 10 THEN
        RAISE EXCEPTION 'Mobile number must be at least 10 digits.';
    END IF;

    IF LENGTH(TRIM(COALESCE(p_password, ''))) < 6 THEN
        RAISE EXCEPTION 'Password must be at least 6 characters.';
    END IF;

    IF p_email IS NOT NULL AND TRIM(p_email) <> '' THEN
        v_clean_email := LOWER(TRIM(p_email));
    ELSE
        v_clean_email := v_clean_mobile || '@vendor.siyasolar.com';
    END IF;

    IF p_vendor_code IS NOT NULL AND TRIM(p_vendor_code) <> '' THEN
        v_code := UPPER(TRIM(p_vendor_code));
    ELSE
        v_code := public.generate_sub_vendor_code();
    END IF;

    IF EXISTS (SELECT 1 FROM public.sub_vendors WHERE UPPER(vendor_code) = v_code) THEN
        RAISE EXCEPTION 'Vendor code "%" is already in use.', v_code;
    END IF;

    IF EXISTS (
        SELECT 1 FROM public.sub_vendors
        WHERE RIGHT(REGEXP_REPLACE(COALESCE(mobile, ''), '[^0-9]', '', 'g'), 10) = v_clean_mobile
    ) THEN
        RAISE EXCEPTION 'Vendor with mobile "%" already exists.', v_clean_mobile;
    END IF;

    SELECT id INTO v_new_user_id
    FROM auth.users
    WHERE LOWER(email) = v_clean_email
    LIMIT 1;

    IF v_new_user_id IS NULL THEN
        v_new_user_id := gen_random_uuid();

        INSERT INTO auth.users (
            instance_id,
            id,
            aud,
            role,
            email,
            encrypted_password,
            email_confirmed_at,
            raw_app_meta_data,
            raw_user_meta_data,
            created_at,
            updated_at,
            confirmation_token,
            recovery_token,
            email_change_token_new,
            email_change,
            phone_change,
            phone_change_token,
            email_change_token_current,
            reauthentication_token,
            is_sso_user,
            is_anonymous
        ) VALUES (
            '00000000-0000-0000-0000-000000000000',
            v_new_user_id,
            'authenticated',
            'authenticated',
            v_clean_email,
            extensions.crypt(TRIM(p_password), extensions.gen_salt('bf')),
            NOW(),
            jsonb_build_object('provider', 'email', 'providers', jsonb_build_array('email')),
            jsonb_build_object('full_name', TRIM(p_name), 'mobile', v_clean_mobile, 'role', 'sub_vendor'),
            NOW(),
            NOW(),
            '',
            '',
            '',
            '',
            '',
            '',
            '',
            '',
            false,
            false
        );
    ELSE
        UPDATE auth.users
        SET encrypted_password = extensions.crypt(TRIM(p_password), extensions.gen_salt('bf')),
            email_confirmed_at = COALESCE(email_confirmed_at, NOW()),
            confirmation_token = COALESCE(confirmation_token, ''),
            recovery_token = COALESCE(recovery_token, ''),
            email_change_token_new = COALESCE(email_change_token_new, ''),
            email_change = COALESCE(email_change, ''),
            phone_change = COALESCE(phone_change, ''),
            phone_change_token = COALESCE(phone_change_token, ''),
            email_change_token_current = COALESCE(email_change_token_current, ''),
            reauthentication_token = COALESCE(reauthentication_token, ''),
            is_sso_user = COALESCE(is_sso_user, false),
            is_anonymous = COALESCE(is_anonymous, false),
            raw_user_meta_data = COALESCE(raw_user_meta_data, '{}'::jsonb) || jsonb_build_object('full_name', TRIM(p_name), 'mobile', v_clean_mobile, 'role', 'sub_vendor'),
            updated_at = NOW()
        WHERE id = v_new_user_id;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM auth.identities ai
        WHERE ai.user_id = v_new_user_id AND ai.provider = 'email'
    ) THEN
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
        );
    END IF;

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
        email = EXCLUDED.email,
        full_name = EXCLUDED.full_name,
        role = 'sub_vendor',
        mobile = EXCLUDED.mobile,
        is_active = true,
        status = 'Active',
        permissions = COALESCE(public.profiles.permissions, '{}'::jsonb) || jsonb_build_object('vendor_code', v_code),
        updated_at = NOW();

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

REVOKE ALL ON FUNCTION public.admin_create_sub_vendor(
    TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, NUMERIC, TEXT
) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_create_sub_vendor(
    TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, NUMERIC, TEXT
) TO authenticated, service_role;

NOTIFY pgrst, 'reload schema';
