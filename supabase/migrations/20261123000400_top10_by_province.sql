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
    r.ket_qua_xet,
    COALESCE(NULLIF(btrim(ts.tinh_thanh), ''), 'Chưa cập nhật') AS tinh_thanh
  FROM public.vw_export_ketqua_vongloai r
  LEFT JOIN public.thisinh ts ON ts.thi_sinh_id = r.thi_sinh_id
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
    r.ket_qua_xet,
    COALESCE(NULLIF(btrim(ts.tinh_thanh), ''), 'Chưa cập nhật') AS tinh_thanh
  FROM public.vw_export_danhsach_chungket r
  LEFT JOIN public.thisinh ts ON ts.thi_sinh_id = r.thi_sinh_id
),
ranked AS (
  SELECT
    r.*,
    count(*) FILTER (WHERE r.vong_thi = 'Vòng loại')
      OVER (PARTITION BY r.cuoc_thi_id, r.bang_dau) AS so_thi_sinh_du_thi_vongloai
  FROM all_results r
)
SELECT
  r.vong_thi,
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
  r.ket_qua_xet,
  r.so_thi_sinh_du_thi_vongloai,
  CASE
    WHEN r.vong_thi = 'Vòng loại'
      THEN ceil(r.so_thi_sinh_du_thi_vongloai * 0.10)::bigint
    ELSE NULL
  END AS so_suat_top10,
  CASE
    WHEN r.vong_thi = 'Vòng loại'
      THEN r.thu_hang <= ceil(r.so_thi_sinh_du_thi_vongloai * 0.10)
    ELSE NULL
  END AS du_dieu_kien_vao_chung_ket,
  r.tinh_thanh
FROM ranked r;

REVOKE ALL ON TABLE public.vw_pm_baocao_ketqua_vong FROM PUBLIC, anon, authenticated;

NOTIFY pgrst, 'reload schema';
