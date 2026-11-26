-- ==============================================================================
-- Migration: 20261126000050_sub_vendor_unified_ledger_complete_sync.sql
-- Module: Sub-Vendor Central Database Unified Sync & RLS Security Hardening
-- Description:
--   1. Fixes v_sub_vendor_unified_ledger VIEW (which previously omitted
--      vendor_material_transactions, customer_payment_transactions, and
--      vendor_site_assignments / consumer_records collection residuals) so EVERY
--      material dispatch, site material issue/return, bank loan credit, customer
--      CRM payment, vendor payout, and manual ledger entry appears in one
--      central chronological ledger without duplicates.
--   2. Uses WITH (security_invoker = true) on views so underlying RLS applies.
--   3. Tightens permissive SELECT RLS policies on sub_vendor_account_ledger and
--      sub_vendor_material_outwards* so sub_vendor users can ONLY read their own
--      vendor records while Admin & non-sub-vendor staff keep full visibility.
--   4. Updates get_vendor_account_summary() and v_sub_vendor_audit_check.
--   5. Adds central reconciliation RPC get_sub_vendor_central_reconciliation().
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- 1. ENSURE PREREQUISITE SELF-DESCRIBING COLUMNS (Safe / Idempotent if 0049 ran)
-- ------------------------------------------------------------------------------
ALTER TABLE public.vendor_payouts
    ADD COLUMN IF NOT EXISTS vendor_name TEXT,
    ADD COLUMN IF NOT EXISTS customer_name TEXT;

UPDATE public.vendor_payouts vp
SET vendor_name = COALESCE(sv.name, 'Sub-Vendor')
FROM public.sub_vendors sv
WHERE vp.vendor_id = sv.id
  AND (vp.vendor_name IS NULL OR TRIM(vp.vendor_name) = '');

ALTER TABLE public.vendor_customer_payments
    ADD COLUMN IF NOT EXISTS vendor_name TEXT,
    ADD COLUMN IF NOT EXISTS customer_name TEXT,
    ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now());

UPDATE public.vendor_customer_payments cp
SET
    vendor_name = COALESCE(cp.vendor_name, sv.name, 'Sub-Vendor'),
    customer_name = COALESCE(cp.customer_name, cr.name, 'Customer')
FROM public.sub_vendors sv, public.consumer_records cr
WHERE cp.vendor_id = sv.id
  AND cp.customer_id = cr.id
  AND (cp.vendor_name IS NULL OR cp.customer_name IS NULL);

-- ------------------------------------------------------------------------------
-- 2. TIGHTEN RLS ON LEDGER & OUTWARD TABLES (ISOLATE SUB-VENDORS BY vendor_id)
-- ------------------------------------------------------------------------------
DROP POLICY IF EXISTS "Staff can read sub_vendor_account_ledger" ON public.sub_vendor_account_ledger;
CREATE POLICY "Staff and own sub-vendor can read sub_vendor_account_ledger"
    ON public.sub_vendor_account_ledger
    FOR SELECT
    TO authenticated
    USING (
        (SELECT public.is_admin())
        OR ((SELECT public.is_active_user()) AND NOT (SELECT public.is_sub_vendor()))
        OR vendor_id = (SELECT public.get_sub_vendor_id())
    );

DROP POLICY IF EXISTS "Staff can read sub_vendor_material_outwards" ON public.sub_vendor_material_outwards;
CREATE POLICY "Staff and own sub-vendor can read sub_vendor_material_outwards"
    ON public.sub_vendor_material_outwards
    FOR SELECT
    TO authenticated
    USING (
        (SELECT public.is_admin())
        OR ((SELECT public.is_active_user()) AND NOT (SELECT public.is_sub_vendor()))
        OR vendor_id = (SELECT public.get_sub_vendor_id())
    );

DROP POLICY IF EXISTS "Staff can read sub_vendor_material_outward_items" ON public.sub_vendor_material_outward_items;
CREATE POLICY "Staff and own sub-vendor can read sub_vendor_material_outward_items"
    ON public.sub_vendor_material_outward_items
    FOR SELECT
    TO authenticated
    USING (
        (SELECT public.is_admin())
        OR ((SELECT public.is_active_user()) AND NOT (SELECT public.is_sub_vendor()))
        OR outward_id IN (
            SELECT id FROM public.sub_vendor_material_outwards
            WHERE vendor_id = (SELECT public.get_sub_vendor_id())
        )
    );

DROP POLICY IF EXISTS "Staff can read sub_vendor_material_outward_audit" ON public.sub_vendor_material_outward_audit;
CREATE POLICY "Staff and own sub-vendor can read sub_vendor_material_outward_audit"
    ON public.sub_vendor_material_outward_audit
    FOR SELECT
    TO authenticated
    USING (
        (SELECT public.is_admin())
        OR ((SELECT public.is_active_user()) AND NOT (SELECT public.is_sub_vendor()))
        OR outward_id IN (
            SELECT id FROM public.sub_vendor_material_outwards
            WHERE vendor_id = (SELECT public.get_sub_vendor_id())
        )
    );

-- ------------------------------------------------------------------------------
-- 3. HELPFUL INDEXES FOR CENTRAL UNIFIED LEDGER PERFORMANCE
-- ------------------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_vmt_vendor_date ON public.vendor_material_transactions (vendor_id, transaction_date DESC);
CREATE INDEX IF NOT EXISTS idx_cpt_customer_status ON public.customer_payment_transactions (customer_id, status);
CREATE INDEX IF NOT EXISTS idx_vcp_assignment_status ON public.vendor_customer_payments (assignment_id, status);

-- ------------------------------------------------------------------------------
-- 4. RECREATE CENTRAL UNIFIED LEDGER VIEW (ALL 7 SOURCES, ZERO DUPLICATES)
-- ------------------------------------------------------------------------------
DROP VIEW IF EXISTS public.v_sub_vendor_unified_ledger CASCADE;

CREATE VIEW public.v_sub_vendor_unified_ledger
WITH (security_invoker = true) AS

-- Branch 1: Direct / Synced entries in sub_vendor_account_ledger
SELECT
    'ledger'::TEXT                              AS source_table,
    l.id::TEXT                                  AS id,
    l.vendor_id::TEXT                           AS vendor_id,
    l.vendor_name                               AS vendor_name,
    l.transaction_date                          AS transaction_date,
    l.transaction_type                          AS transaction_type,
    l.category                                  AS category,
    l.credit_amount::NUMERIC(14, 2)             AS credit_amount,
    l.debit_amount::NUMERIC(14, 2)              AS debit_amount,
    l.running_balance::NUMERIC(14, 2)           AS running_balance,
    l.reference_number                          AS reference_number,
    l.reference_id::TEXT                        AS reference_id,
    l.payment_mode                              AS payment_mode,
    l.particulars                               AS particulars,
    l.remarks                                   AS remarks,
    l.status                                    AS status,
    l.created_at                                AS created_at
FROM public.sub_vendor_account_ledger l

UNION ALL

-- Branch 2: Active Material Outward Dispatches not already mirrored in ledger
SELECT
    'material_outward'::TEXT                    AS source_table,
    'mo_' || mo.id::TEXT                        AS id,
    mo.vendor_id::TEXT                          AS vendor_id,
    mo.vendor_name                              AS vendor_name,
    mo.outward_date                             AS transaction_date,
    'MATERIAL_OUTWARD'::TEXT                    AS transaction_type,
    'MATERIAL'::TEXT                            AS category,
    COALESCE(mo.total_value, 0.00)::NUMERIC(14, 2) AS credit_amount,
    0.00::NUMERIC(14, 2)                        AS debit_amount,
    0.00::NUMERIC(14, 2)                        AS running_balance,
    mo.outward_number                           AS reference_number,
    mo.id::TEXT                                 AS reference_id,
    'Inventory'::TEXT                           AS payment_mode,
    'Material Outward Dispatch (' || mo.total_items || ' items, Qty: ' || mo.total_quantity || ')' AS particulars,
    mo.remarks                                  AS remarks,
    mo.status                                   AS status,
    mo.created_at                               AS created_at
FROM public.sub_vendor_material_outwards mo
WHERE mo.status = 'Active'
  AND NOT EXISTS (
      SELECT 1 FROM public.sub_vendor_account_ledger l2
      WHERE l2.reference_id = mo.id AND l2.status = 'Active'
  )

UNION ALL

-- Branch 3: Site-wise Material Issues & Returns from vendor_material_transactions
SELECT
    'vendor_material_transaction'::TEXT         AS source_table,
    'vmt_' || vmt.id::TEXT                      AS id,
    vmt.vendor_id::TEXT                         AS vendor_id,
    COALESCE(sv.name, 'Sub-Vendor')             AS vendor_name,
    vmt.transaction_date                        AS transaction_date,
    CASE
        WHEN UPPER(COALESCE(vmt.transaction_type, 'ISSUE')) = 'RETURN' THEN 'MATERIAL_PAYMENT'
        ELSE 'MATERIAL_OUTWARD'
    END                                         AS transaction_type,
    'MATERIAL'::TEXT                            AS category,
    CASE
        WHEN UPPER(COALESCE(vmt.transaction_type, 'ISSUE')) = 'RETURN' THEN 0.00
        ELSE COALESCE(vmt.total_amount, 0.00)
    END::NUMERIC(14, 2)                         AS credit_amount,
    CASE
        WHEN UPPER(COALESCE(vmt.transaction_type, 'ISSUE')) = 'RETURN' THEN COALESCE(vmt.total_amount, 0.00)
        ELSE 0.00
    END::NUMERIC(14, 2)                         AS debit_amount,
    0.00::NUMERIC(14, 2)                        AS running_balance,
    COALESCE(
        NULLIF(TRIM(vmt.challan_number), ''),
        cr.consumer_no,
        'SITE-' || LEFT(vmt.assignment_id::TEXT, 8)
    )                                           AS reference_number,
    vmt.id::TEXT                                AS reference_id,
    'Inventory'::TEXT                           AS payment_mode,
    CASE
        WHEN UPPER(COALESCE(vmt.transaction_type, 'ISSUE')) = 'RETURN' THEN 'Site Material Return: '
        ELSE 'Site Material Given: '
    END || vmt.item_name || ' (' || vmt.quantity || ' ' || COALESCE(vmt.unit, 'Nos') ||
    CASE WHEN cr.name IS NOT NULL THEN ' | ' || cr.name ELSE '' END || ')' AS particulars,
    vmt.remarks                                 AS remarks,
    'Active'::TEXT                              AS status,
    vmt.created_at                              AS created_at
FROM public.vendor_material_transactions vmt
JOIN public.sub_vendors sv ON sv.id = vmt.vendor_id
LEFT JOIN public.consumer_records cr ON cr.id = vmt.customer_id
WHERE COALESCE(vmt.total_amount, 0.00) > 0
  AND NOT EXISTS (
      SELECT 1 FROM public.sub_vendor_account_ledger l_vmt
      WHERE l_vmt.reference_id = vmt.id AND l_vmt.status = 'Active'
  )

UNION ALL

-- Branch 4: Approved Customer Cash & Bank Loan Credits in vendor_customer_payments
SELECT
    'customer_payment'::TEXT                    AS source_table,
    'cp_' || cp.id::TEXT                        AS id,
    cp.vendor_id::TEXT                          AS vendor_id,
    COALESCE(cp.vendor_name, sv.name, 'Sub-Vendor') AS vendor_name,
    cp.payment_date                             AS transaction_date,
    'MATERIAL_PAYMENT'::TEXT                    AS transaction_type,
    'MATERIAL'::TEXT                            AS category,
    0.00::NUMERIC(14, 2)                        AS credit_amount,
    cp.amount::NUMERIC(14, 2)                   AS debit_amount,
    0.00::NUMERIC(14, 2)                        AS running_balance,
    COALESCE(
        NULLIF(TRIM(cp.reference_number), ''),
        NULLIF(TRIM(cp.loan_application_id), ''),
        cr.consumer_no,
        '-'
    )                                           AS reference_number,
    cp.id::TEXT                                 AS reference_id,
    CASE
        WHEN cp.payment_mode IN ('Bank Transfer', 'NEFT/RTGS', 'UPI', 'Cheque', 'Cash', 'Inventory')
        THEN cp.payment_mode
        ELSE 'Bank Transfer'
    END                                         AS payment_mode,
    CASE
        WHEN cp.payment_type = 'BANK_LOAN'
            THEN 'Bank Loan Credited (' || COALESCE(NULLIF(TRIM(cp.bank_name), ''), 'Bank') ||
                 COALESCE(' - ' || COALESCE(cp.customer_name, cr.name), '') || ')'
        ELSE 'Customer Cash / Payment Received (' || COALESCE(cp.payment_stage, 'Payment') ||
             COALESCE(' - ' || COALESCE(cp.customer_name, cr.name), '') || ')'
    END                                         AS particulars,
    cp.remarks                                  AS remarks,
    'Active'::TEXT                              AS status,
    cp.created_at                               AS created_at
FROM public.vendor_customer_payments cp
JOIN public.sub_vendors sv ON sv.id = cp.vendor_id
LEFT JOIN public.consumer_records cr ON cr.id = cp.customer_id
WHERE cp.status = 'Approved'
  AND NOT EXISTS (
      SELECT 1 FROM public.sub_vendor_account_ledger l3
      WHERE l3.reference_id = cp.id AND l3.status = 'Active'
  )

UNION ALL

-- Branch 5: Valid Main CRM Customer / Loan Payments for assigned sites
--           (skipped only when an equivalent vendor_customer_payments row exists)
SELECT
    'crm_customer_payment'::TEXT                AS source_table,
    'cpt_' || cpt.id::TEXT || '_' || LEFT(vsa.id::TEXT, 8) AS id,
    vsa.vendor_id::TEXT                         AS vendor_id,
    COALESCE(sv.name, 'Sub-Vendor')             AS vendor_name,
    cpt.payment_date                            AS transaction_date,
    'MATERIAL_PAYMENT'::TEXT                    AS transaction_type,
    'MATERIAL'::TEXT                            AS category,
    0.00::NUMERIC(14, 2)                        AS credit_amount,
    cpt.amount::NUMERIC(14, 2)                  AS debit_amount,
    0.00::NUMERIC(14, 2)                        AS running_balance,
    COALESCE(NULLIF(TRIM(cpt.reference_number), ''), cr.consumer_no, cpt.consumer_no, '-') AS reference_number,
    cpt.id::TEXT                                AS reference_id,
    CASE
        WHEN cpt.payment_mode IN ('Bank Transfer', 'NEFT/RTGS', 'UPI', 'Cheque', 'Cash', 'Inventory')
        THEN cpt.payment_mode
        ELSE 'Bank Transfer'
    END                                         AS payment_mode,
    CASE
        WHEN LOWER(COALESCE(cpt.remarks, '') || ' ' || COALESCE(cpt.payment_type, '')) LIKE '%loan%'
            THEN 'Bank Loan / Finance Credited (' || COALESCE(cpt.payment_type, 'Loan') ||
                 CASE WHEN cr.name IS NOT NULL THEN ' - ' || cr.name ELSE '' END || ')'
        ELSE 'Customer Payment Received (' || COALESCE(cpt.payment_type, 'Payment') ||
             CASE WHEN cr.name IS NOT NULL THEN ' - ' || cr.name ELSE '' END || ')'
    END                                         AS particulars,
    cpt.remarks                                 AS remarks,
    'Active'::TEXT                              AS status,
    cpt.created_at                              AS created_at
FROM public.customer_payment_transactions cpt
JOIN public.vendor_site_assignments vsa ON vsa.customer_id = cpt.customer_id
JOIN public.sub_vendors sv ON sv.id = vsa.vendor_id
LEFT JOIN public.consumer_records cr ON cr.id = cpt.customer_id
WHERE vsa.status <> 'Cancelled'
  AND cpt.status = 'Valid'
  AND COALESCE(cpt.deleted, false) = false
  AND COALESCE(cpt.verification_status, 'Pending') NOT IN ('Rejected', 'Void')
  AND NOT EXISTS (
      SELECT 1 FROM public.sub_vendor_account_ledger l_cpt
      WHERE l_cpt.reference_id = cpt.id AND l_cpt.status = 'Active'
  )
  AND NOT EXISTS (
      SELECT 1 FROM public.vendor_customer_payments cp_dup
      WHERE cp_dup.assignment_id = vsa.id
        AND cp_dup.status = 'Approved'
        AND (
            (NULLIF(TRIM(cp_dup.reference_number), '') IS NOT NULL
             AND NULLIF(TRIM(cpt.reference_number), '') IS NOT NULL
             AND UPPER(TRIM(cp_dup.reference_number)) = UPPER(TRIM(cpt.reference_number)))
            OR (cp_dup.amount = cpt.amount AND ABS(cp_dup.payment_date - cpt.payment_date) <= 1)
        )
  )

UNION ALL

-- Branch 6: Assignment / Consumer Paid Residual Fallback (captures direct DB
--           or legacy Loan/Customer receipts when item rows are absent)
SELECT
    'assignment_collection'::TEXT               AS source_table,
    'a_coll_' || vsa.id::TEXT                   AS id,
    vsa.vendor_id::TEXT                         AS vendor_id,
    COALESCE(sv.name, 'Sub-Vendor')             AS vendor_name,
    vsa.assigned_date                           AS transaction_date,
    'MATERIAL_PAYMENT'::TEXT                    AS transaction_type,
    'MATERIAL'::TEXT                            AS category,
    0.00::NUMERIC(14, 2)                        AS credit_amount,
    ROUND((
        GREATEST(COALESCE(vsa.total_customer_received, 0.00), COALESCE(cr.paid_amount, 0.00))
        - COALESCE((
            SELECT SUM(cp2.amount)
            FROM public.vendor_customer_payments cp2
            WHERE cp2.assignment_id = vsa.id AND cp2.status = 'Approved'
        ), 0.00)
        - COALESCE((
            SELECT SUM(cpt2.amount)
            FROM public.customer_payment_transactions cpt2
            WHERE cpt2.customer_id = vsa.customer_id
              AND cpt2.status = 'Valid'
              AND COALESCE(cpt2.deleted, false) = false
              AND COALESCE(cpt2.verification_status, 'Pending') NOT IN ('Rejected', 'Void')
              AND NOT EXISTS (
                  SELECT 1 FROM public.vendor_customer_payments cp_dup2
                  WHERE cp_dup2.assignment_id = vsa.id
                    AND cp_dup2.status = 'Approved'
                    AND (
                        (NULLIF(TRIM(cp_dup2.reference_number), '') IS NOT NULL
                         AND NULLIF(TRIM(cpt2.reference_number), '') IS NOT NULL
                         AND UPPER(TRIM(cp_dup2.reference_number)) = UPPER(TRIM(cpt2.reference_number)))
                        OR (cp_dup2.amount = cpt2.amount AND ABS(cp_dup2.payment_date - cpt2.payment_date) <= 1)
                    )
              )
        ), 0.00)
    )::NUMERIC, 2)                              AS debit_amount,
    0.00::NUMERIC(14, 2)                        AS running_balance,
    COALESCE(NULLIF(TRIM(vsa.loan_application_id), ''), cr.consumer_no, 'COLL-' || LEFT(vsa.id::TEXT, 8)) AS reference_number,
    vsa.id::TEXT                                AS reference_id,
    CASE WHEN COALESCE(vsa.total_loan_credited, 0.00) > 0 THEN 'Bank Transfer' ELSE 'Cash' END AS payment_mode,
    CASE
        WHEN COALESCE(vsa.total_loan_credited, 0.00) > 0
            THEN 'Site Loan & Customer Collection (' || COALESCE(cr.name, 'Site') || ' | Loan: Rs. ' || ROUND(vsa.total_loan_credited, 2) || ')'
        ELSE 'Site Customer Collection (' || COALESCE(cr.name, 'Site') || ')'
    END                                         AS particulars,
    'Auto-synced residual from Site Assignment / Consumer Paid Amount'::TEXT AS remarks,
    'Active'::TEXT                              AS status,
    vsa.created_at                              AS created_at
FROM public.vendor_site_assignments vsa
JOIN public.sub_vendors sv ON sv.id = vsa.vendor_id
LEFT JOIN public.consumer_records cr ON cr.id = vsa.customer_id
WHERE vsa.status <> 'Cancelled'
  AND NOT EXISTS (
      SELECT 1 FROM public.sub_vendor_account_ledger l_a
      WHERE l_a.reference_id = vsa.id AND l_a.status = 'Active'
  )
  AND (
      GREATEST(COALESCE(vsa.total_customer_received, 0.00), COALESCE(cr.paid_amount, 0.00))
      - COALESCE((
          SELECT SUM(cp2.amount)
          FROM public.vendor_customer_payments cp2
          WHERE cp2.assignment_id = vsa.id AND cp2.status = 'Approved'
      ), 0.00)
      - COALESCE((
          SELECT SUM(cpt2.amount)
          FROM public.customer_payment_transactions cpt2
          WHERE cpt2.customer_id = vsa.customer_id
            AND cpt2.status = 'Valid'
            AND COALESCE(cpt2.deleted, false) = false
            AND COALESCE(cpt2.verification_status, 'Pending') NOT IN ('Rejected', 'Void')
            AND NOT EXISTS (
                SELECT 1 FROM public.vendor_customer_payments cp_dup2
                WHERE cp_dup2.assignment_id = vsa.id
                  AND cp_dup2.status = 'Approved'
                  AND (
                      (NULLIF(TRIM(cp_dup2.reference_number), '') IS NOT NULL
                       AND NULLIF(TRIM(cpt2.reference_number), '') IS NOT NULL
                       AND UPPER(TRIM(cp_dup2.reference_number)) = UPPER(TRIM(cpt2.reference_number)))
                      OR (cp_dup2.amount = cpt2.amount AND ABS(cp_dup2.payment_date - cpt2.payment_date) <= 1)
                  )
            )
      ), 0.00)
  ) > 0.01

UNION ALL

-- Branch 7: Approved/Paid Vendor Payouts not already in sub_vendor_account_ledger
SELECT
    'vendor_payout'::TEXT                       AS source_table,
    'vp_' || vp.id::TEXT                        AS id,
    vp.vendor_id::TEXT                          AS vendor_id,
    COALESCE(vp.vendor_name, sv2.name, 'Sub-Vendor') AS vendor_name,
    vp.payout_date                              AS transaction_date,
    'ADVANCE_GIVEN'::TEXT                       AS transaction_type,
    'ADVANCE'::TEXT                             AS category,
    0.00::NUMERIC(14, 2)                        AS credit_amount,
    vp.amount::NUMERIC(14, 2)                   AS debit_amount,
    0.00::NUMERIC(14, 2)                        AS running_balance,
    COALESCE(NULLIF(TRIM(vp.reference_number), ''), '-') AS reference_number,
    vp.id::TEXT                                 AS reference_id,
    CASE
        WHEN vp.payment_mode IN ('Bank Transfer', 'NEFT/RTGS', 'UPI', 'Cheque', 'Cash', 'Inventory')
        THEN vp.payment_mode
        ELSE 'Bank Transfer'
    END                                         AS payment_mode,
    'Payout / Advance to Sub-Vendor'            AS particulars,
    vp.remarks                                  AS remarks,
    'Active'::TEXT                              AS status,
    vp.created_at                               AS created_at
FROM public.vendor_payouts vp
JOIN public.sub_vendors sv2 ON sv2.id = vp.vendor_id
WHERE vp.status IN ('Approved', 'Paid')
  AND NOT EXISTS (
      SELECT 1 FROM public.sub_vendor_account_ledger l4
      WHERE l4.reference_id = vp.id AND l4.status = 'Active'
  );

GRANT SELECT ON public.v_sub_vendor_unified_ledger TO authenticated, service_role;

-- ------------------------------------------------------------------------------
-- 5. UPDATE get_vendor_account_summary() RPC TO READ FROM UNIFIED LEDGER VIEW
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_vendor_account_summary(
    p_vendor_id UUID DEFAULT NULL
)
RETURNS TABLE (
    vendor_id               TEXT,
    vendor_name             TEXT,
    vendor_code             TEXT,
    total_credit            NUMERIC(14, 2),
    total_debit             NUMERIC(14, 2),
    net_balance             NUMERIC(14, 2),
    total_material_outward  NUMERIC(14, 2),
    total_material_payments NUMERIC(14, 2),
    total_advance_given     NUMERIC(14, 2),
    total_advance_refund    NUMERIC(14, 2),
    entry_count             BIGINT
)
LANGUAGE sql
STABLE
SECURITY INVOKER
AS $$
    SELECT
        sv.id::TEXT                                                             AS vendor_id,
        sv.name                                                                 AS vendor_name,
        sv.vendor_code                                                          AS vendor_code,
        COALESCE(SUM(CASE WHEN u.status = 'Active' THEN u.credit_amount ELSE 0 END), 0.00)::NUMERIC(14, 2) AS total_credit,
        COALESCE(SUM(CASE WHEN u.status = 'Active' THEN u.debit_amount  ELSE 0 END), 0.00)::NUMERIC(14, 2) AS total_debit,
        COALESCE(SUM(CASE WHEN u.status = 'Active' THEN u.credit_amount - u.debit_amount ELSE 0 END), 0.00)::NUMERIC(14, 2) AS net_balance,
        COALESCE(SUM(CASE WHEN u.status = 'Active' AND u.transaction_type = 'MATERIAL_OUTWARD' THEN u.credit_amount ELSE 0 END), 0.00)::NUMERIC(14, 2) AS total_material_outward,
        COALESCE(SUM(CASE WHEN u.status = 'Active' AND u.transaction_type = 'MATERIAL_PAYMENT' THEN u.debit_amount  ELSE 0 END), 0.00)::NUMERIC(14, 2) AS total_material_payments,
        COALESCE(SUM(CASE WHEN u.status = 'Active' AND u.transaction_type = 'ADVANCE_GIVEN'    THEN u.debit_amount  ELSE 0 END), 0.00)::NUMERIC(14, 2) AS total_advance_given,
        COALESCE(SUM(CASE WHEN u.status = 'Active' AND u.transaction_type = 'ADVANCE_REFUND'   THEN u.credit_amount ELSE 0 END), 0.00)::NUMERIC(14, 2) AS total_advance_refund,
        COUNT(u.id)                                                             AS entry_count
    FROM public.sub_vendors sv
    LEFT JOIN public.v_sub_vendor_unified_ledger u ON u.vendor_id = sv.id::TEXT
    WHERE (p_vendor_id IS NULL OR sv.id = p_vendor_id)
    GROUP BY sv.id, sv.name, sv.vendor_code
    ORDER BY sv.name;
$$;

GRANT EXECUTE ON FUNCTION public.get_vendor_account_summary(UUID) TO authenticated, service_role;

-- ------------------------------------------------------------------------------
-- 6. CENTRAL RECONCILIATION RPC (RECONCILES FINANCIAL SUMMARY & ACCOUNT LEDGER)
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_sub_vendor_central_reconciliation(
    p_vendor_id UUID DEFAULT NULL
)
RETURNS TABLE (
    vendor_id                       TEXT,
    vendor_name                     TEXT,
    vendor_code                     TEXT,
    site_count                      BIGINT,
    total_site_quotation            NUMERIC(14, 2),
    total_customer_collection       NUMERIC(14, 2),
    total_loan_credited             NUMERIC(14, 2),
    total_site_material_cost        NUMERIC(14, 2),
    total_unallocated_outward_cost  NUMERIC(14, 2),
    total_direct_vendor_payments    NUMERIC(14, 2),
    total_vendor_payouts            NUMERIC(14, 2),
    total_siya_charges              NUMERIC(14, 2),
    total_other_expenses            NUMERIC(14, 2),
    ledger_total_credit             NUMERIC(14, 2),
    ledger_total_debit              NUMERIC(14, 2),
    ledger_net_balance              NUMERIC(14, 2)
)
LANGUAGE sql
STABLE
SECURITY INVOKER
AS $$
    WITH site_agg AS (
        SELECT
            vsa.vendor_id,
            COUNT(*) FILTER (WHERE vsa.status <> 'Cancelled') AS site_count,
            COALESCE(SUM(CASE WHEN vsa.status <> 'Cancelled'
                THEN GREATEST(COALESCE(vsa.total_customer_site_amount, 0.00), COALESCE(cr.total_amount, 0.00))
                ELSE 0.00 END), 0.00) AS total_site_quotation,
            COALESCE(SUM(CASE WHEN vsa.status <> 'Cancelled'
                THEN GREATEST(COALESCE(vsa.total_customer_received, 0.00), COALESCE(cr.paid_amount, 0.00))
                ELSE 0.00 END), 0.00) AS total_customer_collection,
            COALESCE(SUM(CASE WHEN vsa.status <> 'Cancelled' THEN COALESCE(vsa.total_loan_credited, 0.00) ELSE 0.00 END), 0.00) AS total_loan_credited,
            COALESCE(SUM(CASE WHEN vsa.status <> 'Cancelled' THEN COALESCE(vsa.vendor_charges, 0.00) ELSE 0.00 END), 0.00) AS total_siya_charges,
            COALESCE(SUM(CASE WHEN vsa.status <> 'Cancelled' THEN COALESCE(vsa.other_expenses, 0.00) ELSE 0.00 END), 0.00) AS total_other_expenses
        FROM public.vendor_site_assignments vsa
        LEFT JOIN public.consumer_records cr ON cr.id = vsa.customer_id
        GROUP BY vsa.vendor_id
    ),
    vmt_agg AS (
        SELECT
            vmt.vendor_id,
            COALESCE(SUM(
                CASE
                    WHEN UPPER(COALESCE(vmt.transaction_type, 'ISSUE')) = 'RETURN' THEN -COALESCE(vmt.total_amount, 0.00)
                    ELSE COALESCE(vmt.total_amount, 0.00)
                END
            ), 0.00) AS total_site_material_cost
        FROM public.vendor_material_transactions vmt
        GROUP BY vmt.vendor_id
    ),
    mo_agg AS (
        SELECT
            mo.vendor_id,
            COALESCE(SUM(CASE WHEN mo.status = 'Active' THEN COALESCE(mo.total_value, 0.00) ELSE 0.00 END), 0.00) AS total_unallocated_outward_cost
        FROM public.sub_vendor_material_outwards mo
        GROUP BY mo.vendor_id
    ),
    direct_pay_agg AS (
        SELECT
            l.vendor_id,
            COALESCE(SUM(CASE WHEN l.status = 'Active' AND l.transaction_type = 'MATERIAL_PAYMENT' THEN l.debit_amount ELSE 0.00 END), 0.00) AS total_direct_vendor_payments
        FROM public.sub_vendor_account_ledger l
        GROUP BY l.vendor_id
    ),
    payout_agg AS (
        SELECT
            vp.vendor_id,
            COALESCE(SUM(CASE WHEN vp.status IN ('Approved', 'Paid') THEN vp.amount ELSE 0.00 END), 0.00) AS total_vendor_payouts
        FROM public.vendor_payouts vp
        GROUP BY vp.vendor_id
    ),
    ledger_agg AS (
        SELECT
            u.vendor_id,
            COALESCE(SUM(CASE WHEN u.status = 'Active' THEN u.credit_amount ELSE 0.00 END), 0.00) AS total_credit,
            COALESCE(SUM(CASE WHEN u.status = 'Active' THEN u.debit_amount  ELSE 0.00 END), 0.00) AS total_debit,
            COALESCE(SUM(CASE WHEN u.status = 'Active' THEN u.credit_amount - u.debit_amount ELSE 0.00 END), 0.00) AS net_balance
        FROM public.v_sub_vendor_unified_ledger u
        GROUP BY u.vendor_id
    )
    SELECT
        sv.id::TEXT                                                         AS vendor_id,
        sv.name                                                             AS vendor_name,
        sv.vendor_code                                                      AS vendor_code,
        COALESCE(sa.site_count, 0)                                          AS site_count,
        COALESCE(sa.total_site_quotation, 0.00)::NUMERIC(14, 2)             AS total_site_quotation,
        COALESCE(sa.total_customer_collection, 0.00)::NUMERIC(14, 2)        AS total_customer_collection,
        COALESCE(sa.total_loan_credited, 0.00)::NUMERIC(14, 2)              AS total_loan_credited,
        COALESCE(vm.total_site_material_cost, 0.00)::NUMERIC(14, 2)         AS total_site_material_cost,
        COALESCE(mo.total_unallocated_outward_cost, 0.00)::NUMERIC(14, 2)   AS total_unallocated_outward_cost,
        COALESCE(dp.total_direct_vendor_payments, 0.00)::NUMERIC(14, 2)     AS total_direct_vendor_payments,
        COALESCE(pa.total_vendor_payouts, 0.00)::NUMERIC(14, 2)             AS total_vendor_payouts,
        COALESCE(sa.total_siya_charges, 0.00)::NUMERIC(14, 2)               AS total_siya_charges,
        COALESCE(sa.total_other_expenses, 0.00)::NUMERIC(14, 2)             AS total_other_expenses,
        COALESCE(la.total_credit, 0.00)::NUMERIC(14, 2)                     AS ledger_total_credit,
        COALESCE(la.total_debit, 0.00)::NUMERIC(14, 2)                      AS ledger_total_debit,
        COALESCE(la.net_balance, 0.00)::NUMERIC(14, 2)                      AS ledger_net_balance
    FROM public.sub_vendors sv
    LEFT JOIN site_agg sa       ON sa.vendor_id = sv.id
    LEFT JOIN vmt_agg vm        ON vm.vendor_id = sv.id
    LEFT JOIN mo_agg mo         ON mo.vendor_id = sv.id
    LEFT JOIN direct_pay_agg dp ON dp.vendor_id = sv.id
    LEFT JOIN payout_agg pa     ON pa.vendor_id = sv.id
    LEFT JOIN ledger_agg la     ON la.vendor_id = sv.id::TEXT
    WHERE (p_vendor_id IS NULL OR sv.id = p_vendor_id)
    ORDER BY sv.name;
$$;

GRANT EXECUTE ON FUNCTION public.get_sub_vendor_central_reconciliation(UUID) TO authenticated, service_role;

-- ------------------------------------------------------------------------------
-- 7. AUDIT HEALTH CHECK VIEW (SECURITY INVOKER + EXPANDED CHECKS)
-- ------------------------------------------------------------------------------
DROP VIEW IF EXISTS public.v_sub_vendor_audit_check CASCADE;

CREATE VIEW public.v_sub_vendor_audit_check
WITH (security_invoker = true) AS

SELECT
    'orphan_ledger_ref'::TEXT         AS issue_type,
    l.id::TEXT                        AS record_id,
    l.vendor_id::TEXT                 AS vendor_id,
    NULL::TEXT                        AS customer_id,
    GREATEST(l.credit_amount, l.debit_amount) AS amount,
    l.transaction_date::TEXT          AS date_field,
    'sub_vendor_account_ledger: reference_id not found in sub_vendor_material_outwards'::TEXT AS description
FROM public.sub_vendor_account_ledger l
WHERE l.transaction_type = 'MATERIAL_OUTWARD'
  AND l.reference_id IS NOT NULL
  AND l.status = 'Active'
  AND NOT EXISTS (
      SELECT 1 FROM public.sub_vendor_material_outwards mo
      WHERE mo.id = l.reference_id
  )
  AND NOT EXISTS (
      SELECT 1 FROM public.vendor_material_transactions vmt
      WHERE vmt.id = l.reference_id
  )

UNION ALL

SELECT
    'orphan_cp_assignment'::TEXT      AS issue_type,
    cp.id::TEXT                       AS record_id,
    cp.vendor_id::TEXT                AS vendor_id,
    cp.customer_id::TEXT              AS customer_id,
    cp.amount                         AS amount,
    cp.payment_date::TEXT             AS date_field,
    'vendor_customer_payments: assignment_id missing in vendor_site_assignments'::TEXT AS description
FROM public.vendor_customer_payments cp
WHERE NOT EXISTS (
    SELECT 1 FROM public.vendor_site_assignments vsa WHERE vsa.id = cp.assignment_id
)

UNION ALL

SELECT
    'orphan_payout_vendor'::TEXT      AS issue_type,
    vp.id::TEXT                       AS record_id,
    vp.vendor_id::TEXT                AS vendor_id,
    NULL::TEXT                        AS customer_id,
    vp.amount                         AS amount,
    vp.payout_date::TEXT              AS date_field,
    'vendor_payouts: vendor_id not in sub_vendors'::TEXT AS description
FROM public.vendor_payouts vp
WHERE NOT EXISTS (SELECT 1 FROM public.sub_vendors sv WHERE sv.id = vp.vendor_id)

UNION ALL

SELECT
    'outward_no_items'::TEXT          AS issue_type,
    mo.id::TEXT                       AS record_id,
    mo.vendor_id::TEXT                AS vendor_id,
    NULL::TEXT                        AS customer_id,
    COALESCE(mo.total_value, 0.00)    AS amount,
    mo.outward_date::TEXT             AS date_field,
    'sub_vendor_material_outwards: outward entry has no line items'::TEXT AS description
FROM public.sub_vendor_material_outwards mo
WHERE NOT EXISTS (
    SELECT 1 FROM public.sub_vendor_material_outward_items i WHERE i.outward_id = mo.id
)
AND mo.status = 'Active'

UNION ALL

SELECT
    'payment_on_cancelled_site'::TEXT AS issue_type,
    cp.id::TEXT                       AS record_id,
    cp.vendor_id::TEXT                AS vendor_id,
    cp.customer_id::TEXT              AS customer_id,
    cp.amount                         AS amount,
    cp.payment_date::TEXT             AS date_field,
    'vendor_customer_payments: payment on a Cancelled site assignment'::TEXT AS description
FROM public.vendor_customer_payments cp
JOIN public.vendor_site_assignments vsa ON vsa.id = cp.assignment_id
WHERE vsa.status = 'Cancelled'
  AND cp.status = 'Approved';

GRANT SELECT ON public.v_sub_vendor_audit_check TO authenticated, service_role;

-- ------------------------------------------------------------------------------
-- 8. RELOAD SUPABASE SCHEMA CACHE
-- ------------------------------------------------------------------------------
NOTIFY pgrst, 'reload schema';
