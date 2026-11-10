import { useState, type ReactNode } from 'react'
import { ChartCard } from '@/components/admin-charts'
import { formatCell, formatFieldLabel, formatTableCell } from '@/components/remote-data'

export type DisplayRow = Record<string, unknown>
export type Visualization = 'metrics' | 'table' | 'bar' | 'bar-horizontal' | 'bar-table' | 'line' | 'area' | 'funnel' | 'pie'

const chartTitleCaseLabels: Record<string, string> = {
  'BỊ LOẠI': 'Bị loại',
  'CHỜ HỒ SƠ': 'Chờ hồ sơ',
  'HOÀN THÀNH': 'Hoàn thành',
  'ĐANG XÉT DUYỆT': 'Đang xét duyệt',
  'ĐÃ ĐÓNG PHÍ': 'Đã đóng phí',
  FACEBOOK: 'Facebook',
  INSTAGRAM: 'Instagram',
}

function isRecord(value: unknown): value is DisplayRow {
  return typeof value === 'object' && value !== null && !Array.isArray(value)
}

function rowsFrom(value: unknown): DisplayRow[] {
  if (Array.isArray(value)) {
    return value.map((row, index) =>
      isRecord(row) ? row : { STT: index + 1, Giá_trị: row },
    )
  }
  if (isRecord(value)) return [value]
  return value == null ? [] : [{ Giá_trị: value }]
}

function formatValue(value: unknown): string {
  return formatCell(value)
}

function formatChartLabel(value: unknown): string {
  const formatted = formatValue(value)
  return chartTitleCaseLabels[formatted.trim().toLocaleUpperCase('vi')] ?? formatted
}

function MetricGrid({ rows }: { rows: DisplayRow[] }) {
  const metricOrder = [
    'tu_ngay',
    'den_ngay',
    'tong_tiep_can',
    'dang_ky_thi',
    'tham_gia_thuc_te',
    'thi_sinh_tham_gia_thuc_te',
    'ty_le_tham_gia_pct',
    'doanh_thu_le_phi',
    'thuc_thu_tai_tro',
    'tong_thu',
    'tong_doanh_thu',
    'giao_dich_thanh_cong',
    'dang_doi_soat',
    'gia_tri_trung_binh',
  ]
  const hiddenMetrics = new Set(['ky_bao_cao', 'thoi_diem_cap_nhat', 'cap_nhat_luc', 'updated_at'])
  const metrics = rows.flatMap((row) =>
    Object.entries(row).filter(([key, value]) =>
      !hiddenMetrics.has(key.toLowerCase())
      && (value == null || ['string', 'number'].includes(typeof value)),
    ),
  ).sort(([first], [second]) => {
    const firstOrder = metricOrder.indexOf(first.toLowerCase())
    const secondOrder = metricOrder.indexOf(second.toLowerCase())
    return (firstOrder < 0 ? metricOrder.length : firstOrder) - (secondOrder < 0 ? metricOrder.length : secondOrder)
  })
  return (
    <div className="grid gap-3 sm:grid-cols-2 2xl:grid-cols-4">
      {metrics.map(([label, value], index) => (
        <div key={`${label}-${index}`} className="min-w-0 rounded-xl border border-slate-100 bg-slate-50/80 p-4">
          <p
            className="break-words text-sm font-medium leading-5 text-slate-600"
            title={formatFieldLabel(label)}
          >
            {formatFieldLabel(label)}
          </p>
          <p className="mt-2 whitespace-pre-line break-words text-lg font-bold leading-7 tracking-tight text-slate-900 tabular-nums">
            {formatTableCell(value, label)}
          </p>
        </div>
      ))}
      {metrics.length === 0 && <p className="text-sm text-slate-600">Chưa có dữ liệu.</p>}
    </div>
  )
}

function ChartView({
  rows,
  type,
  valueField,
  labelField,
  secondaryLabelField,
}: {
  rows: DisplayRow[]
  type: Exclude<Visualization, 'metrics' | 'table' | 'bar-table'>
  valueField?: string
  labelField?: string
  secondaryLabelField?: string
}) {
  const labelKey = labelField ?? Object.keys(rows[0] ?? {}).find((key) =>
    /name|ten|label|ngay|date|truong|tinh|kenh|giai_doan|stage|nhom|buoc|khoang_diem|bang_dau|trang_thai|cap_do|loai_doi_tuong/i.test(key),
  )
  const valueKey = valueField ?? Object.keys(rows[0] ?? {}).find((key) =>
    /so_luong|so_dang_ky|dang_ky|gia_tri|tong|count|value|total|diem|doanh_thu|so_giao_dich|ty_le|tyle|hoan_thanh|brand_reach|luot/i.test(key)
      && typeof rows[0][key] === 'number',
  ) ?? Object.keys(rows[0] ?? {}).find((key) => typeof rows[0][key] === 'number')
  const entries = rows.map((row, index) => {
    const values = Object.entries(row)
    const labelEntry = labelKey ? values.find(([key]) => key === labelKey) : undefined
    const rawLabel = labelEntry?.[1]
    const primaryLabel = labelEntry && labelKey?.toLowerCase() === 'ngay' && typeof rawLabel === 'string'
      ? (() => {
        const date = rawLabel.match(/^(\d{4})-(\d{2})-(\d{2})/)
        return date ? `${date[3]}/${date[2]}` : formatChartLabel(rawLabel)
      })()
      : labelEntry ? formatChartLabel(rawLabel) : `Bước ${index + 1}`
    const secondaryLabel = secondaryLabelField ? row[secondaryLabelField] : undefined
    return {
      label: secondaryLabel == null || secondaryLabel === ''
        ? primaryLabel
        : `${primaryLabel} · ${formatChartLabel(secondaryLabel)}`,
      value: valueKey && typeof row[valueKey] === 'number' ? row[valueKey] : undefined,
      row,
    }
  }).filter((entry) => typeof entry.value === 'number')

  if (!entries.length) return <p className="text-sm text-slate-500">Chưa có dữ liệu biểu đồ.</p>
  const labelCounts = new Map<string, number>()
  entries.forEach(({ label }) => labelCounts.set(label, (labelCounts.get(label) ?? 0) + 1))
  const disambiguatedEntries = entries.map((entry) => {
    if ((labelCounts.get(entry.label) ?? 0) < 2) return entry
    const contextField = ['truong_hoc', 'ten_bai_tap', 'tinh_thanh', 'ten_cuoc_thi', 'nguon']
      .find((field) => field !== labelKey && field !== secondaryLabelField
        && typeof entry.row[field] === 'string'
        && entry.row[field] !== '')
    return contextField
      ? { ...entry, label: `${entry.label} · ${formatChartLabel(entry.row[contextField])}` }
      : entry
  })
  const maxValue = Math.max(...entries.map((entry) => entry.value ?? 0), 1)

  if (type === 'funnel') {
    return (
      <div className="space-y-2">
        {entries.map((entry, index) => {
          const width = Math.max(((entry.value ?? 0) / maxValue) * 100, 8)
          return (
            <div key={`${entry.label}-${index}`} className="flex justify-center">
              <div
                className="flex min-h-10 items-center justify-between gap-3 rounded-lg bg-blue-50 px-3 text-xs text-blue-900"
                style={{ width: `${width}%` }}
              >
                <span className="truncate font-medium">{entry.label}</span>
                <strong>{formatValue(entry.value)}</strong>
              </div>
            </div>
          )
        })}
      </div>
    )
  }

  return (
    <div className={type === 'bar-horizontal' && entries.length > 12 ? 'max-h-[720px] overflow-y-auto' : undefined}>
      <ChartCard
        title=""
        data={disambiguatedEntries.map((entry) => ({ label: entry.label, value: entry.value }))}
        kind={type === 'area' ? 'area' : type === 'line' ? 'line' : type === 'pie' ? 'pie' : 'bar'}
        xKey="label"
        yKey="value"
        seriesName={valueKey ? formatFieldLabel(valueKey) : 'Số lượng'}
        height={type === 'bar-horizontal' ? Math.max(280, entries.length * 22 + 40) : 280}
        horizontal={type === 'bar-horizontal'}
        bare
      />
    </div>
  )
}

function DataTable({ rows, compact = false }: { rows: DisplayRow[]; compact?: boolean }) {
  const columns = Array.from(new Set(rows.flatMap((row) => Object.keys(row))))
  const [profileStatus, setProfileStatus] = useState('')
  const [paymentStatus, setPaymentStatus] = useState('')
  if (!columns.length) return <p className="text-sm text-slate-500">Chưa có dữ liệu.</p>
  const profileStatuses = Array.from(new Set(rows.map((row) => row.trang_thai_ho_so).filter((value): value is string => typeof value === 'string'))).sort()
  const paymentStatuses = Array.from(new Set(rows.map((row) => row.trang_thai_thanh_toan).filter((value): value is string => typeof value === 'string'))).sort()
  const filteredRows = rows.filter((row) =>
    (!profileStatus || row.trang_thai_ho_so === profileStatus)
    && (!paymentStatus || row.trang_thai_thanh_toan === paymentStatus),
  )

  function formatSource(value: unknown): string {
    if (typeof value !== 'string') return formatTableCell(value)
    const sources = value.split(',').map((source) => source.trim()).filter(Boolean)
    if (sources.length < 2) return formatTableCell(value, 'nguon')
    return `Cả ${sources.slice(0, -1).join(', ')} và ${sources[sources.length - 1]}`
  }

  return (
    <div>
      {compact && (profileStatuses.length > 0 || paymentStatuses.length > 0) && (
        <div className="mb-2 flex flex-wrap items-center gap-2">
          {profileStatuses.length > 0 && (
            <label className="flex items-center gap-1.5 text-[11px] font-medium text-slate-600">
              Hồ sơ
              <select
                aria-label="Lọc theo trạng thái hồ sơ"
                value={profileStatus}
                onChange={(event) => setProfileStatus(event.target.value)}
                className="h-8 rounded-lg border border-slate-200 bg-white px-2 text-xs text-slate-700 outline-none focus:border-blue-400"
              >
                <option value="">Tất cả</option>
                {profileStatuses.map((status) => <option key={status} value={status}>{formatTableCell(status, 'trang_thai_ho_so')}</option>)}
              </select>
            </label>
          )}
          {paymentStatuses.length > 0 && (
            <label className="flex items-center gap-1.5 text-[11px] font-medium text-slate-600">
              Thanh toán
              <select
                aria-label="Lọc theo trạng thái thanh toán"
                value={paymentStatus}
                onChange={(event) => setPaymentStatus(event.target.value)}
                className="h-8 rounded-lg border border-slate-200 bg-white px-2 text-xs text-slate-700 outline-none focus:border-blue-400"
              >
                <option value="">Tất cả</option>
                {paymentStatuses.map((status) => <option key={status} value={status}>{formatTableCell(status, 'trang_thai_thanh_toan')}</option>)}
              </select>
            </label>
          )}
          <span className="text-[11px] text-slate-400">{filteredRows.length} / {rows.length}</span>
        </div>
      )}
      <div className={`${compact ? 'max-h-[360px]' : 'max-h-[440px]'} overflow-auto rounded-lg`}>
        <table className={`w-full ${compact ? 'min-w-[560px] text-xs' : 'min-w-[600px] text-sm'} text-left`}>
          <thead>
            <tr className="border-b border-slate-200 bg-slate-50 text-xs tracking-wide text-slate-600">
              {columns.map((column) => <th key={column} className={`sticky top-0 z-10 bg-slate-50 font-semibold ${compact ? 'px-2.5 py-2' : 'px-4 py-3'}`}>{formatFieldLabel(column)}</th>)}
            </tr>
          </thead>
          <tbody>
            {filteredRows.map((row, index) => (
              <tr key={index} className="border-b border-slate-50 last:border-0">
                {columns.map((column) => (
                  <td key={column} className={`max-w-[320px] whitespace-pre-line break-words text-slate-700 ${compact ? 'px-2.5 py-2' : 'px-4 py-3.5'}`}>
                    {compact && column === 'nguon' ? formatSource(row[column]) : formatTableCell(row[column], column)}
                  </td>
                ))}
              </tr>
            ))}
            {filteredRows.length === 0 && (
              <tr>
                <td colSpan={columns.length} className="px-3 py-5 text-center text-xs text-slate-500">Không có dữ liệu phù hợp với trạng thái đã chọn.</td>
              </tr>
            )}
          </tbody>
        </table>
      </div>
    </div>
  )
}

export function DataPanel({
  title,
  description,
  data,
  loading,
  error,
  notice,
  visualization = 'table',
  action,
  compactTable = false,
  chartValueField,
  chartLabelField,
  chartSecondaryLabelField,
}: {
  title: string
  description?: string
  data: unknown
  loading: boolean
  error?: string
  notice?: string
  visualization?: Visualization
  action?: ReactNode
  compactTable?: boolean
  chartValueField?: string
  chartLabelField?: string
  chartSecondaryLabelField?: string
}) {
  const rows = rowsFrom(data)
  return (
    <section className={`min-w-0 self-start rounded-2xl border border-slate-200 bg-white shadow-sm shadow-slate-100/70 ${compactTable ? 'p-3' : 'p-5'}`}>
      <div className={`${compactTable ? 'mb-3' : 'mb-4'} flex flex-wrap items-start justify-between gap-3`}>
        <div>
          <h2 className="text-base font-bold text-slate-900">{title}</h2>
          {description && <p className="mt-1 text-xs leading-5 text-slate-500">{description}</p>}
        </div>
        {action}
      </div>
      {loading ? (
        <p className="rounded-xl bg-slate-50 px-4 py-8 text-center text-sm text-slate-600">Đang tải dữ liệu…</p>
      ) : notice ? (
        <p className="rounded-xl bg-amber-50 px-4 py-3 text-xs leading-5 text-amber-800">{notice}</p>
      ) : error ? (
        <p role="alert" className="rounded-xl bg-rose-50 px-4 py-3 text-sm leading-6 text-rose-700">{error}</p>
      ) : visualization === 'metrics' ? (
        <MetricGrid rows={rows} />
      ) : visualization === 'bar-table' ? (
        <div className={compactTable ? 'space-y-4' : 'space-y-6'}>
          <ChartView
            rows={rows}
            type="bar"
            valueField={chartValueField}
            labelField={chartLabelField}
            secondaryLabelField={chartSecondaryLabelField}
          />
          <DataTable rows={rows} compact={compactTable} />
        </div>
      ) : visualization === 'bar' || visualization === 'bar-horizontal' || visualization === 'line' || visualization === 'area' || visualization === 'pie' || visualization === 'funnel' ? (
        <ChartView
          rows={rows}
          type={visualization}
          valueField={chartValueField}
          labelField={chartLabelField}
          secondaryLabelField={chartSecondaryLabelField}
        />
      ) : (
        <DataTable rows={rows} compact={compactTable} />
      )}
    </section>
  )
}
