-- Reset the password for every existing Supabase Auth account.
CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA extensions;

UPDATE auth.users
SET
  encrypted_password = extensions.crypt('111111', extensions.gen_salt('bf')),
  updated_at = now();
