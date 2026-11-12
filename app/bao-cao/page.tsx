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

type ReportTab = 'Tổng quan' | 'Thí sinh' | 'Doanh thu' | 'Học vụ' | 'Đối tác' | 'Hỗ trợ' | 'Bảo mật'
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

type ReportCategory = { permission: string; sections: SectionDefinition[] }

const emptyReportColumns: Record<string, string[]> = {
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
    'brand_reach',
    'luot_tuong_tac',
  ],
  supplier_list: [
    'doanh_nghiep_id',
    'ten_doanh_nghiep',
    'hinh_thuc',
    'so_thi_sinh_cung_cap',
    'doanh_thu',
    'hoa_hong',
  ],
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
    permission: 'BAO_CAO_TONG_QUAN',
    sections: [
      { reportId: 'overview_summary', title: 'Chỉ số tổng quan', description: 'Chỉ số thí sinh, tham gia và doanh thu trong kỳ.', visualization: 'metrics' },
      { reportId: 'lead_pipeline', title: 'Lead hợp nhất theo nguồn', description: 'Đối chiếu lead từ biểu mẫu, Lead Ads và đăng ký web theo trạng thái hồ sơ/thanh toán.', visualization: 'table' },
      { reportId: 'overview_progress', title: 'Tiến độ chỉ tiêu', description: 'Tỷ lệ hoàn thành và số liệu chi tiết của từng chỉ tiêu.', visualization: 'bar-table' },
      { reportId: 'overview_comparison', title: 'So sánh đăng ký với kỳ trước', visualization: 'metrics' },
      { reportId: 'overview_enrollment_funnel', title: 'Phễu tuyển sinh', description: 'Tiếp cận → Đăng ký → Tham gia.', visualization: 'funnel' },
      { reportId: 'overview_registration_trend', title: 'Khoảng 16 ngày có nhiều lượt đăng ký nhất', description: '16 ngày liên tiếp có tổng lượt đăng ký cao nhất trong kỳ.', visualization: 'area' },
    ],
  },
  'Thí sinh': {
    permission: 'BAO_CAO_THISINH',
    sections: [
      { reportId: 'student_summary', title: 'Tổng quan thí sinh', visualization: 'metrics' },
      { reportId: 'student_status', title: 'Trạng thái hồ sơ', visualization: 'pie' },
      { reportId: 'student_schools', title: 'Thí sinh theo trường', visualization: 'bar-horizontal' },
      { reportId: 'student_top1', title: 'Top 1% thí sinh', visualization: 'table' },
      { reportId: 'student_top3', title: 'Top 3% thí sinh', visualization: 'table' },
      { reportId: 'student_school_scores', title: 'Kết quả theo trường và bảng', visualization: 'bar-table' },
      { reportId: 'student_utm', title: 'Hiệu quả theo nguồn UTM', visualization: 'table' },
    ],
  },
  'Doanh thu': {
    permission: 'BAO_CAO_DOANH_THU',
    sections: [
      { reportId: 'revenue_summary', title: 'Tổng quan doanh thu', visualization: 'metrics' },
      { reportId: 'payment_funnel', title: 'Phễu thanh toán', visualization: 'funnel' },
      { reportId: 'revenue_by_province', title: 'Doanh thu theo tỉnh/thành', visualization: 'bar-horizontal' },
      { reportId: 'revenue_by_region', title: 'Doanh thu theo 3 miền', visualization: 'bar-horizontal' },
      { reportId: 'revenue_trend', title: 'Xu hướng doanh thu theo ngày', visualization: 'line' },
      { reportId: 'revenue_by_channel', title: 'Doanh thu theo kênh', visualization: 'pie' },
      { reportId: 'revenue_reconciliation', title: 'Giao dịch chờ đối soát quá 48 giờ', visualization: 'table' },
      { reportId: 'transaction_details', title: 'Chi tiết giao dịch', visualization: 'table', requiredPermission: 'BAO_CAO_DOANH_THU_CHI_TIET' },
    ],
  },
  'Học vụ': {
    permission: 'BAO_CAO_HOC_VU',
    sections: [
      { reportId: 'submission_status', title: 'Trạng thái bài nộp', visualization: 'pie' },
      { reportId: 'submission_failures', title: 'Bài tập có tỷ lệ không đạt cao', visualization: 'bar-horizontal' },
      { reportId: 'submission_failures_by_province', title: 'Tỷ lệ không đạt theo tỉnh/thành', visualization: 'bar-horizontal' },
      { reportId: 'contest_rounds', title: 'Các vòng thi', visualization: 'table' },
      { reportId: 'contest_results', title: 'Kết quả vòng sơ loại', visualization: 'table' },
      { reportId: 'contest_top56', title: '56 thí sinh có thứ hạng cao nhất', description: 'Hiển thị thí sinh có kết quả vòng sơ loại đã chấm điểm; nếu chưa đủ 56, hệ thống chưa có đủ bài thi hợp lệ.', visualization: 'bar-horizontal' },
      { reportId: 'contest_finalists', title: 'Danh sách thí sinh chung kết và xác nhận tham gia', visualization: 'table' },
      { reportId: 'submission_details', title: 'Chi tiết bài làm và nhận xét', visualization: 'table' },
      { reportId: 'practice_top15', title: 'Top 15 thí sinh luyện tập', description: 'Xếp hạng theo số bài luyện tập đã nộp hoặc đã chấm trong kỳ; chỉ tính bài được phân loại là luyện tập.', visualization: 'table' },
    ],
  },
  'Đối tác': {
    permission: 'BAO_CAO_DOI_TAC',
    sections: [
      { reportId: 'sponsor_summary', title: 'Tổng quan tài trợ và đối tác', visualization: 'metrics' },
      { reportId: 'sponsor_funnel', title: 'Phễu tài trợ', visualization: 'funnel' },
      { reportId: 'sponsor_tiers', title: 'Cơ cấu cấp tài trợ', visualization: 'pie' },
      { reportId: 'sponsor_list', title: 'Giá trị tài trợ và Brand reach', visualization: 'table' },
      { reportId: 'supplier_list', title: 'Đối soát doanh nghiệp cung cấp thí sinh', visualization: 'table' },
      { reportId: 'sponsor_revenue_by_province', title: 'Doanh thu đối tác theo tỉnh/thành', visualization: 'bar-horizontal' },
      { reportId: 'sponsor_trend', title: 'Xu hướng tài trợ', visualization: 'line' },
      { reportId: 'sponsor_daily_revenue', title: 'Doanh thu và hoa hồng theo ngày', visualization: 'area' },
    ],
  },
  'Hỗ trợ': {
    permission: 'BAO_CAO_HO_TRO',
    sections: [
      { reportId: 'support_by_status', title: 'Hội thoại theo trạng thái', visualization: 'pie' },
      { reportId: 'support_by_entity', title: 'Hội thoại theo nhóm đối tượng', visualization: 'bar' },
      { reportId: 'support_faq_summary', title: 'Hiệu quả bộ câu hỏi FAQ', visualization: 'metrics' },
      { reportId: 'support_faq_categories', title: 'Câu hỏi theo danh mục', visualization: 'bar-horizontal' },
      { reportId: 'support_conversations', title: 'Danh sách hội thoại cần theo dõi', visualization: 'table' },
    ],
  },
  'Bảo mật': {
    permission: 'BAO_CAO_AN_NINH',
    sections: [
      { reportId: 'security_log', title: 'Nhật ký thao tác bảo mật', visualization: 'table' },
      { reportId: 'import_sessions', title: 'Lịch sử các phiên nhập dữ liệu', visualization: 'table' },
      { reportId: 'import_errors', title: 'Chi tiết lỗi nhập dữ liệu', visualization: 'table' },
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
  return `${new Date().getFullYear()}-Q3`
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
    <AdminShell active="KPI & Báo cáo" title="KPI & Báo cáo">
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
  const [exportFormat, setExportFormat] = useState<'excel' | 'word' | 'pdf' | 'csv'>('excel')
  const [exportError, setExportError] = useState('')
  const tabs = Object.keys(reportSections) as ReportTab[]
  const options = useMemo(quarterOptions, [])
  const allowedTabs = tabs.filter((tab) => reportAccess.permissions.includes(reportSections[tab].permission))
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
    student_status: exportRows(results.student_status).map((row) => ({
      ...row,
      trang_thai: String(row.trang_thai ?? '').trim().toLocaleUpperCase('vi') === 'ĐÃ NỘP BÀI'
        ? 'HOÀN THÀNH'
        : row.trang_thai,
    })),
    student_school_scores: exportRows(results.student_school_scores).map((row) =>
      Object.fromEntries(Object.entries(row).filter(([key]) => key.toLowerCase() !== 'ty_le_xuat_sac_pct')),
    ),
    student_utm: exportRows(results.student_utm).map((row) =>
      Object.fromEntries(Object.entries(row).filter(([key]) => key.toLowerCase() !== 'roi_pct')),
    ),
  }), [period, results])
  const registrationTrendRows = exportRows(displayResults.overview_registration_trend)
  const registrationTrendStart = registrationTrendRows[0]?.ngay
  const registrationTrendEnd = registrationTrendRows[registrationTrendRows.length - 1]?.ngay
  const registrationTrendRange = registrationTrendStart && registrationTrendEnd
    ? `${exportCell(registrationTrendStart, 'ngay')} – ${exportCell(registrationTrendEnd, 'ngay')}`
    : ''

  const visibleSections = sections.filter((section) => {
    if (loading || errors[section.reportId]) return true
    const data = displayResults[section.reportId]
    if (data == null) return true
    if (Array.isArray(data)) return data.length > 0
    return typeof data !== 'object' || Object.keys(data).length > 0
  })

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

  function downloadFile(blob: Blob, extension: string) {
    const url = URL.createObjectURL(blob)
    const link = document.createElement('a')
    link.href = url
    link.download = `bao-cao-${period}-${currentReportTab.toLocaleLowerCase('vi').replaceAll(' ', '-')}.${extension}`
    link.click()
    window.setTimeout(() => URL.revokeObjectURL(url), 1000)
  }

  async function exportReport() {
    setExportError('')
    const datasets = reportExportRows(exportFormat === 'excel')
    if (!datasets.length) return

    try {
    if (exportFormat === 'pdf') {
      const printWindow = window.open('', '_blank', 'width=1000,height=800')
      if (!printWindow) {
        setExportError('Trình duyệt đang chặn cửa sổ in. Hãy cho phép cửa sổ bật lên để lưu PDF.')
        return
      }
      printWindow.opener = null
      const reportHtml = datasets.map(({ title, rows }) => {
        const columns = Array.from(new Set(rows.flatMap((row) => Object.keys(row))))
        return `<section><h2>${htmlEscape(title)}</h2><table><thead><tr>${columns.map((column) => `<th>${htmlEscape(formatFieldLabel(column))}</th>`).join('')}</tr></thead><tbody>${rows.map((row) => `<tr>${columns.map((column) => `<td>${htmlEscape(exportCell(row[column], column))}</td>`).join('')}</tr>`).join('')}</tbody></table></section>`
      }).join('')
      printWindow.document.write(`<!doctype html>
<html lang="vi">
  <head>
    <meta charset="utf-8">
    <title>Báo cáo ${htmlEscape(currentReportTab)} ${htmlEscape(period)}</title>
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
    <h1>Báo cáo ${htmlEscape(currentReportTab)}</h1>
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

    if (exportFormat === 'csv') {
      const lines: string[] = []
      for (const { title, rows } of datasets) {
        const columns = Array.from(new Set(rows.flatMap((row) => Object.keys(row))))
        lines.push(csvCell(title), columns.map((column) => csvCell(formatFieldLabel(column))).join(','))
        for (const row of rows) lines.push(columns.map((column) => csvCell(row[column], column)).join(','))
        lines.push('')
      }
      downloadFile(new Blob([`\uFEFF${lines.join('\r\n')}`], { type: 'text/csv;charset=utf-8' }), 'csv')
      return
    }

    if (exportFormat === 'excel') {
      const excelDatasets = datasets.filter(({ reportId }) =>
        !['overview_comparison', 'student_top1', 'student_top3', 'contest_finalists', 'practice_top15'].includes(reportId),
      )
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
      excelDatasets.forEach(({ reportId, title, rows, visualization, hasData, emptyColumns, emptyMessage }, datasetIndex) => {
        const sheetIndex = datasetIndex
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
      })
      const workbookOutput = XLSX.write(workbook, { bookType: 'xlsx', type: 'array', compression: true }) as ArrayBuffer
      const output = addExcelCharts(workbookOutput, chartSources)
      downloadFile(new Blob([output], { type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet' }), 'xlsx')
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
    for (const { title, rows } of datasets) {
      const columns = Array.from(new Set(rows.flatMap((row) => Object.keys(row))))
      children.push(new Paragraph({
        heading: HeadingLevel.HEADING_1,
        keepNext: true,
        spacing: { before: 240, after: 100 },
        children: [new TextRun({ text: title, bold: true, color: '1D5FA7', font: 'Arial', size: 36 })],
      }))
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
    downloadFile(wordFile, 'docx')
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
      const responses = await Promise.all(
        sections.map(async (section) => {
          const response = section.reportId === 'revenue_by_region'
            ? await supabase.rpc('fn_report_revenue_by_region', { p_ky: period })
            : section.reportId === 'practice_top15'
              ? await supabase.rpc('fn_report_practice_top15', { p_ky: period })
              : section.reportId === 'lead_pipeline'
                ? await supabase.rpc('fn_report_lead_pipeline', { p_ky: period })
                : section.reportId === 'overview_registration_trend'
                  ? await supabase.rpc('fn_report_registration_peak_trend', { p_ky: period })
                : await supabase.rpc('fn_bao_cao_du_lieu', {
                  p_ma_bao_cao: section.reportId,
                  p_ky: period,
                })
          return { reportId: section.reportId, data: response.data, error: response.error }
        }),
      )
      if (!active) return
      const nextResults: Record<string, unknown> = {}
      const nextErrors: Record<string, string> = {}
      for (const response of responses) {
        if (response.error) nextErrors[response.reportId] = `Không tải được dữ liệu: ${response.error.message}`
        else nextResults[response.reportId] = response.data
      }

      setResults((current) => ({ ...current, ...nextResults }))
      setErrors(nextErrors)
      setLoading(false)
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
          <button
            onClick={() => setRequestNumber((number) => number + 1)}
            className="flex h-10 items-center gap-2 rounded-xl border border-slate-200 bg-white px-3 text-sm font-semibold text-slate-700 shadow-sm hover:bg-slate-50"
          >
            <RefreshCw size={14} /> Làm mới
          </button>
          <button
            onClick={exportReport}
            disabled={!sections.some((section) => displayResults[section.reportId] != null)}
            className="flex h-10 items-center gap-2 rounded-r-xl bg-blue-600 px-3.5 text-sm font-semibold text-white shadow-md shadow-blue-200 hover:bg-blue-700 disabled:opacity-50"
          >
            {exportFormat === 'excel' && <FileSpreadsheet size={14} />}
            {exportFormat === 'word' && <FileText size={14} />}
            {exportFormat === 'pdf' && <Printer size={14} />}
            {exportFormat === 'csv' && <Download size={14} />}
            Xuất
          </button>
          <label className="sr-only" htmlFor="report-export-format">Định dạng xuất báo cáo</label>
          <select
            id="report-export-format"
            value={exportFormat}
            onChange={(event) => setExportFormat(event.target.value as typeof exportFormat)}
            className="order-[-1] h-10 rounded-l-xl border border-slate-200 bg-white px-3 text-sm font-medium text-slate-700 sm:order-none"
          >
            <option value="excel">Excel</option>
            <option value="word">Word</option>
            <option value="pdf">PDF</option>
            <option value="csv">CSV</option>
          </select>
        </div>
      </div>

      {exportError && (
        <p role="alert" className="mb-4 rounded-xl border border-rose-200 bg-rose-50 px-4 py-3 text-xs text-rose-700">
          Xuất file không thành công: {exportError}
        </p>
      )}

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
              {tab}
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
          <div key={`${period}-${section.reportId}`} className="w-full">
            <DataPanel
              title={section.title}
              description={section.reportId === 'overview_registration_trend'
                ? `16 ngày liên tiếp có tổng lượt đăng ký cao nhất trong kỳ.${registrationTrendRange ? ` Khoảng: ${registrationTrendRange}.` : ''}`
                : section.description}
              data={displayResults[section.reportId]}
              loading={loading && !displayResults[section.reportId]}
              error={errors[section.reportId]}
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
