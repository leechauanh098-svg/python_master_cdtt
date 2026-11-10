'use client'

import { useEffect, useMemo, useState } from 'react'
import { getSupabaseBrowserClient } from '@/lib/supabase-browser'

export type DataRow = Record<string, unknown>
export type DataSource =
  | { kind: 'view'; name: string }
  | { kind: 'rpc'; name: string; args?: Record<string, unknown> }

const fieldLabels: Record<string, string> = {
  bai_nop_id: 'Mã bài nộp',
  bai_qua_han: 'Bài quá hạn',
  bai_tap_id: 'Mã bài tập',
  bang: 'Bảng',
  bang_dau: 'Bảng đấu',
  brand_reach: 'Lượt tiếp cận thương hiệu',
  cap_do_tai_tro: 'Cấp độ tài trợ',
  cau_hoi_chuan: 'Câu hỏi',
  cau_tra_loi_chuan: 'Câu trả lời',
  cccd: 'Số CCCD',
  chien_dich: 'Chiến dịch',
  chi_phi: 'Chi phí',
  cong_ty_giu_lai: 'Doanh thu công ty giữ lại',
  cuoc_thi_id: 'Mã cuộc thi',
  da_co_embedding: 'Đã tạo dữ liệu tìm kiếm',
  da_thanh_toan: 'Đã thanh toán',
  danh_gia: 'Đánh giá',
  danh_muc: 'Danh mục',
  danh_muc_hien_thi: 'Danh mục',
  dang_doi_soat: 'Đang đối soát',
  dang_ky_id: 'Mã đăng ký',
  doi_tuong_id: 'Mã đối tượng',
  dang_ky_ky_truoc: 'Đăng ký kỳ trước',
  dang_ky_thi: 'Đăng ký thi',
  dang_ky: 'Đăng ký',
  den_ngay: 'Đến ngày',
  diem_cao_nhat: 'Điểm cao nhất',
  diem_dat: 'Điểm đạt',
  diem_dat_duoc: 'Điểm đạt được',
  diem_toi_da: 'Điểm tối đa',
  dap_an_chon_id: 'Mã đáp án đã chọn',
  dap_an_dung_id: 'Mã đáp án đúng',
  doanh_nghiep_id: 'Mã doanh nghiệp',
  doanh_thu: 'Doanh thu',
  doanh_thu_le_phi: 'Doanh thu lệ phí',
  doanh_thu_tu_doi_tac: 'Doanh thu từ đối tác',
  doi_tac_cung_cap: 'Đối tác cung cấp',
  dung_luong_mb: 'Dung lượng (MB)',
  duoc_phep: 'Được phép',
  diem_trung_binh: 'Điểm trung bình',
  email: 'Email',
  faq_id: 'Mã FAQ',
  gia_tri_quy_doi: 'Giá trị quy đổi',
  gia_tri: 'Giá trị',
  gia_tri_hien_tai: 'Giá trị hiện tại',
  gia_tri_trung_binh: 'Giá trị trung bình',
  giao_dich_thanh_cong: 'Giao dịch thành công',
  giai_doan: 'Giai đoạn',
  giao_dich_id: 'Mã giao dịch',
  han_dang_ky: 'Hạn đăng ký',
  hang_toan_quoc: 'Xếp hạng toàn quốc',
  hoan_thanh_pct: 'Tỷ lệ hoàn thành (%)',
  hoa_hong_doi_tac: 'Hoa hồng đối tác',
  hoa_hong: 'Hoa hồng',
  hoa_hong_phai_tra: 'Hoa hồng phải trả',
  hop_dong_da_ky: 'Hợp đồng đã ký',
  ho_ten: 'Họ và tên',
  kenh: 'Kênh',
  ket_qua_xet: 'Kết quả xét',
  ket_qua: 'Kết quả',
  khoang_diem: 'Khoảng điểm',
  kpi_id: 'Mã chỉ số',
  ky_bao_cao: 'Kỳ báo cáo',
  lan_nop: 'Lần nộp',
  le_phi_thi: 'Lệ phí thi',
  loai_tai_lieu: 'Loại tài liệu',
  loai_cau_hoi: 'Loại câu hỏi',
  loai_doi_tuong: 'Loại đối tượng',
  loai_tai_tro: 'Loại tài trợ',
  luot_tiep_can: 'Lượt tiếp cận',
  luot_xem: 'Lượt xem',
  ma_gioi_thieu: 'Mã giới thiệu',
  ma_cuoc_thi: 'Mã cuộc thi',
  ma_thisinh: 'Mã thí sinh',
  ma_thi_sinh: 'Mã thí sinh',
  ma_giao_dich: 'Mã giao dịch',
  ma_thanh_toan: 'Mã thanh toán',
  ma_loi: 'Mã lỗi',
  ma_so_thue: 'Mã số thuế',
  modun_chucnang: 'Nhóm chức năng',
  mo_ta: 'Mô tả',
  muc_tieu: 'Mục tiêu',
  nhan_xet_cau_hoi: 'Nhận xét câu hỏi',
  nam_sinh: 'Năm sinh',
  nguon: 'Nguồn',
  nguon_utm: 'Nguồn UTM',
  nguon_lead: 'Nguồn khách hàng tiềm năng',
  ngay_cap_nhat: 'Ngày cập nhật',
  ngay_bat_dau: 'Ngày bắt đầu',
  ngay_dang_tai: 'Ngày đăng tải',
  ngay_ket_thuc: 'Ngày kết thúc',
  ngay: 'Ngày',
  ngay_thi_chung_ket: 'Ngày thi chung kết',
  nhom: 'Nhóm',
  nhom_tin_hieu: 'Nhóm tín hiệu',
  nhom_tuoi: 'Nhóm tuổi',
  noi_dung: 'Nội dung',
  noi_dung_cau_hoi: 'Nội dung câu hỏi',
  noi_dung_hoi: 'Nội dung câu hỏi',
  noi_dung_tra_loi: 'Câu trả lời của thí sinh',
  hinh_thuc: 'Hình thức',
  nhom_kpi: 'Nhóm chỉ số',
  noi_dung_rut_gon: 'Nội dung tóm tắt',
  permission_id: 'Mã quyền',
  qna_id: 'Mã hội thoại',
  kenh_tuong_tac: 'Kênh tương tác',
  cot_loi: 'Cột lỗi',
  so_dong: 'Số dòng',
  so_dong_thanh_cong: 'Số dòng thành công',
  so_dong_loi: 'Số dòng lỗi',
  tong_so_dong: 'Tổng số dòng',
  ten_bang_dich: 'Tên bảng đích',
  ten_file: 'Tên tệp',
  ten_hien_thi: 'Tên hiển thị',
  import_id: 'Mã lần nhập',
  vi_tri_loi: 'Vị trí lỗi',
  thong_diep_loi: 'Chi tiết lỗi',
  thoi_gian_loi: 'Thời điểm lỗi',
  so_bai_hoan_thanh: 'Số bài hoàn thành',
  so_giao_dich_thanh_cong: 'Số giao dịch thành công',
  roi_pct: 'Tỷ suất hoàn vốn (%)',
  sdt: 'Số điện thoại',
  so_tien: 'Số tiền',
  so_bai_da_nop: 'Số bài đã nộp',
  so_bai_dang_cham: 'Số bài đang chấm',
  so_cau_hoi: 'Số câu hỏi',
  so_dang_ky: 'Số lượt đăng ký',
  so_doi_tac_cung_cap: 'Số đối tác cung cấp',
  so_doan: 'Số đoạn',
  so_doanh_nghiep: 'Số doanh nghiệp',
  so_giao_dich: 'Số giao dịch',
  so_lan_nop_bai_toi_da: 'Số lần nộp tối đa',
  so_luong: 'Số lượng',
  so_luot: 'Số lượt làm bài',
  so_luong_da_nop: 'Số lượng đã nộp',
  so_nha_tai_tro: 'Số nhà tài trợ',
  so_thi_sinh: 'Số thí sinh',
  so_thi_sinh_cung_cap: 'Số thí sinh cung cấp',
  so_thi_sinh_hoan_tat_thanh_toan: 'Số thí sinh đã thanh toán',
  tham_gia_thuc_te: 'Tham gia thực tế',
  tai_lieu_id: 'Mã tài liệu',
  thanh_toan_id: 'Mã thanh toán',
  ti_le_hoan_thanh_quyen_loi: 'Tỷ lệ hoàn thành quyền lợi',
  ty_le_hoan_thanh_quyen_loi: 'Tỷ lệ hoàn thành quyền lợi',
  ty_le_phan_tram: 'Tỷ lệ phần trăm',
  tong_tien_hien_kim: 'Tổng tiền hiện kim',
  tong_quy_doi_hien_vat: 'Tổng quy đổi hiện vật',
  ten_bai_tap: 'Tên bài tập',
  ten_chuc_nang: 'Tên chức năng',
  ten_cuoc_thi: 'Tên cuộc thi',
  ten_doanh_nghiep: 'Tên doanh nghiệp',
  ten_file_goc: 'Tên tệp gốc',
  ten_kpi: 'Tên chỉ số',
  ten_nhom: 'Tên nhóm',
  ten_quyen: 'Tên quyền',
  ten_sale_phu_trach: 'Nhân viên phụ trách',
  ten_tai_lieu: 'Tên tài liệu',
  ten_thi_sinh: 'Tên thí sinh',
  ten_vai_tro: 'Tên vai trò',
  thoi_diem_cap_nhat: 'Cập nhật lúc',
  thoi_gian_bat_dau: 'Thời gian bắt đầu',
  thoi_gian_ket_thuc: 'Thời gian kết thúc',
  thuc_thu_tai_tro: 'Thực thu tài trợ',
  thuc_thu: 'Thực thu',
  thoi_gian: 'Thời gian',
  thoi_gian_lam_bai: 'Thời gian làm bài',
  thoi_gian_lam_giay: 'Thời gian làm (giây)',
  thoi_gian_nop: 'Thời gian nộp',
  thu_tu: 'Thứ tự',
  thu_tu_doan: 'Thứ tự đoạn',
  thi_sinh_id: 'Mã thí sinh',
  thi_sinh_tham_gia_thuc_te: 'Thí sinh tham gia thực tế',
  tinh_thanh: 'Tỉnh/thành phố',
  tinh_trang_xac_nhan: 'Tình trạng xác nhận',
  trang_thai_xac_nhan: 'Trạng thái xác nhận',
  so_luong_doanh_nghiep: 'Số lượng doanh nghiệp',
  tong_bai_da_nop: 'Tổng bài đã nộp',
  tong_diem: 'Tổng điểm',
  tong_doanh_thu: 'Tổng doanh thu',
  tong_doanh_thu_cuoc_thi_vnd: 'Tổng doanh thu cuộc thi',
  tong_le_phi_thu_duoc: 'Lệ phí đã thu',
  tong_thu: 'Tổng thu',
  tong_tiep_can: 'Tổng lượt tiếp cận',
  tong_tiep_can_thuc_te: 'Tổng lượt tiếp cận thực tế',
  tong_luot_nop: 'Tổng lượt nộp',
  tong_luot_dang_ky: 'Tổng lượt đăng ký',
  tong_luot_thanh_toan: 'Tổng lượt thanh toán',
  trang_thai: 'Trạng thái',
  trang_thai_lead: 'Trạng thái khách hàng tiềm năng',
  trang_thai_thanh_toan: 'Trạng thái thanh toán',
  trang_thai_doi_soat: 'Trạng thái đối soát',
  trang_thai_ho_so: 'Trạng thái hồ sơ',
  truong: 'Trường học',
  truong_hoc: 'Trường học',
  vung: 'Khu vực',
  so_luong_ho_so: 'Số hồ sơ',
  email_da_an: 'Email (đã ẩn)',
  sdt_da_an: 'Số điện thoại (đã ẩn)',
  giao_dich_da_an: 'Mã giao dịch (đã ẩn)',
  so_da_dang_ky: 'Số đã đăng ký',
  so_ho_so_duyet: 'Số hồ sơ đã duyệt',
  thoi_gian_thanh_toan: 'Thời gian thanh toán',
  total: 'Tổng số',
  thu_hang: 'Thứ hạng',
  tong_cau_hoi: 'Tổng câu hỏi',
  tyle_huu_ich_pt: 'Tỷ lệ hữu ích (%)',
  ty_le_huu_ich_pct: 'Tỷ lệ hữu ích (%)',
  luot_xem_tich_luy: 'Lượt xem tích lũy',
  nhan_vien_ho_tro: 'Nhân viên hỗ trợ',
  nhan_vien_id: 'Mã nhân viên hỗ trợ',
  danh_gia_hai_long: 'Đánh giá hài lòng',
  cau_hoi_so: 'Câu hỏi số',
  cau_tra_loi_cua_thi_sinh: 'Câu trả lời của thí sinh',
  cau_tra_loi_thi_sinh: 'Câu trả lời của thí sinh',
  la_dap_an_dung: 'Là đáp án đúng',
  place: 'Thứ hạng',
  hang: 'Thứ hạng',
  source: 'Nguồn',
  lead_status: 'Trạng thái khách hàng tiềm năng',
  profile_status: 'Trạng thái hồ sơ',
  payment_status: 'Trạng thái thanh toán',
  sources: 'Nguồn tiếp cận',
  so_luong_thi_sinh: 'Số thí sinh',
  tong_so_doanh_nghiep_tai_tro: 'Số doanh nghiệp tài trợ',
  tong_tien_hien_kim_vnd: 'Tổng tiền hiện kim',
  tong_quy_doi_hien_vat_vnd: 'Tổng giá trị hiện vật quy đổi',
  ty_le_hoan_thanh_quyen_loi_pct: 'Tỷ lệ hoàn thành quyền lợi (%)',
  thoi_gian_lam_bai_giay: 'Thời gian làm bài (giây)',
  so_ngay_qua_han: 'Số ngày quá hạn',
  tyle_dat_pt: 'Tỷ lệ đạt (%)',
  tyle_khong_dat_pt: 'Tỷ lệ không đạt (%)',
  target_gap: 'Chênh lệch so với kỳ trước',
  tu_ngay: 'Từ ngày',
  ty_le_pct: 'Tỷ lệ (%)',
  ty_le_so_voi_tiep_can_pct: 'Tỷ lệ so với tiếp cận (%)',
  ty_le_tham_gia_pct: 'Tỷ lệ tham gia (%)',
  ty_le_xuat_sac_pct: 'Tỷ lệ xuất sắc (%)',
  ty_le_dat_pct: 'Tỷ lệ đạt (%)',
  ty_le_tiep_can_pct: 'Tỷ lệ tiếp cận (%)',
  buoc: 'Bước',
  vector_id_hien_thi: 'Mã đoạn',
  vaitro_id: 'Mã vai trò',
  xep_hang: 'Xếp hạng',
}

const localizedValues: Record<string, string> = {
  ALL: 'Tất cả',
  AN: 'Đã ẩn',
  ACADEMIC: 'Học vụ',
  ADMIN: 'Quản trị viên',
  BAI_TAP: 'Bài tập',
  BAINOP: 'Bài nộp',
  BANG_A: 'Bảng A',
  BANG_B: 'Bảng B',
  BAO_CAO: 'Báo cáo',
  BAN_TO_CHUC: 'Ban tổ chức',
  BAITAP: 'Bài tập',
  BIEUMAU: 'Biểu mẫu',
  BO_QUA: 'Bỏ qua',
  CANH_BAO: 'Cảnh báo',
  CUOC_THI: 'Cuộc thi',
  CUOCTHI: 'Cuộc thi',
  CHO_DUYET: 'Chờ duyệt',
  CHO_THANH_TOAN: 'Chờ thanh toán',
  CHO_XU_LY: 'Chờ xử lý',
  CHUA_THANH_TOAN: 'Chưa thanh toán',
  CHUA_CO_HO_SO: 'Chưa có hồ sơ',
  CHUA_CO_DIEM: 'Chưa có điểm',
  CHUA_TRA_LOI: 'Chưa trả lời',
  CONG_KHAI: 'Công khai',
  CUSTOMER_SUPPORT: 'Chăm sóc khách hàng',
  DASHBOARD: 'Bảng điều khiển',
  DA_CHAM_DIEM: 'Đã chấm điểm',
  DA_DANG_KY: 'Đã đăng ký',
  DA_DUYET: 'Đã duyệt',
  DA_NOP: 'Đã nộp',
  'ĐÃ_NỘP_BÀI': 'HOÀN THÀNH',
  DA_THANH_TOAN: 'Đã thanh toán',
  DA_TAO_TAI_KHOAN: 'Đã tạo tài khoản',
  DA_TRA_LOI: 'Đã trả lời',
  DANG_NHAP: 'Đăng nhập',
  DANG_XUAT: 'Đăng xuất',
  DANG_KY: 'Đăng ký',
  DANG_DIEN_RA: 'Đang diễn ra',
  DANG_LAM: 'Đang làm',
  DANG_LIEN_HE: 'Đang liên hệ',
  DANG_DOI_SOAT: 'Đang đối soát',
  DANG_AP_DUNG: 'Đang áp dụng',
  DANGKY: 'Đăng ký',
  DANGKYWEB: 'Đăng ký web',
  DOANHNGHIEP: 'Doanh nghiệp',
  DOANHNGHIEP_PIPELINE: 'Quy trình doanh nghiệp',
  DAT: 'Đạt',
  DOANH_NGHIEP: 'Doanh nghiệp',
  DOANH_THU: 'Doanh thu',
  DONG_TRONG: 'Dòng trống',
  DIEN_TU: 'Điền từ',
  EMAIL_KHONG_HOP_LE: 'Email không hợp lệ',
  ERROR_MISSING_INFO: 'Thiếu thông tin',
  FILE: 'Tệp',
  GIAO_DICH: 'Giao dịch',
  IMPORT: 'Nhập dữ liệu',
  HOAN_TAT_CO_LOI: 'Hoàn tất nhưng có lỗi',
  HOAN_THANH: 'HOÀN THÀNH',
  HOAN_TIEN: 'Hoàn tiền',
  HE_THONG: 'Hệ thống',
  HIEN_KIM: 'Hiện kim',
  HIEN_VAT: 'Hiện vật',
  HO_TRO_KY_THUAT: 'Hỗ trợ kỹ thuật',
  JUDGE: 'Giám khảo',
  KNOWLEDGE_BASE: 'Kho tri thức',
  KIM_CUONG: 'Kim cương',
  KET_THUC: 'Đã kết thúc',
  KHONG_DAT: 'Không đạt',
  KHONG_TAI_TRO: 'Không tài trợ',
  KHONG_HOP_LE: 'Không hợp lệ',
  HUY_DANG_KY: 'Đã hủy đăng ký',
  HUY_GIAO_DICH: 'Đã hủy giao dịch',
  IT: 'Công nghệ thông tin',
  LOI: 'Lỗi',
  LOI_HE_THONG: 'Lỗi hệ thống',
  MANAGER: 'Quản lý',
  MA_DA_TON_TAI: 'Mã đã tồn tại',
  NGAY_SINH_KHONG_HOP_LE: 'Ngày sinh không hợp lệ',
  NHANVIEN: 'Nhân viên',
  NOI_DUNG: 'Nội dung',
  OBJECT_STORAGE: 'Kho lưu trữ',
  PHAN_TICH: 'Phân tích',
  QUANGCAO: 'Quảng cáo',
  SALES: 'Kinh doanh',
  SALE_STAFF: 'Nhân viên kinh doanh',
  SUA: 'Sửa',
  SUPPORT_STAFF: 'Nhân viên hỗ trợ',
  TAILIEU: 'Tài liệu',
  THEM: 'Thêm',
  THANH_CONG: 'Thành công',
  THANHTOAN: 'Thanh toán',
  THAT_BAI: 'Thất bại',
  THIEU_DU_LIEU: 'Thiếu dữ liệu',
  SDT_KHONG_HOP_LE: 'Số điện thoại không hợp lệ',
  CCCD_KHONG_HOP_LE: 'Số căn cước không hợp lệ',
  THISINH: 'Thí sinh',
  TRAC_NGHIEM_1: 'Trắc nghiệm một đáp án',
  TRAC_NGHIEM_NHIEU: 'Trắc nghiệm nhiều đáp án',
  TU_LUAN: 'Tự luận',
  XOA: 'Xóa',
  THANH_TOAN_THANH_CONG: 'Đã thanh toán thành công',
  TRUNG_LAP: 'Trùng lặp',
  DA_DOI_SOAT: 'Đã đối soát',
  CHUA_PHAT_SINH: 'Chưa phát sinh',
  DAM_PHAN: 'Đàm phán',
  DE_XUAT_GUI: 'Đã gửi đề xuất',
  KY_HOP_DONG: 'Đã ký hợp đồng',
  THUC_THU: 'Đã thực thu',
  MIEN_BAC: 'Miền Bắc',
  MIEN_TRUNG: 'Miền Trung',
  MIEN_NAM: 'Miền Nam',
  CHUA_XAC_DINH: 'Chưa xác định',
  GIA_TRI_VUOT_GIOI_HAN: 'Giá trị vượt quá giới hạn cho phép',
  VI_PHAM_RANG_BUOC_CHECK: 'Vi phạm điều kiện dữ liệu',
  DINH_DANG_SAI: 'Sai định dạng',
  KHOA_NGOAI_KHONG_TON_TAI: 'Không tìm thấy dữ liệu liên quan',
  SO_TIEN: 'Số tiền',
  TRANG_THAI_THANH_TOAN: 'Trạng thái thanh toán',
  LUYEN_TAP: 'Luyện tập',
  ACTIVE: 'Đang hoạt động',
  INACTIVE: 'Đã ngừng hoạt động',
  DANG_XU_LY: 'Đang xử lý',
  DA_XU_LY: 'Đã xử lý',
  DA_KET_THUC: 'Đã kết thúc',
  HUY: 'Đã hủy',
  KHOA: 'Đã khóa',
  MARKETING: 'Tiếp thị',
  MO: 'Mở',
  MO_DANG_KY: 'Mở',
  DANG_MO: 'Mở',
  DONG_HANH: 'Đồng hành',
  DONG: 'Đồng',
  BAC: 'Bạc',
  VANG: 'Vàng',
  QUY_CHE: 'Quy chế',
  TAI_LIEU_KY_THUAT: 'Tài liệu kỹ thuật',
  TAI_TRO_DOI_TAC: 'Tài trợ đối tác',
  CUNG_CAP_THI_SINH: 'Cung cấp thí sinh',
  TAI_TRO_DONG_HANH: 'Tài trợ đồng hành',
  MOI_TAO: 'Mới tạo',
  NOI_BO: 'Nội bộ',
  QNA: 'Hỏi đáp',
  QUA_HAN_NOP: 'Quá hạn nộp',
  SAP_DIEN_RA: 'Sắp diễn ra',
  TIEP_CAN: 'Tiếp cận',
  THAM_GIA: 'Tham gia',
  THANH_TOAN: 'Thanh toán',
  THI_SINH: 'Thí sinh',
}

export function rowsFrom(value: unknown): DataRow[] {
  if (Array.isArray(value)) {
    return value.filter((row): row is DataRow => typeof row === 'object' && row !== null)
  }
  return value && typeof value === 'object' ? [value as DataRow] : []
}

export function useRemoteRows(source: DataSource, refresh = 0) {
  const client = useMemo(() => getSupabaseBrowserClient(), [])
  const sourceKey = JSON.stringify(source)
  const [data, setData] = useState<DataRow[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')

  useEffect(() => {
    let active = true
    async function load() {
      if (!client) {
        setData([])
        setError('Chưa cấu hình kết nối Supabase.')
        setLoading(false)
        return
      }
      setLoading(true)
      setError('')
      try {
        const current = JSON.parse(sourceKey) as DataSource
        const response = current.kind === 'view'
          ? await client.from(current.name).select('*')
          : await client.rpc(current.name, current.args ?? {})
        if (!active) return
        if (response.error) {
          setData([])
          setError(response.error.message)
        } else {
          setData(rowsFrom(response.data))
        }
      } catch (loadError) {
        if (!active) return
        setData([])
        setError(loadError instanceof Error ? loadError.message : String(loadError))
      } finally {
        if (active) setLoading(false)
      }
    }
    void load()
    return () => { active = false }
  }, [client, refresh, sourceKey])

  return { data, loading, error, client }
}

export function formatCell(value: unknown): string {
  if (value == null || value === '') return '—'
  if (typeof value === 'number') return new Intl.NumberFormat('vi-VN').format(value)
  if (typeof value === 'boolean') return value ? 'Có' : 'Không'
  if (typeof value === 'object') return JSON.stringify(value)
  const text = String(value)
  const normalized = text.trim().toUpperCase()
  const exactTranslation = localizedValues[normalized] ?? localizedValues[normalized.replace(/\s+/g, '_')]
  if (exactTranslation) return exactTranslation
  return text.replace(/\b[A-Z][A-Z0-9_]{2,}\b/g, (token) => localizedValues[token] ?? token)
}

export function formatTableCell(value: unknown, field?: string): string {
  if (field?.toLowerCase() === 'nam_sinh' && (typeof value === 'number' || typeof value === 'string') && /^\d{4}$/.test(String(value))) {
    return String(value)
  }
  if (typeof value !== 'string') return formatCell(value)
  if (/^\d{4}-\d{2}-\d{2}$/.test(value)) {
    const [year, month, day] = value.split('-').map(Number)
    return new Date(Date.UTC(year, month - 1, day)).toLocaleDateString('vi-VN', { timeZone: 'UTC' })
  }
  if (!/^\d{4}-\d{2}-\d{2}[T ]\d{2}:\d{2}/.test(value)) {
    return formatCell(value)
  }
  const dateTime = new Date(value)
  if (Number.isNaN(dateTime.getTime())) return formatCell(value)
  const date = dateTime.toLocaleDateString('vi-VN')
  const time = dateTime.toLocaleTimeString('vi-VN', { hour: '2-digit', minute: '2-digit', second: '2-digit', hour12: false })
  return `${date}\n${time}`
}

export function formatFieldLabel(field: string): string {
  const normalized = field.toLowerCase()
  const label = fieldLabels[normalized] ?? normalized.replaceAll('_', ' ')
  return label.charAt(0).toLocaleUpperCase('vi') + label.slice(1)
}

export function recordLabel(row: DataRow, keys: string[]): string {
  const match = Object.entries(row).find(([key]) => keys.includes(key.toLowerCase()))
  return match ? formatCell(match[1]) : '—'
}
