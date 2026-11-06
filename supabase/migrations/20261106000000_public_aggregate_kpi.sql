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
