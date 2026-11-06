'use client'

import { useEffect, useMemo, useState } from 'react'
import { BarChart3, CalendarDays, Download, RefreshCw } from 'lucide-react'
import { AdminShell } from '@/components/admin-shell'
import { DataPanel, type Visualization } from '@/components/data-panel'
import { getSupabaseBrowserClient } from '@/lib/supabase-browser'

type ReportTab = 'Tổng quan' | 'Thí sinh' | 'Tài trợ' | 'Doanh thu'
type SectionDefinition = {
  rpc: string
  title: string
  description?: string
  visualization: Visualization
  acceptsPeriod?: boolean
}

const reportSections: Record<ReportTab, SectionDefinition[]> = {
  'Tổng quan': [
    { rpc: 'fn_kpi_tongquan_chiso', title: 'Chỉ số tổng quan', description: 'Thí sinh tham gia, thực thu tài trợ, doanh thu lệ phí và tổng thu.', visualization: 'metrics' },
    { rpc: 'fn_kpi_tongquan_tin_hieu', title: 'Tín hiệu cảnh báo', description: 'Các điểm cần chú ý trong kỳ báo cáo.', visualization: 'table' },
    { rpc: 'fn_kpi_tongquan_tien_do', title: 'Tiến độ so với mục tiêu', description: 'Mức độ hoàn thành mục tiêu theo kỳ.', visualization: 'bar' },
  ],
  'Thí sinh': [
    { rpc: 'fn_kpi_thisinh_tong_quan', title: 'Tổng quan thí sinh', visualization: 'metrics' },
    { rpc: 'fn_kpi_thisinh_pheu', title: 'Phễu thí sinh', description: 'Tiếp cận → Đăng ký → Tham gia → Hoàn thành.', visualization: 'funnel' },
    { rpc: 'fn_kpi_thisinh_theo_truong', title: 'Thí sinh theo trường', visualization: 'bar-table' },
    { rpc: 'fn_kpi_thisinh_top1pct', title: 'Top 1% xuất sắc', visualization: 'table' },
    { rpc: 'fn_kpi_thisinh_utm_roi', title: 'ROI theo UTM', visualization: 'table' },
    { rpc: 'fn_kpi_thisinh_pho_diem', title: 'Phổ điểm', description: 'Phân bố điểm theo các khoảng 0–20%, 20–40%…', visualization: 'bar' },
    { rpc: 'fn_kpi_thisinh_truong_bang', title: 'Tỷ lệ xuất sắc theo trường', visualization: 'table' },
  ],
  'Tài trợ': [
    { rpc: 'fn_kpi_taitro_tong_quan', title: 'Tổng quan tài trợ', visualization: 'metrics' },
    { rpc: 'fn_kpi_taitro_pheu', title: 'Phễu tài trợ', description: 'Tiến độ qua 5 giai đoạn tài trợ.', visualization: 'funnel' },
    { rpc: 'fn_kpi_taitro_co_cau_cap', title: 'Cơ cấu cấp tài trợ', visualization: 'pie', acceptsPeriod: false },
    { rpc: 'fn_kpi_taitro_nha_tai_tro', title: 'Nhà tài trợ', visualization: 'table' },
    { rpc: 'fn_kpi_taitro_ds_doi_tac', title: 'Đối tác cung cấp', visualization: 'table' },
    { rpc: 'fn_kpi_taitro_doanh_thu_tinh', title: 'Doanh thu theo tỉnh', visualization: 'bar' },
    { rpc: 'fn_kpi_taitro_xu_huong', title: 'Xu hướng tài trợ', visualization: 'line' },
    { rpc: 'fn_kpi_taitro_doanh_thu_ngay', title: 'Doanh thu tài trợ theo ngày', visualization: 'line' },
  ],
  'Doanh thu': [
    { rpc: 'fn_kpi_doanhthu_tong_quan', title: 'Tổng quan doanh thu', visualization: 'metrics' },
    { rpc: 'fn_kpi_doanhthu_pheu', title: 'Phễu thanh toán', visualization: 'funnel' },
    { rpc: 'fn_kpi_doanhthu_theo_khu_vuc', title: 'Doanh thu theo khu vực', visualization: 'bar' },
    { rpc: 'fn_kpi_doanhthu_xu_huong', title: 'Xu hướng doanh thu theo ngày', visualization: 'line' },
    { rpc: 'fn_kpi_doanhthu_cho_doi_soat_48h', title: 'Chờ đối soát trong 48 giờ', description: 'Danh sách cần xử lý gấp.', visualization: 'table' },
    { rpc: 'fn_kpi_doanhthu_theo_kenh', title: 'Doanh thu theo kênh', visualization: 'bar' },
    { rpc: 'fn_kpi_doanhthu_chi_tiet', title: 'Chi tiết giao dịch', visualization: 'table' },
  ],
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

function csvCell(value: unknown): string {
  const text = value == null
    ? ''
    : typeof value === 'object'
      ? JSON.stringify(value)
      : String(value)
  return `"${text.replaceAll('"', '""')}"`
}

export default function ReportPage() {
  const supabase = useMemo(() => getSupabaseBrowserClient(), [])
  const [activeTab, setActiveTab] = useState<ReportTab>('Tổng quan')
  const [period, setPeriod] = useState('2026-Q3')
  const [results, setResults] = useState<Record<string, unknown>>({})
  const [errors, setErrors] = useState<Record<string, string>>({})
  const [loading, setLoading] = useState(false)
  const [requestNumber, setRequestNumber] = useState(0)
  const tabs = Object.keys(reportSections) as ReportTab[]
  const options = useMemo(quarterOptions, [])
  const sections = reportSections[activeTab]
  const visibleSections = sections.filter((section) => {
    if (loading || errors[section.rpc]) return true
    const data = results[section.rpc]
    if (data == null) return true
    if (Array.isArray(data)) return data.length > 0
    return typeof data !== 'object' || Object.keys(data).length > 0
  })

  function exportReport() {
    const lines: string[] = []
    for (const section of sections) {
      const data = results[section.rpc]
      if (data == null) continue
      const rows = Array.isArray(data)
        ? data.filter((row): row is Record<string, unknown> => typeof row === 'object' && row !== null)
        : typeof data === 'object'
          ? [data as Record<string, unknown>]
          : [{ Giá_trị: data }]
      if (rows.length === 0) continue
      const columns = Array.from(new Set(rows.flatMap((row) => Object.keys(row))))
      lines.push(csvCell(section.title), columns.map(csvCell).join(','))
      for (const row of rows) lines.push(columns.map((column) => csvCell(row[column])).join(','))
      lines.push('')
    }
    if (!lines.length) return
    const blob = new Blob([`\uFEFF${lines.join('\r\n')}`], { type: 'text/csv;charset=utf-8' })
    const url = URL.createObjectURL(blob)
    const link = document.createElement('a')
    link.href = url
    link.download = `bao-cao-${period}-${activeTab.toLocaleLowerCase('vi').replaceAll(' ', '-')}.csv`
    link.click()
    URL.revokeObjectURL(url)
  }

  useEffect(() => {
    let active = true
    async function loadReport() {
      if (!supabase) {
        setErrors(Object.fromEntries(sections.map((section) => [section.rpc, 'Thiếu cấu hình Supabase. Khai báo NEXT_PUBLIC_SUPABASE_URL và NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY.'])))
        setLoading(false)
        return
      }
      setLoading(true)
      setErrors({})
      setResults((current) => {
        const next = { ...current }
        for (const section of sections) delete next[section.rpc]
        return next
      })
      const responses = await Promise.all(
        sections.map(async (section) => {
          const { data, error } = await supabase.rpc(
            section.rpc,
            section.acceptsPeriod === false ? {} : { p_ky: period },
          )
          return { rpc: section.rpc, data, error }
        }),
      )
      if (!active) return
      const nextResults: Record<string, unknown> = {}
      const nextErrors: Record<string, string> = {}
      for (const response of responses) {
        if (response.error) nextErrors[response.rpc] = `Không tải được dữ liệu: ${response.error.message}`
        else nextResults[response.rpc] = response.data
      }
      setResults((current) => ({ ...current, ...nextResults }))
      setErrors(nextErrors)
      setLoading(false)
    }
    void loadReport()
    return () => { active = false }
  }, [period, requestNumber, sections, supabase])

  return (
    <AdminShell active="KPI & Báo cáo" title="KPI & Báo cáo">
      <div className="mb-6 flex flex-wrap items-end justify-between gap-4">
        <div>
          <p className="text-sm text-slate-500">Theo dõi hiệu quả vận hành, thí sinh, tài trợ và doanh thu.</p>
        </div>
        <div className="flex flex-wrap items-center gap-2">
          <label className="relative flex h-10 items-center gap-2 rounded-xl border border-slate-200 bg-white px-3 shadow-sm">
            <CalendarDays size={15} className="text-indigo-500" />
            <span className="text-xs font-medium text-slate-500">Kỳ báo cáo</span>
            <select
              value={period}
              onChange={(event) => setPeriod(event.target.value)}
              className="appearance-none bg-transparent pr-1 text-xs font-semibold text-slate-800 outline-none"
              aria-label="Kỳ báo cáo"
            >
              {options.map((option) => <option key={option} value={option}>{option}</option>)}
              {!options.includes(period) && <option value={period}>{period}</option>}
            </select>
          </label>
          <button
            onClick={() => setRequestNumber((number) => number + 1)}
            className="flex h-10 items-center gap-2 rounded-xl border border-slate-200 bg-white px-3 text-xs font-semibold text-slate-600 shadow-sm hover:bg-slate-50"
          >
            <RefreshCw size={14} /> Làm mới
          </button>
          <button
            onClick={exportReport}
            disabled={!sections.some((section) => results[section.rpc] != null)}
            className="flex h-10 items-center gap-2 rounded-xl bg-indigo-600 px-3.5 text-xs font-semibold text-white shadow-md shadow-indigo-200 hover:bg-indigo-700"
          >
            <Download size={14} /> Xuất báo cáo
          </button>
        </div>
      </div>

      <div className="mb-5 overflow-x-auto border-b border-slate-200">
        <div className="flex min-w-max gap-1">
          {tabs.map((tab) => (
            <button
              key={tab}
              onClick={() => setActiveTab(tab)}
              className={`flex items-center gap-2 border-b-2 px-4 py-3 text-xs font-semibold transition ${
                activeTab === tab
                  ? 'border-indigo-600 text-indigo-700'
                  : 'border-transparent text-slate-500 hover:text-slate-800'
              }`}
            >
              {tab === 'Tổng quan' && <BarChart3 size={15} />}
              {tab}
            </button>
          ))}
        </div>
      </div>

      <div className="mb-4 flex items-center justify-between">
        <p className="text-xs text-slate-500">Dữ liệu kỳ <span className="font-semibold text-slate-800">{period}</span></p>
        {loading && <span className="text-[11px] text-slate-400">Đang đồng bộ dữ liệu…</span>}
      </div>

      <div className="grid items-start gap-4 xl:grid-cols-2">
        {visibleSections.map((section) => (
          <DataPanel
            key={`${period}-${section.rpc}`}
            title={section.title}
            description={section.description}
            data={results[section.rpc]}
            loading={loading && !results[section.rpc]}
            error={errors[section.rpc]}
            visualization={section.visualization}
          />
        ))}
        {!loading && visibleSections.length === 0 && (
          <p className="col-span-full rounded-xl bg-slate-50 p-6 text-center text-sm text-slate-500">
            Kỳ báo cáo này chưa có dữ liệu.
          </p>
        )}
      </div>
    </AdminShell>
  )
}
