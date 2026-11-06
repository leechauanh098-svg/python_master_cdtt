-- Allow the explicitly public applicant read RPCs to return rows despite table RLS.
-- These functions expose applicant personal data to anon as requested.
GRANT USAGE ON SCHEMA public TO anon, authenticated;

DO $$
DECLARE
  routine record;
  expected_names text[] := ARRAY[
    'fn_loc_thisinh',
    'fn_tim_kiem_thisinh',
    'fn_xem_chi_tiet_thisinh',
    'fn_xuat_thisinh'
  ];
  found_names integer;
BEGIN
  FOR routine IN
    SELECT p.oid::regprocedure AS signature
    FROM pg_catalog.pg_proc AS p
    JOIN pg_catalog.pg_namespace AS n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.proname = ANY (expected_names)
      AND p.prokind = 'f'
  LOOP
    EXECUTE format('ALTER FUNCTION %s SECURITY DEFINER', routine.signature);
    EXECUTE format(
      'ALTER FUNCTION %s SET search_path = pg_catalog, public, pg_temp',
      routine.signature
    );
    EXECUTE format('REVOKE EXECUTE ON FUNCTION %s FROM PUBLIC', routine.signature);
    EXECUTE format(
      'GRANT EXECUTE ON FUNCTION %s TO anon, authenticated',
      routine.signature
    );
  END LOOP;

  SELECT count(DISTINCT p.proname)
  INTO found_names
  FROM pg_catalog.pg_proc AS p
  JOIN pg_catalog.pg_namespace AS n ON n.oid = p.pronamespace
  WHERE n.nspname = 'public'
    AND p.proname = ANY (expected_names)
    AND p.prokind = 'f';

  IF found_names <> cardinality(expected_names) THEN
    RAISE EXCEPTION 'Expected all applicant read RPCs; found % of %',
      found_names, cardinality(expected_names);
  END IF;
END
$$;

NOTIFY pgrst, 'reload schema';
