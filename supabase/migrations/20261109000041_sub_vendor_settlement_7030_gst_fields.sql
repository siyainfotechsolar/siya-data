-- ==============================================================================
-- Migration: 20261109000041_sub_vendor_settlement_7030_gst_fields.sql
-- Module: Sub-Vendor Settlement & Payout Statutory 70:30 GST & Margin Paperwork Fields
-- SIYA INFOTECH & SOLAR ENERGY
-- Description:
--   Adds columns to public.vendor_settlements to store:
--   1. use_70_30_gst_rule (statutory 70:30 GST split vs flat rate)
--   2. is_margin_receipt_only (10% loan margin paperwork receipt exemption)
--   3. goods_taxable_70, goods_gst_5 (70% solar equipment portion @ 5% GST)
--   4. services_taxable_30, services_gst_18 (30% services/BOS portion @ 18% GST)
-- ==============================================================================

ALTER TABLE public.vendor_settlements
    ADD COLUMN IF NOT EXISTS use_70_30_gst_rule BOOLEAN NOT NULL DEFAULT true,
    ADD COLUMN IF NOT EXISTS is_margin_receipt_only BOOLEAN NOT NULL DEFAULT true,
    ADD COLUMN IF NOT EXISTS goods_taxable_70 NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    ADD COLUMN IF NOT EXISTS goods_gst_5 NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    ADD COLUMN IF NOT EXISTS services_taxable_30 NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    ADD COLUMN IF NOT EXISTS services_gst_18 NUMERIC(12, 2) NOT NULL DEFAULT 0.00;

NOTIFY pgrst, 'reload schema';
