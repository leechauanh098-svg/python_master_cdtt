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
  WITH period AS (
    SELECT r.tu, r.den
    FROM public.fn_ky_bao_cao(p_ky) r
  ),
  graded_submissions AS (
    SELECT
      bn.thi_sinh_id,
      (
        bn.tong_diem * 100.0
        / NULLIF(question_totals.diem_toi_da, 0)
      )::numeric(6,2) AS diem_pct
    FROM public.bainop bn
    JOIN public.thisinh ts ON ts.thi_sinh_id = bn.thi_sinh_id
    CROSS JOIN period
    CROSS JOIN LATERAL (
      SELECT sum(ch.diem_toi_da) AS diem_toi_da
      FROM public.cauhoi ch
      WHERE ch.bai_tap_id = bn.bai_tap_id
    ) question_totals
    WHERE bn.trang_thai IN ('DA_NOP', 'DA_CHAM_DIEM')
      AND bn.tong_diem IS NOT NULL
      AND ts.truong_hoc IS NOT NULL
      AND COALESCE(bn.thoi_gian_nop, bn.updated_at, bn.created_at) >= period.tu
      AND COALESCE(bn.thoi_gian_nop, bn.updated_at, bn.created_at) < period.den
  ),
  best_score AS (
    SELECT graded_submissions.thi_sinh_id, max(graded_submissions.diem_pct) AS diem_pct
    FROM graded_submissions
    WHERE graded_submissions.diem_pct IS NOT NULL
    GROUP BY graded_submissions.thi_sinh_id
  )
  SELECT
    ts.truong_hoc,
    ts.bang_dau,
    count(DISTINCT ts.thi_sinh_id)::bigint,
    (
      count(DISTINCT CASE
        WHEN best_score.diem_pct >= p_nguong_xuat_sac_pct THEN ts.thi_sinh_id
      END) * 100.0
      / NULLIF(count(DISTINCT best_score.thi_sinh_id), 0)
    )::numeric(5,2)
  FROM public.thisinh ts
  LEFT JOIN best_score ON best_score.thi_sinh_id = ts.thi_sinh_id
  WHERE ts.truong_hoc IS NOT NULL
  GROUP BY ts.truong_hoc, ts.bang_dau
  ORDER BY count(DISTINCT ts.thi_sinh_id) DESC;
$$;

NOTIFY pgrst, 'reload schema';
