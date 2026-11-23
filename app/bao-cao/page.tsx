'use client'

import { useEffect, useMemo, useState } from 'react'
import { BarChart3, CalendarDays, Download, FileSpreadsheet, FileText, Printer, RefreshCw } from 'lucide-react'
import {
  AlignmentType,
  BorderStyle,
  Document,
  HeadingLevel,
  Packer,
  PageOrientation,
  Paragraph,
  ShadingType,
  Table,
  TableCell,
  TableRow,
  TextRun,
  VerticalAlign,
  WidthType,
} from 'docx'
import * as XLSX from 'xlsx-js-style'
import { AdminShell } from '@/components/admin-shell'
import { DataPanel, type Visualization } from '@/components/data-panel'
import { useReportAccess } from '@/components/report-access'
import { formatFieldLabel, formatTableCell } from '@/components/remote-data'
import { addExcelCharts, type ExcelChartSource } from '@/lib/excel-charts'
import { buildExcelDashboard } from '@/lib/excel-dashboards'
import { getSupabaseBrowserClient } from '@/lib/supabase-browser'

type ReportTab =
  | 'Tổng quan'
  | 'Vận hành thí sinh'
  | 'Tài chính'
  | 'Marketing'
  | 'Tài trợ/đối tác'
  | 'Học thuật/kết quả thi'
  | 'Hỗ trợ'
  | 'Hệ thống'
type ExportFormat = 'excel' | 'word' | 'pdf' | 'csv'
type SectionDefinition = {
  reportId: string
  title: string
  description?: string
  visualization: Visualization
  requiredPermission?: string
}

type ReportExportDataset = {
  reportId: string
  title: string
  rows: Record<string, unknown>[]
  visualization: Visualization
  hasData: boolean
  emptyColumns?: string[]
  emptyMessage?: string
}

type ReportCategory = { permissions: string[]; sections: SectionDefinition[] }

const emptyReportColumns: Record<string, string[]> = {
  contest_certificates: [
    'thi_sinh_id',
    'ho_ten',
    'bang_dau',
    'truong_hoc',
    'tong_diem',
    'thu_hang',
    'ket_qua_xet',
  ],
  contest_results: [
    'cuoc_thi_id',
    'ten_cuoc_thi',
    'bang_dau',
    'thu_hang',
    'thi_sinh_id',
    'ho_ten',
    'email',
    'sdt',
    'truong_hoc',
    'tong_diem',
    'thoi_gian_lam_bai_giay',
    'thoi_gian_nop',
    'ket_qua_xet',
  ],
  contest_finalists_a: [
    'cuoc_thi_id',
    'ten_cuoc_thi',
    'bang_dau',
    'thu_hang',
    'thi_sinh_id',
    'ho_ten',
    'email',
    'sdt',
    'truong_hoc',
    'tong_diem',
    'thoi_gian_lam_bai_giay',
    'thoi_gian_nop',
    'ket_qua_xet',
  ],
  contest_finalists_b: [
    'cuoc_thi_id',
    'ten_cuoc_thi',
    'bang_dau',
    'thu_hang',
    'thi_sinh_id',
    'ho_ten',
    'email',
    'sdt',
    'truong_hoc',
    'tong_diem',
    'thoi_gian_lam_bai_giay',
    'thoi_gian_nop',
    'ket_qua_xet',
  ],
  contest_school_round_summary: [
    'vong_thi',
    'cuoc_thi_id',
    'ten_cuoc_thi',
    'bang_dau',
    'truong_hoc',
    'so_thi_sinh_du_thi',
    'so_thi_sinh_dat_yeu_cau',
    'so_thi_sinh_du_dieu_kien_vao_chung_ket',
  ],
  contest_qualifiers_top10: [
    'cuoc_thi_id',
    'ten_cuoc_thi',
    'bang_dau',
    'thu_hang',
    'thi_sinh_id',
    'ho_ten',
    'truong_hoc',
    'tong_diem',
    'thoi_gian_lam_bai_giay',
    'so_thi_sinh_du_thi_vongloai',
    'so_suat_top10',
    'du_dieu_kien_vao_chung_ket',
  ],
  student_status: ['trang_thai', 'so_luong'],
  revenue_by_channel: ['kenh', 'so_luong', 'doanh_thu', 'ty_le_pct'],
  transaction_details: [
    'nguon',
    'thanh_toan_id',
    'giao_dich_id',
    'thi_sinh_id',
    'ho_ten',
    'bang_dau',
    'tinh_thanh',
    'le_phi_thi',
    'trang_thai_thanh_toan',
    'thoi_gian_thanh_toan',
    'kenh',
  ],
  sponsor_list: [
    'doanh_nghiep_id',
    'ten_doanh_nghiep',
    'cap_do_tai_tro',
    'loai_tai_tro',
    'thuc_thu',
  ],
  student_utm: ['nguon_utm', 'chien_dich', 'luot_tiep_can', 'so_dang_ky', 'chi_phi', 'doanh_thu', 'roi_pct'],
  practice_top15: ['hang', 'thi_sinh_id', 'ho_ten', 'truong_hoc', 'so_bai_hoan_thanh'],
  support_conversations: [
    'qna_id',
    'thi_sinh_id',
    'doanh_nghiep_id',
    'doi_tuong_id',
    'loai_doi_tuong',
    'ten_hien_thi',
    'noi_dung_hoi',
    'noi_dung_tra_loi',
    'tai_lieu_id',
    'thoi_gian',
    'kenh_tuong_tac',
    'trang_thai',
    'danh_gia_hai_long',
    'nhan_vien_id_ho_tro',
  ],
  supplier_list: [
    'doanh_nghiep_id',
    'ten_doanh_nghiep',
    'hinh_thuc',
    'so_thi_sinh_cung_cap',
    'doanh_thu',
    'hoa_hong',
  ],
  support_top_questions: ['thu_tu', 'cau_hoi', 'so_lan_xuat_hien'],
  partner_referral_conversion: [
    'doanh_nghiep_id',
    'ten_doanh_nghiep',
    'so_ho_so_duoc_ghi_nhan',
    'so_ho_so_da_thanh_toan',
    'so_ho_so_chua_thanh_toan',
    'so_ho_so_dang_cho',
    'so_giao_dich_that_bai_huy',
    'ty_le_chuyen_doi_thanh_toan_pct',
  ],
  support_unanswered_age: [
    'kenh_tuong_tac',
    'nhom_tuoi_chua_tra_loi',
    'so_cau_chua_tra_loi',
    'tuoi_trung_binh_gio',
    'tuoi_lon_nhat_gio',
  ],
  import_quality: [
    'ten_bang_dich',
    'cot_loi',
    'ma_loi',
    'mo_ta_loi',
    'muc_do',
    'so_dong_loi',
    'so_phien_anh_huong',
    'so_file_anh_huong',
  ],
  import_sessions: [
    'import_id',
    'ten_file',
    'ten_bang_dich',
    'thoi_gian_bat_dau',
    'thoi_gian_ket_thuc',
    'tong_so_dong',
    'so_dong_thanh_cong',
    'so_dong_loi',
    'trang_thai',
  ],
  import_errors: [
    'import_id',
    'ten_file',
    'so_dong',
    'cot_loi',
    'vi_tri_loi',
    'ma_loi',
    'thong_diep_loi',
    'thoi_gian_loi',
  ],
}

const reportSections: Record<ReportTab, ReportCategory> = {
  'Tổng quan': {
    permissions: ['BAO_CAO_TONG_QUAN'],
    sections: [
      { reportId: 'overview_summary', title: 'Chỉ số tổng quan', description: 'Tổng hợp đăng ký, tham gia và doanh thu trong kỳ.', visualization: 'metrics', requiredPermission: 'BAO_CAO_TONG_QUAN' },
      { reportId: 'overview_comparison', title: 'So sánh đăng ký với kỳ trước', visualization: 'metrics', requiredPermission: 'BAO_CAO_TONG_QUAN' },
      { reportId: 'overview_progress', title: 'Tiến độ chỉ tiêu', description: 'Tỷ lệ hoàn thành và số liệu chi tiết của từng chỉ tiêu.', visualization: 'bar-table', requiredPermission: 'BAO_CAO_TONG_QUAN' },
    ],
  },
  'Vận hành thí sinh': {
    permissions: ['BAO_CAO_TONG_QUAN', 'BAO_CAO_THISINH'],
    sections: [
      { reportId: 'student_summary', title: 'Tổng quan thí sinh', visualization: 'metrics', requiredPermission: 'BAO_CAO_THISINH' },
      { reportId: 'student_status', title: 'Tình trạng thanh toán trong kỳ', description: 'Đối chiếu đăng ký thi với thanh toán thành công trong kỳ.', visualization: 'pie', requiredPermission: 'BAO_CAO_THISINH' },
      { reportId: 'overview_enrollment_funnel', title: 'Phễu tuyển sinh', description: 'Theo dõi chuyển đổi từ tiếp cận đến đăng ký và tham gia.', visualization: 'funnel', requiredPermission: 'BAO_CAO_TONG_QUAN' },
      { reportId: 'overview_registration_trend', title: 'Khoảng 16 ngày có nhiều lượt đăng ký nhất', description: '16 ngày liên tiếp có tổng lượt đăng ký cao nhất trong kỳ.', visualization: 'area', requiredPermission: 'BAO_CAO_TONG_QUAN' },
      { reportId: 'student_schools', title: 'Số thí sinh theo trường', visualization: 'bar-horizontal', requiredPermission: 'BAO_CAO_THISINH' },
      { reportId: 'student_school_scores', title: 'Số thí sinh theo trường của từng bảng đấu', visualization: 'bar-table', requiredPermission: 'BAO_CAO_THISINH' },
    ],
  },
  'Tài chính': {
    permissions: ['BAO_CAO_DOANH_THU', 'BAO_CAO_DOANH_THU_CHI_TIET', 'BAO_CAO_DOI_TAC'],
    sections: [
      { reportId: 'revenue_summary', title: 'Tổng quan doanh thu', visualization: 'metrics', requiredPermission: 'BAO_CAO_DOANH_THU' },
      { reportId: 'payment_funnel', title: 'Phễu thanh toán', visualization: 'funnel', requiredPermission: 'BAO_CAO_DOANH_THU' },
      { reportId: 'revenue_trend', title: 'Xu hướng doanh thu theo ngày', visualization: 'line', requiredPermission: 'BAO_CAO_DOANH_THU' },
      { reportId: 'revenue_by_channel', title: 'Doanh thu theo kênh', visualization: 'pie', requiredPermission: 'BAO_CAO_DOANH_THU' },
      { reportId: 'revenue_by_region', title: 'Doanh thu theo 3 miền', visualization: 'bar-horizontal', requiredPermission: 'BAO_CAO_DOANH_THU' },
      { reportId: 'revenue_by_province', title: 'Doanh thu theo tỉnh/thành', visualization: 'bar-horizontal', requiredPermission: 'BAO_CAO_DOANH_THU' },
      { reportId: 'revenue_reconciliation', title: 'Giao dịch chờ đối soát quá 48 giờ', visualization: 'table', requiredPermission: 'BAO_CAO_DOANH_THU' },
      { reportId: 'sponsor_daily_revenue', title: 'Doanh thu và hoa hồng theo ngày', visualization: 'area', requiredPermission: 'BAO_CAO_DOI_TAC' },
      { reportId: 'transaction_details', title: 'Chi tiết giao dịch', visualization: 'table', requiredPermission: 'BAO_CAO_DOANH_THU_CHI_TIET' },
    ],
  },
  'Marketing': {
    permissions: ['BAO_CAO_TONG_QUAN', 'BAO_CAO_THISINH'],
    sections: [
      { reportId: 'lead_pipeline', title: 'Lead theo nguồn và trạng thái', description: 'Đối chiếu lead từ biểu mẫu, Lead Ads và đăng ký web theo trạng thái hồ sơ/thanh toán.', visualization: 'table', requiredPermission: 'BAO_CAO_TONG_QUAN' },
      { reportId: 'student_utm', title: 'Nguồn lead, chi phí và ROI quảng cáo', description: 'Tổng hợp lượt tiếp cận, đăng ký, chi phí, doanh thu và ROI theo nguồn/campaign UTM.', visualization: 'table', requiredPermission: 'BAO_CAO_THISINH' },
    ],
  },
  'Tài trợ/đối tác': {
    permissions: ['BAO_CAO_DOI_TAC'],
    sections: [
      { reportId: 'sponsor_summary', title: 'Thực thu và hợp đồng tài trợ', description: 'Tổng hợp thực thu, số hợp đồng đã ký, doanh thu đối tác và hoa hồng.', visualization: 'metrics', requiredPermission: 'BAO_CAO_DOI_TAC' },
      { reportId: 'sponsor_funnel', title: 'Phễu tài trợ và tiến độ hợp đồng', visualization: 'funnel', requiredPermission: 'BAO_CAO_DOI_TAC' },
      { reportId: 'sponsor_tiers', title: 'Cơ cấu cấp tài trợ', visualization: 'pie', requiredPermission: 'BAO_CAO_DOI_TAC' },
      { reportId: 'sponsor_list', title: 'Thực thu và hiệu quả truyền thông', description: 'Theo dõi thực thu theo nhà tài trợ.', visualization: 'table', requiredPermission: 'BAO_CAO_DOI_TAC' },
      { reportId: 'sponsor_revenue_by_province', title: 'Doanh thu đối tác theo tỉnh/thành', visualization: 'bar-horizontal', requiredPermission: 'BAO_CAO_DOI_TAC' },
      { reportId: 'sponsor_trend', title: 'Xu hướng doanh thu từ doanh nghiệp cung cấp thí sinh', visualization: 'line', requiredPermission: 'BAO_CAO_DOI_TAC' },
      { reportId: 'supplier_list', title: 'Đối soát doanh nghiệp cung cấp thí sinh', visualization: 'table', requiredPermission: 'BAO_CAO_DOI_TAC' },
    ],
  },
  'Học thuật/kết quả thi': {
    permissions: ['BAO_CAO_HOC_VU'],
    sections: [
      { reportId: 'contest_rounds', title: 'Các vòng thi', visualization: 'table', requiredPermission: 'BAO_CAO_HOC_VU' },
      { reportId: 'submission_status', title: 'Trạng thái bài nộp gần nhất theo thí sinh', visualization: 'pie', requiredPermission: 'BAO_CAO_HOC_VU' },
      { reportId: 'contest_certificates', title: 'Danh sách thí sinh được chứng chỉ COS Pro', description: 'Danh sách thí sinh đạt từ 600/1000 điểm; dữ liệu tách biệt với thứ hạng xét giải.', visualization: 'table', requiredPermission: 'BAO_CAO_HOC_VU' },
      { reportId: 'contest_results', title: 'Kết quả vòng loại', description: 'Chỉ gồm bài thi của các vòng loại theo Bảng A và Bảng B, không gồm Vòng Chung kết.', visualization: 'table', requiredPermission: 'BAO_CAO_HOC_VU' },
      { reportId: 'contest_school_round_summary', title: 'Thống kê thí sinh theo vòng, trường và bảng', description: 'Đếm thí sinh đã thanh toán có bài được chấm, số đạt yêu cầu và số đủ điều kiện vào chung kết.', visualization: 'table', requiredPermission: 'BAO_CAO_HOC_VU' },
      { reportId: 'contest_qualifiers_top10', title: 'Danh sách Top 10% vòng loại vào chung kết', description: 'Xếp riêng theo từng cuộc thi vòng loại và bảng; làm tròn chỉ tiêu lên, giữ tất cả thí sinh đồng hạng tại ngưỡng.', visualization: 'table', requiredPermission: 'BAO_CAO_HOC_VU' },
      { reportId: 'contest_finalists_a', title: 'Kết quả vòng chung kết - Bảng A', description: 'Điểm và thứ hạng chung kết của thí sinh Bảng A đã thanh toán.', visualization: 'table', requiredPermission: 'BAO_CAO_HOC_VU' },
      { reportId: 'contest_finalists_b', title: 'Kết quả vòng chung kết - Bảng B', description: 'Điểm và thứ hạng chung kết của thí sinh Bảng B đã thanh toán.', visualization: 'table', requiredPermission: 'BAO_CAO_HOC_VU' },
      { reportId: 'submission_details', title: 'Chi tiết bài làm và nhận xét', visualization: 'table', requiredPermission: 'BAO_CAO_HOC_VU' },
      { reportId: 'submission_failures', title: 'Bài tập có tỷ lệ không đạt cao', visualization: 'bar-horizontal', requiredPermission: 'BAO_CAO_HOC_VU' },
      { reportId: 'submission_failures_by_province', title: 'Tỷ lệ không đạt theo tỉnh/thành', visualization: 'bar-horizontal', requiredPermission: 'BAO_CAO_HOC_VU' },
    ],
  },
  'Hỗ trợ': {
    permissions: ['BAO_CAO_HO_TRO'],
    sections: [
      { reportId: 'support_by_status', title: 'Hội thoại theo trạng thái', visualization: 'pie', requiredPermission: 'BAO_CAO_HO_TRO' },
      { reportId: 'support_by_entity', title: 'Hội thoại theo nhóm đối tượng', visualization: 'bar', requiredPermission: 'BAO_CAO_HO_TRO' },
      { reportId: 'support_conversations', title: 'Danh sách hội thoại Q&A', description: 'Xem tối đa 200 hội thoại gần đây cùng nội dung hỏi, trả lời và trạng thái xử lý.', visualization: 'table', requiredPermission: 'BAO_CAO_HO_TRO' },
      { reportId: 'support_faq_summary', title: 'Hiệu quả bộ câu hỏi FAQ', visualization: 'metrics', requiredPermission: 'BAO_CAO_HO_TRO' },
      { reportId: 'support_top_questions', title: 'Top câu hỏi thường gặp', description: 'Tối đa 50 câu hỏi, xếp từ được hỏi nhiều nhất đến ít nhất trong kỳ báo cáo.', visualization: 'table', requiredPermission: 'BAO_CAO_HO_TRO' },
      { reportId: 'support_faq_categories', title: 'Câu hỏi theo danh mục', visualization: 'bar-horizontal', requiredPermission: 'BAO_CAO_HO_TRO' },
    ],
  },
  'Hệ thống': {
    permissions: ['BAO_CAO_AN_NINH'],
    sections: [
      { reportId: 'import_sessions', title: 'Lịch sử các phiên nhập dữ liệu', visualization: 'table', requiredPermission: 'BAO_CAO_AN_NINH' },
      { reportId: 'import_errors', title: 'Chi tiết lỗi nhập dữ liệu', visualization: 'table', requiredPermission: 'BAO_CAO_AN_NINH' },
      { reportId: 'import_quality', title: 'Lỗi nhập liệu theo bảng, cột và nguyên nhân', visualization: 'bar-horizontal', requiredPermission: 'BAO_CAO_AN_NINH' },
      { reportId: 'security_log', title: 'Nhật ký thao tác bảo mật', visualization: 'table', requiredPermission: 'BAO_CAO_AN_NINH' },
    ],
  },
}

function quarterOptions(): string[] {
  const now = new Date()
  const options: string[] = []
  for (let offset = 0; offset < 12; offset += 1) {
    const date = new Date(now.getFullYear(), now.getMonth() - offset * 3, 1)
    const quarter = Math.floor(date.getMonth() / 3) + 1
    const value = `${date.getFullYear()}-Q${quarter}`
    if (!options.includes(value)) options.push(value)
  }
  return options
}

function defaultReportPeriod(): string {
  const now = new Date()
  return `${now.getFullYear()}-Q3`
}

function reportPeriodRange(period: string): string {
  const match = /^(\d{4})-Q([1-4])$/.exec(period)
  if (!match) return 'Kỳ không hợp lệ'
  const year = Number(match[1])
  const quarter = Number(match[2])
  const start = new Date(Date.UTC(year, (quarter - 1) * 3, 1))
  const end = new Date(Date.UTC(year, quarter * 3, 0))
  const formatDate = (date: Date) => new Intl.DateTimeFormat('vi-VN', {
    timeZone: 'UTC',
    day: '2-digit',
    month: '2-digit',
    year: 'numeric',
  }).format(date)
  return `${formatDate(start)} – ${formatDate(end)}`
}

function peakRegistrationWindow(value: unknown, period: string): Record<string, unknown>[] {
  const [yearText, quarterText] = period.split('-Q')
  const year = Number(yearText)
  const quarter = Number(quarterText)
  if (!Number.isInteger(year) || quarter < 1 || quarter > 4) return exportRows(value)

  const quarterStart = Date.UTC(year, (quarter - 1) * 3, 1)
  const quarterEnd = Date.UTC(year, quarter * 3, 1) - 86_400_000
  const today = new Date()
  const todayUtc = Date.UTC(today.getFullYear(), today.getMonth(), today.getDate())
  if (todayUtc < quarterStart) return []
  const end = Math.min(quarterEnd, Math.max(todayUtc, quarterStart))
  const byDate = new Map<string, Record<string, unknown>>()
  exportRows(value).forEach((row) => {
    const date = String(row.ngay ?? '').slice(0, 10)
    if (!date) return
    const previous = byDate.get(date)
    const count = Number(row.so_dang_ky)
    byDate.set(date, {
      ngay: date,
      so_dang_ky: (typeof previous?.so_dang_ky === 'number' ? previous.so_dang_ky : 0)
        + (Number.isFinite(count) ? count : 0),
    })
  })

  const days = Array.from({ length: Math.floor((end - quarterStart) / 86_400_000) + 1 }, (_, index) => {
    const date = new Date(quarterStart + index * 86_400_000).toISOString().slice(0, 10)
    return byDate.get(date) ?? { ngay: date, so_dang_ky: 0 }
  })
  if (days.length <= 16) return days

  let windowTotal = days.slice(0, 16).reduce((total, row) => total + Number(row.so_dang_ky), 0)
  let peakTotal = windowTotal
  let peakStart = 0
  for (let start = 1; start <= days.length - 16; start += 1) {
    windowTotal += Number(days[start + 15].so_dang_ky) - Number(days[start - 1].so_dang_ky)
    if (windowTotal >= peakTotal) {
      peakTotal = windowTotal
      peakStart = start
    }
  }
  return days.slice(peakStart, peakStart + 16)
}

function csvCell(value: unknown, field?: string): string {
  const rawText = value == null
    ? ''
    : typeof value === 'object'
      ? JSON.stringify(value)
      : exportCell(value, field)
  const text = /^[\t\r ]*[=+\-@]/.test(rawText) ? `'${rawText}` : rawText
  return `"${text.replaceAll('"', '""')}"`
}

function exportRows(value: unknown): Record<string, unknown>[] {
  if (Array.isArray(value)) {
    return value.filter((row): row is Record<string, unknown> => typeof row === 'object' && row !== null)
  }
  if (value && typeof value === 'object') return [value as Record<string, unknown>]
  return value == null ? [] : [{ Giá_trị: value }]
}

function studentPaymentStatusRows(value: unknown): Record<string, unknown>[] | null {
  const [summary] = exportRows(value)
  if (!summary) return null

  const registered = Number(summary.dang_ky_thi)
  const paid = Number(summary.tham_gia_thuc_te)
  if (!Number.isFinite(registered) || !Number.isFinite(paid)) return null

  return [
    { trang_thai: 'Đã thanh toán', so_luong: paid },
    { trang_thai: 'Chưa thanh toán', so_luong: registered - paid },
  ].filter((row) => Number(row.so_luong) > 0)
}

function aggregateImportQuality(value: unknown): Record<string, unknown>[] {
  const totals = new Map<string, { name: string; errorCount: number }>()
  for (const row of exportRows(value)) {
    const name = String(row.ten_bang_dich ?? '').trim() || 'Không xác định'
    const key = name.toLocaleLowerCase('vi')
    const group = totals.get(key) ?? { name, errorCount: 0 }
    const errorCount = Number(row.so_dong_loi)
    if (Number.isFinite(errorCount)) group.errorCount += errorCount
    totals.set(key, group)
  }
  return Array.from(totals.values(), ({ name, errorCount }) => ({
    ten_bang_dich: name,
    so_dong_loi: errorCount,
  }))
}

function withoutOverviewMetrics(value: unknown): unknown {
  const hiddenKeys = new Set([
    'tu_ngay',
    'den_ngay',
    'tham_gia_thuc_te',
    'tong_doanh_thu',
    'giao_dich_thanh_cong',
    'dang_doi_soat',
    'gia_tri_trung_binh',
  ])
  const filterRow = (row: Record<string, unknown>) =>
    Object.fromEntries(Object.entries(row).filter(([key]) => !hiddenKeys.has(key.toLowerCase())))

  if (Array.isArray(value)) {
    return value.map((row) =>
      typeof row === 'object' && row !== null && !Array.isArray(row)
        ? filterRow(row as Record<string, unknown>)
        : row,
    )
  }
  if (typeof value === 'object' && value !== null) return filterRow(value as Record<string, unknown>)
  return value
}

function exportCell(value: unknown, field?: string): string {
  if (value == null) return ''
  if (typeof value === 'object') return JSON.stringify(value)
  if (typeof value === 'string') {
    const dateOnly = value.match(/^(\d{4}-\d{2}-\d{2})(?:[T ].*)?$/)
    if (dateOnly) return formatTableCell(dateOnly[1], field)
  }
  return typeof value === 'string' ? formatTableCell(value, field) : String(value)
}

function exportValue(value: unknown, field: string): unknown {
  if (typeof value === 'string') {
    const dateOnly = value.match(/^(\d{4}-\d{2}-\d{2})(?:[T ].*)?$/)
    if (dateOnly) return formatTableCell(dateOnly[1], field)
  }
  return typeof value === 'string' ? formatTableCell(value, field) : value
}

function htmlEscape(value: unknown): string {
  return exportCell(value)
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&#39;')
}

function safeSheetName(value: string, used: Set<string>): string {
  const base = value.replace(/[\\/?*[\]:]/g, ' ').trim().slice(0, 31) || 'Bao cao'
  let name = base
  let suffix = 2
  while (used.has(name.toLocaleLowerCase('vi'))) {
    const tail = ` ${suffix++}`
    name = `${base.slice(0, 31 - tail.length)}${tail}`
  }
  used.add(name.toLocaleLowerCase('vi'))
  return name
}

export default function ReportPage() {
  return (
    <AdminShell active="Báo cáo" title="Báo cáo">
      <ReportContent />
    </AdminShell>
  )
}

function ReportContent() {
  const supabase = useMemo(() => getSupabaseBrowserClient(), [])
  const reportAccess = useReportAccess()
  const [activeTab, setActiveTab] = useState<ReportTab>('Tổng quan')
  const [period, setPeriod] = useState(defaultReportPeriod)
  const [results, setResults] = useState<Record<string, unknown>>({})
  const [errors, setErrors] = useState<Record<string, string>>({})
  const [loading, setLoading] = useState(false)
  const [requestNumber, setRequestNumber] = useState(0)
  const [exportError, setExportError] = useState('')
  const [exportFormat, setExportFormat] = useState<ExportFormat>('excel')
  const [loadedAt, setLoadedAt] = useState<Date | null>(null)
  const tabs = Object.keys(reportSections) as ReportTab[]
  const options = useMemo(quarterOptions, [])
  const allowedTabs = tabs.filter((tab) =>
    reportSections[tab].permissions.some((permission) => reportAccess.permissions.includes(permission)),
  )
  const selectedTab = allowedTabs.includes(activeTab) ? activeTab : allowedTabs[0]
  const currentReportTab = selectedTab ?? activeTab
  const sections = useMemo(
    () => selectedTab
      ? reportSections[selectedTab].sections.filter((section) =>
        !section.requiredPermission || reportAccess.permissions.includes(section.requiredPermission),
      )
      : [],
    [reportAccess.permissions, selectedTab],
  )

  useEffect(() => {
    if (selectedTab && activeTab !== selectedTab) setActiveTab(selectedTab)
  }, [activeTab, selectedTab])

  const displayResults: Record<string, unknown> = useMemo(() => ({
    ...results,
    overview_summary: withoutOverviewMetrics(results.overview_summary),
    overview_registration_trend: peakRegistrationWindow(results.overview_registration_trend, period),
    student_status: studentPaymentStatusRows(results.student_summary),
    student_school_scores: exportRows(results.student_school_scores).map((row) =>
      Object.fromEntries(Object.entries(row).filter(([key]) => key.toLowerCase() !== 'ty_le_xuat_sac_pct')),
    ),
    student_utm: exportRows(results.student_utm),
    sponsor_list: exportRows(results.sponsor_list).map((row) =>
      Object.fromEntries(Object.entries(row).filter(([key]) => !['brand_reach', 'luot_tuong_tac'].includes(key.toLowerCase()))),
    ),
    import_quality: aggregateImportQuality(results.import_quality),
  }), [period, results])
  const registrationTrendRows = exportRows(displayResults.overview_registration_trend)
  const registrationTrendStart = registrationTrendRows[0]?.ngay
  const registrationTrendEnd = registrationTrendRows[registrationTrendRows.length - 1]?.ngay
  const registrationTrendRange = registrationTrendStart && registrationTrendEnd
    ? `${exportCell(registrationTrendStart, 'ngay')} – ${exportCell(registrationTrendEnd, 'ngay')}`
    : ''

  const visibleSections = sections

  function reportExportRows(includeEmpty = false): ReportExportDataset[] {
    return sections.flatMap<ReportExportDataset>((section) => {
      const sourceRows = exportRows(displayResults[section.reportId])
      const rows = section.reportId === 'overview_summary' && sourceRows.length
        ? [Object.assign({}, ...sourceRows)]
        : sourceRows
      if (rows.length) {
        return [{ reportId: section.reportId, title: section.title, rows, visualization: section.visualization, hasData: true }]
      }
      if (!includeEmpty) return []
      const message = errors[section.reportId]
        ? `Không tải được dữ liệu: ${errors[section.reportId]}`
        : 'Báo cáo không trả về dữ liệu trong kỳ đã chọn.'
      return [{
        reportId: section.reportId,
        title: section.title,
        rows: [],
        emptyColumns: emptyReportColumns[section.reportId] ?? ['trang_thai_du_lieu'],
        emptyMessage: message,
        visualization: section.visualization,
        hasData: false,
      }]
    })
  }

  function downloadFile(blob: Blob, extension: string, reportIds?: readonly string[]) {
    const url = URL.createObjectURL(blob)
    const link = document.createElement('a')
    link.href = url
    const reportName = reportIds?.length === 1
      ? reportIds[0] === 'support_top_questions'
        ? '50-cau-hoi-thuong-gap'
        : reportIds[0]
      : currentReportTab.toLocaleLowerCase('vi').replaceAll(' ', '-')
    link.download = `bao-cao-${period}-${reportName}.${extension}`
    link.click()
    window.setTimeout(() => URL.revokeObjectURL(url), 1000)
  }

  async function exportReport(format: ExportFormat, reportIds?: readonly string[]) {
    setExportError('')
    const datasets = reportExportRows(true)
      .filter((dataset) => !reportIds || reportIds.includes(dataset.reportId))
    if (!datasets.length) return

    try {
    if (format === 'pdf') {
      const printWindow = window.open('', '_blank', 'width=1000,height=800')
      if (!printWindow) {
        setExportError('Trình duyệt đang chặn cửa sổ in. Hãy cho phép cửa sổ bật lên để lưu PDF.')
        return
      }
      printWindow.opener = null
      const reportHtml = datasets.map(({ title, rows, emptyMessage }) => {
        if (!rows.length) {
          return `<section><h2>${htmlEscape(title)}</h2><p class="empty-note">${htmlEscape(emptyMessage)}</p></section>`
        }
        const columns = Array.from(new Set(rows.flatMap((row) => Object.keys(row))))
        return `<section><h2>${htmlEscape(title)}</h2><table><thead><tr>${columns.map((column) => `<th>${htmlEscape(formatFieldLabel(column))}</th>`).join('')}</tr></thead><tbody>${rows.map((row) => `<tr>${columns.map((column) => `<td>${htmlEscape(exportCell(row[column], column))}</td>`).join('')}</tr>`).join('')}</tbody></table></section>`
      }).join('')
      printWindow.document.write(`<!doctype html>
<html lang="vi">
  <head>
    <meta charset="utf-8">
    <title>${htmlEscape(reportIds?.includes('support_top_questions') ? 'Top câu hỏi thường gặp' : `Báo cáo ${currentReportTab}`)} ${htmlEscape(period)}</title>
    <style>
      @page { size: A4 landscape; margin: 18mm 16mm; }
      * { box-sizing: border-box; }
      body {
        margin: 0;
        color: #1e293b;
        font: 13pt Arial, sans-serif;
        line-height: 1.45;
      }
      h1 {
        margin: 0 0 18pt;
        padding: 0 0 8pt;
        border-bottom: 2px solid #2563eb;
        color: #1d5fa7;
        font-size: 25pt;
        line-height: 1.2;
      }
      .report-meta { margin: 0 0 4pt; color: #475569; }
      .report-time { margin: 0 0 24pt; color: #64748b; }
      section { margin: 0 0 20pt; }
      h2 {
        margin: 16pt 0 7pt;
        color: #1d5fa7;
        font-size: 18pt;
        line-height: 1.25;
        break-after: avoid;
      }
      table {
        width: 100%;
        border-collapse: collapse;
        table-layout: auto;
        margin: 0 0 14pt;
      }
      thead { display: table-header-group; }
      tr { break-inside: avoid; }
      th, td {
        border: 1px solid #94a3b8;
        padding: 6pt 8pt;
        text-align: left;
        vertical-align: middle;
        overflow-wrap: anywhere;
      }
      th {
        background: #2563eb;
        color: #fff;
        font-weight: 700;
      }
      tbody tr:nth-child(even) { background: #f1f5f9; }
      .empty-note { padding: 10pt 12pt; border: 1px solid #fed7aa; background: #fff7ed; color: #9a3412; }
      @media screen {
        body { max-width: 1120px; margin: 32px auto; padding: 32px; background: #fff; box-shadow: 0 1px 8px #cbd5e1; }
      }
      @media print {
        body { print-color-adjust: exact; -webkit-print-color-adjust: exact; }
        h1, h2 { break-after: avoid; }
      }
    </style>
  </head>
  <body>
    <h1>${htmlEscape(reportIds?.includes('support_top_questions') ? 'Top câu hỏi thường gặp' : `Báo cáo ${currentReportTab}`)}</h1>
    <p class="report-meta">Kỳ báo cáo: ${htmlEscape(period)}</p>
    <p class="report-time">Xuất lúc: ${htmlEscape(new Date().toLocaleString('vi-VN'))}</p>
    ${reportHtml}
  </body>
</html>`)
      printWindow.document.close()
      printWindow.focus()
      printWindow.onafterprint = () => printWindow.close()
      printWindow.print()
      return
    }

    if (format === 'csv') {
      const lines: string[] = []
      for (const { title, rows, emptyColumns, emptyMessage } of datasets) {
        const columns = emptyColumns ?? Array.from(new Set(rows.flatMap((row) => Object.keys(row))))
        lines.push(csvCell(title), columns.map((column) => csvCell(formatFieldLabel(column))).join(','))
        if (rows.length) {
          for (const row of rows) lines.push(columns.map((column) => csvCell(row[column], column)).join(','))
        } else {
          lines.push(csvCell(emptyMessage))
        }
        lines.push('')
      }
      downloadFile(new Blob([`\uFEFF${lines.join('\r\n')}`], { type: 'text/csv;charset=utf-8' }), 'csv', reportIds)
      return
    }

    if (format === 'excel') {
      const excelDatasets = datasets.filter((dataset) => dataset.reportId !== 'overview_summary')
      const usedNames = new Set<string>()
      const workbook = XLSX.utils.book_new()
      const chartSources: ExcelChartSource[] = []
      const dashboard = buildExcelDashboard(currentReportTab, period, datasets.filter((dataset) => dataset.hasData), results)
      const dashboardChartCounts = new Map<string, number>()
      const headerStyle = {
        fill: { fgColor: { rgb: '2563EB' } },
        font: { bold: true, color: { rgb: 'FFFFFF' }, sz: 11 },
        alignment: { horizontal: 'center', vertical: 'center', wrapText: true },
        border: {
          top: { style: 'thin', color: { rgb: '1D4ED8' } },
          bottom: { style: 'thin', color: { rgb: '1D4ED8' } },
          left: { style: 'thin', color: { rgb: '1D4ED8' } },
          right: { style: 'thin', color: { rgb: '1D4ED8' } },
        },
      }
      const titleStyle = {
        fill: { fgColor: { rgb: 'DBEAFE' } },
        font: { bold: true, color: { rgb: '1E3A8A' }, sz: 16 },
        alignment: { horizontal: 'left', vertical: 'center' },
      }
      const metadataStyle = {
        font: { color: { rgb: '64748B' }, sz: 10 },
        alignment: { horizontal: 'left', vertical: 'center' },
      }
      const border = {
        top: { style: 'thin', color: { rgb: 'D8E1EC' } },
        bottom: { style: 'thin', color: { rgb: 'D8E1EC' } },
        left: { style: 'thin', color: { rgb: 'D8E1EC' } },
        right: { style: 'thin', color: { rgb: 'D8E1EC' } },
      }
      const includeDashboardSheet = !reportIds || reportIds.length > 1 || reportIds.includes('overview_summary')
      const detailSheetOffset = includeDashboardSheet ? 1 : 0
      if (includeDashboardSheet) {
        const dashboardColumnCount = 12
        const dashboardRows: string[][] = []
        const dashboardMerges: { s: { r: number; c: number }; e: { r: number; c: number } }[] = []
        const ensureDashboardRow = (rowIndex: number) => {
          while (dashboardRows.length <= rowIndex) {
            dashboardRows.push(Array.from({ length: dashboardColumnCount }, () => ''))
          }
        }

        ensureDashboardRow(1)
        dashboardRows[0][0] = dashboard.title
        dashboardRows[1][0] = `Kỳ báo cáo: ${period}    ·    Xuất lúc: ${new Date().toLocaleString('vi-VN')}`
        dashboardMerges.push(
          { s: { r: 0, c: 0 }, e: { r: 0, c: dashboardColumnCount - 1 } },
          { s: { r: 1, c: 0 }, e: { r: 1, c: dashboardColumnCount - 1 } },
        )

        dashboard.kpis.forEach((metric, index) => {
          const startRow = 3 + Math.floor(index / 4) * 4
          const startColumn = (index % 4) * 3
          ensureDashboardRow(startRow + 2)
          dashboardRows[startRow][startColumn] = metric.label
          dashboardRows[startRow + 1][startColumn] = metric.value
          dashboardRows[startRow + 2][startColumn] = metric.detail ?? ''
          for (let row = startRow; row <= startRow + 2; row += 1) {
            dashboardMerges.push({
              s: { r: row, c: startColumn },
              e: { r: row, c: startColumn + 2 },
            })
          }
        })

        let contentRow = 3 + Math.ceil(dashboard.kpis.length / 4) * 4

        const dashboardWorksheet = XLSX.utils.aoa_to_sheet(dashboardRows)
        dashboardWorksheet['!merges'] = dashboardMerges
        dashboardWorksheet['!cols'] = Array.from({ length: dashboardColumnCount }, () => ({ wch: 15 }))
        dashboardWorksheet['!rows'] = []
        dashboardWorksheet['!rows'][0] = { hpt: 36 }
        dashboardWorksheet['!rows'][1] = { hpt: 24 }

        const dashboardTitleStyle = {
          fill: { fgColor: { rgb: '2563EB' } },
          font: { bold: true, color: { rgb: 'FFFFFF' }, sz: 20 },
          alignment: { horizontal: 'left', vertical: 'center' },
        }
        const dashboardMetadataStyle = {
          fill: { fgColor: { rgb: 'F1F5F9' } },
          font: { color: { rgb: '64748B' }, sz: 10 },
          alignment: { horizontal: 'left', vertical: 'center' },
        }
        const dashboardMetricColors = ['EFF6FF', 'DBEAFE', 'EFF6FF', 'DBEAFE']
        const dashboardTileBorder = {
          top: { style: 'thin', color: { rgb: 'CBD5E1' } },
          bottom: { style: 'thin', color: { rgb: 'CBD5E1' } },
          left: { style: 'thin', color: { rgb: 'CBD5E1' } },
          right: { style: 'thin', color: { rgb: 'CBD5E1' } },
        }
        for (let column = 0; column < dashboardColumnCount; column += 1) {
          const titleAddress = XLSX.utils.encode_cell({ r: 0, c: column })
          const metadataAddress = XLSX.utils.encode_cell({ r: 1, c: column })
          dashboardWorksheet[titleAddress] ??= { t: 's', v: '' }
          dashboardWorksheet[metadataAddress] ??= { t: 's', v: '' }
          dashboardWorksheet[titleAddress].s = dashboardTitleStyle
          dashboardWorksheet[metadataAddress].s = dashboardMetadataStyle
        }
        dashboard.kpis.forEach((metric, index) => {
          const startRow = 3 + Math.floor(index / 4) * 4
          const startColumn = (index % 4) * 3
          const fill = dashboardMetricColors[index % dashboardMetricColors.length]
          for (let row = startRow; row <= startRow + 2; row += 1) {
            dashboardWorksheet['!rows']![row] = { hpt: row === startRow + 1 ? 34 : 22 }
            for (let column = startColumn; column < startColumn + 3; column += 1) {
              const address = XLSX.utils.encode_cell({ r: row, c: column })
              dashboardWorksheet[address] ??= { t: 's', v: '' }
              dashboardWorksheet[address].s = {
                fill: { fgColor: { rgb: fill } },
                font: {
                  color: { rgb: row === startRow + 1 ? '0F172A' : '475569' },
                  bold: row !== startRow + 2,
                  sz: row === startRow + 1 ? 16 : 10,
                },
                alignment: { horizontal: 'left', vertical: 'center', wrapText: true },
                border: dashboardTileBorder,
              }
            }
          }
        })
        if (dashboard.charts.length) {
          contentRow += 1
          ensureDashboardRow(contentRow)
          dashboardRows[contentRow][0] = 'BIỂU ĐỒ TỔNG QUAN'
          dashboardMerges.push({
            s: { r: contentRow, c: 0 },
            e: { r: contentRow, c: dashboardColumnCount - 1 },
          })
          dashboardWorksheet['!merges'] = dashboardMerges
          for (let column = 0; column < dashboardColumnCount; column += 1) {
            const address = XLSX.utils.encode_cell({ r: contentRow, c: column })
            dashboardWorksheet[address] ??= { t: 's', v: '' }
            dashboardWorksheet[address].s = {
              fill: { fgColor: { rgb: '2563EB' } },
              font: { bold: true, color: { rgb: 'FFFFFF' }, sz: 11 },
              alignment: { horizontal: 'left', vertical: 'center' },
            }
          }
          dashboardWorksheet['!rows']![contentRow] = { hpt: 24 }
          const chartStartRow = contentRow + 1
          dashboard.charts.forEach((item, index) => {
            chartSources.push({
              sheetIndex: 0,
              title: item.title,
              columns: [],
              rows: [],
              chartData: item,
              anchor: {
                column: index % 2 === 0 ? 0 : 6,
                row: chartStartRow + Math.floor(index / 2) * 18,
                widthColumns: 6,
                heightRows: 16,
              },
            })
          })
          const lastChartRow = chartStartRow + Math.ceil(dashboard.charts.length / 2) * 18
          dashboardWorksheet['!ref'] = XLSX.utils.encode_range({
            s: { r: 0, c: 0 },
            e: { r: lastChartRow, c: dashboardColumnCount - 1 },
          })
        }
        XLSX.utils.book_append_sheet(workbook, dashboardWorksheet, safeSheetName('Tổng quan', usedNames))
      }

      excelDatasets.forEach(({ reportId, title, rows, visualization, hasData, emptyColumns, emptyMessage }, datasetIndex) => {
        const sheetIndex = datasetIndex + detailSheetOffset
        const columns = emptyColumns ?? Array.from(new Set(rows.flatMap((row) => Object.keys(row))))
        const headerRow = 4
        const firstDataRow = headerRow + 1
        const lastColumn = Math.max(columns.length - 1, 0)
        const sheetRows = [
          [title],
          [`Kỳ báo cáo: ${period}`],
          [`Xuất lúc: ${new Date().toLocaleString('vi-VN')}`],
          [],
          columns.map(formatFieldLabel),
          ...rows.map((row) => columns.map((column) => exportValue(row[column] ?? null, column))),
          ...(emptyMessage ? [[`Ghi chú: ${emptyMessage}`]] : []),
        ]
        const worksheet = XLSX.utils.aoa_to_sheet(sheetRows)
        if (emptyMessage && columns.length > 1) {
          worksheet['!merges'] = [
            ...(worksheet['!merges'] ?? []),
            { s: { r: firstDataRow, c: 0 }, e: { r: firstDataRow, c: lastColumn } },
          ]
        }
        worksheet['!cols'] = columns.map((column) => ({
          wch: Math.min(42, Math.max(14, formatFieldLabel(column).length + 2, ...rows.map((row) => Math.min(exportCell(row[column], column).length + 2, 42)))),
        }))
        worksheet['!merges'] = [
          ...(worksheet['!merges'] ?? []),
          ...[0, 1, 2].map((row) => ({
            s: { r: row, c: 0 },
            e: { r: row, c: lastColumn },
          })),
        ]
        worksheet['!rows'] = [
          { hpt: 32 },
          { hpt: 20 },
          { hpt: 20 },
          { hpt: 10 },
          { hpt: 28 },
        ]
        if (emptyMessage) worksheet['!rows'][firstDataRow] = { hpt: 30 }
        for (let columnIndex = 0; columnIndex < columns.length; columnIndex += 1) {
          const titleAddress = XLSX.utils.encode_cell({ r: 0, c: columnIndex })
          const periodAddress = XLSX.utils.encode_cell({ r: 1, c: columnIndex })
          const timestampAddress = XLSX.utils.encode_cell({ r: 2, c: columnIndex })
          if (worksheet[titleAddress]) worksheet[titleAddress].s = titleStyle
          if (worksheet[periodAddress]) worksheet[periodAddress].s = metadataStyle
          if (worksheet[timestampAddress]) worksheet[timestampAddress].s = metadataStyle
        }
        columns.forEach((_, index) => {
          const headerAddress = XLSX.utils.encode_cell({ r: headerRow, c: index })
          if (worksheet[headerAddress]) worksheet[headerAddress].s = headerStyle
        })
        rows.forEach((row, rowIndex) => {
          const excelRow = firstDataRow + rowIndex
          worksheet['!rows']![excelRow] = { hpt: 22 }
          columns.forEach((column, columnIndex) => {
            const address = XLSX.utils.encode_cell({ r: excelRow, c: columnIndex })
            const cell = worksheet[address]
            if (!cell) return
            cell.s = {
              fill: { fgColor: { rgb: rowIndex % 2 === 0 ? 'FFFFFF' : 'F1F5F9' } },
              font: { color: { rgb: '1E293B' }, sz: 10 },
              alignment: {
                horizontal: typeof row[column] === 'number' ? 'right' : 'left',
                vertical: 'center',
                wrapText: true,
              },
              border,
              ...(typeof row[column] === 'number'
                ? { numFmt: Number.isInteger(row[column]) ? '#,##0' : '#,##0.##' }
                : {}),
            }
          })
        })
        if (emptyMessage) {
          const noteCell = worksheet[XLSX.utils.encode_cell({ r: firstDataRow, c: 0 })]
          if (noteCell) {
            noteCell.s = {
              fill: { fgColor: { rgb: 'FFF7ED' } },
              font: { color: { rgb: '9A3412' }, italic: true, sz: 10 },
              alignment: { vertical: 'center', wrapText: true },
              border,
            }
          }
        }
        worksheet['!autofilter'] = {
          ref: XLSX.utils.encode_range({
            s: { r: headerRow, c: 0 },
            e: { r: headerRow + rows.length, c: lastColumn },
          }),
        }
        const chartsStartRow = firstDataRow + rows.length + 2
        const customCharts = hasData ? dashboard.charts.filter((item) => item.reportId === reportId) : []
        customCharts.forEach((item) => {
          const chartIndex = dashboardChartCounts.get(reportId) ?? 0
          dashboardChartCounts.set(reportId, chartIndex + 1)
          chartSources.push({
            sheetIndex,
            title: item.title,
            columns: [],
            rows: [],
            chartData: item,
            anchor: {
              column: 0,
              row: chartsStartRow + chartIndex * 20,
              widthColumns: 12,
              heightRows: 19,
            },
          })
        })
        if (hasData && !dashboard.customChartReportIds.includes(reportId) && reportId !== 'overview_summary') {
          const chartColumns = reportId === 'overview_progress'
            ? columns.filter((column) => column === 'ten_kpi' || column === 'hoan_thanh_pct')
            : columns
          chartSources.push({
            sheetIndex,
            title,
            visualization,
            columns: chartColumns.map((key) => ({ key, label: formatFieldLabel(key) })),
            rows,
          })
        }
        XLSX.utils.book_append_sheet(workbook, worksheet, safeSheetName(title, usedNames))

        if (reportId === 'contest_results' || reportId.startsWith('contest_finalists_')) {
          const resultColumns = columns
          const resultGroups = [
            { table: 'BANG_A', outcome: 'ĐẠT YÊU CẦU', label: 'Bảng A - Đạt' },
            { table: 'BANG_A', outcome: 'KHÔNG ĐẠT', label: 'Bảng A - Không đạt' },
            { table: 'BANG_B', outcome: 'ĐẠT YÊU CẦU', label: 'Bảng B - Đạt' },
            { table: 'BANG_B', outcome: 'KHÔNG ĐẠT', label: 'Bảng B - Không đạt' },
          ]

          resultGroups.forEach((group) => {
            const groupedRows = rows.filter((row) => {
              const table = String(row.bang_dau ?? '').toUpperCase()
              const outcome = String(row.ket_qua_xet ?? '').trim().toUpperCase()
              return table === group.table && (
                outcome === group.outcome
                || (group.outcome === 'ĐẠT YÊU CẦU' && outcome.includes('ĐẠT') && !outcome.includes('KHÔNG'))
                || (group.outcome === 'KHÔNG ĐẠT' && outcome.includes('KHÔNG'))
              )
            })
            const sheetTitle = `${title} - ${group.label}`
            const splitRows = [
              [sheetTitle],
              [`Kỳ báo cáo: ${period}`],
              [`Xuất lúc: ${new Date().toLocaleString('vi-VN')}`],
              [],
              resultColumns.map(formatFieldLabel),
              ...groupedRows.map((row) => resultColumns.map((column) => exportValue(row[column] ?? null, column))),
              ...(groupedRows.length === 0 ? [['Không có dữ liệu trong nhóm này']] : []),
            ]
            const splitWorksheet = XLSX.utils.aoa_to_sheet(splitRows)
            splitWorksheet['!cols'] = resultColumns.map((column) => ({
              wch: Math.min(42, Math.max(14, formatFieldLabel(column).length + 2)),
            }))
            splitWorksheet['!merges'] = [0, 1, 2].map((rowIndex) => ({
              s: { r: rowIndex, c: 0 },
              e: { r: rowIndex, c: Math.max(resultColumns.length - 1, 0) },
            }))
            splitWorksheet['!rows'] = [{ hpt: 32 }, { hpt: 20 }, { hpt: 20 }, { hpt: 10 }, { hpt: 28 }]
            resultColumns.forEach((_, columnIndex) => {
              ;[0, 1, 2].forEach((rowIndex) => {
                const address = XLSX.utils.encode_cell({ r: rowIndex, c: columnIndex })
                if (splitWorksheet[address]) {
                  splitWorksheet[address].s = rowIndex === 0 ? titleStyle : metadataStyle
                }
              })
              const headerAddress = XLSX.utils.encode_cell({ r: 4, c: columnIndex })
              if (splitWorksheet[headerAddress]) splitWorksheet[headerAddress].s = headerStyle
            })
            XLSX.utils.book_append_sheet(workbook, splitWorksheet, safeSheetName(sheetTitle, usedNames))
          })
        }
      })
      const workbookOutput = XLSX.write(workbook, { bookType: 'xlsx', type: 'array', compression: true }) as ArrayBuffer
      const output = addExcelCharts(workbookOutput, chartSources)
      downloadFile(new Blob([output], { type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet' }), 'xlsx', reportIds)
      return
    }

    const tableBorder = {
      style: BorderStyle.SINGLE,
      size: 1,
      color: 'CBD5E1',
    }
    const tableBorders = {
      top: tableBorder,
      bottom: tableBorder,
      left: tableBorder,
      right: tableBorder,
      insideHorizontal: tableBorder,
      insideVertical: tableBorder,
    }
    const cellMargins = { top: 100, bottom: 100, left: 120, right: 120 }
    const children: (Paragraph | Table)[] = [
      new Paragraph({
        alignment: AlignmentType.LEFT,
        spacing: { after: 140 },
        border: {
          bottom: { style: BorderStyle.SINGLE, size: 10, color: '2563EB', space: 8 },
        },
        children: [new TextRun({
          text: `Báo cáo ${currentReportTab}`,
          bold: true,
          color: '1D5FA7',
          font: 'Arial',
          size: 48,
        })],
      }),
      new Paragraph({
        spacing: { after: 40 },
        children: [new TextRun({ text: `Kỳ báo cáo: ${period}`, color: '475569', font: 'Arial', size: 26 })],
      }),
      new Paragraph({
        spacing: { after: 360 },
        children: [new TextRun({ text: `Xuất lúc: ${new Date().toLocaleString('vi-VN')}`, color: '64748B', font: 'Arial', size: 26 })],
      }),
    ]
    for (const { title, rows, emptyColumns, emptyMessage } of datasets) {
      const columns = emptyColumns ?? Array.from(new Set(rows.flatMap((row) => Object.keys(row))))
      children.push(new Paragraph({
        heading: HeadingLevel.HEADING_1,
        keepNext: true,
        spacing: { before: 240, after: 100 },
        children: [new TextRun({ text: title, bold: true, color: '1D5FA7', font: 'Arial', size: 36 })],
      }))
      if (!rows.length) {
        children.push(new Paragraph({
          shading: { type: ShadingType.CLEAR, fill: 'FFF7ED' },
          spacing: { after: 180 },
          children: [new TextRun({
            text: emptyMessage ?? 'Báo cáo không trả về dữ liệu trong kỳ đã chọn.',
            color: '9A3412',
            font: 'Arial',
            size: 26,
          })],
        }))
        continue
      }
      const tableRows = [
        new TableRow({
          tableHeader: true,
          children: columns.map((column) => new TableCell({
            shading: { type: ShadingType.CLEAR, fill: '2563EB' },
            margins: cellMargins,
            verticalAlign: VerticalAlign.CENTER,
            children: [new Paragraph({
              alignment: AlignmentType.LEFT,
              spacing: { after: 0 },
              children: [new TextRun({
                text: formatFieldLabel(column),
                bold: true,
                color: 'FFFFFF',
                font: 'Arial',
                size: 26,
              })],
            })],
          })),
        }),
        ...rows.map((row, rowIndex) => new TableRow({
          children: columns.map((column) => new TableCell({
            shading: { type: ShadingType.CLEAR, fill: rowIndex % 2 === 0 ? 'FFFFFF' : 'F1F5F9' },
            margins: cellMargins,
            verticalAlign: VerticalAlign.CENTER,
            children: [new Paragraph({
              spacing: { after: 0 },
              children: [new TextRun({
                text: exportCell(row[column], column),
                color: '1E293B',
                font: 'Arial',
                size: 26,
              })],
            })],
          })),
        })),
      ]
      children.push(new Table({
        rows: tableRows,
        width: { size: 100, type: WidthType.PERCENTAGE },
        columnWidths: columns.map(() => Math.floor(9360 / columns.length)),
        borders: tableBorders,
        margins: cellMargins,
      }))
      children.push(new Paragraph({ spacing: { after: 180 }, children: [] }))
    }
    const document = new Document({
      sections: [{
        properties: {
          page: {
            size: { orientation: PageOrientation.LANDSCAPE },
            margin: { top: 720, right: 720, bottom: 720, left: 720 },
          },
        },
        children,
      }],
    })
    const wordFile = await Packer.toBlob(document)
    downloadFile(wordFile, 'docx', reportIds)
  } catch (error) {
    setExportError(error instanceof Error ? error.message : String(error))
  }
  }

  useEffect(() => {
    let active = true
    async function loadReport() {
      if (reportAccess.loading || reportAccess.error || !selectedTab || sections.length === 0) return
      if (!supabase) {
        setErrors(Object.fromEntries(sections.map((section) => [section.reportId, 'Thiếu cấu hình Supabase. Khai báo NEXT_PUBLIC_SUPABASE_URL và NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY.'])))
        setLoading(false)
        return
      }
      setLoading(true)
      setErrors({})
      setResults((current) => {
        const next = { ...current }
        for (const section of sections) delete next[section.reportId]
        return next
      })
      try {
        const responses = await Promise.all(
          sections.filter((section) => section.reportId !== 'student_status').map(async (section) => {
            let response: { data: unknown; error: { message: string } | null }
            switch (section.reportId) {
              case 'contest_certificates':
                response = await supabase.rpc('fn_bao_cao_du_lieu', {
                  p_ma_bao_cao: 'contest_results',
                  p_ky: period,
                })
                if (!response.error) {
                  const certificates = exportRows(response.data)
                    .filter((row) => Number(row.tong_diem) >= 600)
                    .filter((row, index, rows) => {
                      const studentId = String(row.thi_sinh_id ?? '')
                      return rows.findIndex((item) => String(item.thi_sinh_id ?? '') === studentId) === index
                    })
                    .map((row) => ({
                      thi_sinh_id: row.thi_sinh_id,
                      ho_ten: row.ho_ten,
                      bang_dau: row.bang_dau,
                      truong_hoc: row.truong_hoc,
                      tong_diem: row.tong_diem,
                      thu_hang: row.thu_hang,
                      ket_qua_xet: 'ĐẠT CHỨNG CHỈ COS PRO',
                    }))
                    .sort((a, b) => Number(b.tong_diem) - Number(a.tong_diem))
                  response = { data: certificates, error: null }
                }
                break
              case 'contest_finalists_a':
              case 'contest_finalists_b':
                response = await supabase.rpc('fn_bao_cao_ketqua_chungket', {
                  p_ky: period,
                  p_bang: section.reportId === 'contest_finalists_a' ? 'BANG_A' : 'BANG_B',
                })
                break
              case 'contest_school_round_summary':
                response = await supabase.rpc('fn_bao_cao_thongke_thisinh_theo_vong', {
                  p_ky: period,
                })
                break
              case 'contest_qualifiers_top10':
                response = await supabase.rpc('fn_bao_cao_ds_top10_vongloai', {
                  p_ky: period,
                })
                break
              case 'support_top_questions':
                response = await supabase.rpc('fn_report_top_faq_questions', { p_ky: period, p_limit: 50 })
                break
              case 'revenue_by_region':
                response = await supabase.rpc('fn_report_revenue_by_region', { p_ky: period })
                break
              case 'lead_pipeline':
                response = await supabase.rpc('fn_report_lead_pipeline', { p_ky: period })
                break
              case 'practice_top15':
                response = await supabase.rpc('fn_report_practice_top15', { p_ky: period })
                break
              case 'overview_registration_trend':
                response = await supabase.rpc('fn_report_registration_peak_trend', { p_ky: period })
                break
              case 'partner_referral_conversion':
                response = await supabase.rpc('fn_report_partner_referral_conversion', { p_ky: period })
                break
              case 'support_unanswered_age':
                response = await supabase.rpc('fn_report_support_unanswered_age', { p_ky: period })
                break
              case 'import_quality':
                response = await supabase.rpc('fn_report_import_quality', { p_ky: period })
                break
              default:
                response = await supabase.rpc('fn_bao_cao_du_lieu', {
                  p_ma_bao_cao: section.reportId,
                  p_ky: period,
                })
            }
            return { reportId: section.reportId, data: response.data, error: response.error }
          }),
        )
        if (!active) return
        const nextResults: Record<string, unknown> = {}
        const nextErrors: Record<string, string> = {}
        for (const response of responses) {
          if (response.error) nextErrors[response.reportId] = `Không tải được dữ liệu: ${response.error.message}`
          else if (response.reportId === 'overview_enrollment_funnel') {
            nextResults[response.reportId] = exportRows(response.data)
              .filter((row) => !String(row.buoc ?? '').trim().toLocaleLowerCase('vi').startsWith('hoàn thành'))
              .map((row) => ({
                ...row,
                buoc: typeof row.buoc === 'string'
                  ? row.buoc.replace(/\s*\(thanh toán thành công\)\s*$/i, '')
                  : row.buoc,
              }))
          } else nextResults[response.reportId] = response.data
        }
        if (nextErrors.student_summary) nextErrors.student_status = nextErrors.student_summary

        setResults((current) => ({ ...current, ...nextResults }))
        setErrors(nextErrors)
      } catch (loadError) {
        if (!active) return
        const message = loadError instanceof Error ? loadError.message : String(loadError)
        setErrors(Object.fromEntries(sections.map((section) => [
          section.reportId,
          `Không tải được dữ liệu: ${message}`,
        ])))
      } finally {
        if (active) {
          setLoadedAt(new Date())
          setLoading(false)
        }
      }
    }
    void loadReport()
    return () => { active = false }
  }, [period, reportAccess.error, reportAccess.loading, requestNumber, sections, selectedTab, supabase])

  return (
    <>
      <div className="mb-6 flex flex-wrap items-end justify-between gap-4">
        <div>
          <p className="text-[10px] font-bold uppercase tracking-[0.18em] text-blue-600">TRUNG TÂM PHÂN TÍCH</p>
          <p className="mt-1 text-base text-slate-600">Theo dõi hiệu quả vận hành, tuyển sinh, tài trợ và doanh thu.</p>
        </div>
        <div className="flex flex-wrap items-center gap-2">
          <label className="relative flex h-10 items-center gap-2 rounded-xl border border-slate-200 bg-white px-3 shadow-sm">
            <CalendarDays size={15} className="text-blue-500" />
            <span className="text-sm font-medium text-slate-600">Kỳ báo cáo</span>
            <select
              value={period}
              onChange={(event) => setPeriod(event.target.value)}
              className="appearance-none bg-transparent pr-1 text-sm font-semibold text-slate-800 outline-none"
              aria-label="Kỳ báo cáo"
            >
              {options.map((option) => <option key={option} value={option}>{option}</option>)}
              {!options.includes(period) && <option value={period}>{period}</option>}
            </select>
          </label>
          <div className="flex items-center gap-2 rounded-xl border border-slate-200 bg-white px-3 py-2 text-[11px] text-slate-500">
            <RefreshCw size={13} className="text-blue-500" />
            {loading ? 'Đang tải dữ liệu…' : loadedAt ? `Tải xong lúc ${loadedAt.toLocaleTimeString('vi-VN', { hour: '2-digit', minute: '2-digit', hour12: false })} ${loadedAt.toLocaleDateString('vi-VN', { day: '2-digit', month: '2-digit', year: 'numeric' })}` : 'Chưa tải dữ liệu'}
          </div>
          <button
            onClick={() => setRequestNumber((number) => number + 1)}
            className="flex h-10 items-center gap-2 rounded-xl border border-slate-200 bg-white px-3 text-sm font-semibold text-slate-700 shadow-sm hover:bg-slate-50"
          >
            <RefreshCw size={14} /> Làm mới
          </button>
          <label>
            <span className="sr-only">Định dạng xuất báo cáo</span>
            <select
              aria-label="Định dạng xuất báo cáo"
              value={exportFormat}
              onChange={(event) => setExportFormat(event.target.value as ExportFormat)}
              className="h-10 rounded-xl border border-slate-200 bg-white px-3 text-sm font-semibold text-slate-700 shadow-sm"
            >
              <option value="excel">Excel (.xlsx)</option>
              <option value="pdf">PDF</option>
              <option value="word">Word (.docx)</option>
              <option value="csv">CSV</option>
            </select>
          </label>
          <button
            onClick={() => void exportReport(exportFormat)}
            disabled={loading || !sections.some((section) => displayResults[section.reportId] != null)}
            className="flex h-10 items-center gap-2 rounded-xl bg-blue-600 px-3.5 text-sm font-semibold text-white shadow-md shadow-blue-200 hover:bg-blue-700 disabled:opacity-50"
          >
            {exportFormat === 'excel'
              ? <FileSpreadsheet size={14} />
              : exportFormat === 'pdf'
                ? <Printer size={14} />
                : <FileText size={14} />}
            Xuất {exportFormat === 'excel' ? 'Excel' : exportFormat === 'word' ? 'Word' : exportFormat.toUpperCase()}
          </button>
        </div>
      </div>

      {exportError && (
        <p role="alert" className="mb-4 rounded-xl border border-rose-200 bg-rose-50 px-4 py-3 text-xs text-rose-700">
          Xuất file không thành công: {exportError}
        </p>
      )}

      <div className="mb-5 rounded-2xl border border-blue-100 bg-blue-50/60 px-4 py-3 text-sm text-blue-800">
        <div className="flex flex-wrap items-center justify-between gap-2">
          <span className="font-semibold">Kỳ đang xem: {period}</span>
          <span className="text-blue-700">Khoảng ngày: {reportPeriodRange(period)}</span>
        </div>
      </div>

      <div className="mb-5 overflow-x-auto border-b border-slate-200">
        <div className="flex min-w-max gap-1">
          {allowedTabs.map((tab) => (
            <button
              key={tab}
              onClick={() => setActiveTab(tab)}
              className={`flex items-center gap-2 border-b-2 px-4 py-3 text-sm font-semibold transition ${
                activeTab === tab
                  ? 'border-blue-600 text-blue-700'
                  : 'border-transparent text-slate-500 hover:text-slate-800'
              }`}
            >
              {tab === 'Tổng quan' && <BarChart3 size={15} />}
              {tab === 'Vận hành thí sinh' ? 'Thí sinh' : tab}
            </button>
          ))}
        </div>
      </div>

      {reportAccess.loading ? (
        <p className="rounded-xl bg-slate-50 p-6 text-center text-sm text-slate-500">Đang kiểm tra quyền báo cáo…</p>
      ) : reportAccess.error ? (
        <p role="alert" className="rounded-xl border border-amber-200 bg-amber-50 p-4 text-sm text-amber-800">{reportAccess.error}</p>
      ) : allowedTabs.length === 0 ? (
        <p className="rounded-xl bg-slate-50 p-6 text-center text-sm text-slate-500">Tài khoản chưa được cấp quyền xem báo cáo hoặc dữ liệu quyền chưa được đồng bộ.</p>
      ) : null}

      <div className="mb-4 flex items-center justify-between">
        <p className="text-sm text-slate-600">
          {sections.length} báo cáo trong kỳ <span className="font-semibold text-slate-800">{period}</span>
        </p>
        {loading && <span className="text-[11px] text-slate-400">Đang đồng bộ dữ liệu…</span>}
      </div>

      <div className="space-y-5">
        {visibleSections.map((section) => (
          <div id={`report-${section.reportId}`} key={`${period}-${section.reportId}`} className="w-full scroll-mt-24">
            <DataPanel
              title={section.title}
              description={section.reportId === 'overview_registration_trend'
                ? `16 ngày liên tiếp có tổng lượt đăng ký cao nhất trong kỳ.${registrationTrendRange ? ` Khoảng: ${registrationTrendRange}.` : ''}`
                : section.description}
              data={displayResults[section.reportId]}
              loading={loading && !displayResults[section.reportId]}
              error={errors[section.reportId]}
              action={section.reportId === 'support_top_questions' && exportRows(displayResults.support_top_questions).length > 0 ? (
                <button
                  type="button"
                  onClick={() => void exportReport('pdf', ['support_top_questions'])}
                  className="inline-flex min-h-9 items-center gap-2 rounded-lg bg-blue-600 px-3 text-xs font-semibold text-white hover:bg-blue-700"
                >
                  <Printer size={14} /> Xuất PDF riêng
                </button>
              ) : undefined}
              visualization={section.visualization}
              compactTable={section.reportId === 'lead_pipeline'}
              chartValueField={section.reportId === 'overview_progress' ? 'hoan_thanh_pct' : undefined}
              chartLabelField={section.reportId === 'overview_progress'
                ? 'ten_kpi'
                : section.reportId === 'student_school_scores' ? 'truong_hoc' : undefined}
              chartSecondaryLabelField={section.reportId === 'student_school_scores' ? 'bang_dau' : undefined}
            />
          </div>
        ))}
        {!loading && visibleSections.length === 0 && (
          <p className="rounded-xl bg-slate-50 p-6 text-center text-sm text-slate-500">
            Kỳ báo cáo này chưa có dữ liệu.
          </p>
        )}
      </div>
    </>
  )
}
