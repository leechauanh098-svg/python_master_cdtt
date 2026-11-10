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
