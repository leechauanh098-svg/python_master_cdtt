-- Run after 004_reporting.sql and 005_kpi_rbac.sql.
-- This RPC exposes a fixed allowlist of read-only module data to signed-in users.
-- It intentionally does not expose mutation, export, or arbitrary SQL functions.

CREATE OR REPLACE FUNCTION public.fn_admin_module_data(
  p_resource text,
  p_ky text DEFAULT '2026-Q3',
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
  v_ky text := COALESCE(NULLIF(p_ky, ''), '2026-Q3');
  v_filter text := NULLIF(btrim(p_filter), '');
BEGIN
  CASE p_resource
    WHEN 'student_status' THEN
      RETURN QUERY SELECT to_jsonb(v) FROM public.vw_thisinh_bieudo_trangthai v LIMIT v_limit;
    WHEN 'student_schools' THEN
      RETURN QUERY SELECT to_jsonb(v) FROM public.vw_thisinh_bieudo_theo_truong v LIMIT v_limit;
    WHEN 'students' THEN
      RETURN QUERY
        SELECT to_jsonb(v)
        FROM public.fn_loc_thisinh(NULL, v_filter, NULL, NULL, NULL, NULL, NULL) v
        LIMIT v_limit;

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
      RETURN QUERY
        SELECT to_jsonb(v)
        FROM public.fn_baitap_tim_kiem(v_filter, NULL, NULL, 1, v_limit) v
        LIMIT v_limit;
    WHEN 'submission_status' THEN
      RETURN QUERY SELECT to_jsonb(v) FROM public.vw_baocao_phanbo_trangthai_bainop v LIMIT v_limit;
    WHEN 'submissions' THEN
      RETURN QUERY
        SELECT to_jsonb(v)
        FROM public.fn_bainop_tim_kiem(v_filter, NULL, NULL, NULL, 1, v_limit) v
        LIMIT v_limit;
    WHEN 'failure_by_assignment' THEN
      RETURN QUERY SELECT to_jsonb(v) FROM public.vw_baitap_tyle_khong_dat_cao v LIMIT v_limit;
    WHEN 'failure_by_region' THEN
      RETURN QUERY SELECT to_jsonb(v) FROM public.vw_tyle_khong_dat_theo_khuvuc v LIMIT v_limit;

    WHEN 'rag_summary' THEN
      RETURN QUERY SELECT to_jsonb(v) FROM public.vw_rag_tongquan v LIMIT v_limit;
    WHEN 'documents' THEN
      RETURN QUERY
        SELECT to_jsonb(v)
        FROM public.fn_tailieu_tim_kiem_loc(v_filter, NULL, NULL, 1, v_limit) v
        LIMIT v_limit;

    WHEN 'conversations' THEN
      RETURN QUERY
        SELECT to_jsonb(v)
        FROM public.fn_hoithoai_tim_kiem_theo_ten(COALESCE(v_filter, '')) v
        ORDER BY v.thoi_gian DESC
        LIMIT v_limit;
    WHEN 'faq_summary' THEN
      RETURN QUERY SELECT to_jsonb(v) FROM public.vw_faq_tongquan v LIMIT v_limit;
    WHEN 'faq_categories' THEN
      RETURN QUERY SELECT to_jsonb(v) FROM public.vw_faq_cay_danhmuc v LIMIT v_limit;
    WHEN 'faq_list' THEN
      IF v_filter IS NULL THEN
        RETURN QUERY
          SELECT to_jsonb(v)
          FROM public.fn_faq_danh_sach_theo_danh_muc(NULL) v
          LIMIT v_limit;
      ELSE
        RETURN QUERY
          SELECT to_jsonb(v)
          FROM public.fn_faq_tim_kiem(v_filter) v
          LIMIT v_limit;
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
      RETURN QUERY
        SELECT to_jsonb(v)
        FROM public.fn_ma_tran_phan_quyen(COALESCE(v_filter, 'ADMIN')) v
        LIMIT v_limit;
    WHEN 'security_audit' THEN
      RETURN QUERY SELECT to_jsonb(v) FROM public.fn_nhat_ky_bao_mat(v_limit) v LIMIT v_limit;
    ELSE
      RAISE EXCEPTION 'Unsupported admin module resource: %', p_resource;
  END CASE;
END;
$$;

REVOKE ALL ON FUNCTION public.fn_admin_module_data(text, text, text, integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_admin_module_data(text, text, text, integer) TO authenticated;

-- Q3 dashboard RPCs are read-only and use fixed, aggregate result shapes.
REVOKE ALL ON FUNCTION public.fn_dashboard_card_public(integer) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.fn_dashboard_xu_huong_16_ngay_public() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.fn_dashboard_pheu_chuyen_doi_web_public(integer) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.fn_dashboard_phan_bo_nhom_tuoi_public() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.fn_dashboard_card_q3_public(integer) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.fn_dashboard_xu_huong_q3_public(integer) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.fn_dashboard_pheu_q3_public(integer) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.fn_dashboard_phan_bo_bang_thi_q3_public(integer) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.fn_dashboard_phan_bo_nhom_tuoi_q3_public(integer) FROM PUBLIC, anon;
REVOKE SELECT ON public.vw_dashboard_phan_bo_bang_thi FROM anon;
REVOKE SELECT ON public.vw_dashboard_phan_bo_nhom_tuoi FROM anon;

GRANT EXECUTE ON FUNCTION public.fn_dashboard_card_q3_public(integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.fn_dashboard_xu_huong_q3_public(integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.fn_dashboard_pheu_q3_public(integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.fn_dashboard_phan_bo_bang_thi_q3_public(integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.fn_dashboard_phan_bo_nhom_tuoi_q3_public(integer) TO authenticated;

NOTIFY pgrst, 'reload schema';
