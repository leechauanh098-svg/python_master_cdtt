'use client'

import { Search } from 'lucide-react'
import { formatFieldLabel, formatTableCell, type DataRow } from '@/components/remote-data'

export function RecordsTable({
  title,
  data,
  loading,
  error,
  columns,
  query,
  onQueryChange,
  onRowClick,
  emptyText = 'Không có bản ghi phù hợp.',
  children,
}: {
  title: string
  data: DataRow[]
  loading: boolean
  error: string
  columns?: string[]
  query?: string
  onQueryChange?: (query: string) => void
  onRowClick?: (row: DataRow) => void
  emptyText?: string
  children?: React.ReactNode
}) {
  const visible = data.filter((row) => {
    if (!query?.trim()) return true
    return JSON.stringify(row).toLocaleLowerCase('vi').includes(query.trim().toLocaleLowerCase('vi'))
  })
  const fields = columns ?? Array.from(new Set(visible.flatMap((row) => Object.keys(row))))

  return (
    <section className="rounded-2xl border border-slate-200 bg-white p-5 shadow-sm shadow-slate-100/70">
      <div className="mb-4 flex flex-wrap items-center justify-between gap-3">
        <div>
          <h2 className="text-sm font-bold text-slate-900">{title}</h2>
          <p className="mt-1 text-[11px] text-slate-400">{visible.length.toLocaleString('vi-VN')} bản ghi</p>
        </div>
        <div className="flex flex-wrap items-center gap-2">
          {onQueryChange && (
            <label className="relative">
              <span className="sr-only">Tìm kiếm</span>
              <Search size={14} className="absolute left-3 top-1/2 -translate-y-1/2 text-slate-400" />
              <input value={query} onChange={(event) => onQueryChange(event.target.value)} placeholder="Tìm kiếm…" className="h-9 w-48 rounded-lg border border-slate-200 pl-9 pr-3 text-xs outline-none focus:border-blue-400" />
            </label>
          )}
          {children}
        </div>
      </div>
      {error ? (
        <p role="alert" className="rounded-xl bg-rose-50 p-4 text-xs leading-5 text-rose-700">Không tải được dữ liệu: {error}</p>
      ) : loading ? (
        <p className="rounded-xl bg-slate-50 p-8 text-center text-xs text-slate-500">Đang tải dữ liệu…</p>
      ) : !visible.length ? (
        <p className="rounded-xl bg-slate-50 p-8 text-center text-xs text-slate-500">{emptyText}</p>
      ) : (
        <div className="overflow-x-auto">
          <table className="w-full min-w-[700px] text-left text-xs">
            <thead>
              <tr className="border-b border-slate-100 text-[10px] uppercase tracking-wide text-slate-400">
                {fields.map((field) => <th key={field} className="whitespace-nowrap px-3 py-3 font-semibold">{formatFieldLabel(field)}</th>)}
              </tr>
            </thead>
            <tbody>
              {visible.map((row, index) => (
                <tr
                  key={`${String(row.id ?? row.thi_sinh_id ?? row.doanh_nghiep_id ?? row.bai_nop_id ?? row.tai_lieu_id ?? row.faq_id ?? row.qna_id ?? 'row')}-${index}`}
                  onClick={() => onRowClick?.(row)}
                  className={`border-b border-slate-50 last:border-0 ${onRowClick ? 'cursor-pointer hover:bg-blue-50/50' : ''}`}
                >
                  {fields.map((field) => <td key={field} className="max-w-[280px] whitespace-pre-line break-words px-3 py-3 text-slate-600">{formatTableCell(row[field], field)}</td>)}
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </section>
  )
}
