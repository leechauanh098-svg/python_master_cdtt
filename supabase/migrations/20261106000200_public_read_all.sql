-- Broad public API access requested for the admin application.
-- This grants access to anon as well as authenticated; RLS policies still apply.
GRANT USAGE ON SCHEMA public TO anon, authenticated;

GRANT SELECT ON ALL TABLES IN SCHEMA public TO anon, authenticated;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO anon, authenticated;

ALTER DEFAULT PRIVILEGES IN SCHEMA public
  GRANT SELECT ON TABLES TO anon, authenticated;
ALTER DEFAULT PRIVILEGES IN SCHEMA public
  GRANT EXECUTE ON FUNCTIONS TO anon, authenticated;

NOTIFY pgrst, 'reload schema';
