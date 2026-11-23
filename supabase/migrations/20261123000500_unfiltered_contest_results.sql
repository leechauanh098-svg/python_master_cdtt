CREATE OR REPLACE FUNCTION public.fn_bao_cao_ketqua_chungket(
  p_ky varchar,
  p_bang varchar
) RETURNS SETOF jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, public, auth, pg_temp
AS $$
DECLARE
  v_employee_id varchar;
BEGIN
  IF p_bang NOT IN ('BANG_A', 'BANG_B') THEN
    RAISE EXCEPTION 'Bảng đấu không hợp lệ.';
  END IF;

  SELECT nv.nhan_vien_id
  INTO v_employee_id
  FROM public.nhanvien nv
  WHERE nv.user_id = auth.uid()
    AND nv.trang_thai = 'ACTIVE'
  LIMIT 1;

  IF v_employee_id IS NULL OR NOT EXISTS (
    SELECT 1
    FROM public.nhanvien_vaitro_ct nvt
    JOIN public.vaitro_quyen vq ON vq.role_id = nvt.role_id
    WHERE nvt.nhan_vien_id = v_employee_id
      AND vq.permission_id = 'BAO_CAO_HOC_VU'
  ) THEN
    RAISE EXCEPTION 'Không có quyền xem kết quả học vụ.';
  END IF;

  RETURN QUERY
  SELECT to_jsonb(r)
  FROM public.vw_export_danhsach_chungket r
  WHERE r.bang_dau = p_bang
  ORDER BY r.thu_hang, r.tong_diem DESC;
END;
$$;

CREATE OR REPLACE FUNCTION public.fn_bao_cao_ds_top10_vongloai(
  p_ky varchar DEFAULT NULL
) RETURNS SETOF jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, public, auth, pg_temp
AS $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM public.fn_current_user_report_permissions()
    WHERE permission_id = 'BAO_CAO_HOC_VU'
  ) THEN
    RAISE EXCEPTION 'Tài khoản không có quyền xem báo cáo học vụ.'
      USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
  SELECT to_jsonb(r)
  FROM public.vw_pm_baocao_ketqua_vong r
  WHERE r.vong_thi = 'Vòng loại'
    AND r.du_dieu_kien_vao_chung_ket
  ORDER BY r.cuoc_thi_id, r.bang_dau, r.tinh_thanh, r.thu_hang, r.thi_sinh_id;
END;
$$;

REVOKE ALL ON FUNCTION public.fn_bao_cao_ketqua_chungket(varchar, varchar) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.fn_bao_cao_ds_top10_vongloai(varchar) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_bao_cao_ketqua_chungket(varchar, varchar) TO authenticated;
GRANT EXECUTE ON FUNCTION public.fn_bao_cao_ds_top10_vongloai(varchar) TO authenticated;

NOTIFY pgrst, 'reload schema';
