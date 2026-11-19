-- 004_reset_box.sql
-- Reset box status for a member to PREPARING
-- Assumes a table `boxes` with columns `member_id uuid` and `status text`
-- Adjust table/column names as needed.
CREATE OR REPLACE FUNCTION reset_box(member_id uuid)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  UPDATE boxes
  SET status = 'PREPARING'
  WHERE member_id = member_id;
  -- Optionally insert audit log
  INSERT INTO audit_logs (entity, entity_id, action, performed_at)
  VALUES ('box', member_id, 'reset', now());
END;
$$;

-- Grant execute privilege to anon and authenticated roles
GRANT EXECUTE ON FUNCTION reset_box(uuid) TO anon, authenticated;

