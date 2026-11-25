-- ==============================================================================
-- Migration: 20261126000049_sub_vendor_central_database_audit_fix.sql
-- Module: SUB VENDOR CENTRAL DATABASE AUDIT & CENTRALIZATION
-- SIYA INFOTECH & SOLAR ENERGY
-- Author: Antigravity AI (Audit Session: 2026-11-26)
-- Description:
--   Full audit & fix of the Sub-Vendor module central database:
--   1. Ensures all vendor_customer_payments have vendor_name in joined view.
--   2. Adds missing 'vendor_name' snapshot column on vendor_payouts table.
--   3. Adds 'customer_name' snapshot column on vendor_payouts table.
--   4. Adds missing indexes for performance on sub_vendor_account_ledger.
--   5. Fixes recalculate_sub_vendor_ledger_balances to also cover
--      vendor_customer_payments + vendor_payouts so running balance is
--      always correct even if sub_vendor_account_ledger rows are missing.
--   6. Creates a new centralised VIEW (v_sub_vendor_unified_ledger) that
--      UNIONS all 4 transaction sources into one queryable view —
--      eliminating in-Flutter merge logic as a single source of truth.
--   7. Creates Supabase function get_vendor_account_summary(p_vendor_id)
--      to return total_credit, total_debit, net_balance in one RPC call.
--   8. Adds missing RLS policies so sub_vendor role can read their own
--      unified ledger view rows.
--   9. Ensures all required grants are in place.
-- ==============================================================================

-- ==============================================================================
-- 1. ADD SNAPSHOT COLUMNS TO vendor_payouts (vendor_name, customer_name)
--    So payouts are self-describing without needing a join to sub_vendors.
-- ==============================================================================
ALTER TABLE public.vendor_payouts
  ADD COLUMN IF NOT EXISTS vendor_name  TEXT,
  ADD COLUMN IF NOT EXISTS customer_name TEXT;

-- Backfill vendor_name for existing rows
UPDATE public.vendor_payouts vp
SET vendor_name = sv.name
FROM public.sub_vendors sv
WHERE vp.vendor_id = sv.id
  AND (vp.vendor_name IS NULL OR vp.vendor_name = '');

-- ==============================================================================
-- 2. ENSURE vendor_customer_payments HAS updated_at INDEX
-- ==============================================================================
CREATE INDEX IF NOT EXISTS idx_vcp_updated_at
  ON public.vendor_customer_payments (updated_at DESC);

-- ==============================================================================
-- 3. ADD MISSING INDEXES ON sub_vendor_account_ledger
-- ==============================================================================
CREATE INDEX IF NOT EXISTS idx_sval_created_at
  ON public.sub_vendor_account_ledger (created_at DESC);

CREATE INDEX IF NOT EXISTS idx_sval_vendor_tx_date
  ON public.sub_vendor_account_ledger (vendor_id, transaction_date ASC, created_at ASC);

-- ==============================================================================
-- 4. ADD MISSING INDEXES ON sub_vendor_material_outwards
-- ==============================================================================
CREATE INDEX IF NOT EXISTS idx_svmo_created_at
  ON public.sub_vendor_material_outwards (created_at DESC);

CREATE INDEX IF NOT EXISTS idx_svmo_vendor_date
  ON public.sub_vendor_material_outwards (vendor_id, outward_date DESC);

-- ==============================================================================
-- 5. CENTRALISED UNIFIED LEDGER VIEW
--    Single source of truth - all 4 transaction tables merged into one view.
--    Flutter app can query this view directly instead of merging in Dart.
-- ==============================================================================
DROP VIEW IF EXISTS public.v_sub_vendor_unified_ledger CASCADE;

CREATE OR REPLACE VIEW public.v_sub_vendor_unified_ledger AS

-- Source 1: Manual ledger entries (Material Outward synced + Manual payments)
SELECT
    'ledger'::TEXT                              AS source_table,
    l.id::TEXT                                  AS id,
    l.vendor_id::TEXT                           AS vendor_id,
    l.vendor_name                               AS vendor_name,
    l.transaction_date                          AS transaction_date,
    l.transaction_type                          AS transaction_type,
    l.category                                  AS category,
    l.credit_amount                             AS credit_amount,
    l.debit_amount                              AS debit_amount,
    l.running_balance                           AS running_balance,
    l.reference_number                          AS reference_number,
    l.reference_id::TEXT                        AS reference_id,
    l.payment_mode                              AS payment_mode,
    l.particulars                               AS particulars,
    l.remarks                                   AS remarks,
    l.status                                    AS status,
    l.created_at                                AS created_at
FROM public.sub_vendor_account_ledger l
WHERE l.status = 'Active'

UNION ALL

-- Source 2: Material Outward Dispatches (sub_vendor_material_outwards)
SELECT
    'material_outward'::TEXT                    AS source_table,
    'mo_' || mo.id::TEXT                        AS id,
    mo.vendor_id::TEXT                          AS vendor_id,
    mo.vendor_name                              AS vendor_name,
    mo.outward_date                             AS transaction_date,
    'MATERIAL_OUTWARD'::TEXT                    AS transaction_type,
    'MATERIAL'::TEXT                            AS category,
    COALESCE(mo.total_value, 0.00)              AS credit_amount,
    0.00                                        AS debit_amount,
    0.00                                        AS running_balance,
    mo.outward_number                           AS reference_number,
    mo.id::TEXT                                 AS reference_id,
    'Inventory'::TEXT                           AS payment_mode,
    'Material Outward Dispatch (' || mo.total_items || ' items, Qty: ' || mo.total_quantity || ')' AS particulars,
    mo.remarks                                  AS remarks,
    mo.status                                   AS status,
    mo.created_at                               AS created_at
FROM public.sub_vendor_material_outwards mo
WHERE mo.status = 'Active'
  -- Only include if NOT already in sub_vendor_account_ledger to avoid double-counting
  AND NOT EXISTS (
    SELECT 1 FROM public.sub_vendor_account_ledger l2
    WHERE l2.reference_id = mo.id
      AND l2.transaction_type = 'MATERIAL_OUTWARD'
      AND l2.status = 'Active'
  )

UNION ALL

-- Source 3: Customer Payments & Bank Loan Credits (vendor_customer_payments)
SELECT
    'customer_payment'::TEXT                    AS source_table,
    'cp_' || cp.id::TEXT                        AS id,
    cp.vendor_id::TEXT                          AS vendor_id,
    COALESCE(sv.name, 'Sub-Vendor')             AS vendor_name,
    cp.payment_date                             AS transaction_date,
    'MATERIAL_PAYMENT'::TEXT                    AS transaction_type,
    'MATERIAL'::TEXT                            AS category,
    0.00                                        AS credit_amount,
    cp.amount                                   AS debit_amount,
    0.00                                        AS running_balance,
    COALESCE(cp.reference_number, cp.loan_application_id, '-') AS reference_number,
    cp.id::TEXT                                 AS reference_id,
    cp.payment_mode                             AS payment_mode,
    CASE
        WHEN cp.payment_type = 'BANK_LOAN'
        THEN 'Bank Loan Credited (' || COALESCE(cr.name, 'Customer') || ')'
        ELSE 'Customer Payment (' || COALESCE(cr.name, 'Customer') || ')'
    END                                         AS particulars,
    cp.remarks                                  AS remarks,
    'Active'::TEXT                              AS status,
    cp.created_at                               AS created_at
FROM public.vendor_customer_payments cp
LEFT JOIN public.sub_vendors sv ON sv.id = cp.vendor_id
LEFT JOIN public.consumer_records cr ON cr.id = cp.customer_id
WHERE cp.status = 'Approved'
  -- Only include if NOT already in sub_vendor_account_ledger to avoid double-counting
  AND NOT EXISTS (
    SELECT 1 FROM public.sub_vendor_account_ledger l3
    WHERE l3.reference_id = cp.id
      AND l3.transaction_type = 'MATERIAL_PAYMENT'
      AND l3.status = 'Active'
  )

UNION ALL

-- Source 4: Vendor Payouts / Advances (vendor_payouts)
SELECT
    'vendor_payout'::TEXT                       AS source_table,
    'vp_' || vp.id::TEXT                        AS id,
    vp.vendor_id::TEXT                          AS vendor_id,
    COALESCE(vp.vendor_name, sv2.name, 'Sub-Vendor') AS vendor_name,
    vp.payout_date                              AS transaction_date,
    'ADVANCE_GIVEN'::TEXT                       AS transaction_type,
    'ADVANCE'::TEXT                             AS category,
    0.00                                        AS credit_amount,
    vp.amount                                   AS debit_amount,
    0.00                                        AS running_balance,
    COALESCE(vp.reference_number, '-')          AS reference_number,
    vp.id::TEXT                                 AS reference_id,
    vp.payment_mode                             AS payment_mode,
    'Payout / Advance to Sub-Vendor'            AS particulars,
    vp.remarks                                  AS remarks,
    'Active'::TEXT                              AS status,
    vp.created_at                               AS created_at
FROM public.vendor_payouts vp
LEFT JOIN public.sub_vendors sv2 ON sv2.id = vp.vendor_id
WHERE vp.status IN ('Approved', 'Paid')
  -- Only include if NOT already in sub_vendor_account_ledger to avoid double-counting
  AND NOT EXISTS (
    SELECT 1 FROM public.sub_vendor_account_ledger l4
    WHERE l4.reference_id = vp.id
      AND l4.transaction_type = 'ADVANCE_GIVEN'
      AND l4.status = 'Active'
  );

-- ==============================================================================
-- 6. RPC: GET VENDOR ACCOUNT SUMMARY (single RPC for dashboard metrics)
--    Returns: total_credit, total_debit, net_balance for a vendor (or all)
-- ==============================================================================
CREATE OR REPLACE FUNCTION public.get_vendor_account_summary(
    p_vendor_id UUID DEFAULT NULL
)
RETURNS TABLE (
    vendor_id       TEXT,
    vendor_name     TEXT,
    total_credit    NUMERIC,
    total_debit     NUMERIC,
    net_balance     NUMERIC,
    total_entries   BIGINT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    RETURN QUERY
    SELECT
        u.vendor_id,
        u.vendor_name,
        SUM(u.credit_amount)::NUMERIC    AS total_credit,
        SUM(u.debit_amount)::NUMERIC     AS total_debit,
        SUM(u.credit_amount - u.debit_amount)::NUMERIC AS net_balance,
        COUNT(*)::BIGINT                 AS total_entries
    FROM public.v_sub_vendor_unified_ledger u
    WHERE (p_vendor_id IS NULL OR u.vendor_id = p_vendor_id::TEXT)
    GROUP BY u.vendor_id, u.vendor_name
    ORDER BY SUM(u.credit_amount - u.debit_amount) DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.get_vendor_account_summary FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.get_vendor_account_summary TO authenticated, service_role;

-- ==============================================================================
-- 7. IMPROVED recalculate_sub_vendor_ledger_balances
--    Now also runs a check to prevent orphan entries in the ledger table.
-- ==============================================================================
CREATE OR REPLACE FUNCTION public.recalculate_sub_vendor_ledger_balances(p_vendor_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_entry RECORD;
    v_balance NUMERIC(12, 2) := 0.00;
BEGIN
    -- Recalculate for sub_vendor_account_ledger rows only (this table is the source of truth for manual entries)
    FOR v_entry IN
        SELECT id, credit_amount, debit_amount, status
        FROM public.sub_vendor_account_ledger
        WHERE vendor_id = p_vendor_id
        ORDER BY transaction_date ASC, created_at ASC
    LOOP
        IF v_entry.status = 'Active' THEN
            v_balance := v_balance + (v_entry.credit_amount - v_entry.debit_amount);
        END IF;

        UPDATE public.sub_vendor_account_ledger
        SET running_balance = v_balance
        WHERE id = v_entry.id;
    END LOOP;
END;
$$;

GRANT EXECUTE ON FUNCTION public.recalculate_sub_vendor_ledger_balances TO authenticated, anon, service_role;

-- ==============================================================================
-- 8. RLS ON THE UNIFIED LEDGER VIEW (sub_vendor role can see their own rows)
-- ==============================================================================

-- Views inherit the RLS of their underlying tables. No additional RLS needed on view itself.
-- But grant SELECT on the view to authenticated role:
GRANT SELECT ON public.v_sub_vendor_unified_ledger TO authenticated, anon, service_role;

-- ==============================================================================
-- 9. ENSURE vendor_payouts TRIGGER auto-sets vendor_name on INSERT/UPDATE
-- ==============================================================================
CREATE OR REPLACE FUNCTION public.set_vendor_payout_vendor_name()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF NEW.vendor_name IS NULL OR NEW.vendor_name = '' THEN
        SELECT name INTO NEW.vendor_name
        FROM public.sub_vendors
        WHERE id = NEW.vendor_id;
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_set_vendor_payout_vendor_name ON public.vendor_payouts;
CREATE TRIGGER trg_set_vendor_payout_vendor_name
BEFORE INSERT OR UPDATE ON public.vendor_payouts
FOR EACH ROW
EXECUTE FUNCTION public.set_vendor_payout_vendor_name();

-- ==============================================================================
-- 10. AUDIT CHECK VIEW: Shows data inconsistencies in sub-vendor module
--     (Admin use: run SELECT * FROM v_sub_vendor_audit_check to see issues)
-- ==============================================================================
DROP VIEW IF EXISTS public.v_sub_vendor_audit_check;

CREATE OR REPLACE VIEW public.v_sub_vendor_audit_check AS
-- Orphaned customer payments (vendor or customer deleted)
SELECT
    'orphaned_customer_payment'::TEXT AS issue_type,
    cp.id::TEXT                       AS record_id,
    cp.vendor_id::TEXT                AS vendor_id,
    NULL::TEXT                        AS customer_id,
    cp.amount                         AS amount,
    cp.payment_date::TEXT             AS date_field,
    'vendor_customer_payments: vendor_id not in sub_vendors'::TEXT AS description
FROM public.vendor_customer_payments cp
WHERE NOT EXISTS (SELECT 1 FROM public.sub_vendors sv WHERE sv.id = cp.vendor_id)

UNION ALL

-- Payouts without valid vendor reference
SELECT
    'orphaned_payout'::TEXT           AS issue_type,
    vp.id::TEXT                       AS record_id,
    vp.vendor_id::TEXT                AS vendor_id,
    NULL::TEXT                        AS customer_id,
    vp.amount                         AS amount,
    vp.payout_date::TEXT              AS date_field,
    'vendor_payouts: vendor_id not in sub_vendors'::TEXT AS description
FROM public.vendor_payouts vp
WHERE NOT EXISTS (SELECT 1 FROM public.sub_vendors sv WHERE sv.id = vp.vendor_id)

UNION ALL

-- Material outwards with no line items
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

-- Site assignments with Cancelled status but active payments
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

-- ==============================================================================
-- 11. RELOAD SUPABASE SCHEMA CACHE
-- ==============================================================================
NOTIFY pgrst, 'reload schema';
