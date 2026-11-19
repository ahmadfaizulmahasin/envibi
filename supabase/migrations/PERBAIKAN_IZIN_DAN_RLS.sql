-- =============================================================================
-- FIX DATABASE PERMISSIONS & ROLES FOR SUPABASE (ANON & AUTHENTICATED)
-- Jalankan file ini langsung di Supabase SQL Editor!
-- =============================================================================

-- 1. Berikan hak akses schema public
GRANT USAGE ON SCHEMA public TO postgres, anon, authenticated, service_role;

-- 2. Berikan hak akses tabel ke role anon dan authenticated
-- (Akses baris data tetap dijaga ketat oleh Row Level Security / RLS)
GRANT ALL ON ALL TABLES IN SCHEMA public TO postgres, anon, authenticated, service_role;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO postgres, anon, authenticated, service_role;
GRANT ALL ON ALL ROUTINES IN SCHEMA public TO postgres, anon, authenticated, service_role;

-- 3. Pastikan tabel yang dibuat di masa mendatang otomatis mendapatkan hak akses ini
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO postgres, anon, authenticated, service_role;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO postgres, anon, authenticated, service_role;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON ROUTINES TO postgres, anon, authenticated, service_role;

-- 4. Pastikan RLS Aktif di tabel-tabel utama
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_roles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.account_applications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.accounts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.savings_boxes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.nfc_tags ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.transactions ENABLE ROW LEVEL SECURITY;

-- 5. Kebijakan RLS untuk profiles (agar user bisa baca dan update profil miliknya)
DROP POLICY IF EXISTS "Member can view own profile" ON public.profiles;
DROP POLICY IF EXISTS "Member can update own profile" ON public.profiles;
DROP POLICY IF EXISTS "Admin can view all profiles" ON public.profiles;
DROP POLICY IF EXISTS "Admin can update all profiles" ON public.profiles;
DROP POLICY IF EXISTS "Public profiles read" ON public.profiles;

CREATE POLICY "Member can view own profile"
  ON public.profiles FOR SELECT
  USING (id = auth.uid());

CREATE POLICY "Member can update own profile"
  ON public.profiles FOR UPDATE
  USING (id = auth.uid())
  WITH CHECK (id = auth.uid());

CREATE POLICY "Admin can view all profiles"
  ON public.profiles FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.user_roles
      WHERE user_roles.user_id = auth.uid() AND user_roles.role IN ('ADMIN', 'SUPER_ADMIN')
    )
  );

CREATE POLICY "Admin can update all profiles"
  ON public.profiles FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM public.user_roles
      WHERE user_roles.user_id = auth.uid() AND user_roles.role IN ('ADMIN', 'SUPER_ADMIN')
    )
  );

-- 6. Kebijakan RLS untuk account_applications (agar user bisa ajukan rekening & baca pengajuannya)
DROP POLICY IF EXISTS "Member can view own applications" ON public.account_applications;
DROP POLICY IF EXISTS "Member can create own applications" ON public.account_applications;
DROP POLICY IF EXISTS "Admin can view all applications" ON public.account_applications;
DROP POLICY IF EXISTS "Admin can update applications" ON public.account_applications;

CREATE POLICY "Member can view own applications"
  ON public.account_applications FOR SELECT
  USING (user_id = auth.uid());

CREATE POLICY "Member can create own applications"
  ON public.account_applications FOR INSERT
  WITH CHECK (user_id = auth.uid());

CREATE POLICY "Admin can view all applications"
  ON public.account_applications FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.user_roles
      WHERE user_roles.user_id = auth.uid() AND user_roles.role IN ('ADMIN', 'SUPER_ADMIN')
    )
  );

CREATE POLICY "Admin can update applications"
  ON public.account_applications FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM public.user_roles
      WHERE user_roles.user_id = auth.uid() AND user_roles.role IN ('ADMIN', 'SUPER_ADMIN')
    )
  );

-- 7. Kebijakan RLS untuk user_roles (agar user & admin bisa cek role)
DROP POLICY IF EXISTS "User can view own roles" ON public.user_roles;
DROP POLICY IF EXISTS "Admin can view all roles" ON public.user_roles;

CREATE POLICY "User can view own roles"
  ON public.user_roles FOR SELECT
  USING (user_id = auth.uid());

CREATE POLICY "Admin can view all roles"
  ON public.user_roles FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.user_roles
      WHERE user_roles.user_id = auth.uid() AND user_roles.role IN ('ADMIN', 'SUPER_ADMIN')
    )
  );

