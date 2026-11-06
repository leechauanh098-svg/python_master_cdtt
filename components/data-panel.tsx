import type { ReactNode } from 'react'
import { formatCell, formatFieldLabel, formatTableCell } from '@/components/remote-data'

export type DisplayRow = Record<string, unknown>
export type Visualization = 'metrics' | 'table' | 'bar' | 'bar-table' | 'line' | 'funnel' | 'pie'

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

function MetricGrid({ rows }: { rows: DisplayRow[] }) {
  const metrics = rows.flatMap((row) =>
    Object.entries(row).filter(([, value]) => value == null || ['string', 'number'].includes(typeof value)),
  )
  return (
    <div className="grid gap-3 sm:grid-cols-2 xl:grid-cols-4">
      {metrics.map(([label, value], index) => (
        <div key={`${label}-${index}`} className="rounded-xl border border-slate-100 bg-slate-50/80 p-4">
          <p
            className="overflow-hidden text-ellipsis whitespace-nowrap text-[11px] font-medium leading-4 text-slate-500"
            title={formatFieldLabel(label)}
          >
            {formatFieldLabel(label)}
          </p>
          <p className="mt-2 whitespace-pre-line break-words text-base font-bold leading-6 tracking-tight text-slate-900 sm:text-lg tabular-nums">
            {formatTableCell(value, label)}
          </p>
        </div>
      ))}
      {metrics.length === 0 && <p className="text-sm text-slate-500">Chưa có dữ liệu.</p>}
    </div>
  )
}

function ChartView({ rows, type }: { rows: DisplayRow[]; type: Exclude<Visualization, 'metrics' | 'table' | 'bar-table'> }) {
  const entries = rows.map((row, index) => {
    const values = Object.entries(row)
    const labelEntry = values.find(([key]) => /name|ten|label|ngay|date|truong|tinh|kenh|giai_doan|stage|nhom|buoc/i.test(key))
    const valueEntry = values.find(([key, value]) => typeof value === 'number' && /so_luong|gia_tri|tong|count|value|total|diem/i.test(key))
      ?? values.find(([, value]) => typeof value === 'number')
    return {
      label: labelEntry ? formatValue(labelEntry[1]) : `Bước ${index + 1}`,
      value: valueEntry?.[1] as number | undefined,
    }
  }).filter((entry) => typeof entry.value === 'number')

  if (!entries.length) return <p className="text-sm text-slate-500">Chưa có dữ liệu biểu đồ.</p>
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

  if (type === 'pie') {
    const total = entries.reduce((sum, entry) => sum + (entry.value ?? 0), 0) || 1
    let offset = 0
    const colors = ['#4f46e5', '#06b6d4', '#10b981', '#f59e0b', '#f43f5e', '#2563eb']
    const segments = entries.map((entry, index) => {
      const start = offset
      offset += ((entry.value ?? 0) / total) * 100
      return `${colors[index % colors.length]} ${start}% ${offset}%`
    })
    return (
      <div className="flex flex-wrap items-center gap-6">
        <div className="h-36 w-36 rounded-full" style={{ background: `conic-gradient(${segments.join(', ')})` }} />
        <div className="space-y-2">
          {entries.map((entry, index) => (
            <p key={`${entry.label}-${index}`} className="flex items-center gap-2 text-xs text-slate-600">
              <span className="h-2.5 w-2.5 rounded-sm" style={{ backgroundColor: colors[index % colors.length] }} />
              {entry.label}: <strong className="text-slate-800">{formatValue(entry.value)}</strong>
            </p>
          ))}
        </div>
      </div>
    )
  }

  if (type === 'line') {
    const points = entries.map((entry, index) => {
      const x = entries.length === 1 ? 50 : (index / (entries.length - 1)) * 100
      const y = 100 - ((entry.value ?? 0) / maxValue) * 88
      return `${x},${y}`
    }).join(' ')
    return (
      <div>
        <svg viewBox="0 0 100 100" preserveAspectRatio="none" className="h-48 w-full overflow-visible">
          <polyline points={points} fill="none" stroke="#4f46e5" strokeWidth="2.5" vectorEffect="non-scaling-stroke" />
          {entries.map((entry, index) => {
            const x = entries.length === 1 ? 50 : (index / (entries.length - 1)) * 100
            const y = 100 - ((entry.value ?? 0) / maxValue) * 88
            return <circle key={`${entry.label}-${index}`} cx={x} cy={y} r="1.8" fill="#4f46e5" vectorEffect="non-scaling-stroke" />
          })}
        </svg>
        <div className="mt-2 flex justify-between gap-2 text-[10px] text-slate-400">
          {entries.map((entry, index) => <span key={`${entry.label}-${index}`} className="truncate">{entry.label}</span>)}
        </div>
      </div>
    )
  }

  return (
    <div className="space-y-3">
      {entries.map((entry, index) => (
        <div key={`${entry.label}-${index}`} className="grid grid-cols-[minmax(70px,1fr)_3fr_auto] items-center gap-3 text-xs">
          <span className="truncate text-slate-500">{entry.label}</span>
          <span className="h-2 overflow-hidden rounded-full bg-slate-100">
            <span className="block h-full rounded-full bg-indigo-500" style={{ width: `${Math.max((entry.value ?? 0) / maxValue * 100, 1)}%` }} />
          </span>
          <strong className="text-slate-700">{formatValue(entry.value)}</strong>
        </div>
      ))}
    </div>
  )
}

function DataTable({ rows }: { rows: DisplayRow[] }) {
  const columns = Array.from(new Set(rows.flatMap((row) => Object.keys(row))))
  if (!columns.length) return <p className="text-sm text-slate-500">Chưa có dữ liệu.</p>
  return (
    <div className="overflow-x-auto">
      <table className="w-full min-w-[560px] text-left text-xs">
        <thead>
          <tr className="border-b border-slate-100 text-[10px] uppercase tracking-wide text-slate-400">
            {columns.map((column) => <th key={column} className="px-3 py-3 font-semibold">{formatFieldLabel(column)}</th>)}
          </tr>
        </thead>
        <tbody>
          {rows.map((row, index) => (
            <tr key={index} className="border-b border-slate-50 last:border-0">
              {columns.map((column) => <td key={column} className="max-w-[280px] whitespace-pre-line break-words px-3 py-3 text-slate-600">{formatTableCell(row[column], column)}</td>)}
            </tr>
          ))}
        </tbody>
      </table>
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
}: {
  title: string
  description?: string
  data: unknown
  loading: boolean
  error?: string
  notice?: string
  visualization?: Visualization
  action?: ReactNode
}) {
  const rows = rowsFrom(data)
  return (
    <section className="min-w-0 rounded-2xl border border-slate-200 bg-white p-5 shadow-sm shadow-slate-100/70">
      <div className="mb-4 flex flex-wrap items-start justify-between gap-3">
        <div>
          <h2 className="text-sm font-bold text-slate-900">{title}</h2>
          {description && <p className="mt-1 text-[11px] text-slate-400">{description}</p>}
        </div>
        {action}
      </div>
      {loading ? (
        <p className="rounded-xl bg-slate-50 px-4 py-8 text-center text-xs text-slate-500">Đang tải dữ liệu…</p>
      ) : notice ? (
        <p className="rounded-xl bg-amber-50 px-4 py-3 text-xs leading-5 text-amber-800">{notice}</p>
      ) : error ? (
        <p role="alert" className="rounded-xl bg-rose-50 px-4 py-3 text-xs leading-5 text-rose-700">{error}</p>
      ) : visualization === 'metrics' ? (
        <MetricGrid rows={rows} />
      ) : visualization === 'bar-table' ? (
        <div className="space-y-6">
          <ChartView rows={rows} type="bar" />
          <DataTable rows={rows} />
        </div>
      ) : visualization === 'bar' || visualization === 'line' || visualization === 'pie' || visualization === 'funnel' ? (
        <ChartView rows={rows} type={visualization} />
      ) : (
        <DataTable rows={rows} />
      )}
    </section>
  )
}
