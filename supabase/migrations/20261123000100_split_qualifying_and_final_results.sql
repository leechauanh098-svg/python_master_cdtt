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

CREATE OR REPLACE VIEW public.vw_export_danhsach_chungket AS
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
