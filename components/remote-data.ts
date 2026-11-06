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
  dang_ky_thi: 'Đăng ký thi',
  dang_ky: 'Đăng ký',
  den_ngay: 'Đến ngày',
  diem_cao_nhat: 'Điểm cao nhất',
  diem_dat: 'Điểm đạt',
  doanh_nghiep_id: 'Mã doanh nghiệp',
  doanh_thu: 'Doanh thu',
  doanh_thu_le_phi: 'Doanh thu lệ phí',
  doanh_thu_tu_doi_tac: 'Doanh thu từ đối tác',
  doi_tac_cung_cap: 'Đối tác cung cấp',
  dung_luong_mb: 'Dung lượng (MB)',
  duoc_phep: 'Được phép',
  email: 'Email',
  faq_id: 'Mã FAQ',
  gia_tri_quy_doi: 'Giá trị quy đổi',
  gia_tri: 'Giá trị',
  gia_tri_hien_tai: 'Giá trị hiện tại',
  gia_tri_trung_binh: 'Giá trị trung bình',
  giao_dich_thanh_cong: 'Giao dịch thành công',
  giai_doan: 'Giai đoạn',
  han_dang_ky: 'Hạn đăng ký',
  hang_toan_quoc: 'Xếp hạng toàn quốc',
  hoan_thanh_pct: 'Tỷ lệ hoàn thành (%)',
  hoa_hong_doi_tac: 'Hoa hồng đối tác',
  hoa_hong_phai_tra: 'Hoa hồng phải trả',
  hop_dong_da_ky: 'Hợp đồng đã ký',
  ho_ten: 'Họ và tên',
  kenh: 'Kênh',
  ket_qua: 'Kết quả',
  khoang_diem: 'Khoảng điểm',
  kpi_id: 'Mã chỉ số',
  ky_bao_cao: 'Kỳ báo cáo',
  lan_nop: 'Lần nộp',
  loai_tai_lieu: 'Loại tài liệu',
  loai_tai_tro: 'Loại tài trợ',
  luot_tiep_can: 'Lượt tiếp cận',
  luot_xem: 'Lượt xem',
  ma_gioi_thieu: 'Mã giới thiệu',
  ma_so_thue: 'Mã số thuế',
  modun_chucnang: 'Nhóm chức năng',
  mo_ta: 'Mô tả',
  muc_tieu: 'Mục tiêu',
  nam_sinh: 'Năm sinh',
  ngay_cap_nhat: 'Ngày cập nhật',
  ngay_bat_dau: 'Ngày bắt đầu',
  ngay_dang_tai: 'Ngày đăng tải',
  ngay_ket_thuc: 'Ngày kết thúc',
  ngay_thi_chung_ket: 'Ngày thi chung kết',
  nguon_utm: 'Nguồn UTM',
  nhom: 'Nhóm',
  nhom_tin_hieu: 'Nhóm tín hiệu',
  nhom_tuoi: 'Nhóm tuổi',
  noi_dung: 'Nội dung',
  hinh_thuc: 'Hình thức',
  nhom_kpi: 'Nhóm chỉ số',
  noi_dung_rut_gon: 'Nội dung tóm tắt',
  permission_id: 'Mã quyền',
  qna_id: 'Mã hội thoại',
  roi_pct: 'Tỷ suất hoàn vốn (%)',
  sdt: 'Số điện thoại',
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
  so_luong_da_nop: 'Số lượng đã nộp',
  so_nha_tai_tro: 'Số nhà tài trợ',
  so_thi_sinh: 'Số thí sinh',
  so_thi_sinh_hoan_tat_thanh_toan: 'Số thí sinh đã thanh toán',
  tham_gia_thuc_te: 'Tham gia thực tế',
  tai_lieu_id: 'Mã tài liệu',
  ti_le_hoan_thanh_quyen_loi: 'Tỷ lệ hoàn thành quyền lợi',
  ty_le_hoan_thanh_quyen_loi: 'Tỷ lệ hoàn thành quyền lợi',
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
  so_luong_doanh_nghiep: 'Số lượng doanh nghiệp',
  tong_bai_da_nop: 'Tổng bài đã nộp',
  tong_diem: 'Tổng điểm',
  tong_doanh_thu: 'Tổng doanh thu',
  tong_doanh_thu_cuoc_thi_vnd: 'Tổng doanh thu cuộc thi',
  tong_le_phi_thu_duoc: 'Lệ phí đã thu',
  tong_thu: 'Tổng thu',
  tong_tiep_can: 'Tổng lượt tiếp cận',
  tong_tiep_can_thuc_te: 'Tổng lượt tiếp cận thực tế',
  trang_thai: 'Trạng thái',
  trang_thai_doi_soat: 'Trạng thái đối soát',
  trang_thai_ho_so: 'Trạng thái hồ sơ',
  truong: 'Trường học',
  truong_hoc: 'Trường học',
  tyle_dat_pt: 'Tỷ lệ đạt (%)',
  tyle_khong_dat_pt: 'Tỷ lệ không đạt (%)',
  tu_ngay: 'Từ ngày',
  ty_le_pct: 'Tỷ lệ (%)',
  ty_le_so_voi_tiep_can_pct: 'Tỷ lệ so với tiếp cận (%)',
  ty_le_tham_gia_pct: 'Tỷ lệ tham gia (%)',
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
  BAI_TAP: 'Bài tập',
  BANG_A: 'Bảng A',
  BANG_B: 'Bảng B',
  BAO_CAO: 'Báo cáo',
  CUOC_THI: 'Cuộc thi',
  CHO_DUYET: 'Chờ duyệt',
  CHUA_CO_DIEM: 'Chưa có điểm',
  CONG_KHAI: 'Công khai',
  DASHBOARD: 'Bảng điều khiển',
  DA_CHAM_DIEM: 'Đã chấm điểm',
  DA_DUYET: 'Đã duyệt',
  DA_NOP: 'Đã nộp',
  DANG_DIEN_RA: 'Đang diễn ra',
  DANG_LAM: 'Đang làm',
  DANG_AP_DUNG: 'Đang áp dụng',
  DAT: 'Đạt',
  DANG_KY: 'Đăng ký',
  DOANH_NGHIEP: 'Doanh nghiệp',
  HOAN_THANH: 'Hoàn thành',
  HE_THONG: 'Hệ thống',
  HIEN_KIM: 'Hiện kim',
  HIEN_VAT: 'Hiện vật',
  KNOWLEDGE_BASE: 'Kho tri thức',
  KET_THUC: 'Đã kết thúc',
  KHONG_DAT: 'Không đạt',
  KHONG_HOP_LE: 'Không hợp lệ',
  KHOA: 'Đã khóa',
  MARKETING: 'Tiếp thị',
  MO: 'Mở',
  MO_DANG_KY: 'Mở',
  DANG_MO: 'Mở',
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
  return localizedValues[text.toUpperCase()] ?? text
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
  if (!/^\d{4}-\d{2}-\d{2}[T ]\d{2}:\d{2}/.test(value)) return formatCell(value)
  const dateTime = new Date(value)
  if (Number.isNaN(dateTime.getTime())) return formatCell(value)
  const date = dateTime.toLocaleDateString('vi-VN')
  const time = dateTime.toLocaleTimeString('vi-VN', { hour: '2-digit', minute: '2-digit', second: '2-digit', hour12: false })
  return `${date}\n${time}`
}

export function formatFieldLabel(field: string): string {
  const normalized = field.toLowerCase()
  return fieldLabels[normalized] ?? normalized.replaceAll('_', ' ')
}

export function recordLabel(row: DataRow, keys: string[]): string {
  const match = Object.entries(row).find(([key]) => keys.includes(key.toLowerCase()))
  return match ? formatCell(match[1]) : '—'
}
