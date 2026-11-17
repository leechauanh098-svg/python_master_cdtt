CREATE OR REPLACE VIEW public.vw_baocao_phanbo_trangthai_bainop AS
WITH latest_submission AS (
  SELECT DISTINCT ON (bn.thi_sinh_id) bn.thi_sinh_id, bn.trang_thai
  FROM public.bainop bn
  ORDER BY bn.thi_sinh_id,
           COALESCE(bn.thoi_gian_nop, bn.thoi_gian_bat_dau) DESC,
           bn.updated_at DESC,
           bn.bai_nop_id DESC
)
SELECT trang_thai, count(*) AS so_luong
FROM latest_submission
GROUP BY trang_thai;
