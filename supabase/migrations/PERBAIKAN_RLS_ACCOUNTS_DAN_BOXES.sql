-- =============================================================================
-- PASTIKAN RLS PADA ACCOUNTS & SAVINGS_BOXES BISA DIBACA LENGKAP OLEH ADMIN
-- Jalankan ini di Supabase SQL Editor
-- =============================================================================

-- 1. Izin tabel accounts
ALTER TABLE public.accounts ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Member can view own accounts" ON public.accounts;
DROP POLICY IF EXISTS "Admin can view all accounts" ON public.accounts;
DROP POLICY IF EXISTS "Admin can manage accounts" ON public.accounts;

CREATE POLICY "Member can view own accounts"
  ON public.accounts FOR SELECT
  USING (user_id = auth.uid());

CREATE POLICY "Admin can view all accounts"
  ON public.accounts FOR SELECT
  USING (public.is_admin());

CREATE POLICY "Admin can manage accounts"
  ON public.accounts FOR ALL
  USING (public.is_admin());

-- 2. Izin tabel savings_boxes
ALTER TABLE public.savings_boxes ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Member can view own boxes" ON public.savings_boxes;
DROP POLICY IF EXISTS "Admin can view all boxes" ON public.savings_boxes;
DROP POLICY IF EXISTS "Admin can manage boxes" ON public.savings_boxes;

CREATE POLICY "Member can view own boxes"
  ON public.savings_boxes FOR SELECT
  USING (user_id = auth.uid());

CREATE POLICY "Admin can view all boxes"
  ON public.savings_boxes FOR SELECT
  USING (public.is_admin());

CREATE POLICY "Admin can manage boxes"
  ON public.savings_boxes FOR ALL
  USING (public.is_admin());

-- 3. Muat Ulang Schema Cache
NOTIFY pgrst, 'reload schema';
