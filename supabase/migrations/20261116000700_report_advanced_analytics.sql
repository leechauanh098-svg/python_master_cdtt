CREATE OR REPLACE FUNCTION public.fn_report_partner_referral_conversion(p_ky varchar DEFAULT NULL)
RETURNS SETOF jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, public, auth, pg_temp
AS $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.fn_current_user_report_permissions()
    WHERE permission_id = 'BAO_CAO_DOI_TAC'
  ) THEN
    RAISE EXCEPTION 'Tài khoản không có quyền xem báo cáo đối tác.'
      USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
  WITH period AS (
    SELECT tu, den FROM public.fn_ky_bao_cao(p_ky)
  ),
  referrals AS (
    SELECT dkw.doanh_nghiep_id,
           COALESCE(
             NULLIF(dkw.thi_sinh_id, ''),
             NULLIF(lower(btrim(dkw.email)), ''),
             NULLIF(regexp_replace(COALESCE(dkw.sdt, ''), '[^0-9]', '', 'g'), ''),
             dkw.giao_dich_id
           ) AS candidate_key,
           dkw.giao_dich_id,
           dkw.trang_thai_thanh_toan
    FROM public.dangkyweb dkw
    CROSS JOIN period p
    WHERE dkw.doanh_nghiep_id IS NOT NULL
      AND dkw.created_at >= p.tu
      AND dkw.created_at < p.den
  ),
  per_candidate AS (
    SELECT doanh_nghiep_id,
           candidate_key,
           count(*) AS so_giao_dich,
           bool_or(trang_thai_thanh_toan = 'THANH_TOAN_THANH_CONG') AS da_thanh_toan,
           bool_or(trang_thai_thanh_toan = 'CHO_THANH_TOAN') AS dang_cho,
           count(*) FILTER (WHERE trang_thai_thanh_toan IN ('THAT_BAI', 'HUY_GIAO_DICH')) AS so_giao_dich_that_bai
    FROM referrals
    GROUP BY doanh_nghiep_id, candidate_key
  )
  SELECT jsonb_build_object(
    'doanh_nghiep_id', dn.doanh_nghiep_id,
    'ten_doanh_nghiep', dn.ten_doanh_nghiep,
    'so_ho_so_duoc_ghi_nhan', count(*),
    'so_ho_so_da_thanh_toan', count(*) FILTER (WHERE pc.da_thanh_toan),
    'so_ho_so_chua_thanh_toan', count(*) FILTER (WHERE NOT pc.da_thanh_toan),
    'so_ho_so_dang_cho', count(*) FILTER (WHERE pc.dang_cho AND NOT pc.da_thanh_toan),
    'so_giao_dich_that_bai_huy', COALESCE(sum(pc.so_giao_dich_that_bai), 0),
    'ty_le_chuyen_doi_thanh_toan_pct',
      round(count(*) FILTER (WHERE pc.da_thanh_toan) * 100.0 / NULLIF(count(*), 0), 2)
  )
  FROM per_candidate pc
  JOIN public.doanhnghiep dn ON dn.doanh_nghiep_id = pc.doanh_nghiep_id
  GROUP BY dn.doanh_nghiep_id, dn.ten_doanh_nghiep
  ORDER BY count(*) FILTER (WHERE pc.da_thanh_toan) DESC,
           count(*) DESC,
           dn.ten_doanh_nghiep;
END;
$$;

CREATE OR REPLACE FUNCTION public.fn_report_support_unanswered_age(p_ky varchar DEFAULT NULL)
RETURNS SETOF jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, public, auth, pg_temp
AS $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.fn_current_user_report_permissions()
    WHERE permission_id = 'BAO_CAO_HO_TRO'
  ) THEN
    RAISE EXCEPTION 'Tài khoản không có quyền xem báo cáo hỗ trợ.'
      USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
  WITH period AS (
    SELECT tu, den FROM public.fn_ky_bao_cao(p_ky)
  ),
  unanswered AS (
    SELECT q.kenh_tuong_tac,
           CASE
             WHEN now() - q.thoi_gian::timestamptz < interval '24 hours' THEN 'Dưới 24 giờ'
             WHEN now() - q.thoi_gian::timestamptz < interval '3 days' THEN '1–3 ngày'
             WHEN now() - q.thoi_gian::timestamptz < interval '7 days' THEN '4–7 ngày'
             ELSE 'Trên 7 ngày'
           END AS nhom_tuoi,
           CASE
             WHEN now() - q.thoi_gian::timestamptz < interval '24 hours' THEN 1
             WHEN now() - q.thoi_gian::timestamptz < interval '3 days' THEN 2
             WHEN now() - q.thoi_gian::timestamptz < interval '7 days' THEN 3
             ELSE 4
           END AS thu_tu,
           extract(epoch FROM (now() - q.thoi_gian::timestamptz)) / 3600.0 AS tuoi_gio
    FROM public.qna q
    CROSS JOIN period p
    WHERE q.trang_thai = 'CHUA_TRA_LOI'
      AND q.thoi_gian >= p.tu
      AND q.thoi_gian < p.den
  )
  SELECT jsonb_build_object(
    'kenh_tuong_tac', kenh_tuong_tac,
    'nhom_tuoi_chua_tra_loi', nhom_tuoi,
    'so_cau_chua_tra_loi', count(*),
    'tuoi_trung_binh_gio', round(avg(tuoi_gio)::numeric, 2),
    'tuoi_lon_nhat_gio', round(max(tuoi_gio)::numeric, 2)
  )
  FROM unanswered
  GROUP BY kenh_tuong_tac, nhom_tuoi, thu_tu
  ORDER BY thu_tu, kenh_tuong_tac;
END;
$$;

CREATE OR REPLACE FUNCTION public.fn_report_import_quality(p_ky varchar DEFAULT NULL)
RETURNS SETOF jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, public, auth, pg_temp
AS $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.fn_current_user_report_permissions()
    WHERE permission_id = 'BAO_CAO_AN_NINH'
  ) THEN
    RAISE EXCEPTION 'Tài khoản không có quyền xem báo cáo bảo mật.'
      USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
  WITH period AS (
    SELECT tu, den FROM public.fn_ky_bao_cao(p_ky)
  )
  SELECT jsonb_build_object(
    'ten_bang_dich', i.ten_bang_dich,
    'cot_loi', COALESCE(NULLIF(btrim(d.cot_loi), ''), 'Không xác định'),
    'ma_loi', COALESCE(d.ma_loi, 'KHONG_RO'),
    'mo_ta_loi', COALESCE(m.mo_ta, d.thong_diep_loi, 'Không có mô tả'),
    'muc_do', COALESCE(m.muc_do, 'KHONG_RO'),
    'so_dong_loi', count(*),
    'so_phien_anh_huong', count(DISTINCT i.import_id),
    'so_file_anh_huong', count(DISTINCT i.ten_file)
  )
  FROM public.audit_log_import_chitiet d
  JOIN public.audit_log_import i ON i.import_id = d.import_id
  LEFT JOIN public.dm_ma_loi_import m ON m.ma_loi = d.ma_loi
  CROSS JOIN period p
  WHERE d.ket_qua = 'LOI'
    AND i.thoi_gian_bat_dau >= p.tu
    AND i.thoi_gian_bat_dau < p.den
  GROUP BY i.ten_bang_dich,
           COALESCE(NULLIF(btrim(d.cot_loi), ''), 'Không xác định'),
           COALESCE(d.ma_loi, 'KHONG_RO'),
           COALESCE(m.mo_ta, d.thong_diep_loi, 'Không có mô tả'),
           COALESCE(m.muc_do, 'KHONG_RO')
  ORDER BY count(*) DESC,
           i.ten_bang_dich,
           COALESCE(NULLIF(btrim(d.cot_loi), ''), 'Không xác định');
END;
$$;

CREATE OR REPLACE FUNCTION public.fn_qna_stamp_first_response()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = pg_catalog, public, pg_temp
AS $$
BEGIN
  IF OLD.thoi_gian_phan_hoi_dau IS NULL
     AND OLD.noi_dung_tra_loi IS NULL
     AND NEW.noi_dung_tra_loi IS NOT NULL THEN
    NEW.thoi_gian_phan_hoi_dau := statement_timestamp();
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_qna_stamp_first_response ON public.qna;
CREATE TRIGGER trg_qna_stamp_first_response
BEFORE UPDATE OF noi_dung_tra_loi, trang_thai ON public.qna
FOR EACH ROW
WHEN (OLD.thoi_gian_phan_hoi_dau IS NULL)
EXECUTE FUNCTION public.fn_qna_stamp_first_response();

REVOKE ALL ON FUNCTION public.fn_report_partner_referral_conversion(character varying) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.fn_report_support_unanswered_age(character varying) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.fn_report_import_quality(character varying) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_report_partner_referral_conversion(character varying) TO authenticated;
GRANT EXECUTE ON FUNCTION public.fn_report_support_unanswered_age(character varying) TO authenticated;
GRANT EXECUTE ON FUNCTION public.fn_report_import_quality(character varying) TO authenticated;
