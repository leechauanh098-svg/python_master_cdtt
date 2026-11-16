CREATE OR REPLACE FUNCTION public.fn_report_top_faq_questions(
  p_ky varchar DEFAULT NULL,
  p_limit integer DEFAULT 50
)
RETURNS SETOF jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, public, auth, pg_temp
AS $$
DECLARE
  v_employee_id varchar(20);
  v_start date;
  v_end date;
  v_limit integer := LEAST(GREATEST(COALESCE(p_limit, 50), 1), 50);
BEGIN
  SELECT nv.nhan_vien_id
  INTO v_employee_id
  FROM public.nhanvien nv
  WHERE nv.trang_thai = 'ACTIVE'
    AND (
      nv.user_id = auth.uid()
      OR (nv.user_id IS NULL AND lower(nv.email) = lower(auth.jwt() ->> 'email'))
    )
  ORDER BY (nv.user_id = auth.uid()) DESC
  LIMIT 1;

  IF v_employee_id IS NULL
     OR NOT public.fn_check_user_permission(v_employee_id, 'BAO_CAO_HO_TRO') THEN
    RAISE EXCEPTION 'Tài khoản không có quyền xem báo cáo hỗ trợ.'
      USING ERRCODE = '42501';
  END IF;

  SELECT k.tu, k.den
  INTO v_start, v_end
  FROM public.fn_ky_bao_cao(p_ky) k;

  RETURN QUERY
  SELECT jsonb_build_object(
    'thu_tu', ranked.thu_tu,
    'cau_hoi', ranked.cau_hoi,
    'so_lan_xuat_hien', ranked.so_lan_xuat_hien
  )
  FROM (
    SELECT
      row_number() OVER (ORDER BY grouped.so_lan_xuat_hien DESC, grouped.question_key)::integer AS thu_tu,
      grouped.cau_hoi,
      grouped.so_lan_xuat_hien
    FROM (
      SELECT
        lower(regexp_replace(btrim(q.noi_dung_hoi), '\s+', ' ', 'g')) AS question_key,
        min(btrim(q.noi_dung_hoi)) AS cau_hoi,
        count(*)::bigint AS so_lan_xuat_hien
      FROM public.qna q
      WHERE q.thoi_gian >= v_start::timestamp
        AND q.thoi_gian < v_end::timestamp
        AND NULLIF(btrim(q.noi_dung_hoi), '') IS NOT NULL
      GROUP BY lower(regexp_replace(btrim(q.noi_dung_hoi), '\s+', ' ', 'g'))
    ) grouped
  ) ranked
  ORDER BY ranked.thu_tu
  LIMIT v_limit;
END;
$$;

REVOKE ALL ON FUNCTION public.fn_report_top_faq_questions(character varying, integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_report_top_faq_questions(character varying, integer) TO authenticated;
