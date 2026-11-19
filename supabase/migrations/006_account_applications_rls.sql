-- 006_account_applications_rls.sql
-- Enable Row Level Security for account_applications
ALTER TABLE public.account_applications ENABLE ROW LEVEL SECURITY;

-- Allow members to INSERT their own application
CREATE POLICY "members can create own application"
  ON public.account_applications
  FOR INSERT
  WITH CHECK (user_id = auth.uid());

-- Allow members to SELECT their own applications (optional, for UI)
CREATE POLICY "members can read own applications"
  ON public.account_applications
  FOR SELECT
  USING (user_id = auth.uid());

-- Allow admins (or service_role) to SELECT all applications
CREATE POLICY "admin can read all applications"
  ON public.account_applications
  FOR SELECT
  USING (auth.role() = 'service_role' OR (SELECT EXISTS (SELECT 1 FROM public.user_roles ur WHERE ur.user_id = auth.uid() AND ur.role = 'ADMIN')));

-- Allow admins to UPDATE status, etc.
CREATE POLICY "admin can update applications"
  ON public.account_applications
  FOR UPDATE
  USING (auth.role() = 'service_role' OR (SELECT EXISTS (SELECT 1 FROM public.user_roles ur WHERE ur.user_id = auth.uid() AND ur.role = 'ADMIN')));

-- Grant explicit execute rights to service_role (already default)
GRANT USAGE ON SCHEMA public TO anon, authenticated;

