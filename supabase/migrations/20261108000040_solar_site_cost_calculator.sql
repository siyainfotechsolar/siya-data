-- ==============================================================================
-- Migration: 20261108000040_solar_site_cost_calculator.sql
-- Module: SIYA SOLAR SITE COST CALCULATOR
-- Description:
--   1. Creates public.solar_site_cost_calculations table to store site-wise solar cost sheets.
--   2. Creates public.solar_cost_material_master table for default rates, specifications, and sizes.
--   3. Seeds initial standard material master records.
--   4. Configures Row Level Security (RLS) for Admin control and Staff access.
--   5. Reloads PostgREST schema cache.
-- ==============================================================================

-- 1. Create Solar Site Cost Calculations Table
CREATE TABLE IF NOT EXISTS public.solar_site_cost_calculations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    calculation_number TEXT NOT NULL UNIQUE,
    site_name TEXT NOT NULL,
    customer_name TEXT,
    system_capacity_kw NUMERIC(6, 2) NOT NULL DEFAULT 0.00,
    calculation_date DATE NOT NULL DEFAULT CURRENT_DATE,
    notes TEXT,

    -- Category Subtotals
    total_panel_cost NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    total_inverter_cost NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    total_gi_pipe_cost NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    total_structure_cost NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    total_bos_cost NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    total_other_material_cost NUMERIC(12, 2) NOT NULL DEFAULT 0.00,

    -- Labour Subtotals (Exactly 3 categories)
    wiring_labour_cost NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    structure_labour_cost NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    civil_labour_cost NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    total_labour_cost NUMERIC(12, 2) NOT NULL DEFAULT 0.00,

    -- Expense Subtotals
    transportation_cost NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    loading_unloading_cost NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    other_expenses_cost NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    total_other_expenses NUMERIC(12, 2) NOT NULL DEFAULT 0.00,

    -- Final Calculated Totals
    final_site_cost NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    cost_per_kw NUMERIC(12, 2) NOT NULL DEFAULT 0.00,

    -- Full Itemized JSONB Payload (Panels, Inverters, Pipes, BOS, Labour, Expenses)
    items_payload JSONB NOT NULL DEFAULT '{}'::jsonb,

    created_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE INDEX IF NOT EXISTS idx_sscc_site_name ON public.solar_site_cost_calculations (site_name);
CREATE INDEX IF NOT EXISTS idx_sscc_customer_name ON public.solar_site_cost_calculations (customer_name);
CREATE INDEX IF NOT EXISTS idx_sscc_calc_number ON public.solar_site_cost_calculations (calculation_number);
CREATE INDEX IF NOT EXISTS idx_sscc_calc_date ON public.solar_site_cost_calculations (calculation_date DESC);

-- 2. Create Solar Cost Material Master Table
CREATE TABLE IF NOT EXISTS public.solar_cost_material_master (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    category TEXT NOT NULL CHECK (category IN ('PANEL', 'INVERTER', 'GI_PIPE', 'STRUCTURE', 'BOS', 'LABOUR', 'EXPENSE', 'OTHER')),
    item_name TEXT NOT NULL,
    specification TEXT,
    unit TEXT NOT NULL DEFAULT 'NOS',
    default_rate NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    default_weight_per_unit NUMERIC(8, 2) NOT NULL DEFAULT 0.00, -- KG per pipe or item
    default_length_feet NUMERIC(8, 2) NOT NULL DEFAULT 20.00,    -- 20 Feet standard for pipes
    display_order INT NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE INDEX IF NOT EXISTS idx_scmm_category ON public.solar_cost_material_master (category);
CREATE INDEX IF NOT EXISTS idx_scmm_item_name ON public.solar_cost_material_master (item_name);

-- 3. Seed Standard Materials and Sizes (Safe upsert)
INSERT INTO public.solar_cost_material_master (category, item_name, specification, unit, default_rate, default_weight_per_unit, default_length_feet, display_order)
VALUES
    -- GI Pipes (Size-wise with default KG weight per standard 20ft pipe)
    ('GI_PIPE', 'GI Pipe 40x40 mm', '40x40 mm Sq. Pipe (1.6mm Thk, 20 Ft)', 'KG', 85.00, 8.00, 20.00, 1),
    ('GI_PIPE', 'GI Pipe 80x40 mm', '80x40 mm Rect. Pipe (2.0mm Thk, 20 Ft)', 'KG', 90.00, 12.00, 20.00, 2),
    ('GI_PIPE', 'GI Pipe 40x20 mm', '40x20 mm Rect. Pipe (1.6mm Thk, 20 Ft)', 'KG', 80.00, 6.00, 20.00, 3),
    ('GI_PIPE', 'GI Pipe 50x50 mm', '50x50 mm Sq. Pipe (2.0mm Thk, 20 Ft)', 'KG', 88.00, 10.00, 20.00, 4),
    ('GI_PIPE', 'Custom Size GI Pipe', 'Custom GI Pipe', 'KG', 85.00, 8.00, 20.00, 5),

    -- Solar Panels
    ('PANEL', 'Mono PERC 550W', '550 Watt Mono PERC Panel', 'WATT', 18.00, 0.00, 0.00, 10),
    ('PANEL', 'TopCon 575W', '575 Watt Bifacial TopCon Panel', 'WATT', 19.50, 0.00, 0.00, 11),
    ('PANEL', 'Mono PERC 600W', '600 Watt Mono PERC Panel', 'WATT', 20.00, 0.00, 0.00, 12),

    -- Inverters (Fixed Cost)
    ('INVERTER', '3.3 kW On-Grid Inverter', 'Single Phase 3.3 kW Dual MPPT', 'FIXED', 25000.00, 0.00, 0.00, 20),
    ('INVERTER', '5.0 kW On-Grid Inverter', 'Single Phase / 3 Phase 5 kW', 'FIXED', 38000.00, 0.00, 0.00, 21),
    ('INVERTER', '6.0 kW On-Grid Inverter', 'Three Phase 6 kW', 'FIXED', 45000.00, 0.00, 0.00, 22),
    ('INVERTER', '10.0 kW On-Grid Inverter', 'Three Phase 10 kW', 'FIXED', 65000.00, 0.00, 0.00, 23),

    -- Other Structure Material
    ('STRUCTURE', 'Purlin', 'GI Purlin Channel', 'KG', 85.00, 0.00, 0.00, 30),
    ('STRUCTURE', 'C Channel', 'C-Section Channel', 'KG', 85.00, 0.00, 0.00, 31),
    ('STRUCTURE', 'Rail', 'Aluminum / GI Rail', 'METER', 180.00, 0.00, 0.00, 32),
    ('STRUCTURE', 'Mid Clamp', 'Aluminum Mid Clamp with SS Bolt', 'NOS', 25.00, 0.00, 0.00, 33),
    ('STRUCTURE', 'End Clamp', 'Aluminum End Clamp with SS Bolt', 'NOS', 25.00, 0.00, 0.00, 34),
    ('STRUCTURE', 'L Clamp', 'L-Feet Bracket', 'NOS', 40.00, 0.00, 0.00, 35),
    ('STRUCTURE', 'Nut & Bolt', 'SS 304 Hardware Set', 'NOS', 12.00, 0.00, 0.00, 36),
    ('STRUCTURE', 'Base Plate', 'Base Plate with Anchor Fasteners', 'NOS', 150.00, 0.00, 0.00, 37),
    ('STRUCTURE', 'Other Structure Material', 'Misc. Structural Fasteners', 'FIXED', 0.00, 0.00, 0.00, 38),

    -- Electrical BOS Material
    ('BOS', 'ACDB', 'AC Distribution Box 1P / 3P', 'FIXED', 2500.00, 0.00, 0.00, 40),
    ('BOS', 'DCDB', 'DC Distribution Box 1000V with SPD & Fuse', 'FIXED', 2200.00, 0.00, 0.00, 41),
    ('BOS', 'DC Cable 4 sq mm', 'Solar UV Protected DC Cable', 'METER', 35.00, 0.00, 0.00, 42),
    ('BOS', 'AC Cable 4 sq mm', 'Copper 3-Core Armoured AC Cable', 'METER', 65.00, 0.00, 0.00, 43),
    ('BOS', 'Earthing Kit', 'Chemical Earthing Electrode + BFC Compound', 'SET', 3500.00, 0.00, 0.00, 44),
    ('BOS', 'Earthing Cable', 'Copper / GI Earthing Strip / Wire', 'METER', 45.00, 0.00, 0.00, 45),
    ('BOS', 'Lightning Arrester', 'ESE / Conventional Copper LA', 'NOS', 1500.00, 0.00, 0.00, 46),
    ('BOS', 'MC4 Connector', 'IP68 MC4 Male/Female Pair', 'NOS', 50.00, 0.00, 0.00, 47),
    ('BOS', 'Conduit Pipe', 'PVC Heavy Gauge Pipe', 'METER', 25.00, 0.00, 0.00, 48),
    ('BOS', 'Cable Tray', 'Perforated GI Cable Tray', 'METER', 120.00, 0.00, 0.00, 49),
    ('BOS', 'Other BOS Material', 'Electrical Consumables', 'FIXED', 0.00, 0.00, 0.00, 50),

    -- Labour (Exactly 3 categories)
    ('LABOUR', 'Wiring Labour', 'AC, DC & Inverter Cable Wiring', 'FIXED', 6000.00, 0.00, 0.00, 60),
    ('LABOUR', 'Structure Labour', 'Module Mounting Structure Erection', 'FIXED', 7000.00, 0.00, 0.00, 61),
    ('LABOUR', 'Civil Labour', 'Foundation & Civil Concrete Work', 'FIXED', 5500.00, 0.00, 0.00, 62),

    -- Expenses
    ('EXPENSE', 'Transportation', 'Site Freight & Transport Charges', 'FIXED', 3000.00, 0.00, 0.00, 70),
    ('EXPENSE', 'Loading / Unloading', 'Loading and Material Unloading at Site', 'FIXED', 500.00, 0.00, 0.00, 71),
    ('EXPENSE', 'Other Expenses', 'Miscellaneous On-site Contingencies', 'FIXED', 1000.00, 0.00, 0.00, 72)
ON CONFLICT DO NOTHING;

-- 4. Enable Row Level Security (RLS)
ALTER TABLE public.solar_site_cost_calculations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.solar_cost_material_master ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Admin full control on solar site cost calculations" ON public.solar_site_cost_calculations;
DROP POLICY IF EXISTS "Staff can read solar site cost calculations" ON public.solar_site_cost_calculations;
DROP POLICY IF EXISTS "Admin full control on solar cost material master" ON public.solar_cost_material_master;
DROP POLICY IF EXISTS "Staff can read solar cost material master" ON public.solar_cost_material_master;

CREATE POLICY "Admin full control on solar site cost calculations"
    ON public.solar_site_cost_calculations FOR ALL TO authenticated
    USING ((SELECT public.is_admin()) OR (auth.jwt()->>'role') IN ('admin', 'super_admin'))
    WITH CHECK ((SELECT public.is_admin()) OR (auth.jwt()->>'role') IN ('admin', 'super_admin'));

CREATE POLICY "Staff can read solar site cost calculations"
    ON public.solar_site_cost_calculations FOR SELECT TO authenticated
    USING (true);

CREATE POLICY "Admin full control on solar cost material master"
    ON public.solar_cost_material_master FOR ALL TO authenticated
    USING ((SELECT public.is_admin()) OR (auth.jwt()->>'role') IN ('admin', 'super_admin'))
    WITH CHECK ((SELECT public.is_admin()) OR (auth.jwt()->>'role') IN ('admin', 'super_admin'));

CREATE POLICY "Staff can read solar cost material master"
    ON public.solar_cost_material_master FOR SELECT TO authenticated
    USING (true);

-- 5. Grants & Schema Cache Reload
GRANT ALL ON public.solar_site_cost_calculations TO authenticated, anon, service_role;
GRANT ALL ON public.solar_cost_material_master TO authenticated, anon, service_role;

NOTIFY pgrst, 'reload schema';

