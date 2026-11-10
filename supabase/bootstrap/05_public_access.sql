-- =============================================================================
-- Source: supabase/migrations/20261106000000_public_aggregate_kpi.sql
-- =============================================================================

-- Public access is limited to read-only aggregate KPI functions.
-- Do not grant anon access to functions returning people, partners, or transactions.

GRANT USAGE ON SCHEMA public TO anon, authenticated;

ALTER FUNCTION public.fn_kpi_tongquan_chiso(character varying) SECURITY DEFINER;
ALTER FUNCTION public.fn_kpi_tongquan_chiso(character varying) SET search_path = pg_catalog, public, pg_temp;
REVOKE EXECUTE ON FUNCTION public.fn_kpi_tongquan_chiso(character varying) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.fn_kpi_tongquan_chiso(character varying) TO anon, authenticated;

ALTER FUNCTION public.fn_kpi_tongquan_tin_hieu(character varying) SECURITY DEFINER;
ALTER FUNCTION public.fn_kpi_tongquan_tin_hieu(character varying) SET search_path = pg_catalog, public, pg_temp;
REVOKE EXECUTE ON FUNCTION public.fn_kpi_tongquan_tin_hieu(character varying) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.fn_kpi_tongquan_tin_hieu(character varying) TO anon, authenticated;

ALTER FUNCTION public.fn_kpi_tongquan_tien_do(character varying) SECURITY DEFINER;
ALTER FUNCTION public.fn_kpi_tongquan_tien_do(character varying) SET search_path = pg_catalog, public, pg_temp;
REVOKE EXECUTE ON FUNCTION public.fn_kpi_tongquan_tien_do(character varying) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.fn_kpi_tongquan_tien_do(character varying) TO anon, authenticated;

ALTER FUNCTION public.fn_kpi_thisinh_tong_quan(character varying) SECURITY DEFINER;
ALTER FUNCTION public.fn_kpi_thisinh_tong_quan(character varying) SET search_path = pg_catalog, public, pg_temp;
REVOKE EXECUTE ON FUNCTION public.fn_kpi_thisinh_tong_quan(character varying) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.fn_kpi_thisinh_tong_quan(character varying) TO anon, authenticated;

ALTER FUNCTION public.fn_kpi_thisinh_pheu(character varying) SECURITY DEFINER;
ALTER FUNCTION public.fn_kpi_thisinh_pheu(character varying) SET search_path = pg_catalog, public, pg_temp;
REVOKE EXECUTE ON FUNCTION public.fn_kpi_thisinh_pheu(character varying) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.fn_kpi_thisinh_pheu(character varying) TO anon, authenticated;

ALTER FUNCTION public.fn_kpi_thisinh_utm_roi(character varying) SECURITY DEFINER;
ALTER FUNCTION public.fn_kpi_thisinh_utm_roi(character varying) SET search_path = pg_catalog, public, pg_temp;
REVOKE EXECUTE ON FUNCTION public.fn_kpi_thisinh_utm_roi(character varying) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.fn_kpi_thisinh_utm_roi(character varying) TO anon, authenticated;

ALTER FUNCTION public.fn_kpi_thisinh_pho_diem(character varying) SECURITY DEFINER;
ALTER FUNCTION public.fn_kpi_thisinh_pho_diem(character varying) SET search_path = pg_catalog, public, pg_temp;
REVOKE EXECUTE ON FUNCTION public.fn_kpi_thisinh_pho_diem(character varying) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.fn_kpi_thisinh_pho_diem(character varying) TO anon, authenticated;

ALTER FUNCTION public.fn_kpi_thisinh_tien_do(character varying) SECURITY DEFINER;
ALTER FUNCTION public.fn_kpi_thisinh_tien_do(character varying) SET search_path = pg_catalog, public, pg_temp;
REVOKE EXECUTE ON FUNCTION public.fn_kpi_thisinh_tien_do(character varying) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.fn_kpi_thisinh_tien_do(character varying) TO anon, authenticated;

ALTER FUNCTION public.fn_kpi_taitro_tong_quan(character varying) SECURITY DEFINER;
ALTER FUNCTION public.fn_kpi_taitro_tong_quan(character varying) SET search_path = pg_catalog, public, pg_temp;
REVOKE EXECUTE ON FUNCTION public.fn_kpi_taitro_tong_quan(character varying) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.fn_kpi_taitro_tong_quan(character varying) TO anon, authenticated;

ALTER FUNCTION public.fn_kpi_taitro_pheu(character varying) SECURITY DEFINER;
ALTER FUNCTION public.fn_kpi_taitro_pheu(character varying) SET search_path = pg_catalog, public, pg_temp;
REVOKE EXECUTE ON FUNCTION public.fn_kpi_taitro_pheu(character varying) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.fn_kpi_taitro_pheu(character varying) TO anon, authenticated;

ALTER FUNCTION public.fn_kpi_taitro_co_cau_cap() SECURITY DEFINER;
ALTER FUNCTION public.fn_kpi_taitro_co_cau_cap() SET search_path = pg_catalog, public, pg_temp;
REVOKE EXECUTE ON FUNCTION public.fn_kpi_taitro_co_cau_cap() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.fn_kpi_taitro_co_cau_cap() TO anon, authenticated;

ALTER FUNCTION public.fn_kpi_taitro_doanh_thu_tinh(character varying) SECURITY DEFINER;
ALTER FUNCTION public.fn_kpi_taitro_doanh_thu_tinh(character varying) SET search_path = pg_catalog, public, pg_temp;
REVOKE EXECUTE ON FUNCTION public.fn_kpi_taitro_doanh_thu_tinh(character varying) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.fn_kpi_taitro_doanh_thu_tinh(character varying) TO anon, authenticated;

ALTER FUNCTION public.fn_kpi_taitro_xu_huong(character varying) SECURITY DEFINER;
ALTER FUNCTION public.fn_kpi_taitro_xu_huong(character varying) SET search_path = pg_catalog, public, pg_temp;
REVOKE EXECUTE ON FUNCTION public.fn_kpi_taitro_xu_huong(character varying) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.fn_kpi_taitro_xu_huong(character varying) TO anon, authenticated;

ALTER FUNCTION public.fn_kpi_taitro_doanh_thu_ngay(character varying) SECURITY DEFINER;
ALTER FUNCTION public.fn_kpi_taitro_doanh_thu_ngay(character varying) SET search_path = pg_catalog, public, pg_temp;
REVOKE EXECUTE ON FUNCTION public.fn_kpi_taitro_doanh_thu_ngay(character varying) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.fn_kpi_taitro_doanh_thu_ngay(character varying) TO anon, authenticated;

ALTER FUNCTION public.fn_kpi_taitro_thi_sinh_khu_vuc(character varying) SECURITY DEFINER;
ALTER FUNCTION public.fn_kpi_taitro_thi_sinh_khu_vuc(character varying) SET search_path = pg_catalog, public, pg_temp;
REVOKE EXECUTE ON FUNCTION public.fn_kpi_taitro_thi_sinh_khu_vuc(character varying) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.fn_kpi_taitro_thi_sinh_khu_vuc(character varying) TO anon, authenticated;

ALTER FUNCTION public.fn_kpi_taitro_tien_do(character varying) SECURITY DEFINER;
ALTER FUNCTION public.fn_kpi_taitro_tien_do(character varying) SET search_path = pg_catalog, public, pg_temp;
REVOKE EXECUTE ON FUNCTION public.fn_kpi_taitro_tien_do(character varying) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.fn_kpi_taitro_tien_do(character varying) TO anon, authenticated;

ALTER FUNCTION public.fn_kpi_doanhthu_tong_quan(character varying) SECURITY DEFINER;
ALTER FUNCTION public.fn_kpi_doanhthu_tong_quan(character varying) SET search_path = pg_catalog, public, pg_temp;
REVOKE EXECUTE ON FUNCTION public.fn_kpi_doanhthu_tong_quan(character varying) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.fn_kpi_doanhthu_tong_quan(character varying) TO anon, authenticated;

ALTER FUNCTION public.fn_kpi_doanhthu_pheu(character varying) SECURITY DEFINER;
ALTER FUNCTION public.fn_kpi_doanhthu_pheu(character varying) SET search_path = pg_catalog, public, pg_temp;
REVOKE EXECUTE ON FUNCTION public.fn_kpi_doanhthu_pheu(character varying) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.fn_kpi_doanhthu_pheu(character varying) TO anon, authenticated;

ALTER FUNCTION public.fn_kpi_doanhthu_theo_khu_vuc(character varying) SECURITY DEFINER;
ALTER FUNCTION public.fn_kpi_doanhthu_theo_khu_vuc(character varying) SET search_path = pg_catalog, public, pg_temp;
REVOKE EXECUTE ON FUNCTION public.fn_kpi_doanhthu_theo_khu_vuc(character varying) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.fn_kpi_doanhthu_theo_khu_vuc(character varying) TO anon, authenticated;

ALTER FUNCTION public.fn_kpi_doanhthu_xu_huong(character varying) SECURITY DEFINER;
ALTER FUNCTION public.fn_kpi_doanhthu_xu_huong(character varying) SET search_path = pg_catalog, public, pg_temp;
REVOKE EXECUTE ON FUNCTION public.fn_kpi_doanhthu_xu_huong(character varying) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.fn_kpi_doanhthu_xu_huong(character varying) TO anon, authenticated;

ALTER FUNCTION public.fn_kpi_doanhthu_tien_do(character varying) SECURITY DEFINER;
ALTER FUNCTION public.fn_kpi_doanhthu_tien_do(character varying) SET search_path = pg_catalog, public, pg_temp;
REVOKE EXECUTE ON FUNCTION public.fn_kpi_doanhthu_tien_do(character varying) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.fn_kpi_doanhthu_tien_do(character varying) TO anon, authenticated;

ALTER FUNCTION public.fn_kpi_doanhthu_theo_kenh(character varying) SECURITY DEFINER;
ALTER FUNCTION public.fn_kpi_doanhthu_theo_kenh(character varying) SET search_path = pg_catalog, public, pg_temp;
REVOKE EXECUTE ON FUNCTION public.fn_kpi_doanhthu_theo_kenh(character varying) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.fn_kpi_doanhthu_theo_kenh(character varying) TO anon, authenticated;

-- Explicitly keep direct identifiers and transaction-level reports private.
REVOKE EXECUTE ON FUNCTION public.fn_kpi_thisinh_top1pct(character varying) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.fn_kpi_thisinh_theo_truong(character varying, numeric) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.fn_kpi_thisinh_truong_bang(character varying, numeric) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.fn_kpi_taitro_nha_tai_tro(character varying) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.fn_kpi_taitro_ds_doi_tac(character varying) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.fn_kpi_doanhthu_cho_doi_soat_48h(character varying) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.fn_kpi_doanhthu_chi_tiet(character varying) FROM PUBLIC, anon;

NOTIFY pgrst, 'reload schema';

-- =============================================================================
-- Source: supabase/migrations/20261106000100_dashboard_public_aggregate_access.sql
-- =============================================================================

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

-- =============================================================================
-- Source: supabase/migrations/20261106000200_public_read_all.sql
-- =============================================================================

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

-- =============================================================================
-- Source: supabase/migrations/20261106000300_applicant_read_rpc_access.sql
-- =============================================================================

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

