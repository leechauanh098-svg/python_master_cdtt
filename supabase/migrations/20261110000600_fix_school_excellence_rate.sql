CREATE OR REPLACE FUNCTION public.fn_kpi_thisinh_truong_bang(
  p_ky varchar DEFAULT NULL,
  p_nguong_xuat_sac_pct numeric DEFAULT 80
)
RETURNS TABLE (
  truong_hoc varchar,
  bang_dau varchar,
  so_thi_sinh bigint,
  ty_le_xuat_sac_pct numeric
)
LANGUAGE sql
STABLE
AS $$
  WITH r AS (
    SELECT * FROM public.fn_ky_bao_cao(p_ky)
  ),
  scores AS (
    SELECT b.thi_sinh_id, max(b.diem_pct) AS diem_pct
    FROM public.vw_bainop_diem_pct b
    CROSS JOIN r
    WHERE b.trang_thai = 'DA_CHAM_DIEM'
      AND b.thoi_gian_nop >= r.tu
      AND b.thoi_gian_nop < r.den
      AND b.diem_pct IS NOT NULL
    GROUP BY b.thi_sinh_id
  )
  SELECT
    ts.truong_hoc,
    ts.bang_dau,
    count(DISTINCT ts.thi_sinh_id),
    COALESCE(
      (
        count(DISTINCT CASE
          WHEN scores.diem_pct >= p_nguong_xuat_sac_pct THEN ts.thi_sinh_id
        END) * 100.0
        / NULLIF(count(DISTINCT scores.thi_sinh_id), 0)
      )::numeric(5,2),
      0::numeric
    )
  FROM r
  CROSS JOIN public.thisinh ts
  LEFT JOIN scores ON scores.thi_sinh_id = ts.thi_sinh_id
  WHERE ts.truong_hoc IS NOT NULL
  GROUP BY ts.truong_hoc, ts.bang_dau
  ORDER BY count(DISTINCT ts.thi_sinh_id) DESC;
$$;

NOTIFY pgrst, 'reload schema';
