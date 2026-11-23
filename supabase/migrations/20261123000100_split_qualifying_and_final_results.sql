CREATE OR REPLACE VIEW public.vw_export_ketqua_vongloai AS
SELECT
  bt.cuoc_thi_id,
  ct.ten_cuoc_thi,
  ts.bang_dau,
  dense_rank() OVER (
    PARTITION BY bt.cuoc_thi_id, ts.bang_dau
    ORDER BY bn.tong_diem DESC NULLS LAST, bn.thoi_gian_lam_bai_giay ASC
  ) AS thu_hang,
  ts.thi_sinh_id,
  ts.ho_ten,
  ts.email,
  ts.sdt,
  ts.truong_hoc,
  bn.tong_diem,
  bn.thoi_gian_lam_bai_giay,
  bn.thoi_gian_nop,
  CASE
    WHEN bn.tong_diem >= bt.diem_dat THEN 'ĐẠT YÊU CẦU'
    ELSE 'KHÔNG ĐẠT'
  END AS ket_qua_xet
FROM public.bainop bn
JOIN public.thisinh ts ON ts.thi_sinh_id = bn.thi_sinh_id
JOIN public.baitap bt ON bt.bai_tap_id = bn.bai_tap_id
JOIN public.cuocthi ct ON ct.cuoc_thi_id = bt.cuoc_thi_id
WHERE bn.trang_thai = 'DA_CHAM_DIEM'
  AND bn.tong_diem IS NOT NULL
  AND ts.bang_dau IN ('BANG_A', 'BANG_B')
  AND bt.bang_dau IN ('BANG_A', 'BANG_B')
  AND ct.ten_cuoc_thi NOT ILIKE '%Chung kết%'
  AND ct.cuoc_thi_id NOT ILIKE '%CK%'
  AND ct.cuoc_thi_id <> 'CT03';

DROP VIEW IF EXISTS public.vw_export_danhsach_chungket;

CREATE VIEW public.vw_export_danhsach_chungket AS
SELECT
  bt.cuoc_thi_id,
  ct.ten_cuoc_thi,
  ts.bang_dau,
  dense_rank() OVER (
    PARTITION BY bt.cuoc_thi_id, ts.bang_dau
    ORDER BY bn.tong_diem DESC NULLS LAST, bn.thoi_gian_lam_bai_giay ASC
  ) AS thu_hang,
  ts.thi_sinh_id,
  ts.ho_ten,
  ts.email,
  ts.sdt,
  ts.truong_hoc,
  bn.tong_diem,
  bn.thoi_gian_lam_bai_giay,
  bn.thoi_gian_nop,
  CASE
    WHEN bn.tong_diem >= bt.diem_dat THEN 'ĐẠT YÊU CẦU'
    ELSE 'KHÔNG ĐẠT'
  END AS ket_qua_xet
FROM public.bainop bn
JOIN public.thisinh ts ON ts.thi_sinh_id = bn.thi_sinh_id
JOIN public.baitap bt ON bt.bai_tap_id = bn.bai_tap_id
JOIN public.cuocthi ct ON ct.cuoc_thi_id = bt.cuoc_thi_id
WHERE bn.trang_thai = 'DA_CHAM_DIEM'
  AND bn.tong_diem IS NOT NULL
  AND ts.bang_dau IN ('BANG_A', 'BANG_B')
  AND (
    ct.ten_cuoc_thi ILIKE '%Chung kết%'
    OR ct.cuoc_thi_id ILIKE '%CK%'
    OR ct.cuoc_thi_id = 'CT03'
  );

UPDATE public.bainop
SET trang_thai = 'DA_CHAM_DIEM',
    updated_at = now()
WHERE trang_thai <> 'DA_CHAM_DIEM';

REVOKE ALL ON TABLE public.vw_export_ketqua_vongloai FROM PUBLIC, anon;
REVOKE ALL ON TABLE public.vw_export_danhsach_chungket FROM PUBLIC, anon;
GRANT SELECT ON TABLE public.vw_export_ketqua_vongloai TO authenticated;
GRANT SELECT ON TABLE public.vw_export_danhsach_chungket TO authenticated;

CREATE OR REPLACE FUNCTION public.fn_bao_cao_ketqua_chungket(
  p_ky varchar DEFAULT NULL
) RETURNS SETOF jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, public, auth, pg_temp
AS $$
DECLARE
  v_employee_id varchar;
  v_permission boolean := false;
BEGIN
  SELECT nv.nhan_vien_id
  INTO v_employee_id
  FROM public.nhanvien nv
  WHERE nv.user_id = auth.uid()
    AND nv.trang_thai = 'ACTIVE'
  LIMIT 1;

  IF v_employee_id IS NULL THEN
    RAISE EXCEPTION 'Không xác định được nhân viên đăng nhập.';
  END IF;

  SELECT EXISTS (
    SELECT 1
    FROM public.nhanvien_vaitro_ct nvt
    JOIN public.vaitro_quyen vq ON vq.role_id = nvt.role_id
    WHERE nvt.nhan_vien_id = v_employee_id
      AND vq.permission_id = 'BAO_CAO_HOC_VU'
  ) INTO v_permission;

  IF NOT v_permission THEN
    RAISE EXCEPTION 'Không có quyền xem kết quả học vụ.';
  END IF;

  RETURN QUERY
  SELECT to_jsonb(r)
  FROM public.vw_export_danhsach_chungket r
  WHERE p_ky IS NULL
     OR r.thoi_gian_nop >= (
       SELECT tu
       FROM public.fn_ky_bao_cao(p_ky)
     )
  ORDER BY r.bang_dau, r.thu_hang NULLS LAST, r.tong_diem DESC NULLS LAST;
END;
$$;

REVOKE ALL ON FUNCTION public.fn_bao_cao_ketqua_chungket(varchar) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_bao_cao_ketqua_chungket(varchar) TO authenticated;
