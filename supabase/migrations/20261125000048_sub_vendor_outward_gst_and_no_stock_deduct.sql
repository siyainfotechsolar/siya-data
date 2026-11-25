-- ==============================================================================
-- Migration: 20261125000048_sub_vendor_outward_gst_and_no_stock_deduct.sql
-- Module: SUB VENDOR MATERIAL OUTWARD TRACKING (RATE, GST & NO STOCK DEDUCTION)
-- Description:
--   1. Adds 'subtotal', 'total_gst', 'total_value' to sub_vendor_material_outwards.
--   2. Adds 'unit_rate', 'base_amount', 'gst_percentage', 'gst_amount', 'total_price'
--      to sub_vendor_material_outward_items.
--   3. Updates outward RPCs to store Rate & GST calculations and NEVER deduct
--      or modify Main Inventory ('solar_cost_material_master.available_stock').
-- ==============================================================================

-- 1. Header Pricing Columns
ALTER TABLE public.sub_vendor_material_outwards
ADD COLUMN IF NOT EXISTS subtotal NUMERIC(14, 2) NOT NULL DEFAULT 0.00,
ADD COLUMN IF NOT EXISTS total_gst NUMERIC(14, 2) NOT NULL DEFAULT 0.00,
ADD COLUMN IF NOT EXISTS total_value NUMERIC(14, 2) NOT NULL DEFAULT 0.00;

-- 2. Line Item Pricing & GST Columns
ALTER TABLE public.sub_vendor_material_outward_items
ADD COLUMN IF NOT EXISTS unit_rate NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
ADD COLUMN IF NOT EXISTS base_amount NUMERIC(14, 2) NOT NULL DEFAULT 0.00,
ADD COLUMN IF NOT EXISTS gst_percentage NUMERIC(5, 2) NOT NULL DEFAULT 0.00,
ADD COLUMN IF NOT EXISTS gst_amount NUMERIC(14, 2) NOT NULL DEFAULT 0.00,
ADD COLUMN IF NOT EXISTS total_price NUMERIC(14, 2) NOT NULL DEFAULT 0.00;

-- 3. Atomic RPC: Record Outward Entry (With Rate & GST, WITHOUT Inventory Stock Deduction)
CREATE OR REPLACE FUNCTION public.record_sub_vendor_material_outward(
    p_vendor_id UUID,
    p_outward_date DATE,
    p_remarks TEXT,
    p_items JSONB,
    p_created_by UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_vendor_name TEXT;
    v_outward_id UUID;
    v_outward_number TEXT;
    v_total_items INT := 0;
    v_total_qty NUMERIC(12, 2) := 0.00;
    v_subtotal NUMERIC(14, 2) := 0.00;
    v_total_gst NUMERIC(14, 2) := 0.00;
    v_grand_total NUMERIC(14, 2) := 0.00;
    v_item JSONB;
    v_material_id UUID;
    v_material_name TEXT;
    v_unit TEXT;
    v_qty NUMERIC(12, 2);
    v_rate NUMERIC(12, 2);
    v_base NUMERIC(14, 2);
    v_gst_pct NUMERIC(5, 2);
    v_gst_amt NUMERIC(14, 2);
    v_final_price NUMERIC(14, 2);
    v_seq_val INT;
BEGIN
    SELECT name INTO v_vendor_name FROM public.sub_vendors WHERE id = p_vendor_id;
    IF v_vendor_name IS NULL THEN
        RAISE EXCEPTION 'Sub-Vendor with ID % not found.', p_vendor_id;
    END IF;

    IF p_items IS NULL OR jsonb_array_length(p_items) = 0 THEN
        RAISE EXCEPTION 'Material Outward entry must contain at least one material row.';
    END IF;

    -- Generate unique Outward Entry Number: OUT-YYYYMMDD-XXXX
    SELECT COALESCE(COUNT(*), 0) + 1 INTO v_seq_val
    FROM public.sub_vendor_material_outwards
    WHERE outward_date = p_outward_date;

    v_outward_number := 'OUT-' || to_char(p_outward_date, 'YYYYMMDD') || '-' || LPAD(v_seq_val::TEXT, 4, '0');
    WHILE EXISTS (SELECT 1 FROM public.sub_vendor_material_outwards WHERE outward_number = v_outward_number) LOOP
        v_seq_val := v_seq_val + 1;
        v_outward_number := 'OUT-' || to_char(p_outward_date, 'YYYYMMDD') || '-' || LPAD(v_seq_val::TEXT, 4, '0');
    END LOOP;

    -- Insert Header
    INSERT INTO public.sub_vendor_material_outwards (
        outward_number, vendor_id, vendor_name, outward_date,
        total_items, total_quantity, subtotal, total_gst, total_value,
        remarks, status, created_by
    ) VALUES (
        v_outward_number, p_vendor_id, v_vendor_name, p_outward_date,
        0, 0, 0, 0, 0,
        p_remarks, 'Active', p_created_by
    ) RETURNING id INTO v_outward_id;

    -- Process Line Items (NO inventory stock deduction)
    FOR v_item IN SELECT * FROM jsonb_array_elements(p_items)
    LOOP
        v_material_id := NULLIF(v_item->>'material_id', '')::UUID;
        v_material_name := COALESCE(v_item->>'material_name', 'Unknown Material');
        v_unit := UPPER(COALESCE(v_item->>'unit', 'NOS'));
        v_qty := COALESCE((v_item->>'quantity')::NUMERIC, 0);
        v_rate := COALESCE((v_item->>'unit_rate')::NUMERIC, 0);
        v_gst_pct := COALESCE((v_item->>'gst_percentage')::NUMERIC, 0);

        IF v_qty <= 0 THEN
            RAISE EXCEPTION 'Quantity for "%" must be greater than zero.', v_material_name;
        END IF;

        v_base := ROUND(v_qty * v_rate, 2);
        v_gst_amt := ROUND(v_base * v_gst_pct / 100.0, 2);
        v_final_price := v_base + v_gst_amt;

        INSERT INTO public.sub_vendor_material_outward_items (
            outward_id, material_id, material_name, unit, quantity,
            unit_rate, base_amount, gst_percentage, gst_amount, total_price
        ) VALUES (
            v_outward_id, v_material_id, v_material_name, v_unit, v_qty,
            v_rate, v_base, v_gst_pct, v_gst_amt, v_final_price
        );

        v_total_items := v_total_items + 1;
        v_total_qty := v_total_qty + v_qty;
        v_subtotal := v_subtotal + v_base;
        v_total_gst := v_total_gst + v_gst_amt;
        v_grand_total := v_grand_total + v_final_price;
    END LOOP;

    -- Update Header Totals
    UPDATE public.sub_vendor_material_outwards
    SET total_items = v_total_items,
        total_quantity = v_total_qty,
        subtotal = v_subtotal,
        total_gst = v_total_gst,
        total_value = v_grand_total
    WHERE id = v_outward_id;

    -- Audit Trail
    INSERT INTO public.sub_vendor_material_outward_audit (
        outward_id, outward_number, action, description, details, performed_by
    ) VALUES (
        v_outward_id,
        v_outward_number,
        'CREATE',
        format('Created outward entry with %s items, qty: %s, grand total: %s (no stock deduction)', v_total_items, v_total_qty, v_grand_total),
        jsonb_build_object('vendor_id', p_vendor_id, 'subtotal', v_subtotal, 'total_gst', v_total_gst, 'grand_total', v_grand_total, 'items', p_items),
        p_created_by
    );

    RETURN jsonb_build_object(
        'success', true,
        'id', v_outward_id,
        'outward_number', v_outward_number,
        'subtotal', v_subtotal,
        'total_gst', v_total_gst,
        'total_value', v_grand_total
    );
END;
$$;

-- 4. Atomic RPC: Update Outward Entry (NO Inventory Stock Modification)
CREATE OR REPLACE FUNCTION public.update_sub_vendor_material_outward(
    p_outward_id UUID,
    p_vendor_id UUID,
    p_outward_date DATE,
    p_remarks TEXT,
    p_items JSONB,
    p_updated_by UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_existing RECORD;
    v_vendor_name TEXT;
    v_total_items INT := 0;
    v_total_qty NUMERIC(12, 2) := 0.00;
    v_subtotal NUMERIC(14, 2) := 0.00;
    v_total_gst NUMERIC(14, 2) := 0.00;
    v_grand_total NUMERIC(14, 2) := 0.00;
    v_item JSONB;
    v_material_id UUID;
    v_material_name TEXT;
    v_unit TEXT;
    v_qty NUMERIC(12, 2);
    v_rate NUMERIC(12, 2);
    v_base NUMERIC(14, 2);
    v_gst_pct NUMERIC(5, 2);
    v_gst_amt NUMERIC(14, 2);
    v_final_price NUMERIC(14, 2);
BEGIN
    SELECT * INTO v_existing FROM public.sub_vendor_material_outwards WHERE id = p_outward_id FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Material Outward entry not found.';
    END IF;
    IF v_existing.status = 'Cancelled' THEN
        RAISE EXCEPTION 'Cannot edit a Cancelled Material Outward record.';
    END IF;

    SELECT name INTO v_vendor_name FROM public.sub_vendors WHERE id = p_vendor_id;
    IF v_vendor_name IS NULL THEN
        RAISE EXCEPTION 'Sub-Vendor not found.';
    END IF;

    DELETE FROM public.sub_vendor_material_outward_items WHERE outward_id = p_outward_id;

    FOR v_item IN SELECT * FROM jsonb_array_elements(p_items)
    LOOP
        v_material_id := NULLIF(v_item->>'material_id', '')::UUID;
        v_material_name := COALESCE(v_item->>'material_name', 'Unknown Material');
        v_unit := UPPER(COALESCE(v_item->>'unit', 'NOS'));
        v_qty := COALESCE((v_item->>'quantity')::NUMERIC, 0);
        v_rate := COALESCE((v_item->>'unit_rate')::NUMERIC, 0);
        v_gst_pct := COALESCE((v_item->>'gst_percentage')::NUMERIC, 0);

        IF v_qty <= 0 THEN
            RAISE EXCEPTION 'Quantity for "%" must be greater than zero.', v_material_name;
        END IF;

        v_base := ROUND(v_qty * v_rate, 2);
        v_gst_amt := ROUND(v_base * v_gst_pct / 100.0, 2);
        v_final_price := v_base + v_gst_amt;

        INSERT INTO public.sub_vendor_material_outward_items (
            outward_id, material_id, material_name, unit, quantity,
            unit_rate, base_amount, gst_percentage, gst_amount, total_price
        ) VALUES (
            p_outward_id, v_material_id, v_material_name, v_unit, v_qty,
            v_rate, v_base, v_gst_pct, v_gst_amt, v_final_price
        );

        v_total_items := v_total_items + 1;
        v_total_qty := v_total_qty + v_qty;
        v_subtotal := v_subtotal + v_base;
        v_total_gst := v_total_gst + v_gst_amt;
        v_grand_total := v_grand_total + v_final_price;
    END LOOP;

    UPDATE public.sub_vendor_material_outwards
    SET vendor_id = p_vendor_id,
        vendor_name = v_vendor_name,
        outward_date = p_outward_date,
        total_items = v_total_items,
        total_quantity = v_total_qty,
        subtotal = v_subtotal,
        total_gst = v_total_gst,
        total_value = v_grand_total,
        remarks = p_remarks,
        updated_at = timezone('utc'::text, now())
    WHERE id = p_outward_id;

    INSERT INTO public.sub_vendor_material_outward_audit (
        outward_id, outward_number, action, description, details, performed_by
    ) VALUES (
        p_outward_id,
        v_existing.outward_number,
        'UPDATE',
        format('Updated outward entry. New total qty: %s, grand total: %s', v_total_qty, v_grand_total),
        jsonb_build_object('subtotal', v_subtotal, 'total_gst', v_total_gst, 'grand_total', v_grand_total, 'items', p_items),
        p_updated_by
    );

    RETURN jsonb_build_object('success', true, 'id', p_outward_id, 'total_value', v_grand_total);
END;
$$;

-- 5. Atomic RPC: Cancel Outward Entry (NO Inventory Stock Modification)
CREATE OR REPLACE FUNCTION public.cancel_sub_vendor_material_outward(
    p_outward_id UUID,
    p_reason TEXT DEFAULT 'Cancelled by Admin',
    p_cancelled_by UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_existing RECORD;
BEGIN
    SELECT * INTO v_existing FROM public.sub_vendor_material_outwards WHERE id = p_outward_id FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Material Outward entry not found.';
    END IF;
    IF v_existing.status = 'Cancelled' THEN
        RAISE EXCEPTION 'Material Outward entry is already cancelled.';
    END IF;

    UPDATE public.sub_vendor_material_outwards
    SET status = 'Cancelled',
        cancelled_at = timezone('utc'::text, now()),
        cancelled_by = p_cancelled_by,
        cancellation_reason = p_reason,
        updated_at = timezone('utc'::text, now())
    WHERE id = p_outward_id;

    INSERT INTO public.sub_vendor_material_outward_audit (
        outward_id, outward_number, action, description, details, performed_by
    ) VALUES (
        p_outward_id,
        v_existing.outward_number,
        'CANCEL',
        format('Cancelled outward entry. Reason: %s', COALESCE(p_reason, 'None')),
        jsonb_build_object('reason', p_reason),
        p_cancelled_by
    );

    RETURN jsonb_build_object('success', true, 'id', p_outward_id);
END;
$$;
