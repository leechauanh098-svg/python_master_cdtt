CREATE OR REPLACE FUNCTION public.fn_report_registration_peak_trend(p_ky varchar DEFAULT NULL)
RETURNS TABLE (ngay date, so_dang_ky bigint)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, public, auth, pg_temp
AS $$
DECLARE
  v_tu date;
  v_den date;
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM public.fn_current_user_report_permissions()
    WHERE permission_id = 'BAO_CAO_TONG_QUAN'
  ) THEN
    RAISE EXCEPTION 'Tài khoản không có quyền xem báo cáo tổng quan.';
  END IF;

  SELECT r.tu, LEAST(r.den - 1, CURRENT_DATE)
  INTO v_tu, v_den
  FROM public.fn_ky_bao_cao(p_ky) r;

  IF v_tu IS NULL OR v_den < v_tu THEN
    RETURN;
  END IF;

  RETURN QUERY
  WITH days AS (
    SELECT generated.day::date AS ngay
    FROM generate_series(v_tu::timestamp, v_den::timestamp, interval '1 day') generated(day)
  )
  SELECT days.ngay, count(DISTINCT dk.thi_sinh_id)::bigint
  FROM days
  LEFT JOIN public.dangky dk ON dk.ngay_dang_ky::date = days.ngay
  GROUP BY days.ngay
  ORDER BY days.ngay;
END;
$$;

REVOKE ALL ON FUNCTION public.fn_report_registration_peak_trend(character varying) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_report_registration_peak_trend(character varying) TO authenticated;

NOTIFY pgrst, 'reload schema';
