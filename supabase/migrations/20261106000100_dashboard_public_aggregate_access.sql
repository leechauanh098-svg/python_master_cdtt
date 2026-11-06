-- Expose only aggregate dashboard data; keep applicant records private.
GRANT USAGE ON SCHEMA public TO anon, authenticated;

DO $$
DECLARE
  routine record;
  expected_names text[] := ARRAY[
    'fn_dashboard_card',
    'fn_dashboard_xu_huong_16_ngay',
    'fn_dashboard_pheu_3_tang_web'
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
    RAISE EXCEPTION 'Expected all dashboard aggregate functions; found % of %',
      found_names, cardinality(expected_names);
  END IF;
END
$$;

GRANT SELECT ON TABLE
  public.vw_dashboard_phan_bo_bang_thi,
  public.vw_dashboard_phan_bo_nhom_tuoi,
  public.vw_thisinh_bieudo_trangthai,
  public.vw_thisinh_bieudo_theo_truong
TO anon, authenticated;

NOTIFY pgrst, 'reload schema';
