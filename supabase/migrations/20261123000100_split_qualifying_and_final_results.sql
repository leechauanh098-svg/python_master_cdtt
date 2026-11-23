CREATE OR REPLACE VIEW public.vw_export_ketqua_vongloai AS
SELECT
  bt.cuoc_thi_id,
  ct.ten_cuoc_thi,
  ts.bang_dau,
  dense_rank() OVER (
    PARTITION BY ts.bang_dau
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
WHERE ts.bang_dau IN ('BANG_A', 'BANG_B')
  AND bt.bang_dau IN ('BANG_A', 'BANG_B')
  AND ct.ten_cuoc_thi NOT ILIKE '%Chung kết%'
  AND ct.cuoc_thi_id NOT ILIKE '%CK%'
  AND ct.cuoc_thi_id <> 'CT03';

CREATE OR REPLACE VIEW public.vw_baocao_xep_hang_vongloai AS
WITH best AS (
  SELECT
    ts.bang_dau,
    ts.thi_sinh_id,
    ts.ho_ten,
    ts.truong_hoc,
    max(bn.tong_diem) AS tong_diem,
    min(bn.thoi_gian_lam_bai_giay) AS thoi_gian_lam_bai_giay
  FROM public.bainop bn
  JOIN public.thisinh ts ON ts.thi_sinh_id = bn.thi_sinh_id
  JOIN public.baitap bt ON bt.bai_tap_id = bn.bai_tap_id
  JOIN public.cuocthi ct ON ct.cuoc_thi_id = bt.cuoc_thi_id
  WHERE bn.trang_thai = 'DA_CHAM_DIEM'
    AND bn.tong_diem IS NOT NULL
    AND ts.bang_dau IN ('BANG_A', 'BANG_B')
    AND ct.ten_cuoc_thi NOT ILIKE '%Chung kết%'
    AND ct.cuoc_thi_id NOT ILIKE '%CK%'
    AND ct.cuoc_thi_id <> 'CT03'
  GROUP BY ts.bang_dau, ts.thi_sinh_id, ts.ho_ten, ts.truong_hoc
)
SELECT
  row_number() OVER (
    PARTITION BY bang_dau
    ORDER BY tong_diem DESC, thoi_gian_lam_bai_giay ASC
  ) AS hang,
  bang_dau,
  thi_sinh_id,
  ho_ten,
  truong_hoc,
  tong_diem
FROM best;

CREATE OR REPLACE FUNCTION public.fn_baocao_xep_hang_vongloai(
  p_bang varchar
) RETURNS SETOF jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, public, auth, pg_temp
AS $$
BEGIN
  IF p_bang NOT IN ('BANG_A', 'BANG_B') THEN
    RAISE EXCEPTION 'Bảng đấu không hợp lệ.';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.nhanvien nv
    JOIN public.nhanvien_vaitro_ct nvt ON nvt.nhan_vien_id = nv.nhan_vien_id
    JOIN public.vaitro_quyen vq ON vq.role_id = nvt.role_id
    WHERE nv.user_id = auth.uid()
      AND nv.trang_thai = 'ACTIVE'
      AND vq.permission_id = 'BAO_CAO_HOC_VU'
  ) THEN
    RAISE EXCEPTION 'Không có quyền xem báo cáo học vụ.';
  END IF;

  RETURN QUERY
  SELECT to_jsonb(r)
  FROM public.vw_baocao_xep_hang_vongloai r
  WHERE r.bang_dau = p_bang
  ORDER BY r.hang;
END;
$$;

REVOKE ALL ON FUNCTION public.fn_baocao_xep_hang_vongloai(varchar) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_baocao_xep_hang_vongloai(varchar) TO authenticated;
