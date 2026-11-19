-- =============================================================================
-- PERBAIKAN INFINITE RECURSION RLS PADA user_roles
-- Jalankan ini di Supabase SQL Editor
-- =============================================================================

-- 1. Buat fungsi helper is_admin dengan SECURITY DEFINER
-- SECURITY DEFINER membuat fungsi ini membypass RLS sehingga TIDAK memicu rekursi tak hingga
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.user_roles
    WHERE user_id = auth.uid() AND role IN ('ADMIN', 'SUPER_ADMIN')
  );
$$;

-- 2. Bersihkan dan perbaiki RLS pada user_roles
DROP POLICY IF EXISTS "User can view own roles" ON public.user_roles;
DROP POLICY IF EXISTS "Admin can view all roles" ON public.user_roles;
DROP POLICY IF EXISTS "Only super admin can manage roles" ON public.user_roles;

-- Untuk tabel user_roles, cukup izinkan user membaca rolenya sendiri.
-- Admin tetap bisa membaca semua via service role atau via is_admin() bypass definer.
CREATE POLICY "User can view own roles"
  ON public.user_roles FOR SELECT
  USING (user_id = auth.uid() OR public.is_admin());

-- 3. Perbaiki RLS pada profiles menggunakan fungsi is_admin() yang bebas rekursi
DROP POLICY IF EXISTS "Member can view own profile" ON public.profiles;
DROP POLICY IF EXISTS "Member can update own profile" ON public.profiles;
DROP POLICY IF EXISTS "Admin can view all profiles" ON public.profiles;
DROP POLICY IF EXISTS "Admin can update all profiles" ON public.profiles;

CREATE POLICY "Member can view own profile"
  ON public.profiles FOR SELECT
  USING (id = auth.uid() OR public.is_admin());

CREATE POLICY "Member can update own profile"
  ON public.profiles FOR UPDATE
  USING (id = auth.uid() OR public.is_admin())
  WITH CHECK (id = auth.uid() OR public.is_admin());

-- 4. Perbaiki RLS pada account_applications menggunakan fungsi is_admin()
DROP POLICY IF EXISTS "Member can view own applications" ON public.account_applications;
DROP POLICY IF EXISTS "Member can create own applications" ON public.account_applications;
DROP POLICY IF EXISTS "Admin can view all applications" ON public.account_applications;
DROP POLICY IF EXISTS "Admin can update applications" ON public.account_applications;

CREATE POLICY "Member can view own applications"
  ON public.account_applications FOR SELECT
  USING (user_id = auth.uid() OR public.is_admin());

CREATE POLICY "Member can create own applications"
  ON public.account_applications FOR INSERT
  WITH CHECK (user_id = auth.uid());

CREATE POLICY "Admin can update applications"
  ON public.account_applications FOR UPDATE
  USING (public.is_admin());
