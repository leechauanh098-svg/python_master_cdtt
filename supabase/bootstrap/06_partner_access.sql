-- =============================================================================
-- Source: supabase/migrations/20261109000000_reporting_role_access.sql
-- =============================================================================

ALTER TABLE public.nhanvien
  DROP CONSTRAINT IF EXISTS chk_nv_phanquyen;
ALTER TABLE public.nhanvien
  ADD CONSTRAINT chk_nv_phanquyen
  CHECK (phan_quyen IN ('ADMIN', 'MANAGER', 'SALE_STAFF', 'SUPPORT_STAFF', 'JUDGE'));

ALTER TABLE public.vaitro
  DROP CONSTRAINT IF EXISTS chk_vt_role;
ALTER TABLE public.vaitro
  ADD CONSTRAINT chk_vt_role
  CHECK (role_id IN ('ADMIN', 'MANAGER', 'SALE_STAFF', 'SUPPORT_STAFF', 'JUDGE'));

INSERT INTO public.vaitro (role_id, ten_vai_tro, mo_ta, trang_thai)
VALUES (
  'JUDGE',
  'Ban Giám khảo',
  'Xem báo cáo bài nộp, kết quả chấm thi và phân tích chất lượng đề.',
  'DANG_AP_DUNG'
)
ON CONFLICT (role_id) DO UPDATE
SET ten_vai_tro = EXCLUDED.ten_vai_tro,
    mo_ta = EXCLUDED.mo_ta,
    trang_thai = 'DANG_AP_DUNG';

INSERT INTO public.quyen (permission_id, ten_quyen, nhom_chuc_nang, mo_ta)
VALUES (
  'BAO_CAO_HOC_VU',
  'Xem báo cáo học vụ',
  'BAO_CAO',
  'Bài nộp, kết quả vòng thi và phân tích đề'
)
ON CONFLICT (permission_id) DO UPDATE
SET ten_quyen = EXCLUDED.ten_quyen,
    nhom_chuc_nang = EXCLUDED.nhom_chuc_nang,
    mo_ta = EXCLUDED.mo_ta;

INSERT INTO public.vaitro_quyen (role_id, permission_id)
VALUES ('JUDGE', 'BAO_CAO_HOC_VU')
ON CONFLICT (role_id, permission_id) DO NOTHING;

INSERT INTO public.nhanvien_vaitro_ct (nhan_vien_id, role_id)
SELECT nv.nhan_vien_id, 'JUDGE'
FROM public.nhanvien nv
WHERE nv.phan_quyen = 'JUDGE'
ON CONFLICT (nhan_vien_id, role_id) DO NOTHING;

CREATE OR REPLACE FUNCTION public.sp_insert_vaitro(
  p_role_id varchar,
  p_ten_vai_tro varchar,
  p_mo_ta varchar,
  p_trang_thai varchar DEFAULT 'DANG_AP_DUNG'
) RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
  IF EXISTS (SELECT 1 FROM public.vaitro WHERE role_id = p_role_id) THEN
    RAISE EXCEPTION 'Mã vai trò % đã tồn tại trong hệ thống.', p_role_id;
  END IF;
  IF p_role_id NOT IN ('ADMIN', 'MANAGER', 'SALE_STAFF', 'SUPPORT_STAFF', 'JUDGE') THEN
    RAISE EXCEPTION 'Vai trò không hợp lệ.';
  END IF;
  IF p_trang_thai NOT IN ('DANG_AP_DUNG', 'TAM_KHOA') THEN
    RAISE EXCEPTION 'Trạng thái không hợp lệ.';
  END IF;
  INSERT INTO public.vaitro (role_id, ten_vai_tro, mo_ta, trang_thai)
  VALUES (p_role_id, p_ten_vai_tro, p_mo_ta, p_trang_thai);
END;
$$;

CREATE OR REPLACE FUNCTION public.fn_current_user_report_permissions()
RETURNS TABLE (ho_ten varchar, role_id varchar, ten_vai_tro varchar, permission_id varchar)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, public, auth, pg_temp
AS $$
  SELECT DISTINCT nv.ho_ten, vt.role_id, vt.ten_vai_tro, vq.permission_id
  FROM public.nhanvien nv
  JOIN public.nhanvien_vaitro_ct nvt ON nvt.nhan_vien_id = nv.nhan_vien_id
  JOIN public.vaitro vt ON vt.role_id = nvt.role_id
  JOIN public.vaitro_quyen vq ON vq.role_id = vt.role_id
  WHERE nv.trang_thai = 'ACTIVE'
    AND vt.trang_thai = 'DANG_AP_DUNG'
    AND (
      nv.user_id = auth.uid()
      OR lower(nv.email) = lower(auth.jwt() ->> 'email')
    )
  ORDER BY vt.role_id, vq.permission_id
$$;

CREATE OR REPLACE FUNCTION public.fn_current_user_can_view_student_records()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, public, auth, pg_temp
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.nhanvien nv
    JOIN public.nhanvien_vaitro_ct nvt ON nvt.nhan_vien_id = nv.nhan_vien_id
    JOIN public.vaitro vt ON vt.role_id = nvt.role_id
    JOIN public.vaitro_quyen vq ON vq.role_id = vt.role_id
    WHERE nv.trang_thai = 'ACTIVE'
      AND vt.trang_thai = 'DANG_AP_DUNG'
      AND vq.permission_id IN ('BAO_CAO_THISINH', 'BAO_CAO_HO_TRO')
      AND (
        nv.user_id = auth.uid()
        OR lower(nv.email) = lower(auth.jwt() ->> 'email')
      )
  )
$$;

CREATE OR REPLACE FUNCTION public.fn_xuat_thisinh(
  p_thi_sinh_id varchar DEFAULT NULL,
  p_ho_ten varchar DEFAULT NULL,
  p_sdt varchar DEFAULT NULL,
  p_email varchar DEFAULT NULL,
  p_truong_hoc varchar DEFAULT NULL,
  p_cccd varchar DEFAULT NULL,
  p_trang_thai_ho_so varchar DEFAULT NULL,
  p_sale_phu_trach_id varchar DEFAULT NULL,
  p_bang_dau varchar DEFAULT NULL
)
RETURNS TABLE (
  id varchar,
  ho_va_ten varchar,
  email varchar,
  so_dien_thoai varchar,
  ngay_sinh date,
  nam_sinh integer,
  cccd varchar,
  dia_chi varchar,
  tinh_thanh varchar,
  truong_hoc varchar,
  bang_dau varchar,
  trang_thai_ho_so varchar,
  sale_phu_trach_id varchar,
  sale_phu_trach varchar
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, public, auth, pg_temp
AS $$
  SELECT ts.thi_sinh_id, ts.ho_ten, ts.email, ts.sdt, ts.ngay_sinh,
         extract(year FROM ts.ngay_sinh)::integer, ts.cccd, ts.dia_chi,
         ts.tinh_thanh, ts.truong_hoc, ts.bang_dau, ts.trang_thai_ho_so,
         ts.sale_phu_trach_id, nv.ho_ten
  FROM public.thisinh ts
  LEFT JOIN public.nhanvien nv ON nv.nhan_vien_id = ts.sale_phu_trach_id
  WHERE public.fn_current_user_can_view_student_records()
    AND (p_thi_sinh_id IS NULL OR p_thi_sinh_id = '' OR ts.thi_sinh_id ILIKE '%' || p_thi_sinh_id || '%')
    AND (p_ho_ten IS NULL OR p_ho_ten = '' OR ts.ho_ten ILIKE '%' || p_ho_ten || '%')
    AND (p_sdt IS NULL OR p_sdt = '' OR ts.sdt LIKE '%' || p_sdt || '%')
    AND (p_email IS NULL OR p_email = '' OR ts.email ILIKE '%' || p_email || '%')
    AND (p_truong_hoc IS NULL OR p_truong_hoc = '' OR ts.truong_hoc ILIKE '%' || p_truong_hoc || '%')
    AND (p_cccd IS NULL OR p_cccd = '' OR ts.cccd LIKE '%' || p_cccd || '%')
    AND (p_trang_thai_ho_so IS NULL OR p_trang_thai_ho_so = 'ALL' OR ts.trang_thai_ho_so = p_trang_thai_ho_so)
    AND (p_sale_phu_trach_id IS NULL OR p_sale_phu_trach_id = 'ALL' OR ts.sale_phu_trach_id = p_sale_phu_trach_id)
    AND (p_bang_dau IS NULL OR p_bang_dau = 'ALL' OR ts.bang_dau = p_bang_dau)
  ORDER BY ts.thi_sinh_id
$$;

CREATE OR REPLACE FUNCTION public.fn_loc_thisinh(
  p_thi_sinh_id varchar DEFAULT NULL,
  p_ho_ten varchar DEFAULT NULL,
  p_nam_sinh integer DEFAULT NULL,
  p_truong_hoc varchar DEFAULT NULL,
  p_trang_thai_ho_so varchar DEFAULT NULL,
  p_sale_phu_trach_id varchar DEFAULT NULL,
  p_bang_dau varchar DEFAULT NULL
)
RETURNS TABLE (
  thi_sinh_id varchar,
  ho_ten varchar,
  email varchar,
  sdt varchar,
  nam_sinh integer,
  truong_hoc varchar,
  trang_thai_ho_so varchar,
  bang_dau varchar,
  sale_phu_trach_id varchar,
  ten_sale_phu_trach varchar
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, public, auth, pg_temp
AS $$
  SELECT ts.thi_sinh_id, ts.ho_ten, ts.email, ts.sdt,
         extract(year FROM ts.ngay_sinh)::integer, ts.truong_hoc,
         ts.trang_thai_ho_so, ts.bang_dau, ts.sale_phu_trach_id, nv.ho_ten
  FROM public.thisinh ts
  LEFT JOIN public.nhanvien nv ON nv.nhan_vien_id = ts.sale_phu_trach_id
  WHERE public.fn_current_user_can_view_student_records()
    AND (p_thi_sinh_id IS NULL OR p_thi_sinh_id = '' OR ts.thi_sinh_id ILIKE '%' || p_thi_sinh_id || '%')
    AND (p_ho_ten IS NULL OR p_ho_ten = '' OR ts.ho_ten ILIKE '%' || p_ho_ten || '%')
    AND (p_nam_sinh IS NULL OR extract(year FROM ts.ngay_sinh)::integer = p_nam_sinh)
    AND (p_truong_hoc IS NULL OR p_truong_hoc = '' OR ts.truong_hoc ILIKE '%' || p_truong_hoc || '%')
    AND (p_trang_thai_ho_so IS NULL OR p_trang_thai_ho_so = 'ALL' OR ts.trang_thai_ho_so = p_trang_thai_ho_so)
    AND (p_sale_phu_trach_id IS NULL OR p_sale_phu_trach_id = 'ALL' OR ts.sale_phu_trach_id = p_sale_phu_trach_id)
    AND (p_bang_dau IS NULL OR p_bang_dau = 'ALL' OR ts.bang_dau = p_bang_dau)
  ORDER BY ts.thi_sinh_id
$$;

CREATE OR REPLACE FUNCTION public.fn_xem_chi_tiet_thisinh(p_thi_sinh_id varchar)
RETURNS TABLE (
  ho_ten varchar,
  email varchar,
  nam_sinh integer,
  truong_hoc varchar,
  trang_thai_ho_so varchar,
  so_dien_thoai varchar,
  cccd varchar,
  bang_dau varchar,
  sale_phu_trach_id varchar,
  sale_phu_trach varchar
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, public, auth, pg_temp
AS $$
BEGIN
  IF NOT public.fn_current_user_can_view_student_records() THEN
    RAISE EXCEPTION 'Tài khoản không có quyền xem hồ sơ thí sinh.'
      USING ERRCODE = '42501';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.thisinh WHERE thi_sinh_id = p_thi_sinh_id) THEN
    RAISE EXCEPTION 'Thí sinh % không tồn tại.', p_thi_sinh_id;
  END IF;
  RETURN QUERY
  SELECT ts.ho_ten, ts.email, extract(year FROM ts.ngay_sinh)::integer,
         ts.truong_hoc, ts.trang_thai_ho_so, ts.sdt, ts.cccd,
         ts.bang_dau, ts.sale_phu_trach_id, nv.ho_ten
  FROM public.thisinh ts
  LEFT JOIN public.nhanvien nv ON nv.nhan_vien_id = ts.sale_phu_trach_id
  WHERE ts.thi_sinh_id = p_thi_sinh_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.fn_tim_kiem_thisinh(p_tu_khoa varchar)
RETURNS TABLE (
  id varchar,
  ho_va_ten varchar,
  email varchar,
  so_dien_thoai varchar,
  nam_sinh integer,
  truong_hoc varchar,
  trang_thai_ho_so varchar,
  bang_dau varchar,
  sale_phu_trach_id varchar,
  sale_phu_trach varchar
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, public, auth, pg_temp
AS $$
DECLARE
  v_kw text := NULLIF(btrim(p_tu_khoa), '');
BEGIN
  IF NOT public.fn_current_user_can_view_student_records() THEN
    RAISE EXCEPTION 'Tài khoản không có quyền tìm kiếm hồ sơ thí sinh.'
      USING ERRCODE = '42501';
  END IF;
  IF v_kw IS NULL THEN
    RAISE EXCEPTION 'Vui lòng nhập thông tin cần tìm kiếm.';
  END IF;
  v_kw := '%' || unaccent(lower(v_kw)) || '%';
  RETURN QUERY
  SELECT ts.thi_sinh_id, ts.ho_ten, ts.email, ts.sdt,
         extract(year FROM ts.ngay_sinh)::integer, ts.truong_hoc,
         ts.trang_thai_ho_so, ts.bang_dau, ts.sale_phu_trach_id, nv.ho_ten
  FROM public.thisinh ts
  LEFT JOIN public.nhanvien nv ON nv.nhan_vien_id = ts.sale_phu_trach_id
  WHERE unaccent(lower(ts.thi_sinh_id)) LIKE v_kw
     OR unaccent(lower(ts.ho_ten)) LIKE v_kw
     OR unaccent(lower(ts.email)) LIKE v_kw
     OR unaccent(lower(COALESCE(ts.truong_hoc, ''))) LIKE v_kw
     OR ts.cccd LIKE v_kw
  ORDER BY ts.thi_sinh_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.fn_kpi_thisinh_top_pct(
  p_ky varchar DEFAULT NULL,
  p_ty_le numeric DEFAULT 3
) RETURNS TABLE (thi_sinh_id varchar, ho_ten varchar, truong_hoc varchar, bang_dau varchar, diem_pct numeric)
LANGUAGE plpgsql
STABLE
AS $$
BEGIN
  IF p_ty_le <= 0 OR p_ty_le > 100 THEN
    RAISE EXCEPTION 'Tỷ lệ xếp hạng phải lớn hơn 0 và không vượt quá 100.';
  END IF;

  RETURN QUERY
  WITH r AS (SELECT * FROM public.fn_ky_bao_cao(p_ky)),
  x AS (
    SELECT b.thi_sinh_id, max(b.diem_pct) AS diem_pct
    FROM public.vw_bainop_diem_pct b
    CROSS JOIN r
    WHERE b.trang_thai = 'DA_CHAM_DIEM'
      AND b.diem_pct IS NOT NULL
      AND b.thoi_gian_nop >= r.tu
      AND b.thoi_gian_nop < r.den
    GROUP BY b.thi_sinh_id
  ),
  ranked AS (
    SELECT x.*, row_number() OVER (ORDER BY x.diem_pct DESC) AS position,
           count(*) OVER () AS total
    FROM x
  )
  SELECT ts.thi_sinh_id, ts.ho_ten, ts.truong_hoc, ts.bang_dau, ranked.diem_pct
  FROM ranked
  JOIN public.thisinh ts ON ts.thi_sinh_id = ranked.thi_sinh_id
  WHERE ranked.position <= ceil(ranked.total * p_ty_le / 100.0)
  ORDER BY ranked.diem_pct DESC;
END;
$$;

CREATE OR REPLACE FUNCTION public.fn_bao_cao_du_lieu(
  p_ma_bao_cao varchar,
  p_ky varchar DEFAULT NULL
) RETURNS SETOF jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, public, auth, pg_temp
AS $$
DECLARE
  v_permission varchar;
  v_employee_id varchar;
BEGIN
  v_permission := CASE p_ma_bao_cao
    WHEN 'overview_summary' THEN 'BAO_CAO_TONG_QUAN'
    WHEN 'overview_progress' THEN 'BAO_CAO_TONG_QUAN'
    WHEN 'overview_comparison' THEN 'BAO_CAO_TONG_QUAN'
    WHEN 'overview_enrollment_funnel' THEN 'BAO_CAO_TONG_QUAN'
    WHEN 'overview_registration_trend' THEN 'BAO_CAO_TONG_QUAN'
    WHEN 'student_summary' THEN 'BAO_CAO_THISINH'
    WHEN 'student_status' THEN 'BAO_CAO_THISINH'
    WHEN 'student_schools' THEN 'BAO_CAO_THISINH'
    WHEN 'student_top1' THEN 'BAO_CAO_THISINH'
    WHEN 'student_top3' THEN 'BAO_CAO_THISINH'
    WHEN 'student_school_scores' THEN 'BAO_CAO_THISINH'
    WHEN 'student_utm' THEN 'BAO_CAO_THISINH'
    WHEN 'revenue_summary' THEN 'BAO_CAO_DOANH_THU'
    WHEN 'payment_funnel' THEN 'BAO_CAO_DOANH_THU'
    WHEN 'revenue_by_province' THEN 'BAO_CAO_DOANH_THU'
    WHEN 'revenue_trend' THEN 'BAO_CAO_DOANH_THU'
    WHEN 'revenue_by_channel' THEN 'BAO_CAO_DOANH_THU'
    WHEN 'revenue_reconciliation' THEN 'BAO_CAO_DOANH_THU'
    WHEN 'transaction_details' THEN 'BAO_CAO_DOANH_THU_CHI_TIET'
    WHEN 'sponsor_summary' THEN 'BAO_CAO_DOI_TAC'
    WHEN 'sponsor_funnel' THEN 'BAO_CAO_DOI_TAC'
    WHEN 'sponsor_tiers' THEN 'BAO_CAO_DOI_TAC'
    WHEN 'sponsor_list' THEN 'BAO_CAO_DOI_TAC'
    WHEN 'supplier_list' THEN 'BAO_CAO_DOI_TAC'
    WHEN 'sponsor_revenue_by_province' THEN 'BAO_CAO_DOI_TAC'
    WHEN 'sponsor_trend' THEN 'BAO_CAO_DOI_TAC'
    WHEN 'sponsor_daily_revenue' THEN 'BAO_CAO_DOI_TAC'
    WHEN 'submission_status' THEN 'BAO_CAO_HOC_VU'
    WHEN 'submission_failures' THEN 'BAO_CAO_HOC_VU'
    WHEN 'submission_failures_by_province' THEN 'BAO_CAO_HOC_VU'
    WHEN 'contest_rounds' THEN 'BAO_CAO_HOC_VU'
    WHEN 'contest_results' THEN 'BAO_CAO_HOC_VU'
    WHEN 'contest_top56' THEN 'BAO_CAO_HOC_VU'
    WHEN 'contest_finalists' THEN 'BAO_CAO_HOC_VU'
    WHEN 'submission_details' THEN 'BAO_CAO_HOC_VU'
    WHEN 'support_conversations' THEN 'BAO_CAO_HO_TRO'
    WHEN 'support_by_status' THEN 'BAO_CAO_HO_TRO'
    WHEN 'support_by_entity' THEN 'BAO_CAO_HO_TRO'
    WHEN 'support_faq_summary' THEN 'BAO_CAO_HO_TRO'
    WHEN 'support_faq_categories' THEN 'BAO_CAO_HO_TRO'
    WHEN 'security_log' THEN 'BAO_CAO_AN_NINH'
    WHEN 'import_sessions' THEN 'BAO_CAO_AN_NINH'
    WHEN 'import_errors' THEN 'BAO_CAO_AN_NINH'
    ELSE NULL
  END;

  IF v_permission IS NULL THEN
    RAISE EXCEPTION 'Mã báo cáo không hợp lệ.';
  END IF;

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

  IF v_employee_id IS NULL OR NOT public.fn_check_user_permission(v_employee_id, v_permission) THEN
    RAISE EXCEPTION 'Tài khoản không có quyền xem báo cáo này.'
      USING ERRCODE = '42501';
  END IF;

  IF p_ma_bao_cao = 'transaction_details'
    AND NOT EXISTS (
      SELECT 1
      FROM public.nhanvien_vaitro_ct nvt
      WHERE nvt.nhan_vien_id = v_employee_id
        AND nvt.role_id IN ('ADMIN', 'MANAGER')
    )
  THEN
    RAISE EXCEPTION 'Chỉ ADMIN và MANAGER được xem thông tin giao dịch chi tiết.'
      USING ERRCODE = '42501';
  END IF;

  CASE p_ma_bao_cao
    WHEN 'overview_summary' THEN
      RETURN QUERY SELECT to_jsonb(r) FROM public.fn_kpi_tongquan_chiso(p_ky) r;
      RETURN QUERY SELECT to_jsonb(r) FROM public.fn_kpi_thisinh_tong_quan(p_ky) r;
      RETURN QUERY SELECT to_jsonb(r) FROM public.fn_kpi_doanhthu_tong_quan(p_ky) r;
    WHEN 'overview_progress' THEN
      RETURN QUERY SELECT to_jsonb(r) FROM public.fn_kpi_tongquan_tien_do(p_ky) r;
    WHEN 'overview_comparison' THEN
      RETURN QUERY
      WITH current_period AS (SELECT * FROM public.fn_ky_bao_cao(p_ky)),
      previous_period AS (
        SELECT to_char((r.tu - interval '3 months')::date, 'YYYY')
               || '-Q' || extract(quarter FROM (r.tu - interval '3 months'))::int::text AS ky
        FROM current_period r
      ),
      current_students AS (
        SELECT * FROM public.fn_kpi_thisinh_tong_quan(p_ky)
      ),
      previous_students AS (
        SELECT * FROM public.fn_kpi_thisinh_tong_quan((SELECT ky FROM previous_period))
      )
      SELECT jsonb_build_object(
        'dang_ky_thi', current_students.dang_ky_thi,
        'dang_ky_ky_truoc', previous_students.dang_ky_thi,
        'target_gap', current_students.dang_ky_thi - previous_students.dang_ky_thi
      )
      FROM current_students
      CROSS JOIN previous_students;
    WHEN 'overview_enrollment_funnel' THEN
      RETURN QUERY SELECT to_jsonb(r) FROM public.fn_kpi_thisinh_pheu(p_ky) r;
    WHEN 'overview_registration_trend' THEN
      RETURN QUERY
      WITH period AS (SELECT * FROM public.fn_ky_bao_cao(p_ky)),
      bounds AS (
        SELECT greatest(tu, (least(den - 1, current_date) - 15)::date) AS tu,
               least(den - 1, current_date) AS den
        FROM period
      )
      SELECT jsonb_build_object(
        'ngay', days.ngay,
        'so_dang_ky', count(DISTINCT dk.thi_sinh_id)
      )
      FROM bounds
      CROSS JOIN LATERAL generate_series(bounds.tu, bounds.den, interval '1 day') AS days(ngay)
      LEFT JOIN public.dangky dk ON dk.ngay_dang_ky::date = days.ngay::date
      GROUP BY days.ngay
      ORDER BY days.ngay;
    WHEN 'student_summary' THEN
      RETURN QUERY SELECT to_jsonb(r) FROM public.fn_kpi_thisinh_tong_quan(p_ky) r;
    WHEN 'student_status' THEN
      RETURN QUERY SELECT to_jsonb(r) FROM public.vw_thisinh_bieudo_trangthai r;
    WHEN 'student_schools' THEN
      RETURN QUERY SELECT to_jsonb(r) FROM public.vw_thisinh_bieudo_theo_truong r;
    WHEN 'student_top1' THEN
      RETURN QUERY SELECT to_jsonb(r) FROM public.fn_kpi_thisinh_top1pct(p_ky) r;
    WHEN 'student_top3' THEN
      RETURN QUERY SELECT to_jsonb(r) FROM public.fn_kpi_thisinh_top_pct(p_ky, 3) r;
    WHEN 'student_school_scores' THEN
      RETURN QUERY SELECT to_jsonb(r) FROM public.fn_kpi_thisinh_truong_bang(p_ky) r;
    WHEN 'student_utm' THEN
      RETURN QUERY SELECT to_jsonb(r) FROM public.fn_kpi_thisinh_utm_roi(p_ky) r;
    WHEN 'revenue_summary' THEN
      RETURN QUERY SELECT to_jsonb(r) FROM public.fn_kpi_doanhthu_tong_quan(p_ky) r;
    WHEN 'payment_funnel' THEN
      RETURN QUERY SELECT to_jsonb(r) FROM public.fn_kpi_doanhthu_pheu(p_ky) r;
    WHEN 'revenue_by_province' THEN
      RETURN QUERY SELECT to_jsonb(r) FROM public.fn_kpi_doanhthu_theo_khu_vuc(p_ky) r;
    WHEN 'revenue_trend' THEN
      RETURN QUERY SELECT to_jsonb(r) FROM public.fn_kpi_doanhthu_xu_huong(p_ky) r;
    WHEN 'revenue_by_channel' THEN
      RETURN QUERY SELECT to_jsonb(r) FROM public.fn_kpi_doanhthu_theo_kenh(p_ky) r;
    WHEN 'revenue_reconciliation' THEN
      RETURN QUERY SELECT to_jsonb(r) FROM public.fn_kpi_doanhthu_cho_doi_soat_48h(p_ky) r;
    WHEN 'transaction_details' THEN
      RETURN QUERY SELECT to_jsonb(r) FROM public.fn_kpi_doanhthu_chi_tiet(p_ky) r;
    WHEN 'sponsor_summary' THEN
      RETURN QUERY SELECT to_jsonb(r) FROM public.fn_kpi_taitro_tong_quan(p_ky) r;
    WHEN 'sponsor_funnel' THEN
      RETURN QUERY SELECT to_jsonb(r) FROM public.fn_kpi_taitro_pheu(p_ky) r;
    WHEN 'sponsor_tiers' THEN
      RETURN QUERY SELECT to_jsonb(r) FROM public.fn_kpi_taitro_co_cau_cap() r;
    WHEN 'sponsor_list' THEN
      RETURN QUERY SELECT to_jsonb(r) FROM public.fn_kpi_taitro_nha_tai_tro(p_ky) r;
    WHEN 'supplier_list' THEN
      RETURN QUERY SELECT to_jsonb(r) FROM public.fn_kpi_taitro_ds_doi_tac(p_ky) r;
    WHEN 'sponsor_revenue_by_province' THEN
      RETURN QUERY SELECT to_jsonb(r) FROM public.fn_kpi_taitro_doanh_thu_tinh(p_ky) r;
    WHEN 'sponsor_trend' THEN
      RETURN QUERY SELECT to_jsonb(r) FROM public.fn_kpi_taitro_xu_huong(p_ky) r;
    WHEN 'sponsor_daily_revenue' THEN
      RETURN QUERY SELECT to_jsonb(r) FROM public.fn_kpi_taitro_doanh_thu_ngay(p_ky) r;
    WHEN 'submission_status' THEN
      RETURN QUERY SELECT to_jsonb(r) FROM public.vw_baocao_phanbo_trangthai_bainop r;
    WHEN 'submission_failures' THEN
      RETURN QUERY SELECT to_jsonb(r) FROM public.vw_baitap_tyle_khong_dat_cao r ORDER BY r.tyle_khong_dat_pt DESC;
    WHEN 'submission_failures_by_province' THEN
      RETURN QUERY SELECT to_jsonb(r) FROM public.vw_tyle_khong_dat_theo_khuvuc r ORDER BY r.tyle_khong_dat_pt DESC;
    WHEN 'contest_rounds' THEN
      RETURN QUERY SELECT to_jsonb(r) FROM public.vw_pm_vong_thi r;
    WHEN 'contest_results' THEN
      RETURN QUERY SELECT to_jsonb(r) FROM public.vw_export_ketqua_vongloai r;
    WHEN 'contest_top56' THEN
      RETURN QUERY
      SELECT jsonb_build_object(
        'hang_toan_quoc', r.hang_toan_quoc,
        'thi_sinh_id', r.thi_sinh_id,
        'ho_ten', r.ho_ten,
        'truong_hoc', r.truong_hoc,
        'bang_dau', r.bang_dau,
        'tong_diem', r.tong_diem,
        'thoi_gian_lam_bai_giay', r.thoi_gian_lam_bai_giay
      )
      FROM public.vw_pm_top_vong_loai r
      WHERE r.hang_toan_quoc <= 56
      ORDER BY r.hang_toan_quoc;
    WHEN 'contest_finalists' THEN
      RETURN QUERY
      SELECT jsonb_build_object(
        'thi_sinh_id', r.thi_sinh_id,
        'ho_ten', r.ho_ten,
        'truong_hoc', r.truong_hoc,
        'tinh_thanh', r.tinh_thanh,
        'bang_dau', r.bang_dau,
        'ten_cuoc_thi', r.ten_cuoc_thi,
        'ngay_thi_chung_ket', r.ngay_thi_chung_ket,
        'tinh_trang_xac_nhan', r.tinh_trang_xac_nhan
      )
      FROM public.vw_export_danhsach_chungket r
      ORDER BY r.ho_ten;
    WHEN 'submission_details' THEN
      RETURN QUERY SELECT to_jsonb(r) FROM public.vw_pm_chi_tiet_bai_lam r;
    WHEN 'support_conversations' THEN
      RETURN QUERY SELECT to_jsonb(r) FROM public.vw_ds_hoithoai r ORDER BY r.thoi_gian DESC LIMIT 200;
    WHEN 'support_by_status' THEN
      RETURN QUERY SELECT jsonb_build_object('trang_thai', q.trang_thai, 'so_luong', count(*))
      FROM public.qna q GROUP BY q.trang_thai ORDER BY q.trang_thai;
    WHEN 'support_by_entity' THEN
      RETURN QUERY SELECT jsonb_build_object('loai_doi_tuong', r.loai_doi_tuong, 'so_luong', count(*))
      FROM public.vw_ds_hoithoai r GROUP BY r.loai_doi_tuong ORDER BY r.loai_doi_tuong;
    WHEN 'support_faq_summary' THEN
      RETURN QUERY SELECT to_jsonb(r) FROM public.vw_faq_tongquan r;
    WHEN 'support_faq_categories' THEN
      RETURN QUERY SELECT to_jsonb(r) FROM public.vw_faq_cay_danhmuc r;
    WHEN 'security_log' THEN
      RETURN QUERY SELECT to_jsonb(r) FROM public.fn_nhat_ky_bao_mat(100) r;
    WHEN 'import_sessions' THEN
      RETURN QUERY
      SELECT jsonb_build_object(
        'import_id', i.import_id,
        'ten_file', i.ten_file,
        'ten_bang_dich', i.ten_bang_dich,
        'thoi_gian_bat_dau', i.thoi_gian_bat_dau,
        'thoi_gian_ket_thuc', i.thoi_gian_ket_thuc,
        'tong_so_dong', i.tong_so_dong,
        'so_dong_thanh_cong', i.so_dong_thanh_cong,
        'so_dong_loi', i.so_dong_loi,
        'trang_thai', i.trang_thai
      )
      FROM public.audit_log_import i
      ORDER BY i.thoi_gian_bat_dau DESC
      LIMIT 100;
    WHEN 'import_errors' THEN
      RETURN QUERY
      SELECT jsonb_build_object(
        'import_id', d.import_id,
        'ten_file', i.ten_file,
        'so_dong', d.so_dong,
        'cot_loi', d.cot_loi,
        'vi_tri_loi', d.vi_tri_loi,
        'ma_loi', d.ma_loi,
        'thong_diep_loi', d.thong_diep_loi,
        'thoi_gian_loi', d.thoi_gian_loi
      )
      FROM public.audit_log_import_chitiet d
      JOIN public.audit_log_import i ON i.import_id = d.import_id
      WHERE d.ket_qua = 'LOI'
      ORDER BY d.thoi_gian_loi DESC
      LIMIT 200;
  END CASE;
END;
$$;

REVOKE ALL ON FUNCTION public.fn_current_user_report_permissions() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_current_user_report_permissions() TO authenticated;
REVOKE ALL ON FUNCTION public.fn_current_user_can_view_student_records() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.fn_xuat_thisinh(character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.fn_xuat_thisinh(character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying) TO authenticated;
REVOKE ALL ON FUNCTION public.fn_loc_thisinh(character varying, character varying, integer, character varying, character varying, character varying, character varying) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.fn_loc_thisinh(character varying, character varying, integer, character varying, character varying, character varying, character varying) TO authenticated;
REVOKE ALL ON FUNCTION public.fn_xem_chi_tiet_thisinh(character varying) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.fn_xem_chi_tiet_thisinh(character varying) TO authenticated;
REVOKE ALL ON FUNCTION public.fn_tim_kiem_thisinh(character varying) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.fn_tim_kiem_thisinh(character varying) TO authenticated;
REVOKE ALL ON FUNCTION public.fn_bao_cao_du_lieu(character varying, character varying) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_bao_cao_du_lieu(character varying, character varying) TO authenticated;

DO $$
DECLARE
  routine record;
BEGIN
  FOR routine IN
    SELECT p.oid::regprocedure AS signature
    FROM pg_catalog.pg_proc p
    JOIN pg_catalog.pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.prokind = 'f'
      AND (
        p.proname LIKE 'fn_kpi_%'
        OR p.proname LIKE 'fn_dashboard_%'
        OR p.proname IN ('fn_nhat_ky_bao_mat', 'fn_tiep_can')
      )
  LOOP
    EXECUTE format('REVOKE ALL ON FUNCTION %s FROM PUBLIC, anon, authenticated', routine.signature);
  END LOOP;
END;
$$;

REVOKE ALL ON TABLE public.audit_log_import, public.audit_log_import_chitiet FROM anon, authenticated;
REVOKE ALL ON TABLE
  public.thisinh,
  public.dangky,
  public.dangkyweb,
  public.thanhtoan,
  public.bainop,
  public.quangcao,
  public.doanhnghiep_pipeline,
  public.qna
FROM anon;
REVOKE ALL ON TABLE
  public.vw_giao_dich_le_phi,
  public.vw_doitac_taitro_theo_cap,
  public.vw_doitac_taitro_gia_tri,
  public.vw_doitac_taitro_pheu,
  public.vw_doitac_taitro_tong_quan,
  public.vw_export_baocao_taitro,
  public.vw_doitac_cungcap_tong_quan,
  public.vw_export_baocao_dn_thisinh,
  public.vw_dashboard_phan_bo_bang_thi,
  public.vw_dashboard_phan_bo_nhom_tuoi,
  public.vw_thisinh_bieudo_trangthai,
  public.vw_thisinh_bieudo_theo_truong,
  public.vw_bainop_diem_pct,
  public.vw_baocao_phanbo_trangthai_bainop,
  public.vw_baitap_tyle_khong_dat_cao,
  public.vw_tyle_khong_dat_theo_khuvuc,
  public.vw_pm_tong_quan,
  public.vw_pm_vong_thi,
  public.vw_pm_chi_tiet_vong,
  public.vw_pm_vong_loai_tong_quan,
  public.vw_pm_bxh_tam_thoi,
  public.vw_pm_top_vong_loai,
  public.vw_pm_chi_tiet_bai_lam,
  public.vw_pm_chungket_tong_quan,
  public.vw_export_ketqua_vongloai,
  public.vw_export_danhsach_chungket,
  public.vw_ds_baitap,
  public.vw_ds_bainop,
  public.vw_rag_tongquan,
  public.vw_faq_tongquan
FROM anon, authenticated;

NOTIFY pgrst, 'reload schema';

-- =============================================================================
-- Source: supabase/migrations/20261109000100_partner_company_access.sql
-- =============================================================================

ALTER TABLE public.doanhnghiep
  ADD COLUMN IF NOT EXISTS auth_user_id uuid;

CREATE UNIQUE INDEX IF NOT EXISTS uq_doanhnghiep_auth_user_id
  ON public.doanhnghiep (auth_user_id)
  WHERE auth_user_id IS NOT NULL;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_catalog.pg_constraint
    WHERE conrelid = 'public.doanhnghiep'::regclass
      AND conname = 'fk_doanhnghiep_auth_user'
  ) THEN
    ALTER TABLE public.doanhnghiep
      ADD CONSTRAINT fk_doanhnghiep_auth_user
      FOREIGN KEY (auth_user_id) REFERENCES auth.users(id) ON DELETE SET NULL;
  END IF;
END;
$$;

COMMENT ON COLUMN public.doanhnghiep.auth_user_id IS
  'Supabase Auth UID assigned by an administrator; one Auth account can map to only one company.';

CREATE OR REPLACE FUNCTION public.fn_current_user_is_active_employee()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, public, auth, pg_temp
AS $$
  SELECT auth.uid() IS NOT NULL
    AND EXISTS (
      SELECT 1
      FROM public.nhanvien nv
      WHERE nv.trang_thai = 'ACTIVE'
        AND (
          nv.user_id = auth.uid()
          OR (
            auth.jwt() ->> 'email' IS NOT NULL
            AND lower(nv.email) = lower(auth.jwt() ->> 'email')
          )
        )
    )
$$;

CREATE OR REPLACE FUNCTION public.fn_current_partner_company_id()
RETURNS varchar
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, public, auth, pg_temp
AS $$
  SELECT dn.doanh_nghiep_id
  FROM public.doanhnghiep dn
  WHERE auth.uid() IS NOT NULL
    AND NOT public.fn_current_user_is_active_employee()
    AND dn.auth_user_id = auth.uid()
$$;

CREATE OR REPLACE FUNCTION public.fn_guard_partner_employee_mapping()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, auth, pg_temp
AS $$
BEGIN
  IF NEW.auth_user_id IS NOT NULL AND EXISTS (
    SELECT 1
    FROM public.nhanvien nv
    LEFT JOIN auth.users au ON au.id = NEW.auth_user_id
    WHERE nv.trang_thai = 'ACTIVE'
      AND (
        nv.user_id = NEW.auth_user_id
        OR (au.email IS NOT NULL AND lower(nv.email) = lower(au.email))
      )
  ) THEN
    RAISE EXCEPTION 'Không thể liên kết tài khoản nhân viên với tài khoản đối tác.';
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_guard_partner_employee_mapping ON public.doanhnghiep;
CREATE TRIGGER trg_guard_partner_employee_mapping
  BEFORE INSERT OR UPDATE OF auth_user_id ON public.doanhnghiep
  FOR EACH ROW EXECUTE FUNCTION public.fn_guard_partner_employee_mapping();

REVOKE ALL ON FUNCTION public.fn_current_user_is_active_employee() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_current_user_is_active_employee() TO authenticated;
REVOKE ALL ON FUNCTION public.fn_current_partner_company_id() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_current_partner_company_id() TO authenticated;
REVOKE ALL ON FUNCTION public.fn_guard_partner_employee_mapping() FROM PUBLIC, anon, authenticated;

DO $$
DECLARE
  relation record;
BEGIN
  FOR relation IN
    SELECT c.relname
    FROM pg_catalog.pg_class c
    JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname = 'public'
      AND c.relkind IN ('r', 'p')
  LOOP
    EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY', relation.relname);
    EXECUTE format('DROP POLICY IF EXISTS auth_employee_access ON public.%I', relation.relname);
    EXECUTE format(
      'CREATE POLICY auth_employee_access ON public.%I FOR ALL TO authenticated USING (public.fn_current_user_is_active_employee()) WITH CHECK (public.fn_current_user_is_active_employee())',
      relation.relname
    );
    EXECUTE format('DROP POLICY IF EXISTS anon_existing_read ON public.%I', relation.relname);
    EXECUTE format(
      'CREATE POLICY anon_existing_read ON public.%I FOR SELECT TO anon USING (true)',
      relation.relname
    );
  END LOOP;
END;
$$;

CREATE POLICY partner_company_read ON public.doanhnghiep
  FOR SELECT TO authenticated
  USING (auth_user_id = auth.uid() AND NOT public.fn_current_user_is_active_employee());

CREATE POLICY partner_referrals_read ON public.dangkyweb
  FOR SELECT TO authenticated
  USING (doanh_nghiep_id = public.fn_current_partner_company_id());

CREATE POLICY partner_sponsorship_pipeline_read ON public.doanhnghiep_pipeline
  FOR SELECT TO authenticated
  USING (doanh_nghiep_id = public.fn_current_partner_company_id());

CREATE POLICY partner_sponsorship_reach_read ON public.truyenthong_taitro
  FOR SELECT TO authenticated
  USING (doanh_nghiep_id = public.fn_current_partner_company_id());

CREATE POLICY partner_company_qna_read ON public.qna
  FOR SELECT TO authenticated
  USING (doanh_nghiep_id = public.fn_current_partner_company_id());

CREATE POLICY partner_company_qna_feedback_read ON public.qna_phanhoi
  FOR SELECT TO authenticated
  USING (
    doanh_nghiep_id = public.fn_current_partner_company_id()
    AND EXISTS (
      SELECT 1
      FROM public.qna q
      WHERE q.qna_id = qna_phanhoi.qna_id
        AND q.doanh_nghiep_id = public.fn_current_partner_company_id()
    )
  );

-- Invoker views keep the caller's row-level policies in force.
DO $$
DECLARE
  relation record;
BEGIN
  FOR relation IN
    SELECT c.relname
    FROM pg_catalog.pg_class c
    JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname = 'public'
      AND c.relkind = 'v'
  LOOP
    EXECUTE format('ALTER VIEW public.%I SET (security_invoker = true)', relation.relname);
  END LOOP;
END;
$$;

CREATE OR REPLACE FUNCTION public.fn_partner_portal_overview()
RETURNS TABLE (
  ten_doanh_nghiep varchar,
  ma_so_thue varchar,
  dia_chi varchar,
  email_lien_he varchar,
  sdt_lien_he varchar,
  hinh_thuc varchar,
  loai_tai_tro varchar,
  cap_do_tai_tro varchar,
  so_luong_thi_sinh bigint,
  tong_le_phi_thu_duoc numeric,
  hoa_hong_phai_tra numeric,
  thuc_thu_tai_tro numeric,
  luot_hien_thi bigint,
  luot_tuong_tac bigint
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, public, auth, pg_temp
AS $$
  SELECT dn.ten_doanh_nghiep, dn.ma_so_thue, dn.dia_chi, dn.email_lien_he,
         dn.sdt_lien_he, dn.hinh_thuc, dn.loai_tai_tro, dn.cap_do_tai_tro,
         referrals.so_luong_thi_sinh, referrals.tong_le_phi_thu_duoc,
         referrals.hoa_hong_phai_tra, sponsorship.thuc_thu_tai_tro,
         reach.luot_hien_thi, reach.luot_tuong_tac
  FROM public.doanhnghiep dn
  CROSS JOIN LATERAL (
    SELECT count(dkw.thanh_toan_id)::bigint AS so_luong_thi_sinh,
           COALESCE(sum(dkw.so_tien) FILTER (
             WHERE dkw.trang_thai_thanh_toan = 'THANH_TOAN_THANH_CONG'
           ), 0)::numeric AS tong_le_phi_thu_duoc,
           COALESCE(sum(COALESCE(dkw.hoa_hong, dkw.so_tien * public.fn_ty_le_hoa_hong()))
             FILTER (WHERE dkw.trang_thai_thanh_toan = 'THANH_TOAN_THANH_CONG'), 0)::numeric
             AS hoa_hong_phai_tra
    FROM public.dangkyweb dkw
    WHERE dkw.doanh_nghiep_id = dn.doanh_nghiep_id
  ) referrals
  CROSS JOIN LATERAL (
    SELECT COALESCE(sum(p.so_tien), 0)::numeric AS thuc_thu_tai_tro
    FROM public.doanhnghiep_pipeline p
    WHERE p.doanh_nghiep_id = dn.doanh_nghiep_id
      AND p.giai_doan = 'THUC_THU'
  ) sponsorship
  CROSS JOIN LATERAL (
    SELECT COALESCE(sum(t.luot_hien_thi), 0)::bigint AS luot_hien_thi,
           COALESCE(sum(t.luot_tuong_tac), 0)::bigint AS luot_tuong_tac
    FROM public.truyenthong_taitro t
    WHERE t.doanh_nghiep_id = dn.doanh_nghiep_id
  ) reach
  WHERE auth.uid() IS NOT NULL
    AND NOT public.fn_current_user_is_active_employee()
    AND dn.auth_user_id = auth.uid()
$$;

REVOKE ALL ON FUNCTION public.fn_partner_portal_overview() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.fn_partner_portal_overview() TO authenticated;

NOTIFY pgrst, 'reload schema';
