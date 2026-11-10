-- DESTRUCTIVE: This removes non-extension-owned views, materialized views,
-- tables, and functions from the public schema. Table data will be lost.
-- Back up the database first. Run manually only when you intend to reset it.
-- Do not run this as part of normal migrations or on a database you need to keep.
--
-- This does not reset the entire database: standalone sequences, custom types,
-- schemas, and objects outside public are not removed. CASCADE may remove
-- dependent objects.

DO $$
DECLARE
  r record;
BEGIN
  -- Drop regular views first, then materialized views.
  FOR r IN
    SELECT c.relname, c.relkind
    FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname = 'public'
      AND c.relkind IN ('v', 'm')
      AND NOT EXISTS (
        SELECT 1
        FROM pg_depend d
        WHERE d.objid = c.oid
          AND d.deptype = 'e'
      )
    ORDER BY CASE c.relkind WHEN 'v' THEN 0 ELSE 1 END
  LOOP
    IF r.relkind = 'm' THEN
      EXECUTE format('DROP MATERIALIZED VIEW IF EXISTS public.%I CASCADE', r.relname);
    ELSE
      EXECUTE format('DROP VIEW IF EXISTS public.%I CASCADE', r.relname);
    END IF;
  END LOOP;

  -- Drop ordinary and partitioned tables.
  FOR r IN
    SELECT c.relname
    FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname = 'public'
      AND c.relkind IN ('r', 'p')
      AND NOT EXISTS (
        SELECT 1
        FROM pg_depend d
        WHERE d.objid = c.oid
          AND d.deptype = 'e'
      )
  LOOP
    EXECUTE format('DROP TABLE IF EXISTS public.%I CASCADE', r.relname);
  END LOOP;

  -- Drop standalone functions that are not owned by an extension.
  FOR r IN
    SELECT p.oid::regprocedure AS signature
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.prokind = 'f'
      AND NOT EXISTS (
        SELECT 1
        FROM pg_depend d
        WHERE d.objid = p.oid
          AND d.deptype = 'e'
      )
  LOOP
    EXECUTE format('DROP FUNCTION IF EXISTS %s CASCADE', r.signature);
  END LOOP;
END
$$;
