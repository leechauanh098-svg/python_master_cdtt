-- Public dashboard access: only aggregate RPC results and aggregate views are exposed.
-- Run this after the reporting functions and dashboard views have been created.

CREATE OR REPLACE FUNCTION public.fn_dashboard_card_public(
  p_so_ngay integer DEFAULT 16
)
RETURNS TABLE (
  tong_luot_dang_ky bigint,
  tong_luot_thanh_toan bigint,
  ty_le_chuyen_doi_thanh_toan numeric,
  doanh_thu_tam_tinh numeric,
  tong_lead_can_cham_soc_lai bigint,
  target_gap bigint
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  WITH period AS (
    SELECT
      CURRENT_DATE AS den,
      CURRENT_DATE - (LEAST(GREATEST(COALESCE(p_so_ngay, 16), 1), 30) - 1) AS tu,
      LEAST(GREATEST(COALESCE(p_so_ngay, 16), 1), 30) AS so_ngay
  ),
  registrations AS (
    SELECT
      count(DISTINCT dk.thi_sinh_id) FILTER (
        WHERE dk.ngay_dang_ky >= p.tu AND dk.ngay_dang_ky < p.den + 1
      ) AS hien_tai,
      count(DISTINCT dk.thi_sinh_id) FILTER (
        WHERE dk.ngay_dang_ky >= p.tu - p.so_ngay AND dk.ngay_dang_ky < p.tu
      ) AS truoc_do
    FROM public.dangky AS dk
    CROSS JOIN period AS p
  ),
  payments AS (
    SELECT
      count(*) FILTER (
        WHERE dk.ngay_dang_ky >= p.tu AND dk.ngay_dang_ky < p.den + 1
          AND dk.trang_thai = 'THANH_CONG'
      ) AS tong_luot_thanh_toan
    FROM public.dangky AS dk
    CROSS JOIN period AS p
  ),
  revenue AS (
    SELECT COALESCE(sum(tt.so_tien), 0) AS doanh_thu_tam_tinh
    FROM public.thanhtoan AS tt
    CROSS JOIN period AS p
    WHERE tt.thoi_gian_thanh_toan >= p.tu
      AND tt.thoi_gian_thanh_toan < p.den + 1
      AND tt.trang_thai_thanh_toan = 'THANH_TOAN_THANH_CONG'
  ),
  leads AS (
    SELECT count(*) AS tong_lead_can_cham_soc_lai
    FROM public.quangcao AS qc
    CROSS JOIN period AS p
    WHERE qc.created_at >= p.tu
      AND qc.created_at < p.den + 1
      AND qc.trang_thai_khach_hang IN ('MOI', 'DANG_LIEN_HE')
  )
  SELECT
    r.hien_tai,
    payments.tong_luot_thanh_toan,
    (CASE
      WHEN r.hien_tai = 0 THEN 0
      ELSE payments.tong_luot_thanh_toan * 100.0 / r.hien_tai
    END)::numeric(10, 2),
    revenue.doanh_thu_tam_tinh,
    leads.tong_lead_can_cham_soc_lai,
    r.hien_tai - r.truoc_do
  FROM registrations AS r
  CROSS JOIN payments
  CROSS JOIN revenue
  CROSS JOIN leads
$$;

CREATE OR REPLACE FUNCTION public.fn_dashboard_xu_huong_16_ngay_public()
RETURNS TABLE (ngay date, so_luot_dang_ky bigint)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT * FROM public.fn_dashboard_xu_huong_16_ngay()
$$;

CREATE OR REPLACE FUNCTION public.fn_dashboard_pheu_chuyen_doi_web_public(
  p_so_ngay integer DEFAULT 16
)
RETURNS TABLE (
  thu_tu integer,
  giai_doan text,
  so_luong bigint,
  ty_le_so_voi_tiep_can numeric
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT
    p.thu_tu,
    p.giai_doan,
    p.so_luong,
    p.ty_le_so_voi_tiep_can
  FROM public.fn_dashboard_pheu_3_tang_web(
    CURRENT_DATE - LEAST(GREATEST(p_so_ngay, 1), 30) + 1,
    CURRENT_DATE
  ) AS p
$$;

CREATE OR REPLACE FUNCTION public.fn_dashboard_phan_bo_nhom_tuoi_public()
RETURNS TABLE (thu_tu integer, nhom_tuoi text, so_luong bigint)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT v.thu_tu, v.nhom_tuoi, v.so_luong
  FROM public.vw_dashboard_phan_bo_nhom_tuoi AS v
$$;

CREATE OR REPLACE FUNCTION public.fn_dashboard_card_q3_public(p_nam integer)
RETURNS TABLE (
  tong_luot_dang_ky bigint,
  tong_luot_thanh_toan bigint,
  ty_le_chuyen_doi_thanh_toan numeric,
  doanh_thu_tam_tinh numeric,
  tong_lead_can_cham_soc_lai bigint,
  target_gap bigint
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  WITH period AS (
    SELECT make_date(p_nam, 7, 1) AS tu, make_date(p_nam, 10, 1) AS den
  ),
  registrations AS (
    SELECT
      count(DISTINCT dk.thi_sinh_id) FILTER (
        WHERE dk.ngay_dang_ky >= p.tu AND dk.ngay_dang_ky < p.den
      ) AS hien_tai,
      count(DISTINCT dk.thi_sinh_id) FILTER (
        WHERE dk.ngay_dang_ky >= p.tu - interval '3 months'
          AND dk.ngay_dang_ky < p.tu
      ) AS truoc_do
    FROM public.dangky AS dk
    CROSS JOIN period AS p
  ),
  payments AS (
    SELECT count(*) AS tong_luot_thanh_toan
    FROM public.dangky AS dk
    CROSS JOIN period AS p
    WHERE dk.ngay_dang_ky >= p.tu
      AND dk.ngay_dang_ky < p.den
      AND dk.trang_thai = 'THANH_CONG'
  ),
  revenue AS (
    SELECT COALESCE(sum(tt.so_tien), 0) AS doanh_thu_tam_tinh
    FROM public.thanhtoan AS tt
    CROSS JOIN period AS p
    WHERE tt.thoi_gian_thanh_toan >= p.tu
      AND tt.thoi_gian_thanh_toan < p.den
      AND tt.trang_thai_thanh_toan = 'THANH_TOAN_THANH_CONG'
  ),
  leads AS (
    SELECT count(*) AS tong_lead_can_cham_soc_lai
    FROM public.quangcao AS qc
    CROSS JOIN period AS p
    WHERE qc.created_at >= p.tu
      AND qc.created_at < p.den
      AND qc.trang_thai_khach_hang IN ('MOI', 'DANG_LIEN_HE')
  )
  SELECT
    r.hien_tai,
    payments.tong_luot_thanh_toan,
    (CASE
      WHEN r.hien_tai = 0 THEN 0
      ELSE payments.tong_luot_thanh_toan * 100.0 / r.hien_tai
    END)::numeric(10, 2),
    revenue.doanh_thu_tam_tinh,
    leads.tong_lead_can_cham_soc_lai,
    r.hien_tai - r.truoc_do
  FROM registrations AS r
  CROSS JOIN payments
  CROSS JOIN revenue
  CROSS JOIN leads
$$;

CREATE OR REPLACE FUNCTION public.fn_dashboard_xu_huong_q3_public(p_nam integer)
RETURNS TABLE (ngay date, so_luot_dang_ky bigint)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  WITH period AS (
    SELECT make_date(p_nam, 7, 1) AS tu, make_date(p_nam, 10, 1) AS den
  ),
  weeks AS (
    SELECT generate_series(
      p.tu::timestamp,
      (p.den - 1)::timestamp,
      interval '7 days'
    )::date AS week_start
    FROM period AS p
  )
  SELECT w.week_start, count(dk.dang_ky_id)
  FROM weeks AS w
  CROSS JOIN period AS p
  LEFT JOIN public.dangky AS dk
    ON dk.ngay_dang_ky >= w.week_start
    AND dk.ngay_dang_ky < LEAST(w.week_start + 7, p.den)
  GROUP BY w.week_start
  ORDER BY w.week_start
$$;

CREATE OR REPLACE FUNCTION public.fn_dashboard_pheu_q3_public(p_nam integer)
RETURNS TABLE (
  thu_tu integer,
  giai_doan text,
  so_luong bigint,
  ty_le_so_voi_tiep_can numeric
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT
    p.thu_tu,
    p.giai_doan,
    p.so_luong,
    p.ty_le_so_voi_tiep_can
  FROM public.fn_dashboard_pheu_3_tang_web(
    make_date(p_nam, 7, 1),
    make_date(p_nam, 9, 30)
  ) AS p
$$;

CREATE OR REPLACE FUNCTION public.fn_dashboard_phan_bo_bang_thi_q3_public(
  p_nam integer
)
RETURNS TABLE (bang_dau varchar, so_luong bigint)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT ts.bang_dau, count(DISTINCT ts.thi_sinh_id)
  FROM public.thisinh AS ts
  JOIN public.dangky AS dk ON dk.thi_sinh_id = ts.thi_sinh_id
  WHERE dk.ngay_dang_ky >= make_date(p_nam, 7, 1)
    AND dk.ngay_dang_ky < make_date(p_nam, 10, 1)
    AND ts.bang_dau IN ('BANG_A', 'BANG_B')
  GROUP BY ts.bang_dau
  ORDER BY ts.bang_dau
$$;

CREATE OR REPLACE FUNCTION public.fn_dashboard_phan_bo_nhom_tuoi_q3_public(
  p_nam integer
)
RETURNS TABLE (thu_tu integer, nhom_tuoi text, so_luong bigint)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  WITH cohort AS (
    SELECT DISTINCT
      ts.thi_sinh_id,
      public.fn_tinh_tuoi_thi(ts.ngay_sinh) AS tuoi
    FROM public.thisinh AS ts
    JOIN public.dangky AS dk ON dk.thi_sinh_id = ts.thi_sinh_id
    WHERE dk.ngay_dang_ky >= make_date(p_nam, 7, 1)
      AND dk.ngay_dang_ky < make_date(p_nam, 10, 1)
      AND ts.ngay_sinh IS NOT NULL
  ),
  grouped AS (
    SELECT
      CASE
        WHEN tuoi < 15 THEN 'DƯỚI 15'
        WHEN tuoi BETWEEN 15 AND 17 THEN '15-17'
        WHEN tuoi BETWEEN 18 AND 20 THEN '18-20'
        ELSE 'TRÊN 20'
      END AS nhom_tuoi,
      CASE
        WHEN tuoi < 15 THEN 1
        WHEN tuoi BETWEEN 15 AND 17 THEN 2
        WHEN tuoi BETWEEN 18 AND 20 THEN 3
        ELSE 4
      END AS thu_tu
    FROM cohort
  )
  SELECT g.thu_tu, g.nhom_tuoi, count(*)::bigint
  FROM grouped AS g
  GROUP BY g.thu_tu, g.nhom_tuoi
  ORDER BY g.thu_tu
$$;

REVOKE ALL ON FUNCTION public.fn_dashboard_card_public(integer) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.fn_dashboard_xu_huong_16_ngay_public() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.fn_dashboard_pheu_chuyen_doi_web_public(integer) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.fn_dashboard_phan_bo_nhom_tuoi_public() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.fn_dashboard_card_q3_public(integer) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.fn_dashboard_xu_huong_q3_public(integer) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.fn_dashboard_pheu_q3_public(integer) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.fn_dashboard_phan_bo_bang_thi_q3_public(integer) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.fn_dashboard_phan_bo_nhom_tuoi_q3_public(integer) FROM PUBLIC;
REVOKE SELECT ON public.vw_dashboard_phan_bo_nhom_tuoi FROM anon;

GRANT EXECUTE ON FUNCTION public.fn_dashboard_card_public(integer) TO anon;
GRANT EXECUTE ON FUNCTION public.fn_dashboard_xu_huong_16_ngay_public() TO anon;
GRANT EXECUTE ON FUNCTION public.fn_dashboard_pheu_chuyen_doi_web_public(integer) TO anon;
GRANT EXECUTE ON FUNCTION public.fn_dashboard_phan_bo_nhom_tuoi_public() TO anon;
GRANT EXECUTE ON FUNCTION public.fn_dashboard_card_q3_public(integer) TO anon;
GRANT EXECUTE ON FUNCTION public.fn_dashboard_xu_huong_q3_public(integer) TO anon;
GRANT EXECUTE ON FUNCTION public.fn_dashboard_pheu_q3_public(integer) TO anon;
GRANT EXECUTE ON FUNCTION public.fn_dashboard_phan_bo_bang_thi_q3_public(integer) TO anon;
GRANT EXECUTE ON FUNCTION public.fn_dashboard_phan_bo_nhom_tuoi_q3_public(integer) TO anon;
GRANT SELECT ON public.vw_dashboard_phan_bo_bang_thi TO anon;

GRANT EXECUTE ON FUNCTION public.fn_dashboard_card_public(integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.fn_dashboard_xu_huong_16_ngay_public() TO authenticated;
GRANT EXECUTE ON FUNCTION public.fn_dashboard_pheu_chuyen_doi_web_public(integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.fn_dashboard_phan_bo_nhom_tuoi_public() TO authenticated;
GRANT SELECT ON TABLE public.vw_dashboard_phan_bo_bang_thi TO authenticated;

NOTIFY pgrst, 'reload schema';

