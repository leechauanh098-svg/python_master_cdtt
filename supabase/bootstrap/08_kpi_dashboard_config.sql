CREATE TABLE IF NOT EXISTS public.kpi_dashboard_config (
  config_id smallint PRIMARY KEY DEFAULT 1 CHECK (config_id = 1),
  canh_bao_pct numeric(5,2) NOT NULL DEFAULT 70 CHECK (canh_bao_pct BETWEEN 0 AND 100),
  theo_doi_ngay integer NOT NULL DEFAULT 7 CHECK (theo_doi_ngay >= 0),
  updated_at timestamptz NOT NULL DEFAULT now(),
  updated_by uuid REFERENCES auth.users(id)
);

INSERT INTO public.kpi_dashboard_config (config_id)
VALUES (1)
ON CONFLICT (config_id) DO NOTHING;

ALTER TABLE public.kpi_muctieu
  DROP CONSTRAINT IF EXISTS chk_kpi_muctieu;

ALTER TABLE public.kpi_muctieu
  ADD CONSTRAINT chk_kpi_muctieu CHECK (muc_tieu > 0) NOT VALID;

CREATE OR REPLACE FUNCTION public.fn_kpi_dashboard_config()
RETURNS TABLE (canh_bao_pct numeric, theo_doi_ngay integer)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, public, auth, pg_temp
AS $$
BEGIN
  IF auth.uid() IS NULL OR NOT EXISTS (
    SELECT 1
    FROM public.nhanvien nv
    WHERE nv.trang_thai = 'ACTIVE'
      AND (
        nv.user_id = auth.uid()
        OR lower(nv.email) = lower(auth.jwt() ->> 'email')
      )
  ) THEN
    RAISE EXCEPTION 'Không có quyền xem cấu hình KPI.' USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
  SELECT c.canh_bao_pct, c.theo_doi_ngay
  FROM public.kpi_dashboard_config c
  WHERE c.config_id = 1;
END;
$$;

REVOKE ALL ON FUNCTION public.fn_kpi_dashboard_config() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_kpi_dashboard_config() TO authenticated;

REVOKE ALL ON TABLE public.kpi_dashboard_config FROM PUBLIC, anon, authenticated;

NOTIFY pgrst, 'reload schema';
