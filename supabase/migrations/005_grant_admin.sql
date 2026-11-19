-- 005_grant_admin.sql
-- Grant ADMIN role to a user identified by email (or user_id)
-- Adjust the email or user_id as needed.

-- 1. Grant by email
INSERT INTO public.user_roles (user_id, role)
SELECT id, 'ADMIN'
FROM auth.users
WHERE email = 'EMAIL_TO_PROMOTE'
ON CONFLICT (user_id, role) DO UPDATE SET role = EXCLUDED.role;

-- 2. Optional: grant by user_id directly
-- INSERT INTO public.user_roles (user_id, role)
-- VALUES ('USER_UUID', 'ADMIN')
-- ON CONFLICT (user_id, role) DO UPDATE SET role = EXCLUDED.role;

