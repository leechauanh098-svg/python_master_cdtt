UPDATE public.kpi_muctieu
SET muc_tieu = 30
WHERE kpi_id = 'KPI_DN_2026Q3'
  AND muc_tieu IS DISTINCT FROM 30;
