DROP VIEW IF EXISTS public.vw_export_danhsach_chungket;

CREATE VIEW public.vw_export_danhsach_chungket AS
WITH best AS (
  SELECT DISTINCT ON (bt.cuoc_thi_id, bn.thi_sinh_id)
    bt.cuoc_thi_id,
    bt.bai_tap_id,
    bt.diem_dat,
    bn.thi_sinh_id,
    bn.tong_diem,
    bn.thoi_gian_lam_bai_giay,
    bn.thoi_gian_nop
  FROM public.bainop bn
  JOIN public.baitap bt ON bt.bai_tap_id = bn.bai_tap_id
  WHERE bn.trang_thai = 'DA_CHAM_DIEM'
    AND bn.tong_diem IS NOT NULL
    AND (
      EXISTS (
        SELECT 1
        FROM public.thanhtoan tt
        JOIN public.cuocthi paid_ct ON paid_ct.cuoc_thi_id = tt.cuoc_thi_id
        WHERE tt.thi_sinh_id = bn.thi_sinh_id
          AND tt.trang_thai_thanh_toan = 'THANH_TOAN_THANH_CONG'
          AND paid_ct.ten_cuoc_thi NOT ILIKE '%Chung kết%'
          AND paid_ct.cuoc_thi_id NOT ILIKE '%CK%'
          AND paid_ct.cuoc_thi_id <> 'CT03'
      )
      OR EXISTS (
        SELECT 1
        FROM public.dangkyweb dkw
        JOIN public.thisinh paid_ts ON paid_ts.thi_sinh_id = dkw.thi_sinh_id
        WHERE dkw.thi_sinh_id = bn.thi_sinh_id
          AND dkw.bang_dau = paid_ts.bang_dau
          AND dkw.trang_thai_thanh_toan = 'THANH_TOAN_THANH_CONG'
      )
    )
  ORDER BY bt.cuoc_thi_id,
           bn.thi_sinh_id,
           bn.tong_diem DESC NULLS LAST,
           bn.thoi_gian_lam_bai_giay ASC NULLS LAST,
           bn.lan_nop DESC
)
SELECT
  best.cuoc_thi_id,
  ct.ten_cuoc_thi,
  ts.bang_dau,
  dense_rank() OVER (
    PARTITION BY best.cuoc_thi_id, ts.bang_dau
    ORDER BY best.tong_diem DESC NULLS LAST,
             best.thoi_gian_lam_bai_giay ASC NULLS LAST
  ) AS thu_hang,
  ts.thi_sinh_id,
  ts.ho_ten,
  ts.email,
  ts.sdt,
  ts.truong_hoc,
  best.tong_diem,
  best.thoi_gian_lam_bai_giay,
  best.thoi_gian_nop,
  CASE
    WHEN best.tong_diem >= best.diem_dat THEN 'ĐẠT YÊU CẦU'
    ELSE 'KHÔNG ĐẠT'
  END AS ket_qua_xet
FROM best
JOIN public.thisinh ts ON ts.thi_sinh_id = best.thi_sinh_id
JOIN public.baitap bt ON bt.bai_tap_id = best.bai_tap_id
JOIN public.cuocthi ct ON ct.cuoc_thi_id = best.cuoc_thi_id
WHERE ts.bang_dau IN ('BANG_A', 'BANG_B')
  AND (
    ct.ten_cuoc_thi ILIKE '%Chung kết%'
    OR ct.cuoc_thi_id ILIKE '%CK%'
    OR ct.cuoc_thi_id = 'CT03'
  );

REVOKE ALL ON TABLE public.vw_export_danhsach_chungket FROM PUBLIC, anon;
GRANT SELECT ON TABLE public.vw_export_danhsach_chungket TO authenticated;

DROP FUNCTION IF EXISTS public.fn_bao_cao_ketqua_chungket(varchar);

CREATE FUNCTION public.fn_bao_cao_ketqua_chungket(
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
  CROSS JOIN LATERAL public.fn_ky_bao_cao(p_ky) ky
  WHERE r.bang_dau = p_bang
    AND (
      p_ky IS NULL
      OR (
        r.thoi_gian_nop >= ky.tu::timestamp
        AND r.thoi_gian_nop < (ky.den + 1)::timestamp
      )
    )
  ORDER BY r.thu_hang, r.tong_diem DESC;
END;
$$;

REVOKE ALL ON FUNCTION public.fn_bao_cao_ketqua_chungket(varchar, varchar) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_bao_cao_ketqua_chungket(varchar, varchar) TO authenticated;

NOTIFY pgrst, 'reload schema';
