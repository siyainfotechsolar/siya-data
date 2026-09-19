-- Migration 27: Admin Create Staff User RPC
-- Enables administrators to provision staff accounts directly with pre-confirmed email
-- and encrypted password without requiring public GoTrue email verification (which fails
-- on custom/internal domains lacking public DNS MX records like @siyasolar.com).

CREATE OR REPLACE FUNCTION public.admin_create_staff_user(
  p_email text,
  p_password text,
  p_full_name text,
  p_mobile text,
  p_role text DEFAULT 'staff',
  p_employee_id text DEFAULT NULL,
  p_department text DEFAULT NULL,
  p_status text DEFAULT 'Active',
  p_permissions jsonb DEFAULT '{}'::jsonb,
  p_remarks text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, extensions
AS $$
DECLARE
  v_new_id uuid;
  v_caller_role text;
  v_caller_is_active boolean;
  v_clean_email text;
  v_legacy_role public.app_role;
BEGIN
  -- 1. Authorization check: Only active admins can create staff users
  SELECT role, is_active INTO v_caller_role, v_caller_is_active
  FROM public.profiles
  WHERE id = auth.uid();

  IF v_caller_role != 'admin' OR v_caller_is_active != true THEN
    RAISE EXCEPTION 'Unauthorized: Only active administrators can create staff users.';
  END IF;

  v_clean_email := LOWER(TRIM(p_email));

  -- Validate email format (basic syntax)
  IF v_clean_email NOT LIKE '%_@__%.__%' THEN
    RAISE EXCEPTION 'Invalid email address format: %', p_email;
  END IF;

  -- Validate password length
  IF LENGTH(p_password) < 6 THEN
    RAISE EXCEPTION 'Password must be at least 6 characters long.';
  END IF;

  -- Check if email already exists in auth.users
  IF EXISTS (SELECT 1 FROM auth.users WHERE LOWER(email) = v_clean_email) THEN
    RAISE EXCEPTION 'A user with email "%" already exists.', v_clean_email;
  END IF;

  -- Resolve legacy role for handle_new_user compatibility
  IF p_role IN ('admin', 'super_admin', 'owner') THEN
    v_legacy_role := 'admin'::public.app_role;
  ELSE
    v_legacy_role := 'staff'::public.app_role;
  END IF;

  v_new_id := gen_random_uuid();

  -- 2. Insert into auth.users with pre-confirmed email & encrypted bcrypt password
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
    v_new_id,
    'authenticated',
    'authenticated',
    v_clean_email,
    extensions.crypt(p_password, extensions.gen_salt('bf')),
    NOW(),
    NOW(),
    jsonb_build_object('provider', 'email', 'providers', jsonb_build_array('email')),
    jsonb_build_object('full_name', TRIM(p_full_name), 'mobile', TRIM(p_mobile), 'role', v_legacy_role),
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

  -- 2b. Insert identity into auth.identities so GoTrue authentication succeeds
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
    v_new_id,
    v_new_id::text,
    jsonb_build_object('sub', v_new_id::text, 'email', v_clean_email, 'email_verified', true, 'phone_verified', false),
    'email',
    NOW(),
    NOW(),
    NOW()
  ) ON CONFLICT (provider, provider_id) DO NOTHING;

  -- 3. Upsert into public.profiles
  INSERT INTO public.profiles (
    id,
    email,
    full_name,
    role,
    mobile,
    employee_id,
    department,
    status,
    is_active,
    can_delete,
    permissions,
    remarks,
    created_at,
    updated_at
  ) VALUES (
    v_new_id,
    v_clean_email,
    TRIM(p_full_name),
    p_role,
    TRIM(p_mobile),
    NULLIF(TRIM(p_employee_id), ''),
    NULLIF(TRIM(p_department), ''),
    p_status,
    (p_status = 'Active'),
    (p_role IN ('admin', 'super_admin', 'owner')),
    COALESCE(p_permissions, '{}'::jsonb),
    NULLIF(TRIM(p_remarks), ''),
    NOW(),
    NOW()
  )
  ON CONFLICT (id) DO UPDATE SET
    email = EXCLUDED.email,
    full_name = EXCLUDED.full_name,
    role = EXCLUDED.role,
    mobile = EXCLUDED.mobile,
    employee_id = EXCLUDED.employee_id,
    department = EXCLUDED.department,
    status = EXCLUDED.status,
    is_active = EXCLUDED.is_active,
    can_delete = EXCLUDED.can_delete,
    permissions = EXCLUDED.permissions,
    remarks = EXCLUDED.remarks,
    updated_at = NOW();

  RETURN v_new_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_set_user_password(
  p_target_user_id uuid,
  p_new_password text
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, extensions
AS $$
DECLARE
  v_caller_role text;
  v_caller_is_active boolean;
BEGIN
  SELECT role, is_active INTO v_caller_role, v_caller_is_active
  FROM public.profiles
  WHERE id = auth.uid();

  IF v_caller_role != 'admin' OR v_caller_is_active != true THEN
    RAISE EXCEPTION 'Unauthorized: Only active administrators can reset passwords.';
  END IF;

  IF LENGTH(p_new_password) < 6 THEN
    RAISE EXCEPTION 'Password must be at least 6 characters long.';
  END IF;

  UPDATE auth.users
  SET encrypted_password = extensions.crypt(p_new_password, extensions.gen_salt('bf')),
      updated_at = NOW()
  WHERE id = p_target_user_id;

  RETURN true;
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_create_staff_user TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_set_user_password TO authenticated;
