-- ==============================================================================
-- Migration: 20261125000046_sub_vendor_material_outward_tracking.sql
-- Module: SUB VENDOR MATERIAL OUTWARD TRACKING & INVENTORY DEDUCTION
-- Description:
--   1. Adds 'available_stock' to public.solar_cost_material_master.
--   2. Creates public.sub_vendor_material_outwards (Outward Transaction Header).
--   3. Creates public.sub_vendor_material_outward_items (Outward Line Items).
--   4. Creates public.sub_vendor_material_outward_audit (Audit trail for create/edit/cancel).
--   5. Implements atomic RPCs:
--        - record_sub_vendor_material_outward (bulk insert + stock deduction)
--        - update_sub_vendor_material_outward (reverse old stock + apply new stock)
--        - cancel_sub_vendor_material_outward (restore stock + mark cancelled)
--   6. Configures Row Level Security (RLS) policies and indexes.
-- ==============================================================================

-- 1. Ensure available_stock column exists on Material Master
ALTER TABLE public.solar_cost_material_master 
ADD COLUMN IF NOT EXISTS available_stock NUMERIC(12, 2) NOT NULL DEFAULT 500.00;

-- Ensure default stock is set for existing rows
UPDATE public.solar_cost_material_master 
SET available_stock = 500.00 
WHERE available_stock IS NULL OR available_stock <= 0;

-- 2. Create Sub-Vendor Material Outward Header Table
CREATE TABLE IF NOT EXISTS public.sub_vendor_material_outwards (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    outward_number TEXT NOT NULL UNIQUE,
    vendor_id UUID NOT NULL REFERENCES public.sub_vendors(id) ON DELETE RESTRICT,
    vendor_name TEXT NOT NULL,
    outward_date DATE NOT NULL DEFAULT CURRENT_DATE,
    total_items INT NOT NULL DEFAULT 0 CHECK (total_items >= 0),
    total_quantity NUMERIC(12, 2) NOT NULL DEFAULT 0.00 CHECK (total_quantity >= 0),
    remarks TEXT,
    status TEXT NOT NULL DEFAULT 'Active' CHECK (status IN ('Active', 'Cancelled')),
    cancelled_at TIMESTAMPTZ,
    cancelled_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    cancellation_reason TEXT,
    created_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE INDEX IF NOT EXISTS idx_svmo_vendor_id ON public.sub_vendor_material_outwards (vendor_id);
CREATE INDEX IF NOT EXISTS idx_svmo_outward_date ON public.sub_vendor_material_outwards (outward_date DESC);
CREATE INDEX IF NOT EXISTS idx_svmo_outward_number ON public.sub_vendor_material_outwards (outward_number);
CREATE INDEX IF NOT EXISTS idx_svmo_status ON public.sub_vendor_material_outwards (status);

-- 3. Create Sub-Vendor Material Outward Items Table (Line Items)
CREATE TABLE IF NOT EXISTS public.sub_vendor_material_outward_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    outward_id UUID NOT NULL REFERENCES public.sub_vendor_material_outwards(id) ON DELETE CASCADE,
    material_id UUID REFERENCES public.solar_cost_material_master(id) ON DELETE RESTRICT,
    material_name TEXT NOT NULL,
    unit TEXT NOT NULL DEFAULT 'NOS',
    quantity NUMERIC(12, 2) NOT NULL CHECK (quantity > 0),
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE INDEX IF NOT EXISTS idx_svmoi_outward_id ON public.sub_vendor_material_outward_items (outward_id);
CREATE INDEX IF NOT EXISTS idx_svmoi_material_id ON public.sub_vendor_material_outward_items (material_id);

-- 4. Create Audit Trail Table
CREATE TABLE IF NOT EXISTS public.sub_vendor_material_outward_audit (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    outward_id UUID NOT NULL REFERENCES public.sub_vendor_material_outwards(id) ON DELETE CASCADE,
    outward_number TEXT NOT NULL,
    action TEXT NOT NULL CHECK (action IN ('CREATE', 'UPDATE', 'CANCEL')),
    description TEXT NOT NULL,
    details JSONB NOT NULL DEFAULT '{}'::jsonb,
    performed_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE INDEX IF NOT EXISTS idx_svmoa_outward_id ON public.sub_vendor_material_outward_audit (outward_id);
CREATE INDEX IF NOT EXISTS idx_svmoa_created_at ON public.sub_vendor_material_outward_audit (created_at DESC);

-- 5. Atomic RPC: Record Outward Entry + Deduct Inventory Stock
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
    v_item JSONB;
    v_material_id UUID;
    v_material_name TEXT;
    v_unit TEXT;
    v_qty NUMERIC(12, 2);
    v_available NUMERIC(12, 2);
    v_seq_val INT;
BEGIN
    -- 1. Validate Sub-Vendor
    SELECT name INTO v_vendor_name FROM public.sub_vendors WHERE id = p_vendor_id;
    IF v_vendor_name IS NULL THEN
        RAISE EXCEPTION 'Sub-Vendor with ID % not found.', p_vendor_id;
    END IF;

    -- 2. Validate Items Array
    IF p_items IS NULL OR jsonb_array_length(p_items) = 0 THEN
        RAISE EXCEPTION 'Material Outward entry must contain at least one material row.';
    END IF;

    -- 3. Check stock availability for all items first
    FOR v_item IN SELECT * FROM jsonb_array_elements(p_items)
    LOOP
        v_material_id := (v_item->>'material_id')::UUID;
        v_qty := (v_item->>'quantity')::NUMERIC;

        IF v_qty IS NULL OR v_qty <= 0 THEN
            RAISE EXCEPTION 'Material quantity must be greater than zero.';
        END IF;

        IF v_material_id IS NOT NULL THEN
            SELECT available_stock, item_name INTO v_available, v_material_name
            FROM public.solar_cost_material_master
            WHERE id = v_material_id
            FOR UPDATE; -- lock row to prevent race conditions

            IF v_available IS NULL THEN
                RAISE EXCEPTION 'Material with ID % not found in master.', v_material_id;
            END IF;

            IF v_qty > v_available THEN
                RAISE EXCEPTION 'Insufficient stock for "%". Available: %, Requested: %', v_material_name, v_available, v_qty;
            END IF;
        END IF;

        v_total_items := v_total_items + 1;
        v_total_qty := v_total_qty + v_qty;
    END LOOP;

    -- 4. Generate Unique Outward Number: OUT-YYYYMMDD-XXXX
    SELECT COUNT(*) + 1 INTO v_seq_val
    FROM public.sub_vendor_material_outwards
    WHERE outward_date = p_outward_date;

    v_outward_number := 'OUT-' || to_char(p_outward_date, 'YYYYMMDD') || '-' || lpad(v_seq_val::TEXT, 4, '0');

    -- Ensure uniqueness in case of collisions
    WHILE EXISTS (SELECT 1 FROM public.sub_vendor_material_outwards WHERE outward_number = v_outward_number) LOOP
        v_seq_val := v_seq_val + 1;
        v_outward_number := 'OUT-' || to_char(p_outward_date, 'YYYYMMDD') || '-' || lpad(v_seq_val::TEXT, 4, '0');
    END LOOP;

    -- 5. Insert Header
    INSERT INTO public.sub_vendor_material_outwards (
        outward_number,
        vendor_id,
        vendor_name,
        outward_date,
        total_items,
        total_quantity,
        remarks,
        status,
        created_by
    ) VALUES (
        v_outward_number,
        p_vendor_id,
        v_vendor_name,
        p_outward_date,
        v_total_items,
        v_total_qty,
        p_remarks,
        'Active',
        p_created_by
    ) RETURNING id INTO v_outward_id;

    -- 6. Insert Items & Deduct Stock
    FOR v_item IN SELECT * FROM jsonb_array_elements(p_items)
    LOOP
        v_material_id := (v_item->>'material_id')::UUID;
        v_material_name := v_item->>'material_name';
        v_unit := COALESCE(v_item->>'unit', 'NOS');
        v_qty := (v_item->>'quantity')::NUMERIC;

        INSERT INTO public.sub_vendor_material_outward_items (
            outward_id,
            material_id,
            material_name,
            unit,
            quantity
        ) VALUES (
            v_outward_id,
            v_material_id,
            v_material_name,
            v_unit,
            v_qty
        );

        -- Deduct stock from Main Inventory
        IF v_material_id IS NOT NULL THEN
            UPDATE public.solar_cost_material_master
            SET available_stock = available_stock - v_qty,
                updated_at = timezone('utc'::text, now())
            WHERE id = v_material_id;
        END IF;
    END LOOP;

    -- 7. Record Audit Trail
    INSERT INTO public.sub_vendor_material_outward_audit (
        outward_id,
        outward_number,
        action,
        description,
        details,
        performed_by
    ) VALUES (
        v_outward_id,
        v_outward_number,
        'CREATE',
        'Created outward entry with ' || v_total_items::TEXT || ' materials, total quantity: ' || v_total_qty::TEXT,
        jsonb_build_object('items', p_items, 'vendor_name', v_vendor_name, 'outward_date', p_outward_date),
        p_created_by
    );

    RETURN jsonb_build_object(
        'success', true,
        'id', v_outward_id,
        'outward_number', v_outward_number,
        'total_items', v_total_items,
        'total_quantity', v_total_qty
    );
END;
$$;

-- 6. Atomic RPC: Update Outward Entry + Reverse Old Stock & Apply New Stock
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
    v_old_status TEXT;
    v_outward_number TEXT;
    v_vendor_name TEXT;
    v_total_items INT := 0;
    v_total_qty NUMERIC(12, 2) := 0.00;
    v_old_item RECORD;
    v_item JSONB;
    v_material_id UUID;
    v_material_name TEXT;
    v_unit TEXT;
    v_qty NUMERIC(12, 2);
    v_available NUMERIC(12, 2);
BEGIN
    -- 1. Check existing record
    SELECT status, outward_number INTO v_old_status, v_outward_number
    FROM public.sub_vendor_material_outwards
    WHERE id = p_outward_id
    FOR UPDATE;

    IF v_old_status IS NULL THEN
        RAISE EXCEPTION 'Material Outward record % not found.', p_outward_id;
    END IF;

    IF v_old_status = 'Cancelled' THEN
        RAISE EXCEPTION 'Cannot edit a Cancelled Material Outward record.';
    END IF;

    -- 2. Validate Sub-Vendor
    SELECT name INTO v_vendor_name FROM public.sub_vendors WHERE id = p_vendor_id;
    IF v_vendor_name IS NULL THEN
        RAISE EXCEPTION 'Sub-Vendor with ID % not found.', p_vendor_id;
    END IF;

    IF p_items IS NULL OR jsonb_array_length(p_items) = 0 THEN
        RAISE EXCEPTION 'Material Outward entry must contain at least one material row.';
    END IF;

    -- 3. REVERSE OLD STOCK: Restore stock for all previous items in this outward
    FOR v_old_item IN 
        SELECT material_id, quantity 
        FROM public.sub_vendor_material_outward_items 
        WHERE outward_id = p_outward_id AND material_id IS NOT NULL
    LOOP
        UPDATE public.solar_cost_material_master
        SET available_stock = available_stock + v_old_item.quantity,
            updated_at = timezone('utc'::text, now())
        WHERE id = v_old_item.material_id;
    END LOOP;

    -- 4. VALIDATE & DEDUCT NEW STOCK
    FOR v_item IN SELECT * FROM jsonb_array_elements(p_items)
    LOOP
        v_material_id := (v_item->>'material_id')::UUID;
        v_qty := (v_item->>'quantity')::NUMERIC;

        IF v_qty IS NULL OR v_qty <= 0 THEN
            RAISE EXCEPTION 'Material quantity must be greater than zero.';
        END IF;

        IF v_material_id IS NOT NULL THEN
            SELECT available_stock, item_name INTO v_available, v_material_name
            FROM public.solar_cost_material_master
            WHERE id = v_material_id
            FOR UPDATE;

            IF v_qty > v_available THEN
                RAISE EXCEPTION 'Insufficient stock for "%". Available: %, Requested: %', v_material_name, v_available, v_qty;
            END IF;
        END IF;

        v_total_items := v_total_items + 1;
        v_total_qty := v_total_qty + v_qty;
    END LOOP;

    -- 5. Delete old items and insert updated items
    DELETE FROM public.sub_vendor_material_outward_items WHERE outward_id = p_outward_id;

    FOR v_item IN SELECT * FROM jsonb_array_elements(p_items)
    LOOP
        v_material_id := (v_item->>'material_id')::UUID;
        v_material_name := v_item->>'material_name';
        v_unit := COALESCE(v_item->>'unit', 'NOS');
        v_qty := (v_item->>'quantity')::NUMERIC;

        INSERT INTO public.sub_vendor_material_outward_items (
            outward_id,
            material_id,
            material_name,
            unit,
            quantity
        ) VALUES (
            p_outward_id,
            v_material_id,
            v_material_name,
            v_unit,
            v_qty
        );

        -- Apply new deduction
        IF v_material_id IS NOT NULL THEN
            UPDATE public.solar_cost_material_master
            SET available_stock = available_stock - v_qty,
                updated_at = timezone('utc'::text, now())
            WHERE id = v_material_id;
        END IF;
    END LOOP;

    -- 6. Update Header
    UPDATE public.sub_vendor_material_outwards
    SET vendor_id = p_vendor_id,
        vendor_name = v_vendor_name,
        outward_date = p_outward_date,
        total_items = v_total_items,
        total_quantity = v_total_qty,
        remarks = p_remarks,
        updated_at = timezone('utc'::text, now())
    WHERE id = p_outward_id;

    -- 7. Audit Log
    INSERT INTO public.sub_vendor_material_outward_audit (
        outward_id,
        outward_number,
        action,
        description,
        details,
        performed_by
    ) VALUES (
        p_outward_id,
        v_outward_number,
        'UPDATE',
        'Updated outward entry: reversed old stock and applied new quantities. New Total Qty: ' || v_total_qty::TEXT,
        jsonb_build_object('items', p_items, 'vendor_name', v_vendor_name, 'outward_date', p_outward_date),
        p_updated_by
    );

    RETURN jsonb_build_object(
        'success', true,
        'id', p_outward_id,
        'outward_number', v_outward_number,
        'total_items', v_total_items,
        'total_quantity', v_total_qty
    );
END;
$$;

-- 7. Atomic RPC: Cancel Outward Entry + Restore Deducted Stock
CREATE OR REPLACE FUNCTION public.cancel_sub_vendor_material_outward(
    p_outward_id UUID,
    p_cancellation_reason TEXT DEFAULT 'Cancelled by Admin',
    p_cancelled_by UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_old_status TEXT;
    v_outward_number TEXT;
    v_item RECORD;
BEGIN
    SELECT status, outward_number INTO v_old_status, v_outward_number
    FROM public.sub_vendor_material_outwards
    WHERE id = p_outward_id
    FOR UPDATE;

    IF v_old_status IS NULL THEN
        RAISE EXCEPTION 'Material Outward record % not found.', p_outward_id;
    END IF;

    IF v_old_status = 'Cancelled' THEN
        RAISE EXCEPTION 'Record is already cancelled.';
    END IF;

    -- 1. Restore stock to inventory
    FOR v_item IN 
        SELECT material_id, quantity 
        FROM public.sub_vendor_material_outward_items 
        WHERE outward_id = p_outward_id AND material_id IS NOT NULL
    LOOP
        UPDATE public.solar_cost_material_master
        SET available_stock = available_stock + v_item.quantity,
            updated_at = timezone('utc'::text, now())
        WHERE id = v_item.material_id;
    END LOOP;

    -- 2. Mark as Cancelled
    UPDATE public.sub_vendor_material_outwards
    SET status = 'Cancelled',
        cancelled_at = timezone('utc'::text, now()),
        cancelled_by = p_cancelled_by,
        cancellation_reason = p_cancellation_reason,
        updated_at = timezone('utc'::text, now())
    WHERE id = p_outward_id;

    -- 3. Audit Log
    INSERT INTO public.sub_vendor_material_outward_audit (
        outward_id,
        outward_number,
        action,
        description,
        details,
        performed_by
    ) VALUES (
        p_outward_id,
        v_outward_number,
        'CANCEL',
        'Cancelled outward entry and restored stock: ' || p_cancellation_reason,
        jsonb_build_object('cancellation_reason', p_cancellation_reason),
        p_cancelled_by
    );

    RETURN jsonb_build_object(
        'success', true,
        'id', p_outward_id,
        'outward_number', v_outward_number,
        'status', 'Cancelled'
    );
END;
$$;

-- 8. Row Level Security (RLS)
ALTER TABLE public.sub_vendor_material_outwards ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sub_vendor_material_outward_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sub_vendor_material_outward_audit ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Admin full control on sub_vendor_material_outwards" ON public.sub_vendor_material_outwards;
DROP POLICY IF EXISTS "Staff can read sub_vendor_material_outwards" ON public.sub_vendor_material_outwards;

CREATE POLICY "Admin full control on sub_vendor_material_outwards"
    ON public.sub_vendor_material_outwards FOR ALL TO authenticated
    USING ((SELECT public.is_admin()) OR (auth.jwt()->>'role') IN ('admin', 'super_admin'))
    WITH CHECK ((SELECT public.is_admin()) OR (auth.jwt()->>'role') IN ('admin', 'super_admin'));

CREATE POLICY "Staff can read sub_vendor_material_outwards"
    ON public.sub_vendor_material_outwards FOR SELECT TO authenticated
    USING (true);

DROP POLICY IF EXISTS "Admin full control on sub_vendor_material_outward_items" ON public.sub_vendor_material_outward_items;
DROP POLICY IF EXISTS "Staff can read sub_vendor_material_outward_items" ON public.sub_vendor_material_outward_items;

CREATE POLICY "Admin full control on sub_vendor_material_outward_items"
    ON public.sub_vendor_material_outward_items FOR ALL TO authenticated
    USING ((SELECT public.is_admin()) OR (auth.jwt()->>'role') IN ('admin', 'super_admin'))
    WITH CHECK ((SELECT public.is_admin()) OR (auth.jwt()->>'role') IN ('admin', 'super_admin'));

CREATE POLICY "Staff can read sub_vendor_material_outward_items"
    ON public.sub_vendor_material_outward_items FOR SELECT TO authenticated
    USING (true);

DROP POLICY IF EXISTS "Admin full control on sub_vendor_material_outward_audit" ON public.sub_vendor_material_outward_audit;
DROP POLICY IF EXISTS "Staff can read sub_vendor_material_outward_audit" ON public.sub_vendor_material_outward_audit;

CREATE POLICY "Admin full control on sub_vendor_material_outward_audit"
    ON public.sub_vendor_material_outward_audit FOR ALL TO authenticated
    USING ((SELECT public.is_admin()) OR (auth.jwt()->>'role') IN ('admin', 'super_admin'))
    WITH CHECK ((SELECT public.is_admin()) OR (auth.jwt()->>'role') IN ('admin', 'super_admin'));

CREATE POLICY "Staff can read sub_vendor_material_outward_audit"
    ON public.sub_vendor_material_outward_audit FOR SELECT TO authenticated
    USING (true);

-- 9. Permissions & PostgREST Cache Reload
GRANT ALL ON public.sub_vendor_material_outwards TO authenticated, anon, service_role;
GRANT ALL ON public.sub_vendor_material_outward_items TO authenticated, anon, service_role;
GRANT ALL ON public.sub_vendor_material_outward_audit TO authenticated, anon, service_role;
GRANT EXECUTE ON FUNCTION public.record_sub_vendor_material_outward TO authenticated, anon, service_role;
GRANT EXECUTE ON FUNCTION public.update_sub_vendor_material_outward TO authenticated, anon, service_role;
GRANT EXECUTE ON FUNCTION public.cancel_sub_vendor_material_outward TO authenticated, anon, service_role;

NOTIFY pgrst, 'reload schema';
