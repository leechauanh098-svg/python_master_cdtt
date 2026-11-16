CREATE OR REPLACE FUNCTION public.fn_kpi_dashboard_snapshot_progress(p_period varchar)
RETURNS TABLE (
  kpi_id varchar,
  nhom varchar,
  ten_kpi varchar,
  muc_tieu numeric,
  gia_tri_hien_tai numeric,
  don_vi varchar,
  huong varchar,
  kieu_cong_don varchar,
  trong_so numeric,
  han_chot date,
  chu_the varchar,
  dinh_nghia text,
  cong_thuc text,
  thoi_diem_cap_nhat timestamptz
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, public, auth, pg_temp
AS $$
BEGIN
  IF auth.uid() IS NULL OR NOT public.fn_current_user_can_view_kpi_dashboard() THEN
    RAISE EXCEPTION 'Bạn không có quyền xem dữ liệu KPI.' USING ERRCODE = '42501';
  END IF;

  IF p_period IS NULL OR p_period !~ '^[0-9]{4}-Q[1-4]$' THEN
    RAISE EXCEPTION 'Kỳ KPI không hợp lệ.';
  END IF;

  RETURN QUERY
  SELECT
    (d.code || '_T' || t.target_id::text)::varchar,
    d.group_code,
    d.name,
    t.target_value,
    latest_snapshot.value,
    d.unit,
    CASE d.direction WHEN 'LOW' THEN 'THAP' ELSE 'CAO' END::varchar,
    d.aggregation,
    t.weight,
    t.due_date,
    COALESCE(nv.ho_ten, NULLIF(t.subject_id, 'ALL'), t.subject_type)::varchar,
    d.formula_text,
    d.formula_text,
    latest_snapshot.created_at
  FROM public.kpi_target t
  JOIN public.kpi_definition d ON d.code = t.kpi_code AND d.active
  JOIN public.kpi_period p ON p.period_id = t.period_id
  LEFT JOIN public.nhanvien nv
    ON t.subject_type = 'NHAN_VIEN'
    AND nv.nhan_vien_id::text = t.subject_id
  CROSS JOIN LATERAL (
    SELECT s.value, s.created_at
    FROM public.kpi_snapshot s
    WHERE s.target_id = t.target_id
      AND s.snapshot_date >= p.start_date
      AND s.snapshot_date < p.end_date
      AND s.snapshot_date <= CURRENT_DATE
    ORDER BY s.snapshot_date DESC, s.created_at DESC
    LIMIT 1
  ) latest_snapshot
  WHERE t.period_id = p_period
    AND t.status IN ('PUBLISHED', 'FINALIZED')
    AND d.code NOT IN ('KPI_TS', 'KPI_DT', 'KPI_DN')
  ORDER BY d.group_code, d.name, t.subject_type, t.subject_id;
END;
$$;

REVOKE ALL ON FUNCTION public.fn_kpi_dashboard_snapshot_progress(varchar) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_kpi_dashboard_snapshot_progress(varchar) TO authenticated;
