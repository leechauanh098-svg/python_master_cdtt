CREATE OR REPLACE FUNCTION public.fn_bao_cao_tyle_top10_theo_tinh(
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
  SELECT to_jsonb(summary)
  FROM (
    SELECT
      COALESCE(NULLIF(btrim(r.tinh_thanh), ''), 'Chưa cập nhật') AS tinh_thanh,
      count(*) AS so_luot_du_thi_vongloai,
      count(*) FILTER (WHERE r.du_dieu_kien_vao_chung_ket) AS so_luot_top10_vao_chung_ket,
      round(
        100.0 * count(*) FILTER (WHERE r.du_dieu_kien_vao_chung_ket)
        / NULLIF(count(*), 0),
        2
      ) AS ty_le_top10_pct
    FROM public.vw_pm_baocao_ketqua_vong r
    WHERE r.vong_thi = 'Vòng loại'
    GROUP BY COALESCE(NULLIF(btrim(r.tinh_thanh), ''), 'Chưa cập nhật')
  ) summary
  ORDER BY summary.ty_le_top10_pct DESC, summary.tinh_thanh;
END;
$$;

REVOKE ALL ON FUNCTION public.fn_bao_cao_tyle_top10_theo_tinh(varchar) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_bao_cao_tyle_top10_theo_tinh(varchar) TO authenticated;

NOTIFY pgrst, 'reload schema';
