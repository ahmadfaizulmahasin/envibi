-- =============================================================================
-- PERBAIKAN INFINITE RECURSION RLS PADA user_roles & profiles & account_applications
-- Berhasil diuji dan aktif di database
-- =============================================================================

-- 1. Hapus fungsi is_admin lama agar tidak ada duplikasi fungsi
DROP FUNCTION IF EXISTS public.is_admin() CASCADE;
DROP FUNCTION IF EXISTS public.is_admin(uuid) CASCADE;

-- 2. Buat kembali fungsi is_admin dengan parameter opsional dan SECURITY DEFINER
CREATE OR REPLACE FUNCTION public.is_admin(uid UUID DEFAULT auth.uid())
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.user_roles
    WHERE user_id = uid AND role IN ('ADMIN', 'SUPER_ADMIN')
  );
$$;

-- 3. Bersihkan dan perbaiki RLS pada user_roles (bebas infinite recursion)
DROP POLICY IF EXISTS "User can view own roles" ON public.user_roles;
DROP POLICY IF EXISTS "Admin can view all roles" ON public.user_roles;
DROP POLICY IF EXISTS "Only super admin can manage roles" ON public.user_roles;

CREATE POLICY "User can view own roles"
  ON public.user_roles FOR SELECT
  USING (user_id = auth.uid() OR public.is_admin());

-- 4. Perbaiki RLS pada profiles
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

-- 5. Perbaiki RLS pada account_applications
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
