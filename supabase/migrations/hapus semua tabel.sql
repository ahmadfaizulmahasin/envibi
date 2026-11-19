DROP SCHEMA public CASCADE;
CREATE SCHEMA public;

GRANT USAGE ON SCHEMA public TO postgres, anon, authenticated, service_role;

GRANT ALL ON SCHEMA public TO postgres, service_role;
GRANT ALL ON SCHEMA public TO anon, authenticated;