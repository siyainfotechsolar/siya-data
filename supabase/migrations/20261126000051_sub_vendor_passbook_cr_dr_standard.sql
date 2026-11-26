-- ==============================================================================
-- SUB-VENDOR MODULE: STANDARD PARTY PASSBOOK CREDIT / DEBIT ACCOUNTING (OPTION A)
-- Migration: 20261126000051_sub_vendor_passbook_cr_dr_standard.sql
-- Purpose:
--   Aligns `sub_vendor_account_ledger`, `v_sub_vendor_unified_ledger`, and all
--   accounting RPCs with Standard Party Passbook / Complete Financial Dashboard
--   (Tab 8) Credit & Debit rules:
--
--     CREDIT (+ Cr / जमा — Payable to Sub-Vendor increases):
--       1. Customer Cash & Bank Loan Credits (`vendor_customer_payments`, `customer_payment_transactions`, residual `vendor_site_assignments`) -> `credit_amount`
--       2. Direct Material Payments Received (`MATERIAL_PAYMENT`) -> `credit_amount`
--       3. Site Material Returns (`vendor_material_transactions` `RETURN`) -> `credit_amount`
--       4. Advance / Deposit Refunds Received (`ADVANCE_REFUND`) -> `credit_amount`
--
--     DEBIT (- Dr / नावे — Payable decreases / Receivable increases):
--       1. Material Outward Dispatches (`sub_vendor_material_outwards`, `MATERIAL_OUTWARD`) -> `debit_amount`
--       2. Site Material Issues (`vendor_material_transactions` `ISSUE`) -> `debit_amount`
--       3. Payouts & Advances Paid to Sub-Vendor (`vendor_payouts`, `ADVANCE_GIVEN`) -> `debit_amount`
--
--     NET BALANCE = Total Credit - Total Debit:
--       >= 0 (Cr) => Payable to Sub-Vendor (आपल्याला Sub Vendor ला देणे)
--        < 0 (Dr) => Recoverable from Sub-Vendor (आपल्याला Sub Vendor कडून येणे)
--
--   100% Idempotent & Re-runnable without double-swapping existing rows.
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- 1. SAFELY MIGRATE EXISTING ROWS IN sub_vendor_account_ledger TO PASSBOOK SIGNS
--    (Guarded so running multiple times never swaps an already-migrated row!)
-- ------------------------------------------------------------------------------
UPDATE public.sub_vendor_account_ledger
SET
    debit_amount  = credit_amount,
    credit_amount = 0.00,
    updated_at    = timezone('utc'::text, now())
WHERE transaction_type = 'MATERIAL_OUTWARD'
  AND COALESCE(credit_amount, 0.00) > 0
  AND COALESCE(debit_amount, 0.00) = 0;

UPDATE public.sub_vendor_account_ledger
SET
    credit_amount = debit_amount,
    debit_amount  = 0.00,
    updated_at    = timezone('utc'::text, now())
WHERE transaction_type = 'MATERIAL_PAYMENT'
  AND COALESCE(debit_amount, 0.00) > 0
  AND COALESCE(credit_amount, 0.00) = 0;

-- Recalculate running balances across all vendors after migrating signs
DO $$
DECLARE
    v_rec RECORD;
BEGIN
    IF EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'recalculate_sub_vendor_ledger_balances') THEN
        FOR v_rec IN SELECT id FROM public.sub_vendors LOOP
            PERFORM public.recalculate_sub_vendor_ledger_balances(v_rec.id);
        END LOOP;
    END IF;
END $$;

-- ------------------------------------------------------------------------------
-- 2. UPDATE record_sub_vendor_ledger_entry() RPC TO WRITE PASSBOOK CREDIT/DEBIT
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.record_sub_vendor_ledger_entry(
    p_vendor_id UUID,
    p_transaction_date DATE,
    p_transaction_type TEXT,
    p_amount NUMERIC(12, 2),
    p_reference_number TEXT,
    p_payment_mode TEXT,
    p_particulars TEXT,
    p_remarks TEXT DEFAULT NULL,
    p_reference_id UUID DEFAULT NULL,
    p_created_by UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_vendor_name TEXT;
    v_category TEXT;
    v_credit NUMERIC(12, 2) := 0.00;
    v_debit NUMERIC(12, 2) := 0.00;
    v_entry_id UUID;
BEGIN
    SELECT name INTO v_vendor_name FROM public.sub_vendors WHERE id = p_vendor_id;
    IF v_vendor_name IS NULL THEN
        RAISE EXCEPTION 'Sub-Vendor with ID % not found.', p_vendor_id;
    END IF;
    IF p_amount <= 0 THEN
        RAISE EXCEPTION 'Transaction amount must be greater than zero.';
    END IF;

    -- Standard Party Passbook Rules:
    -- Credit (+ Cr): MATERIAL_PAYMENT (receipts/payments/loans), ADVANCE_REFUND
    -- Debit  (- Dr): MATERIAL_OUTWARD (materials given), ADVANCE_GIVEN (payouts/advances paid)
    IF p_transaction_type = 'MATERIAL_OUTWARD' THEN
        v_category := 'MATERIAL';
        v_credit := 0.00;
        v_debit := p_amount;
    ELSIF p_transaction_type = 'MATERIAL_PAYMENT' THEN
        v_category := 'MATERIAL';
        v_credit := p_amount;
        v_debit := 0.00;
    ELSIF p_transaction_type = 'ADVANCE_GIVEN' THEN
        v_category := 'ADVANCE';
        v_credit := 0.00;
        v_debit := p_amount;
    ELSIF p_transaction_type = 'ADVANCE_REFUND' THEN
        v_category := 'ADVANCE';
        v_credit := p_amount;
        v_debit := 0.00;
    ELSE
        RAISE EXCEPTION 'Invalid transaction type: %', p_transaction_type;
    END IF;

    INSERT INTO public.sub_vendor_account_ledger (
        vendor_id, vendor_name, transaction_date, transaction_type, category,
        credit_amount, debit_amount, running_balance, reference_number, reference_id,
        payment_mode, particulars, remarks, status, created_by
    ) VALUES (
        p_vendor_id, v_vendor_name, p_transaction_date, p_transaction_type, v_category,
        v_credit, v_debit, 0.00, p_reference_number, p_reference_id,
        COALESCE(p_payment_mode, 'Bank Transfer'), p_particulars, p_remarks, 'Active', p_created_by
    ) RETURNING id INTO v_entry_id;

    PERFORM public.recalculate_sub_vendor_ledger_balances(p_vendor_id);

    RETURN jsonb_build_object(
        'success', true,
        'id', v_entry_id,
        'vendor_id', p_vendor_id,
        'credit_amount', v_credit,
        'debit_amount', v_debit
    );
END;
$$;

-- ------------------------------------------------------------------------------
-- 3. RECREATE v_sub_vendor_unified_ledger WITH STANDARD PASSBOOK SIGNS
--    (ALL 7 SOURCES, ZERO DUPLICATES, SECURITY INVOKER)
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

-- Branch 2: Active Material Outward Dispatches (Debit - Material Given to Sub-Vendor)
SELECT
    'material_outward'::TEXT                    AS source_table,
    'mo_' || mo.id::TEXT                        AS id,
    mo.vendor_id::TEXT                          AS vendor_id,
    mo.vendor_name                              AS vendor_name,
    mo.outward_date                             AS transaction_date,
    'MATERIAL_OUTWARD'::TEXT                    AS transaction_type,
    'MATERIAL'::TEXT                            AS category,
    0.00::NUMERIC(14, 2)                        AS credit_amount,
    COALESCE(mo.total_value, 0.00)::NUMERIC(14, 2) AS debit_amount,
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
      WHERE l2.status = 'Active'
        AND (
            l2.reference_id = mo.id
            OR (
                l2.transaction_type = 'MATERIAL_OUTWARD'
                AND l2.vendor_id = mo.vendor_id
                AND UPPER(TRIM(l2.reference_number)) = UPPER(TRIM(mo.outward_number))
            )
        )
  )

UNION ALL

-- Branch 3: Site-wise Material Issues (Debit) & Returns (Credit)
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
        WHEN UPPER(COALESCE(vmt.transaction_type, 'ISSUE')) = 'RETURN' THEN COALESCE(vmt.total_amount, 0.00)
        ELSE 0.00
    END::NUMERIC(14, 2)                         AS credit_amount,
    CASE
        WHEN UPPER(COALESCE(vmt.transaction_type, 'ISSUE')) = 'RETURN' THEN 0.00
        ELSE COALESCE(vmt.total_amount, 0.00)
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

-- Branch 4: Approved Customer Cash & Bank Loan Credits (Credit - Money Received for Site)
SELECT
    'customer_payment'::TEXT                    AS source_table,
    'cp_' || cp.id::TEXT                        AS id,
    cp.vendor_id::TEXT                          AS vendor_id,
    COALESCE(cp.vendor_name, sv.name, 'Sub-Vendor') AS vendor_name,
    cp.payment_date                             AS transaction_date,
    'MATERIAL_PAYMENT'::TEXT                    AS transaction_type,
    'MATERIAL'::TEXT                            AS category,
    cp.amount::NUMERIC(14, 2)                   AS credit_amount,
    0.00::NUMERIC(14, 2)                        AS debit_amount,
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

-- Branch 5: Valid Main CRM Customer / Loan Payments (Credit - Deduplicated against cp)
SELECT
    'crm_customer_payment'::TEXT                AS source_table,
    'cpt_' || cpt.id::TEXT || '_' || LEFT(vsa.id::TEXT, 8) AS id,
    vsa.vendor_id::TEXT                         AS vendor_id,
    COALESCE(sv.name, 'Sub-Vendor')             AS vendor_name,
    cpt.payment_date                            AS transaction_date,
    'MATERIAL_PAYMENT'::TEXT                    AS transaction_type,
    'MATERIAL'::TEXT                            AS category,
    cpt.amount::NUMERIC(14, 2)                  AS credit_amount,
    0.00::NUMERIC(14, 2)                        AS debit_amount,
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
            OR (cp_dup.amount = cpt.amount AND ABS(cp_dup.payment_date::DATE - cpt.payment_date::DATE) <= 1)
        )
  )

UNION ALL

-- Branch 6: Assignment / Consumer Paid Residual Fallback (Credit)
SELECT
    'assignment_collection'::TEXT               AS source_table,
    'a_coll_' || vsa.id::TEXT                   AS id,
    vsa.vendor_id::TEXT                         AS vendor_id,
    COALESCE(sv.name, 'Sub-Vendor')             AS vendor_name,
    vsa.assigned_date                           AS transaction_date,
    'MATERIAL_PAYMENT'::TEXT                    AS transaction_type,
    'MATERIAL'::TEXT                            AS category,
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
                        OR (cp_dup2.amount = cpt2.amount AND ABS(cp_dup2.payment_date::DATE - cpt2.payment_date::DATE) <= 1)
                    )
              )
        ), 0.00)
    )::NUMERIC, 2)                              AS credit_amount,
    0.00::NUMERIC(14, 2)                        AS debit_amount,
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
                      OR (cp_dup2.amount = cpt2.amount AND ABS(cp_dup2.payment_date::DATE - cpt2.payment_date::DATE) <= 1)
                  )
            )
      ), 0.00)
  ) > 0.01

UNION ALL

-- Branch 7: Approved/Paid Vendor Payouts (Debit - Money Paid Out to Sub-Vendor)
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
-- 4. UPDATE get_vendor_account_summary() RPC FOR PASSBOOK TOTALS
-- ------------------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.get_vendor_account_summary(UUID);

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
        COALESCE(SUM(CASE WHEN u.status = 'Active' AND u.transaction_type = 'MATERIAL_OUTWARD' THEN u.debit_amount  ELSE 0 END), 0.00)::NUMERIC(14, 2) AS total_material_outward,
        COALESCE(SUM(CASE WHEN u.status = 'Active' AND u.transaction_type = 'MATERIAL_PAYMENT' THEN u.credit_amount ELSE 0 END), 0.00)::NUMERIC(14, 2) AS total_material_payments,
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
-- 5. UPDATE get_sub_vendor_central_reconciliation() FOR PASSBOOK direct_pay_agg
-- ------------------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.get_sub_vendor_central_reconciliation(UUID);

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
            COALESCE(SUM(CASE
                WHEN l.status = 'Active' AND l.transaction_type = 'MATERIAL_PAYMENT'
                THEN GREATEST(COALESCE(l.credit_amount, 0.00), COALESCE(l.debit_amount, 0.00))
                ELSE 0.00
            END), 0.00) AS total_direct_vendor_payments
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
-- 6. RELOAD SUPABASE SCHEMA CACHE
-- ------------------------------------------------------------------------------
NOTIFY pgrst, 'reload schema';
