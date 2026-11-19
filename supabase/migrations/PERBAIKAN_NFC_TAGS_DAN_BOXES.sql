-- =============================================================================
-- PERBAIKAN RLS PADA TABEL nfc_tags, savings_boxes, dan shipments
-- Agar Admin bisa menulis tag NFC, update status kotak, dan input resi pengiriman
-- =============================================================================

-- 1. Izin tabel nfc_tags
ALTER TABLE public.nfc_tags ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Member can view nfc tags for own boxes" ON public.nfc_tags;
DROP POLICY IF EXISTS "Admin can manage all nfc tags" ON public.nfc_tags;
DROP POLICY IF EXISTS "Admin can view nfc tags" ON public.nfc_tags;
DROP POLICY IF EXISTS "Admin can insert nfc tags" ON public.nfc_tags;
DROP POLICY IF EXISTS "Admin can update nfc tags" ON public.nfc_tags;

-- Member hanya boleh melihat tag untuk kotak miliknya
CREATE POLICY "Member can view nfc tags for own boxes"
  ON public.nfc_tags FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.savings_boxes sb
      WHERE sb.id = box_id AND sb.user_id = auth.uid()
    )
  );

-- Admin diizinkan SELECT, INSERT, UPDATE, DELETE tag NFC
CREATE POLICY "Admin can view nfc tags"
  ON public.nfc_tags FOR SELECT
  USING (public.is_admin());

CREATE POLICY "Admin can insert nfc tags"
  ON public.nfc_tags FOR INSERT
  WITH CHECK (public.is_admin());

CREATE POLICY "Admin can update nfc tags"
  ON public.nfc_tags FOR UPDATE
  USING (public.is_admin())
  WITH CHECK (public.is_admin());

-- 2. Izin tabel savings_boxes
ALTER TABLE public.savings_boxes ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Member can view own boxes" ON public.savings_boxes;
DROP POLICY IF EXISTS "Admin can view all boxes" ON public.savings_boxes;
DROP POLICY IF EXISTS "Admin can insert boxes" ON public.savings_boxes;
DROP POLICY IF EXISTS "Admin can update boxes" ON public.savings_boxes;
DROP POLICY IF EXISTS "Admin can manage boxes" ON public.savings_boxes;

CREATE POLICY "Member can view own boxes"
  ON public.savings_boxes FOR SELECT
  USING (user_id = auth.uid());

CREATE POLICY "Admin can view all boxes"
  ON public.savings_boxes FOR SELECT
  USING (public.is_admin());

CREATE POLICY "Admin can insert boxes"
  ON public.savings_boxes FOR INSERT
  WITH CHECK (public.is_admin());

CREATE POLICY "Admin can update boxes"
  ON public.savings_boxes FOR UPDATE
  USING (public.is_admin())
  WITH CHECK (public.is_admin());

-- 3. Izin tabel shipments
ALTER TABLE public.shipments ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Member can view own shipments" ON public.shipments;
DROP POLICY IF EXISTS "Admin can manage all shipments" ON public.shipments;
DROP POLICY IF EXISTS "Admin can view shipments" ON public.shipments;
DROP POLICY IF EXISTS "Admin can insert shipments" ON public.shipments;
DROP POLICY IF EXISTS "Admin can update shipments" ON public.shipments;

CREATE POLICY "Member can view own shipments"
  ON public.shipments FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.savings_boxes sb
      WHERE sb.id = box_id AND sb.user_id = auth.uid()
    )
  );

CREATE POLICY "Admin can view shipments"
  ON public.shipments FOR SELECT
  USING (public.is_admin());

CREATE POLICY "Admin can insert shipments"
  ON public.shipments FOR INSERT
  WITH CHECK (public.is_admin());

CREATE POLICY "Admin can update shipments"
  ON public.shipments FOR UPDATE
  USING (public.is_admin())
  WITH CHECK (public.is_admin());

-- 4. Reload schema cache PostgREST Supabase
NOTIFY pgrst, 'reload schema';
