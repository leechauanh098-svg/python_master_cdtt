CREATE OR REPLACE FUNCTION public.fn_kpi_gd(p_tu date, p_den date)
RETURNS SETOF public.vw_giao_dich_le_phi
LANGUAGE sql
STABLE
AS $$
  SELECT x.nguon, x.thanh_toan_id, x.giao_dich_id, x.thi_sinh_id, x.nguoi_key,
         x.thoi_gian_thanh_toan, x.so_tien, x.bang_dau, x.trang_thai_thanh_toan,
         x.tinh_thanh, x.truong_hoc, x.doanh_nghiep_id, x.hoa_hong
  FROM (
    SELECT g.*,
           row_number() OVER (
             PARTITION BY g.nguoi_key, g.trang_thai_thanh_toan
             ORDER BY CASE g.nguon WHEN 'DANGKYWEB' THEN 0 ELSE 1 END,
                      g.thoi_gian_thanh_toan
           ) AS rn
    FROM public.vw_giao_dich_le_phi g
    WHERE g.thoi_gian_thanh_toan >= p_tu
      AND g.thoi_gian_thanh_toan < p_den
  ) x
  WHERE x.rn = 1
$$;
