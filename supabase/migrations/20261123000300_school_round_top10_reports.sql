CREATE OR REPLACE VIEW public.vw_pm_baocao_ketqua_vong AS
WITH all_results AS (
  SELECT
    'Vòng loại'::text AS vong_thi,
    r.cuoc_thi_id,
    r.ten_cuoc_thi,
    r.bang_dau,
    r.thu_hang,
    r.thi_sinh_id,
    r.ho_ten,
    r.truong_hoc,
    r.tong_diem,
    r.thoi_gian_lam_bai_giay,
    r.thoi_gian_nop,
    r.ket_qua_xet
  FROM public.vw_export_ketqua_vongloai r
  UNION ALL
  SELECT
    'Chung kết'::text AS vong_thi,
    r.cuoc_thi_id,
    r.ten_cuoc_thi,
    r.bang_dau,
    r.thu_hang,
    r.thi_sinh_id,
    r.ho_ten,
    r.truong_hoc,
    r.tong_diem,
    r.thoi_gian_lam_bai_giay,
    r.thoi_gian_nop,
    r.ket_qua_xet
  FROM public.vw_export_danhsach_chungket r
),
ranked AS (
  SELECT
    r.*,
    count(*) FILTER (WHERE r.vong_thi = 'Vòng loại')
      OVER (PARTITION BY r.cuoc_thi_id, r.bang_dau) AS so_thi_sinh_du_thi_vongloai
  FROM all_results r
)
SELECT
  r.*,
  CASE
    WHEN r.vong_thi = 'Vòng loại'
      THEN ceil(r.so_thi_sinh_du_thi_vongloai * 0.10)::bigint
    ELSE NULL
  END AS so_suat_top10,
  CASE
    WHEN r.vong_thi = 'Vòng loại'
      THEN r.thu_hang <= ceil(r.so_thi_sinh_du_thi_vongloai * 0.10)
    ELSE NULL
  END AS du_dieu_kien_vao_chung_ket
FROM ranked r;

REVOKE ALL ON TABLE public.vw_pm_baocao_ketqua_vong FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.fn_bao_cao_thongke_thisinh_theo_vong(
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
  WITH filtered AS (
    SELECT r.*
    FROM public.vw_pm_baocao_ketqua_vong r
    CROSS JOIN LATERAL public.fn_ky_bao_cao(p_ky) ky
    WHERE p_ky IS NULL
       OR (
         r.thoi_gian_nop >= ky.tu::timestamp
         AND r.thoi_gian_nop < ky.den::timestamp
       )
  )
  SELECT to_jsonb(summary)
  FROM (
    SELECT
      r.vong_thi,
      r.cuoc_thi_id,
      r.ten_cuoc_thi,
      r.bang_dau,
      COALESCE(NULLIF(btrim(r.truong_hoc), ''), 'Chưa cập nhật') AS truong_hoc,
      count(*) AS so_thi_sinh_du_thi,
      count(*) FILTER (WHERE r.ket_qua_xet = 'ĐẠT YÊU CẦU') AS so_thi_sinh_dat_yeu_cau,
      CASE
        WHEN r.vong_thi = 'Vòng loại'
          THEN count(*) FILTER (WHERE r.du_dieu_kien_vao_chung_ket)
        ELSE NULL
      END AS so_thi_sinh_du_dieu_kien_vao_chung_ket
    FROM filtered r
    GROUP BY
      r.vong_thi,
      r.cuoc_thi_id,
      r.ten_cuoc_thi,
      r.bang_dau,
      COALESCE(NULLIF(btrim(r.truong_hoc), ''), 'Chưa cập nhật')
  ) summary
  ORDER BY summary.vong_thi, summary.cuoc_thi_id, summary.bang_dau, summary.truong_hoc;
END;
$$;

CREATE OR REPLACE FUNCTION public.fn_bao_cao_ds_top10_vongloai(
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
  SELECT to_jsonb(r)
  FROM public.vw_pm_baocao_ketqua_vong r
  CROSS JOIN LATERAL public.fn_ky_bao_cao(p_ky) ky
  WHERE r.vong_thi = 'Vòng loại'
    AND r.du_dieu_kien_vao_chung_ket
    AND (
      p_ky IS NULL
      OR (
        r.thoi_gian_nop >= ky.tu::timestamp
        AND r.thoi_gian_nop < ky.den::timestamp
      )
    )
  ORDER BY r.cuoc_thi_id, r.bang_dau, r.thu_hang, r.thi_sinh_id;
END;
$$;

REVOKE ALL ON FUNCTION public.fn_bao_cao_thongke_thisinh_theo_vong(varchar) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.fn_bao_cao_ds_top10_vongloai(varchar) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_bao_cao_thongke_thisinh_theo_vong(varchar) TO authenticated;
GRANT EXECUTE ON FUNCTION public.fn_bao_cao_ds_top10_vongloai(varchar) TO authenticated;

NOTIFY pgrst, 'reload schema';
