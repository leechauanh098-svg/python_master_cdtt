CREATE OR REPLACE FUNCTION public.fn_bao_cao_tyle_chungchi_theo_tinh(
  p_ky varchar DEFAULT NULL
) RETURNS SETOF jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, public, auth, pg_temp
AS $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM public.fn_current_user_report_permissions()
    WHERE permission_id = 'BAO_CAO_HOC_VU'
  ) THEN
    RAISE EXCEPTION 'Tài khoản không có quyền xem báo cáo học vụ.'
      USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
  WITH students AS (
    SELECT
      r.thi_sinh_id,
      COALESCE(MAX(NULLIF(btrim(r.tinh_thanh), '')), 'Chưa cập nhật') AS tinh_thanh,
      COALESCE(bool_or(r.tong_diem >= 600), false) AS dat_chung_chi
    FROM public.vw_pm_baocao_ketqua_vong r
    WHERE r.vong_thi = 'Vòng loại'
      AND r.thi_sinh_id IS NOT NULL
    GROUP BY r.thi_sinh_id
  )
  SELECT to_jsonb(summary)
  FROM (
    SELECT
      s.tinh_thanh,
      count(*) AS so_thi_sinh_du_thi,
      count(*) FILTER (WHERE s.dat_chung_chi) AS so_thi_sinh_dat_chung_chi,
      count(*) FILTER (WHERE NOT s.dat_chung_chi) AS so_thi_sinh_khong_dat_chung_chi,
      round(
        100.0 * count(*) FILTER (WHERE s.dat_chung_chi) / NULLIF(count(*), 0),
        2
      ) AS ty_le_dat_chung_chi_pct,
      round(
        100.0 * count(*) FILTER (WHERE NOT s.dat_chung_chi) / NULLIF(count(*), 0),
        2
      ) AS ty_le_khong_dat_chung_chi_pct
    FROM students s
    GROUP BY s.tinh_thanh
  ) summary
  ORDER BY summary.ty_le_dat_chung_chi_pct DESC, summary.tinh_thanh;
END;
$$;

REVOKE ALL ON FUNCTION public.fn_bao_cao_tyle_chungchi_theo_tinh(varchar) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_bao_cao_tyle_chungchi_theo_tinh(varchar) TO authenticated;

NOTIFY pgrst, 'reload schema';
