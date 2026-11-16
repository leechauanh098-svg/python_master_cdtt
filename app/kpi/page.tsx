'use client'

import Link from 'next/link'
import { useCallback, useEffect, useMemo, useState } from 'react'
import { AdminShell } from '@/components/admin-shell'
import { useReportAccess } from '@/components/report-access'
import { getSupabaseBrowserClient } from '@/lib/supabase-browser'

const GROUPS = ['BTC', 'Nhân viên hỗ trợ', 'Giám khảo', 'Trường', 'Doanh nghiệp', 'Nhà tài trợ'] as const
const TABS = ['Tổng quan', 'BTC', 'Nhân viên', 'Giám khảo', 'Trường', 'Doanh nghiệp', 'Nhà tài trợ'] as const
const STATUSES = ['Đạt', 'Đúng tiến độ', 'Chưa đạt'] as const
const SUMMARY_STATUSES = ['Đạt', 'Đúng tiến độ', 'Chưa đạt'] as const
type KpiStatus = (typeof STATUSES)[number]
type KpiTab = (typeof TABS)[number]
type StatusFilter = KpiStatus | 'Tất cả'
type KpiReadiness = {
  kpi_id: string
  nhom: string
  ten_kpi: string
  ly_do: string
}

type RawKpi = {
  kpi_id?: string | null
  nhom?: string | null
  ten_kpi?: string | null
  muc_tieu?: number | string | null
  gia_tri_hien_tai?: number | string | null
  hoan_thanh_pct?: number | string | null
  don_vi?: string | null
  huong?: string | null
  han_chot?: string | null
  chu_the?: string | null
}

type KpiRow = RawKpi & {
  kpi_id: string
  nhom: string
  ten_kpi: string
  muc_tieu: number | null
  gia_tri_hien_tai: number | null
  hoan_thanh_pct: number | null
  status: KpiStatus
  group: (typeof GROUPS)[number]
  unit: string
}

const STATUS_STYLE: Record<KpiStatus, string> = {
  'Đạt': 'bg-emerald-50 text-emerald-700 ring-1 ring-emerald-200',
  'Đúng tiến độ': 'bg-blue-50 text-blue-700 ring-1 ring-blue-200',
  'Chưa đạt': 'bg-rose-50 text-rose-700 ring-1 ring-rose-200',
}

function vietnamCalendarDate(): Date {
  return new Date(Date.now() + 7 * 60 * 60 * 1000)
}

function localDateKey(date: Date): string {
  return `${date.getUTCFullYear()}-${String(date.getUTCMonth() + 1).padStart(2, '0')}-${String(date.getUTCDate()).padStart(2, '0')}`
}

function defaultKpiPeriod(): string {
  const now = vietnamCalendarDate()
  return `${now.getUTCFullYear()}-Q${Math.floor(now.getUTCMonth() / 3) + 1}`
}

function getErrorMessage(error: unknown): string {
  if (error instanceof Error) return error.message
  if (typeof error === 'string') return error
  if (typeof error === 'object' && error !== null && 'message' in error && typeof error.message === 'string') {
    return error.message
  }
  return 'Đã xảy ra lỗi khi tải dữ liệu KPI.'
}

function getQuarterDates(period: string): { start: Date; end: Date } | null {
  const match = /^(\d{4})-Q([1-4])$/.exec(period)
  if (!match) return null
  const year = Number(match[1])
  const quarter = Number(match[2])
  return {
    start: new Date(Date.UTC(year, (quarter - 1) * 3, 1)),
    end: new Date(Date.UTC(year, quarter * 3, 1)),
  }
}

function periodOptions(): string[] {
  const current = vietnamCalendarDate()
  return Array.from({ length: 12 }, (_, index) => {
    const date = new Date(Date.UTC(current.getUTCFullYear(), current.getUTCMonth() - index * 3, 1))
    return `${date.getUTCFullYear()}-Q${Math.floor(date.getUTCMonth() / 3) + 1}`
  }).filter((value, index, values) => values.indexOf(value) === index)
}

function formatDate(value: Date | string): string {
  const date = value instanceof Date ? value : new Date(value)
  if (Number.isNaN(date.getTime())) return '—'
  return new Intl.DateTimeFormat('vi-VN', {
    timeZone: 'Asia/Ho_Chi_Minh',
    day: '2-digit',
    month: '2-digit',
    year: 'numeric',
  }).format(date)
}

function formatPeriod(period: string): string {
  const dates = getQuarterDates(period)
  if (!dates) return period
  const end = new Date(dates.end.getTime() - 24 * 60 * 60 * 1000)
  return `${formatDate(dates.start)} – ${formatDate(end)}`
}

function formatDateTime(value: Date | string): string {
  const date = value instanceof Date ? value : new Date(value)
  if (Number.isNaN(date.getTime())) return '—'
  return new Intl.DateTimeFormat('vi-VN', {
    timeZone: 'Asia/Ho_Chi_Minh',
    hour: '2-digit',
    minute: '2-digit',
    day: '2-digit',
    month: '2-digit',
    year: 'numeric',
  }).format(date)
}

function parseNumber(value: unknown): number | null {
  if (value === null || value === undefined || value === '') return null
  const result = Number(value)
  return Number.isFinite(result) ? result : null
}

function formatValue(value: number | null, unit: string): string {
  if (value === null) return '—'
  if (unit.toLocaleLowerCase('vi') === 'vnd' || unit.toLocaleLowerCase('vi') === 'vnđ' || unit === '₫') {
    return `${new Intl.NumberFormat('vi-VN', { maximumFractionDigits: 0 }).format(value)} VNĐ`
  }
  return `${new Intl.NumberFormat('vi-VN', { maximumFractionDigits: 2 }).format(value)}${unit ? ` ${unit}` : ''}`
}

function unwrapRpcRows(value: unknown): Record<string, unknown>[] {
  if (!Array.isArray(value)) return []
  return value.flatMap((item) => {
    if (!item || typeof item !== 'object') return []
    const record = item as Record<string, unknown>
    const unwrapped = record.row_data
    return unwrapped && typeof unwrapped === 'object' && !Array.isArray(unwrapped)
      ? [unwrapped as Record<string, unknown>]
      : [record]
  })
}

function groupForKpi(raw: RawKpi): (typeof GROUPS)[number] {
  const code = String(raw.kpi_id ?? '').toUpperCase()
  const group = String(raw.nhom ?? '').toUpperCase()
  if (group === 'THI_SINH' || group === 'DOANH_THU') return 'BTC'
  if (group === 'DOANH_NGHIEP' || code.startsWith('KPI_DN')) return 'Doanh nghiệp'
  if (code.startsWith('KPI_HT') || group.includes('HO_TRO')) return 'Nhân viên hỗ trợ'
  if (code.startsWith('KPI_GK') || group.includes('GIAM_KHAO')) return 'Giám khảo'
  if (code.startsWith('KPI_TR') || group.includes('TRUONG')) return 'Trường'
  if (code.startsWith('KPI_TT') || group.includes('TAI_TRO')) return 'Nhà tài trợ'
  return 'BTC'
}

function progressPercent(target: number, current: number, direction: string): number {
  const lowerIsBetter = /thap|lower|low/i.test(direction)
  if (lowerIsBetter) {
    if (current <= target) return current === 0 ? 150 : (target / current) * 100
    return (target / current) * 100
  }
  return (current / target) * 100
}

function statusFor(
  completion: number,
  dueDate: string | null | undefined,
  period: string,
  periodClosed: boolean,
): KpiStatus {
  if (completion >= 100) return 'Đạt'
  if (periodClosed) return 'Chưa đạt'
  const today = vietnamCalendarDate()
  if (dueDate && dueDate.slice(0, 10) < localDateKey(today)) return 'Chưa đạt'
  const dates = getQuarterDates(period)
  if (!dates) return 'Chưa đạt'
  const todayStart = Date.UTC(today.getUTCFullYear(), today.getUTCMonth(), today.getUTCDate())
  if (todayStart < dates.start.getTime()) return 'Đúng tiến độ'
  const totalDays = Math.max(1, (dates.end.getTime() - dates.start.getTime()) / 86400000)
  const elapsedDays = Math.min(totalDays, Math.floor((todayStart - dates.start.getTime()) / 86400000) + 1)
  return completion >= elapsedDays * 100 / totalDays ? 'Đúng tiến độ' : 'Chưa đạt'
}

function getTabGroup(tab: KpiTab): (typeof GROUPS)[number] | null {
  if (tab === 'Nhân viên') return 'Nhân viên hỗ trợ'
  return tab === 'Tổng quan' ? null : tab
}

function statusRank(status: KpiStatus): number {
  return { 'Chưa đạt': 0, 'Đúng tiến độ': 1, 'Đạt': 2 }[status]
}

function matchesStatus(row: KpiRow, filter: StatusFilter): boolean {
  return filter === 'Tất cả' || row.status === filter
}

export default function KpiPage() {
  const supabase = useMemo(() => getSupabaseBrowserClient(), [])
  const access = useReportAccess()
  const [period, setPeriod] = useState(defaultKpiPeriod)
  const [activeTab, setActiveTab] = useState<KpiTab>('Tổng quan')
  const [statusFilter, setStatusFilter] = useState<StatusFilter>('Tất cả')
  const [rows, setRows] = useState<KpiRow[]>([])
  const [readiness, setReadiness] = useState<KpiReadiness[]>([])
  const [lastUpdated, setLastUpdated] = useState<Date | null>(null)
  const [periodClosed, setPeriodClosed] = useState(false)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')
  const [loadWarnings, setLoadWarnings] = useState<string[]>([])
  const [refreshKey, setRefreshKey] = useState(0)
  const [selectedId, setSelectedId] = useState<string | null>(null)

  const loadData = useCallback(async () => {
    if (!supabase) {
      setError('Không thể kết nối nguồn dữ liệu KPI. Vui lòng kiểm tra cấu hình hệ thống.')
      setLoading(false)
      return
    }

    setLoading(true)
    setError('')
    setLoadWarnings([])
    try {
      const [progressCall, snapshotProgressCall, periodStatusCall, readinessCall] = await Promise.allSettled([
        supabase.rpc('fn_admin_module_data', { p_resource: 'kpi_progress', p_ky: period, p_limit: 200 }),
        supabase.rpc('fn_kpi_dashboard_snapshot_progress', { p_period: period }),
        supabase.rpc('fn_kpi_dashboard_period_status', { p_period: period }),
        supabase.rpc('fn_kpi_dashboard_readiness', { p_period: period }),
      ])
      if (progressCall.status === 'rejected') throw progressCall.reason
      if (progressCall.value.error) throw progressCall.value.error

      const warnings: string[] = []
      const snapshotProgressResult = snapshotProgressCall.status === 'fulfilled'
        ? snapshotProgressCall.value
        : null
      if (!snapshotProgressResult || snapshotProgressResult.error) {
        warnings.push(`Không tải được KPI mở rộng: ${snapshotProgressResult?.error?.message ?? String(snapshotProgressCall.status === 'rejected' ? snapshotProgressCall.reason : '')}`)
      }

      let nextPeriodClosed = false
      const periodStatusResult = periodStatusCall.status === 'fulfilled' ? periodStatusCall.value : null
      if (!periodStatusResult || periodStatusResult.error) {
        warnings.push(`Không xác định được trạng thái chốt kỳ: ${periodStatusResult?.error?.message ?? String(periodStatusCall.status === 'rejected' ? periodStatusCall.reason : '')}`)
      } else {
        const periodStatus = String(unwrapRpcRows(periodStatusResult.data)[0]?.period_status ?? '').toUpperCase()
        nextPeriodClosed = periodStatus === 'FINALIZED'
      }
      setPeriodClosed(nextPeriodClosed)

      const readinessResult = readinessCall.status === 'fulfilled' ? readinessCall.value : null
      if (!readinessResult || readinessResult.error) {
        setReadiness([])
        const readinessError = readinessResult?.error
        const readinessMessage = readinessError?.code === 'PGRST202'
          ? 'Supabase chưa nhận diện RPC fn_kpi_dashboard_readiness. Hãy áp dụng migration 20261116000600_kpi_source_aggregation.sql và tải lại schema cache.'
          : readinessError?.message ?? String(readinessCall.status === 'rejected' ? readinessCall.reason : '')
        warnings.push(`Không tải được tình trạng cấu hình KPI: ${readinessMessage}`)
      } else {
        setReadiness(unwrapRpcRows(readinessResult.data).flatMap((record): KpiReadiness[] => {
          if (
            typeof record.kpi_id !== 'string'
            || typeof record.nhom !== 'string'
            || typeof record.ten_kpi !== 'string'
            || typeof record.ly_do !== 'string'
          ) return []
          return [{ kpi_id: record.kpi_id, nhom: record.nhom, ten_kpi: record.ten_kpi, ly_do: record.ly_do }]
        }))
      }
      setLoadWarnings(warnings)

      const invalidIds: string[] = []
      const progressRecords = [
        ...unwrapRpcRows(progressCall.value.data),
        ...(snapshotProgressResult && !snapshotProgressResult.error
          ? unwrapRpcRows(snapshotProgressResult.data)
          : []),
      ]
      const nextRows = progressRecords.flatMap((record): KpiRow[] => {
        const raw = record as RawKpi
        const id = typeof raw.kpi_id === 'string' ? raw.kpi_id.trim() : ''
        if (!/^KPI_(TS|DT|DN\d*|HT\d*|GK\d*|TR\d*|TT\d*)(_[A-Z0-9]+)*$/i.test(id)) {
          invalidIds.push(id || '(trống)')
          return []
        }

        const target = parseNumber(raw.muc_tieu)
        const current = parseNumber(raw.gia_tri_hien_tai)
        if (target === null || target <= 0 || current === null) return []
        const direction = String(raw.huong ?? 'CAO')
        const completion = progressPercent(target, current, direction)
        const status = statusFor(completion, raw.han_chot, period, nextPeriodClosed)
        const sourceGroup = String(raw.nhom ?? '')
        const unit = String(raw.don_vi ?? (
          sourceGroup === 'DOANH_THU' ? 'VNĐ' : sourceGroup === 'THI_SINH' ? 'thí sinh' : sourceGroup === 'DOANH_NGHIEP' ? 'doanh nghiệp' : ''
        ))
        return [{
          ...raw,
          kpi_id: id,
          nhom: sourceGroup,
          ten_kpi: typeof raw.ten_kpi === 'string' && raw.ten_kpi.trim() ? raw.ten_kpi : id,
          muc_tieu: target,
          gia_tri_hien_tai: current,
          hoan_thanh_pct: completion,
          status,
          group: groupForKpi(raw),
          unit,
        }]
      })

      if (invalidIds.length) console.error('Đã bỏ qua KPI có mã không hợp lệ:', invalidIds)
      nextRows.sort((left, right) => statusRank(left.status) - statusRank(right.status))
      setRows(nextRows)
      setLastUpdated(new Date())
      setSelectedId((previous) => nextRows.some((row) => row.kpi_id === previous) ? previous : nextRows[0]?.kpi_id ?? null)
    } catch (loadError) {
      setRows([])
      setReadiness([])
      setError(getErrorMessage(loadError))
    } finally {
      setLoading(false)
    }
  }, [period, supabase])

  useEffect(() => { void loadData() }, [loadData, refreshKey])

  const visibleTabs = useMemo(() => {
    if (access.roleIds.includes('ADMIN') || access.roleIds.includes('MANAGER')) return TABS
    const result: KpiTab[] = ['Tổng quan']
    if (access.roleIds.includes('SUPPORT_STAFF')) result.push('Nhân viên')
    if (access.roleIds.includes('JUDGE')) result.push('Giám khảo')
    if (access.roleIds.includes('SALE_STAFF')) result.push('Doanh nghiệp')
    return result
  }, [access.roleIds])

  useEffect(() => {
    if (!visibleTabs.includes(activeTab)) setActiveTab(visibleTabs[0] ?? 'Tổng quan')
  }, [activeTab, visibleTabs])

  const selectedRow = rows.find((row) => row.kpi_id === selectedId) ?? null
  const filteredRows = useMemo(() => rows.filter((row) => {
    const group = getTabGroup(activeTab)
    return (!group || row.group === group) && matchesStatus(row, statusFilter)
  }), [activeTab, rows, statusFilter])

  const statusCounts = useMemo(() => {
    const counts: Record<(typeof SUMMARY_STATUSES)[number], number> = {
      'Đạt': 0,
      'Đúng tiến độ': 0,
      'Chưa đạt': 0,
    }
    for (const row of rows) {
      counts[row.status] += 1
    }
    return counts
  }, [rows])

  const groupSummaries = useMemo(() => GROUPS.map((group) => {
    const groupRows = rows.filter((row) => row.group === group)
    const visibleRows = groupRows.filter((row) => matchesStatus(row, statusFilter))
    const featured = [...visibleRows]
      .sort((left, right) => left.ten_kpi.localeCompare(right.ten_kpi, 'vi'))
      .slice(0, 3)
    return { group, rows: groupRows, visibleRows, featured }
  }).filter(({ rows: groupRows }) => groupRows.length > 0)
    .sort((left, right) => Number(right.rows.length > 0) - Number(left.rows.length > 0)), [rows, statusFilter])

  const visibleGroupSummaries = useMemo(
    () => statusFilter === 'Tất cả'
      ? groupSummaries
      : groupSummaries.filter(({ visibleRows }) => visibleRows.length > 0),
    [groupSummaries, statusFilter],
  )

  const adminUser = access.roleIds.includes('ADMIN')
  const tabGroup = getTabGroup(activeTab)

  return (
    <AdminShell active="KPI" title="KPI">
      <div className="mb-6 flex flex-wrap items-end justify-between gap-4">
        <div>
          <h2 className="text-2xl font-bold text-slate-900">KPI – Theo dõi mục tiêu và tiến độ</h2>
        </div>
        <div className="flex max-w-full flex-wrap items-center gap-2">
          <label className="flex h-10 items-center gap-2 rounded-xl border border-slate-200 bg-white px-3 shadow-sm">
            <span className="text-sm font-medium text-slate-600">Kỳ KPI</span>
            <select
              value={period}
              onChange={(event) => setPeriod(event.target.value)}
              className="appearance-none bg-transparent pr-1 text-sm font-semibold text-slate-800 outline-none"
              aria-label="Chọn kỳ KPI"
            >
              {periodOptions().map((option) => <option key={option} value={option}>{option}</option>)}
            </select>
          </label>
          <div className="flex h-10 items-center gap-2 rounded-xl border border-slate-200 bg-white px-3 text-xs text-slate-600">
            <span>{formatPeriod(period)}</span>
            {periodClosed && <span className="rounded-full bg-emerald-50 px-2 py-1 font-semibold text-emerald-700">Đã chốt</span>}
          </div>
          <div className="flex h-10 items-center gap-2 rounded-xl border border-slate-200 bg-white px-3 text-[11px] text-slate-500">
            {loading ? 'Đang tải dữ liệu…' : lastUpdated ? `Tải xong lúc ${formatDateTime(lastUpdated)}` : 'Chưa tải dữ liệu'}
          </div>
          <button
            type="button"
            onClick={() => setRefreshKey((value) => value + 1)}
            disabled={loading}
            className="flex h-10 items-center rounded-xl border border-slate-200 bg-white px-3 text-sm font-semibold text-slate-700 shadow-sm hover:bg-slate-50 disabled:opacity-60"
          >
            Làm mới
          </button>
          {adminUser && (
            <Link href="/kpi/cai-dat" className="flex h-10 items-center rounded-xl border border-slate-200 bg-white px-3 text-sm font-semibold text-slate-700 shadow-sm hover:bg-slate-50">
              Cài đặt KPI
            </Link>
          )}
          <Link href="/bao-cao" className="flex h-10 items-center rounded-xl bg-blue-600 px-3.5 text-sm font-semibold text-white shadow-md shadow-blue-200 hover:bg-blue-700">
            Mở Báo cáo
          </Link>
        </div>
      </div>

      {error && (
        <div role="alert" className="mb-5 flex flex-wrap items-center justify-between gap-3 rounded-xl border border-rose-200 bg-rose-50 p-4 text-sm text-rose-800">
          <span>{error}</span>
          <button type="button" onClick={() => setRefreshKey((value) => value + 1)} className="rounded-lg border border-rose-300 bg-white px-3 py-2 font-semibold hover:bg-rose-100">
            Thử lại
          </button>
        </div>
      )}
      {loadWarnings.length > 0 && (
        <div role="status" className="mb-5 rounded-xl border border-amber-200 bg-amber-50 p-4 text-sm text-amber-900">
          <p className="font-semibold">Một số dữ liệu phụ trợ chưa tải được:</p>
          <ul className="mt-1 list-inside list-disc space-y-1">
            {loadWarnings.map((warning) => <li key={warning}>{warning}</li>)}
          </ul>
        </div>
      )}

      {activeTab !== 'Tổng quan' && (
        <div className="mb-5 overflow-x-auto border-b border-slate-200">
          <div className="flex min-w-max gap-1" role="tablist" aria-label="Các nhóm KPI">
            {visibleTabs.map((tab) => (
              <button
                key={tab}
                id={`kpi-tab-${tab}`}
                type="button"
                role="tab"
                aria-selected={activeTab === tab}
                aria-controls="kpi-tab-panel"
                onClick={() => { setActiveTab(tab); setStatusFilter('Tất cả') }}
                className={`flex min-h-12 items-center border-b-2 px-4 py-3 text-sm font-semibold transition ${
                  activeTab === tab ? 'border-blue-600 text-blue-700' : 'border-transparent text-slate-600 hover:text-slate-900'
                }`}
              >
                {tab}
              </button>
            ))}
          </div>
        </div>
      )}

      <div id="kpi-tab-panel" role="tabpanel" aria-labelledby={`kpi-tab-${activeTab}`}>
        {activeTab === 'Tổng quan' ? (
          <>
            <section aria-label="Số lượng KPI theo trạng thái" className="mb-6 grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
              <button
                type="button"
                aria-pressed={statusFilter === 'Tất cả'}
                onClick={() => setStatusFilter('Tất cả')}
                className={`flex min-h-[92px] items-center justify-between gap-3 rounded-2xl border bg-white px-5 py-4 text-left shadow-sm transition hover:-translate-y-0.5 hover:shadow-md ${statusFilter === 'Tất cả' ? 'border-blue-500 ring-2 ring-blue-100' : 'border-slate-200'}`}
              >
                <span className="text-sm font-semibold text-slate-700">Tất cả</span>
                <span className="text-2xl font-bold text-slate-900">{loading ? '—' : rows.length}</span>
              </button>
              {SUMMARY_STATUSES.map((status) => {
                const selected = statusFilter === status
                return (
                  <button
                    key={status}
                    type="button"
                    aria-pressed={selected}
                    onClick={() => setStatusFilter(selected ? 'Tất cả' : status)}
                    className={`flex min-h-[92px] items-center justify-between gap-3 rounded-2xl border bg-white px-5 py-4 text-left shadow-sm transition hover:-translate-y-0.5 hover:shadow-md ${selected ? 'border-blue-500 ring-2 ring-blue-100' : 'border-slate-200'}`}
                  >
                    <span className="text-sm font-semibold text-slate-700">{status}</span>
                    <span className="text-2xl font-bold text-slate-900">{loading ? '—' : statusCounts[status]}</span>
                  </button>
                )
              })}
            </section>
            {!loading && adminUser && readiness.length > 0 && (
              <details className="mb-6 rounded-xl border border-slate-200 bg-white">
                <summary className="cursor-pointer px-5 py-4 text-sm font-semibold text-slate-800">
                  KPI chưa hiển thị: {readiness.length} mục cần thiết lập hoặc bổ sung dữ liệu
                </summary>
                <div className="border-t border-slate-100 px-5 py-4">
                  <p className="mb-3 text-sm text-slate-600">
                    KPI thiếu mục tiêu hoặc chưa đủ dữ liệu nguồn trong kỳ được liệt kê riêng, không tính vào điểm nhóm.
                  </p>
                  <ul className="space-y-2">
                    {readiness.map((item) => (
                      <li key={item.kpi_id} className="flex flex-wrap items-baseline justify-between gap-2 text-sm">
                        <span className="font-medium text-slate-800">{item.ten_kpi}</span>
                        <span className="text-slate-600">{item.ly_do}</span>
                      </li>
                    ))}
                  </ul>
                  <Link href="/kpi/cai-dat" className="mt-4 inline-flex min-h-9 items-center text-sm font-semibold text-blue-700 hover:text-blue-900">
                    Thiết lập mục tiêu
                  </Link>
                </div>
              </details>
            )}
            <section aria-label="Tiến độ KPI theo nhóm" className="grid gap-6 md:grid-cols-2 xl:grid-cols-3">
              {visibleGroupSummaries.map(({ group, rows: groupRows, visibleRows, featured }) => {
                const groupTab: KpiTab = group === 'Nhân viên hỗ trợ' ? 'Nhân viên' : group
                return (
                  <article
                    id={`kpi-group-${group}`}
                    key={group}
                    className="flex h-full min-h-[320px] flex-col rounded-2xl border border-slate-200 bg-white p-5 shadow-sm sm:p-6"
                  >
                    <header>
                      <div className="flex flex-wrap items-center justify-between gap-2">
                        <h3 className="text-lg font-bold text-slate-900">{group}</h3>
                      </div>
                    </header>
                    {loading ? (
                      <div className="mt-5 space-y-4" aria-label="Đang tải KPI">
                        <div className="h-7 w-32 animate-pulse rounded bg-slate-100" />
                        <div className="h-16 animate-pulse rounded-xl bg-slate-100" />
                        <div className="h-10 animate-pulse rounded-xl bg-slate-100" />
                      </div>
                    ) : (
                      <>
                        <div className="mt-5 flex-1 space-y-4">
                          {featured.map((row) => (
                              <div key={row.kpi_id} className="rounded-xl border border-slate-200 bg-white p-4">
                                <div className="flex flex-wrap items-start justify-between gap-2">
                                  <p className="min-w-0 flex-1 text-sm font-semibold leading-5 text-slate-800">{row.ten_kpi}</p>
                                  <StatusBadge status={row.status} />
                                </div>
                                <div className="mt-4 grid grid-cols-2 gap-3">
                                  <div className="min-w-0 rounded-lg bg-slate-50 px-3 py-2">
                                    <p className="text-[11px] font-medium text-slate-500">Hiện tại</p>
                                    <p className="mt-1 break-words text-sm font-semibold leading-5 text-slate-900">{formatValue(row.gia_tri_hien_tai, row.unit)}</p>
                                  </div>
                                  <div className="min-w-0 rounded-lg bg-slate-50 px-3 py-2">
                                    <p className="text-[11px] font-medium text-slate-500">Mục tiêu</p>
                                    <p className="mt-1 break-words text-sm font-semibold leading-5 text-slate-900">{formatValue(row.muc_tieu, row.unit)}</p>
                                  </div>
                                </div>
                                <div className="mt-4">
                                  <ProgressBar value={row.hoan_thanh_pct} />
                                </div>
                              </div>
                            ))}
                        </div>
                      </>
                    )}
                    <footer className="mt-4 border-t border-slate-100 pt-3">
                      <button
                        type="button"
                        onClick={() => { setActiveTab(groupTab); setStatusFilter('Tất cả') }}
                        className="inline-flex min-h-10 items-center text-sm font-semibold text-blue-700 hover:text-blue-900"
                      >
                        Xem {visibleRows.length} KPI
                      </button>
                    </footer>
                  </article>
                )
              })}
            </section>
            {!loading && visibleGroupSummaries.length === 0 && (
              <p className="mt-5 rounded-xl border border-slate-200 bg-white px-5 py-4 text-sm text-slate-600">
                {rows.length === 0
                  ? `Chưa có KPI có số liệu từ Supabase trong kỳ ${period}.`
                  : 'Không có KPI phù hợp với trạng thái đã chọn.'}
              </p>
            )}
          </>
        ) : (
          <section aria-label={`KPI ${activeTab}`} className="grid gap-5 xl:grid-cols-[minmax(0,1.5fr)_minmax(320px,0.8fr)]">
            <div className="overflow-hidden rounded-2xl border border-slate-200 bg-white shadow-sm">
              <div className="flex flex-wrap items-center justify-between gap-3 border-b border-slate-200 px-5 py-4">
                <div>
                  <h3 className="text-lg font-bold text-slate-900">KPI {activeTab}</h3>
                  <p className="mt-1 text-sm text-slate-600">{formatPeriod(period)}</p>
                </div>
                <label className="flex items-center gap-2 text-sm text-slate-600">
                  <span>Trạng thái</span>
                  <select value={statusFilter} onChange={(event) => setStatusFilter(event.target.value as StatusFilter)} className="min-h-10 rounded-lg border border-slate-200 bg-white px-2">
                    <option value="Tất cả">Tất cả</option>
                    {STATUSES.map((status) => <option key={status} value={status}>{status}</option>)}
                  </select>
                </label>
              </div>
              {loading ? (
                <div className="space-y-3 p-5">{[0, 1, 2, 3].map((item) => <div key={item} className="h-14 animate-pulse rounded-xl bg-slate-100" />)}</div>
              ) : (
                <div className="overflow-x-auto">
                  <table className="min-w-[800px] w-full text-left text-sm">
                    <thead className="bg-slate-50 text-slate-700">
                      <tr>
                        {['Chủ thể', 'Tên KPI', 'Mục tiêu', 'Hiện tại', 'Hoàn thành', 'Trạng thái'].map((title) => <th key={title} className="px-4 py-3 font-semibold">{title}</th>)}
                      </tr>
                    </thead>
                    <tbody>
                      {filteredRows.map((row) => (
                        <tr
                          key={row.kpi_id}
                          onClick={() => setSelectedId(row.kpi_id)}
                          onKeyDown={(event) => { if (event.key === 'Enter' || event.key === ' ') setSelectedId(row.kpi_id) }}
                          tabIndex={0}
                          aria-selected={selectedId === row.kpi_id}
                          className={`cursor-pointer border-t border-slate-100 hover:bg-blue-50/50 ${selectedId === row.kpi_id ? 'bg-blue-50/50' : ''}`}
                        >
                          <td className="px-4 py-3 text-slate-700">{row.chu_the || row.group}</td>
                          <td className="px-4 py-3">
                            <span className="block font-semibold text-slate-900">{row.ten_kpi}</span>
                            <span className="text-xs text-slate-500">{row.kpi_id}</span>
                          </td>
                          <td className="px-4 py-3 text-slate-700">{formatValue(row.muc_tieu, row.unit)}</td>
                          <td className="px-4 py-3 text-slate-700">{formatValue(row.gia_tri_hien_tai, row.unit)}</td>
                          <td className="min-w-40 px-4 py-3"><ProgressBar value={row.hoan_thanh_pct} /></td>
                          <td className="px-4 py-3"><StatusBadge status={row.status} /></td>
                        </tr>
                      ))}
                      {filteredRows.length === 0 && <tr><td colSpan={6} className="px-5 py-12 text-center text-sm text-slate-600">Không có KPI phù hợp với bộ lọc.</td></tr>}
                    </tbody>
                  </table>
                </div>
              )}
            </div>
            <KpiDetails row={selectedRow && selectedRow.group === tabGroup ? selectedRow : filteredRows[0] ?? null} />
          </section>
        )}
      </div>
    </AdminShell>
  )
}

function formatPercent(value: number | null): string {
  if (value === null || !Number.isFinite(value)) return '—'
  if (value > 150) return '150%+'
  return `${new Intl.NumberFormat('vi-VN', { maximumFractionDigits: 2 }).format(value)}%`
}

function ProgressBar({ value, showLabel = true }: { value: number | null; showLabel?: boolean }) {
  const clampedValue = value === null ? 0 : Math.min(Math.max(value, 0), 150)
  const baseWidth = Math.min(clampedValue, 100) / 1.5
  const excessWidth = Math.max(clampedValue - 100, 0) / 1.5
  return (
    <div className="flex items-center gap-2">
      <div className="min-w-20 flex-1">
        <div
          role="progressbar"
          aria-valuemin={0}
          aria-valuemax={150}
          aria-valuenow={clampedValue}
          className="relative h-2.5 overflow-hidden rounded-full bg-slate-200"
        >
          <div className="absolute inset-y-0 left-0 bg-blue-600" style={{ width: `${baseWidth}%` }} />
          {excessWidth > 0 && <div className="absolute inset-y-0 left-2/3 bg-emerald-500" style={{ width: `${excessWidth}%` }} />}
          <div className="absolute inset-y-0 left-2/3 z-10 w-0.5 bg-slate-700" />
        </div>
        <div className="relative h-3 text-[9px] leading-3 text-slate-500">
          <span className="absolute left-2/3 -translate-x-1/2">100%</span>
        </div>
      </div>
      {showLabel && <span className="min-w-[56px] text-right text-sm font-bold text-slate-800">{formatPercent(value)}</span>}
    </div>
  )
}

function StatusBadge({ status }: { status: KpiStatus }) {
  return (
    <span className={`inline-flex whitespace-nowrap rounded-full px-2.5 py-1 text-xs font-semibold ${STATUS_STYLE[status]}`}>
      {status}
    </span>
  )
}

function KpiDetails({ row }: { row: KpiRow | null }) {
  return (
    <aside className="min-h-[220px] rounded-2xl border border-slate-200 bg-white p-5 shadow-sm">
      {!row ? (
        <div className="flex min-h-[180px] items-center justify-center text-center text-sm text-slate-600">Chọn một KPI trong bảng.</div>
      ) : (
        <div>
          <div className="flex items-start justify-between gap-3">
            <div>
              <p className="text-xs font-bold uppercase tracking-wide text-blue-700">{row.kpi_id}</p>
              <h3 className="mt-1 text-lg font-bold text-slate-900">{row.ten_kpi}</h3>
              <p className="mt-1 text-sm text-slate-600">{row.chu_the || row.group}</p>
            </div>
            <StatusBadge status={row.status} />
          </div>
          <div className="mt-5 grid gap-3 rounded-xl bg-slate-50 p-4 text-sm sm:grid-cols-2">
            <p className="text-slate-600">Hiện tại: <span className="font-semibold text-slate-900">{formatValue(row.gia_tri_hien_tai, row.unit)}</span></p>
            <p className="text-slate-600">Mục tiêu: <span className="font-semibold text-slate-900">{formatValue(row.muc_tieu, row.unit)}</span></p>
            <p className="text-slate-600">Hoàn thành: <span className="font-semibold text-slate-900">{formatPercent(row.hoan_thanh_pct)}</span></p>
          </div>
        </div>
      )}
    </aside>
  )
}
