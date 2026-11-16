CREATE OR REPLACE FUNCTION public.fn_current_user_can_view_kpi_dashboard()
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
    JOIN public.vaitro vt ON vt.role_id = nvt.role_id AND vt.trang_thai = 'DANG_AP_DUNG'
    WHERE nv.trang_thai = 'ACTIVE'
      AND (
        nv.user_id = auth.uid()
        OR (
          nv.user_id IS NULL
          AND lower(nv.email) = lower(auth.jwt() ->> 'email')
        )
      )
      AND (
        vt.role_id = 'ADMIN'
        OR (vt.role_id = 'MANAGER' AND nv.phong_ban = 'BAN_TO_CHUC')
      )
  )
$$;

CREATE OR REPLACE FUNCTION public.fn_kpi_set_target(
  p_kpi_id varchar,
  p_period varchar,
  p_group varchar,
  p_name varchar,
  p_target numeric,
  p_reason varchar DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, auth, pg_temp
AS $$
DECLARE
  v_employee_id varchar(20);
  v_employee_name varchar(100);
  v_old_target numeric(18,2);
  v_exists boolean;
  v_expected_prefix text;
BEGIN
  SELECT nv.nhan_vien_id, nv.ho_ten
  INTO v_employee_id, v_employee_name
  FROM public.nhanvien nv
  JOIN public.nhanvien_vaitro_ct nvt ON nvt.nhan_vien_id = nv.nhan_vien_id
  JOIN public.vaitro vt ON vt.role_id = nvt.role_id AND vt.trang_thai = 'DANG_AP_DUNG'
  WHERE nv.trang_thai = 'ACTIVE'
    AND vt.role_id = 'ADMIN'
    AND (
      nv.user_id = auth.uid()
      OR (
        nv.user_id IS NULL
        AND lower(nv.email) = lower(auth.jwt() ->> 'email')
      )
    )
  LIMIT 1;

  IF auth.uid() IS NULL OR v_employee_id IS NULL THEN
    RAISE EXCEPTION 'Chỉ Admin mới được thiết lập mục tiêu KPI.' USING ERRCODE = '42501';
  END IF;
  IF p_target IS NULL OR p_target <= 0 THEN
    RAISE EXCEPTION 'Mục tiêu phải lớn hơn 0.';
  END IF;
  IF p_period !~ '^[0-9]{4}-Q[1-4]$' THEN
    RAISE EXCEPTION 'Kỳ KPI không hợp lệ.';
  END IF;
  IF p_name IS NULL OR btrim(p_name) = '' THEN
    RAISE EXCEPTION 'Tên KPI không được để trống.';
  END IF;
  IF p_kpi_id IS NULL THEN
    RAISE EXCEPTION 'Mã KPI không được để trống.';
  END IF;

  v_expected_prefix := CASE p_group
    WHEN 'THI_SINH' THEN 'KPI_TS_'
    WHEN 'DOANH_THU' THEN 'KPI_DT_'
    WHEN 'DOANH_NGHIEP' THEN 'KPI_DN_'
    ELSE NULL
  END;
  IF v_expected_prefix IS NULL OR p_kpi_id <> v_expected_prefix || replace(p_period, '-Q', 'Q') THEN
    RAISE EXCEPTION 'Mã KPI không khớp nhóm và kỳ được chọn.';
  END IF;
  IF EXISTS (
    SELECT 1 FROM public.kpi_muctieu k
    WHERE k.ky_bao_cao = p_period
      AND k.nhom = p_group
      AND k.ten_kpi = btrim(p_name)
      AND k.kpi_id <> p_kpi_id
  ) THEN
    RAISE EXCEPTION 'KPI này đã có mục tiêu trong kỳ.';
  END IF;

  SELECT k.muc_tieu
  INTO v_old_target
  FROM public.kpi_muctieu k
  WHERE k.kpi_id = p_kpi_id
  FOR UPDATE;
  v_exists := FOUND;
  IF v_exists AND length(btrim(COALESCE(p_reason, ''))) < 10 THEN
    RAISE EXCEPTION 'Lý do thay đổi phải có ít nhất 10 ký tự.';
  END IF;

  INSERT INTO public.kpi_muctieu (kpi_id, ky_bao_cao, nhom, ten_kpi, muc_tieu)
  VALUES (p_kpi_id, p_period, p_group, btrim(p_name), p_target)
  ON CONFLICT (kpi_id) DO UPDATE
    SET ky_bao_cao = EXCLUDED.ky_bao_cao,
        nhom = EXCLUDED.nhom,
        ten_kpi = EXCLUDED.ten_kpi,
        muc_tieu = EXCLUDED.muc_tieu;

  INSERT INTO public.audit_log (
    nguoi_thuc_hien_id, nguoi_thuc_hien, actor_role_id, vai_tro,
    ten_bang, id_ban_ghi, hanh_dong, du_lieu_cu, du_lieu_moi, ghi_chu
  ) VALUES (
    v_employee_id, v_employee_name, 'ADMIN', 'Quản trị viên',
    'kpi_muctieu', p_kpi_id, CASE WHEN v_exists THEN 'SUA' ELSE 'THEM' END,
    CASE WHEN v_exists THEN v_old_target::text ELSE NULL END,
    p_target::text,
    NULLIF(btrim(p_reason), '')
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.fn_admin_module_data(
  p_resource text,
  p_ky text DEFAULT NULL,
  p_filter text DEFAULT NULL,
  p_limit integer DEFAULT 50
)
RETURNS TABLE (row_data jsonb)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_limit integer := LEAST(GREATEST(COALESCE(p_limit, 50), 1), 100);
  v_ky text := COALESCE(NULLIF(p_ky, ''), to_char(CURRENT_DATE, 'YYYY') || '-Q' || extract(quarter FROM CURRENT_DATE)::int::text);
  v_filter text := NULLIF(btrim(p_filter), '');
BEGIN
  IF p_resource IN (
    'kpi_overview', 'kpi_signals', 'kpi_progress', 'student_kpi',
    'student_funnel', 'sponsor_kpi', 'revenue_kpi', 'revenue_funnel',
    'revenue_channels', 'revenue_trend', 'payment_pending', 'marketing_roi'
  ) AND NOT public.fn_current_user_can_view_kpi_dashboard() THEN
    RAISE EXCEPTION 'Tài khoản không có quyền xem dữ liệu KPI toàn hệ thống.' USING ERRCODE = '42501';
  END IF;

  CASE p_resource
    WHEN 'student_status' THEN
      RETURN QUERY SELECT to_jsonb(v) FROM public.vw_thisinh_bieudo_trangthai v LIMIT v_limit;
    WHEN 'student_schools' THEN
      RETURN QUERY SELECT to_jsonb(v) FROM public.vw_thisinh_bieudo_theo_truong v LIMIT v_limit;
    WHEN 'students' THEN
      RETURN QUERY SELECT to_jsonb(v) FROM public.fn_loc_thisinh(NULL, v_filter, NULL, NULL, NULL, NULL, NULL) v LIMIT v_limit;
    WHEN 'partner_sponsor_summary' THEN
      RETURN QUERY SELECT to_jsonb(v) FROM public.vw_doitac_taitro_tong_quan v LIMIT v_limit;
    WHEN 'partner_sponsors' THEN
      RETURN QUERY SELECT to_jsonb(v) FROM public.vw_doitac_taitro_ds v LIMIT v_limit;
    WHEN 'partner_supplier_summary' THEN
      RETURN QUERY SELECT to_jsonb(v) FROM public.vw_doitac_cungcap_tong_quan v LIMIT v_limit;
    WHEN 'partner_suppliers' THEN
      RETURN QUERY SELECT to_jsonb(v) FROM public.vw_doitac_cungcap_ds v LIMIT v_limit;
    WHEN 'contest_summary' THEN
      RETURN QUERY SELECT to_jsonb(v) FROM public.vw_pm_tong_quan v LIMIT v_limit;
    WHEN 'contests' THEN
      RETURN QUERY SELECT to_jsonb(v) FROM public.vw_pm_vong_thi v LIMIT v_limit;
    WHEN 'contest_round_summary' THEN
      RETURN QUERY SELECT to_jsonb(v) FROM public.vw_pm_vong_loai_tong_quan v LIMIT v_limit;
    WHEN 'final_round_summary' THEN
      RETURN QUERY SELECT to_jsonb(v) FROM public.vw_pm_chungket_tong_quan v LIMIT v_limit;
    WHEN 'assignment_summary' THEN
      RETURN QUERY SELECT to_jsonb(v) FROM public.fn_baitap_tong_quan_kpi(NULL) v LIMIT v_limit;
    WHEN 'assignments' THEN
      RETURN QUERY SELECT to_jsonb(v) FROM public.fn_baitap_tim_kiem(v_filter, NULL, NULL, 1, v_limit) v LIMIT v_limit;
    WHEN 'submission_status' THEN
      RETURN QUERY SELECT to_jsonb(v) FROM public.vw_baocao_phanbo_trangthai_bainop v LIMIT v_limit;
    WHEN 'submissions' THEN
      RETURN QUERY SELECT to_jsonb(v) FROM public.fn_bainop_tim_kiem(v_filter, NULL, NULL, NULL, 1, v_limit) v LIMIT v_limit;
    WHEN 'failure_by_assignment' THEN
      RETURN QUERY SELECT to_jsonb(v) FROM public.vw_baitap_tyle_khong_dat_cao v LIMIT v_limit;
    WHEN 'failure_by_region' THEN
      RETURN QUERY SELECT to_jsonb(v) FROM public.vw_tyle_khong_dat_theo_khuvuc v LIMIT v_limit;
    WHEN 'rag_summary' THEN
      RETURN QUERY SELECT to_jsonb(v) FROM public.vw_rag_tongquan v LIMIT v_limit;
    WHEN 'documents' THEN
      RETURN QUERY SELECT to_jsonb(v) FROM public.fn_tailieu_tim_kiem_loc(v_filter, NULL, NULL, 1, v_limit) v LIMIT v_limit;
    WHEN 'conversations' THEN
      RETURN QUERY
        SELECT to_jsonb(v) FROM public.fn_hoithoai_tim_kiem_theo_ten(COALESCE(v_filter, '')) v
        ORDER BY v.thoi_gian DESC LIMIT v_limit;
    WHEN 'faq_summary' THEN
      RETURN QUERY SELECT to_jsonb(v) FROM public.vw_faq_tongquan v LIMIT v_limit;
    WHEN 'faq_categories' THEN
      RETURN QUERY SELECT to_jsonb(v) FROM public.vw_faq_cay_danhmuc v LIMIT v_limit;
    WHEN 'faq_list' THEN
      IF v_filter IS NULL THEN
        RETURN QUERY SELECT to_jsonb(v) FROM public.fn_faq_danh_sach_theo_danh_muc(NULL) v LIMIT v_limit;
      ELSE
        RETURN QUERY SELECT to_jsonb(v) FROM public.fn_faq_tim_kiem(v_filter) v LIMIT v_limit;
      END IF;
    WHEN 'kpi_overview' THEN
      RETURN QUERY SELECT to_jsonb(v) FROM public.fn_kpi_tongquan_chiso(v_ky) v LIMIT v_limit;
    WHEN 'kpi_signals' THEN
      RETURN QUERY SELECT to_jsonb(v) FROM public.fn_kpi_tongquan_tin_hieu(v_ky) v LIMIT v_limit;
    WHEN 'kpi_progress' THEN
      RETURN QUERY SELECT to_jsonb(v) FROM public.fn_kpi_tongquan_tien_do(v_ky) v LIMIT v_limit;
    WHEN 'student_kpi' THEN
      RETURN QUERY SELECT to_jsonb(v) FROM public.fn_kpi_thisinh_tong_quan(v_ky) v LIMIT v_limit;
    WHEN 'student_funnel' THEN
      RETURN QUERY SELECT to_jsonb(v) FROM public.fn_kpi_thisinh_pheu(v_ky) v LIMIT v_limit;
    WHEN 'sponsor_kpi' THEN
      RETURN QUERY SELECT to_jsonb(v) FROM public.fn_kpi_taitro_tong_quan(v_ky) v LIMIT v_limit;
    WHEN 'revenue_kpi' THEN
      RETURN QUERY SELECT to_jsonb(v) FROM public.fn_kpi_doanhthu_tong_quan(v_ky) v LIMIT v_limit;
    WHEN 'revenue_funnel' THEN
      RETURN QUERY SELECT to_jsonb(v) FROM public.fn_kpi_doanhthu_pheu(v_ky) v LIMIT v_limit;
    WHEN 'revenue_channels' THEN
      RETURN QUERY SELECT to_jsonb(v) FROM public.fn_kpi_doanhthu_theo_kenh(v_ky) v LIMIT v_limit;
    WHEN 'revenue_trend' THEN
      RETURN QUERY SELECT to_jsonb(v) FROM public.fn_kpi_doanhthu_xu_huong(v_ky) v LIMIT v_limit;
    WHEN 'payment_pending' THEN
      RETURN QUERY SELECT to_jsonb(v) FROM public.fn_kpi_doanhthu_cho_doi_soat_48h(v_ky) v LIMIT v_limit;
    WHEN 'marketing_roi' THEN
      RETURN QUERY SELECT to_jsonb(v) FROM public.fn_kpi_thisinh_utm_roi(v_ky) v LIMIT v_limit;
    WHEN 'roles' THEN
      RETURN QUERY SELECT to_jsonb(v) FROM public.vw_vaitro v LIMIT v_limit;
    WHEN 'permissions' THEN
      RETURN QUERY SELECT to_jsonb(v) FROM public.fn_ma_tran_phan_quyen(COALESCE(v_filter, 'ADMIN')) v LIMIT v_limit;
    WHEN 'security_audit' THEN
      RETURN QUERY SELECT to_jsonb(v) FROM public.fn_nhat_ky_bao_mat(v_limit) v LIMIT v_limit;
    ELSE
      RAISE EXCEPTION 'Unsupported admin module resource: %', p_resource;
  END CASE;
END;
$$;

REVOKE ALL ON FUNCTION public.fn_current_user_can_view_kpi_dashboard() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_current_user_can_view_kpi_dashboard() TO authenticated;
REVOKE ALL ON FUNCTION public.fn_kpi_set_target(varchar, varchar, varchar, varchar, numeric, varchar) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_kpi_set_target(varchar, varchar, varchar, varchar, numeric, varchar) TO authenticated;
REVOKE ALL ON FUNCTION public.fn_admin_module_data(text, text, text, integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_admin_module_data(text, text, text, integer) TO authenticated;

REVOKE ALL ON FUNCTION public.fn_kpi_tongquan_chiso(character varying) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.fn_kpi_tongquan_tin_hieu(character varying) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.fn_kpi_tongquan_tien_do(character varying) FROM PUBLIC, anon, authenticated;

NOTIFY pgrst, 'reload schema';
