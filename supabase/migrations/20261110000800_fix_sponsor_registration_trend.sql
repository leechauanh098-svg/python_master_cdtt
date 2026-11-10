CREATE OR REPLACE FUNCTION public.fn_kpi_taitro_xu_huong(p_ky varchar DEFAULT NULL)
RETURNS TABLE (ngay date, bang_dau varchar, so_dang_ky bigint, doanh_thu numeric)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, public, auth, pg_temp
AS $$
  WITH period AS (
    SELECT tu, den FROM public.fn_ky_bao_cao(p_ky)
  ),
  registrations AS (
    SELECT dk.ngay_dang_ky::date AS ngay,
           COALESCE(ct.bang_dau, 'TẤT CẢ (CHUNG KẾT)')::varchar AS bang_dau,
           count(DISTINCT dk.dang_ky_id)::bigint AS so_dang_ky
    FROM public.dangky dk
    JOIN public.cuocthi ct ON ct.cuoc_thi_id = dk.cuoc_thi_id
    CROSS JOIN period
    WHERE dk.trang_thai <> 'HUY_DANG_KY'
      AND dk.ngay_dang_ky >= period.tu
      AND dk.ngay_dang_ky < period.den
    GROUP BY dk.ngay_dang_ky::date, COALESCE(ct.bang_dau, 'TẤT CẢ (CHUNG KẾT)')
  ),
  sponsor_revenue AS (
    SELECT g.thoi_gian_thanh_toan::date AS ngay,
           COALESCE(g.bang_dau, 'TẤT CẢ (CHUNG KẾT)')::varchar AS bang_dau,
           sum(g.so_tien)::numeric AS doanh_thu
    FROM public.vw_giao_dich_le_phi g
    CROSS JOIN period
    WHERE g.doanh_nghiep_id IS NOT NULL
      AND g.trang_thai_thanh_toan = 'THANH_TOAN_THANH_CONG'
      AND g.thoi_gian_thanh_toan >= period.tu
      AND g.thoi_gian_thanh_toan < period.den
    GROUP BY g.thoi_gian_thanh_toan::date, COALESCE(g.bang_dau, 'TẤT CẢ (CHUNG KẾT)')
  )
  SELECT COALESCE(registrations.ngay, sponsor_revenue.ngay),
         COALESCE(registrations.bang_dau, sponsor_revenue.bang_dau),
         COALESCE(registrations.so_dang_ky, 0),
         COALESCE(sponsor_revenue.doanh_thu, 0)
  FROM registrations
  FULL OUTER JOIN sponsor_revenue
    USING (ngay, bang_dau)
  ORDER BY 1, 2;
$$;
