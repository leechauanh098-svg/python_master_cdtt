CREATE OR REPLACE FUNCTION public.fn_kpi_dashboard_period_status(p_period varchar)
RETURNS TABLE (period_status varchar)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, public, auth, pg_temp
AS $$
BEGIN
  IF auth.uid() IS NULL OR NOT public.fn_current_user_can_view_kpi_dashboard() THEN
    RAISE EXCEPTION 'Bạn không có quyền xem trạng thái kỳ KPI.' USING ERRCODE = '42501';
  END IF;

  IF p_period IS NULL OR p_period !~ '^[0-9]{4}-Q[1-4]$' THEN
    RAISE EXCEPTION 'Kỳ KPI không hợp lệ.';
  END IF;

  RETURN QUERY
  SELECT kp.status
  FROM public.kpi_period kp
  WHERE kp.period_id = p_period;
END;
$$;

REVOKE ALL ON FUNCTION public.fn_kpi_dashboard_period_status(varchar) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_kpi_dashboard_period_status(varchar) TO authenticated;
