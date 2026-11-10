'use client'

import { useEffect, useMemo, useState } from 'react'
import { Download, Eye, Filter, RefreshCw, Search, X } from 'lucide-react'
import { AdminShell } from '@/components/admin-shell'
import { RecordsTable } from '@/components/records-table'
import { formatCell, formatFieldLabel, formatTableCell, type DataRow } from '@/components/remote-data'
import { getSupabaseBrowserClient } from '@/lib/supabase-browser'

function csvEscape(value: unknown): string {
  return `"${String(value ?? '').replaceAll('"', '""')}"`
}

export default function StudentsPage() {
  const supabase = useMemo(() => getSupabaseBrowserClient(), [])
  const [rows, setRows] = useState<DataRow[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')
  const [search, setSearch] = useState('')
  const [filters, setFilters] = useState({ id: '', name: '', year: '', school: '', status: 'ALL', board: 'ALL', sale: 'ALL' })
  const [page, setPage] = useState(1)
  const [selected, setSelected] = useState<DataRow | null>(null)
  const [detail, setDetail] = useState<DataRow | null>(null)
  const [detailLoading, setDetailLoading] = useState(false)
  const [detailError, setDetailError] = useState('')
  const [refresh, setRefresh] = useState(0)
  const pageSize = 15

  useEffect(() => {
    let active = true
    async function load() {
      if (!supabase) {
        setError('Chưa cấu hình kết nối Supabase.')
        setLoading(false)
        return
      }
      setLoading(true)
      setError('')
      const args = {
        p_thi_sinh_id: filters.id || null,
        p_ho_ten: filters.name || null,
        p_nam_sinh: filters.year ? Number(filters.year) : null,
        p_truong_hoc: filters.school || null,
        p_trang_thai_ho_so: filters.status === 'ALL' ? null : filters.status,
        p_sale_phu_trach_id: filters.sale === 'ALL' ? null : filters.sale,
        p_bang_dau: filters.board === 'ALL' ? null : filters.board,
      }
      const response = search.trim()
        ? await supabase.rpc('fn_tim_kiem_thisinh', { p_tu_khoa: search.trim() })
        : await supabase.rpc('fn_loc_thisinh', args)
      if (!active) return
      if (response.error) {
        setRows([])
        setError(response.error.message)
      } else {
        setRows(Array.isArray(response.data) ? response.data as DataRow[] : [])
      }
      setLoading(false)
    }
    void load()
    return () => { active = false }
  }, [filters, refresh, search, supabase])

  useEffect(() => {
    setPage(1)
  }, [filters, search])

  async function openDetail(row: DataRow) {
    const id = row.thi_sinh_id ?? row.id
    if (id == null || !supabase) return
    setSelected(row)
    setDetail(null)
    setDetailError('')
    setDetailLoading(true)
    const { data, error: responseError } = await supabase.rpc('fn_xem_chi_tiet_thisinh', { p_thi_sinh_id: id })
    if (responseError) setDetailError(responseError.message)
    else setDetail(Array.isArray(data) ? data[0] ?? null : data as DataRow | null)
    setDetailLoading(false)
  }

  async function exportRows() {
    if (!supabase) return
    const args = {
      p_thi_sinh_id: filters.id || null,
      p_ho_ten: filters.name || null,
      p_sdt: null,
      p_email: search || null,
      p_truong_hoc: filters.school || null,
      p_cccd: null,
      p_trang_thai_ho_so: filters.status === 'ALL' ? null : filters.status,
      p_sale_phu_trach_id: filters.sale === 'ALL' ? null : filters.sale,
      p_bang_dau: filters.board === 'ALL' ? null : filters.board,
    }
    const { data, error: exportError } = await supabase.rpc('fn_xuat_thisinh', args)
    if (exportError) {
      setError(`Xuất dữ liệu thất bại: ${exportError.message}`)
      return
    }
    const exportData = Array.isArray(data) ? data as DataRow[] : []
    if (!exportData.length) {
      setError('Không có dữ liệu để xuất.')
      return
    }
    const columns = Object.keys(exportData[0])
    const csv = [columns.map(csvEscape).join(','), ...exportData.map((item) => columns.map((column) => csvEscape(item[column])).join(','))].join('\r\n')
    const url = URL.createObjectURL(new Blob([`\uFEFF${csv}`], { type: 'text/csv;charset=utf-8' }))
    const link = document.createElement('a')
    link.href = url
    link.download = 'danh-sach-thi-sinh.csv'
    link.click()
    URL.revokeObjectURL(url)
  }

  const pageRows = rows.slice((page - 1) * pageSize, page * pageSize)
  const totalPages = Math.max(1, Math.ceil(rows.length / pageSize))
  const tableColumns = ['thi_sinh_id', 'ho_ten', 'email', 'sdt', 'nam_sinh', 'truong_hoc', 'trang_thai_ho_so', 'bang_dau', 'ten_sale_phu_trach']

  return (
    <AdminShell active="Quản lý thí sinh" title="Quản lý thí sinh">
      <div className="mb-5 flex flex-wrap items-end justify-between gap-3">
        <div><p className="text-sm text-slate-500">Theo dõi hồ sơ, trạng thái và thông tin thí sinh.</p></div>
        <div className="flex gap-2">
          <button onClick={() => setRefresh((value) => value + 1)} className="flex h-9 items-center gap-2 rounded-xl border border-slate-200 bg-white px-3 text-xs font-medium text-slate-600"><RefreshCw size={14} /> Làm mới</button>
          <button onClick={() => void exportRows()} className="flex h-9 items-center gap-2 rounded-xl bg-blue-600 px-3 text-xs font-semibold text-white"><Download size={14} /> Xuất CSV</button>
        </div>
      </div>

      <section className="mb-5 rounded-2xl border border-slate-200 bg-white p-5 shadow-sm shadow-slate-100/70">
        <div className="mb-4 flex items-center gap-2"><Filter size={15} className="text-blue-500" /><div><h2 className="text-sm font-bold text-slate-900">Bộ lọc nâng cao</h2><p className="text-[11px] text-slate-400">Tìm kiếm không dấu và lọc theo hồ sơ.</p></div></div>
        <div className="mb-4 relative"><Search size={14} className="absolute left-3 top-1/2 -translate-y-1/2 text-slate-400" /><input value={search} onChange={(event) => setSearch(event.target.value)} placeholder="Tìm mã, họ tên, email, trường hoặc CCCD…" className="h-10 w-full rounded-xl border border-slate-200 pl-9 pr-3 text-xs outline-none focus:border-blue-400" /></div>
        <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
          <FilterInput label="Mã thí sinh" value={filters.id} onChange={(value) => setFilters({ ...filters, id: value })} />
          <FilterInput label="Họ tên" value={filters.name} onChange={(value) => setFilters({ ...filters, name: value })} />
          <FilterInput label="Năm sinh" value={filters.year} onChange={(value) => setFilters({ ...filters, year: value })} type="number" />
          <FilterInput label="Trường học" value={filters.school} onChange={(value) => setFilters({ ...filters, school: value })} />
          <FilterSelect label="Trạng thái hồ sơ" value={filters.status} onChange={(value) => setFilters({ ...filters, status: value })} options={['ALL', 'CHO_DUYET', 'DA_DUYET', 'KHONG_HOP_LE', 'KHOA']} />
          <FilterSelect label="Bảng đấu" value={filters.board} onChange={(value) => setFilters({ ...filters, board: value })} options={['ALL', 'BANG_A', 'BANG_B']} />
          <FilterInput label="Mã sale phụ trách" value={filters.sale === 'ALL' ? '' : filters.sale} onChange={(value) => setFilters({ ...filters, sale: value || 'ALL' })} />
        </div>
      </section>

      <RecordsTable title="Danh sách thí sinh" data={pageRows} loading={loading} error={error} columns={tableColumns} onRowClick={openDetail} emptyText="Không tìm thấy thí sinh phù hợp.">
        <span className="mr-2 text-[10px] text-slate-400">Trang {page}/{totalPages}</span>
        <button disabled={page <= 1} onClick={() => setPage((value) => value - 1)} className="h-8 rounded-lg border px-3 text-xs disabled:opacity-40">Trước</button>
        <button disabled={page >= totalPages} onClick={() => setPage((value) => value + 1)} className="h-8 rounded-lg border px-3 text-xs disabled:opacity-40">Sau</button>
      </RecordsTable>

      {selected && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-slate-950/40 p-4" onMouseDown={(event) => { if (event.target === event.currentTarget) { setSelected(null); setDetail(null) } }}>
          <section role="dialog" aria-modal="true" aria-labelledby="student-detail-title" className="max-h-[85vh] w-full max-w-2xl overflow-auto rounded-2xl bg-white p-5 shadow-xl">
            <div className="mb-4 flex items-center justify-between"><div><h2 id="student-detail-title" className="text-base font-bold text-slate-900">Chi tiết thí sinh</h2><p className="mt-1 text-[11px] text-slate-400">{String(selected.thi_sinh_id ?? selected.id ?? '')}</p></div><button onClick={() => { setSelected(null); setDetail(null) }} aria-label="Đóng" className="rounded-lg p-2 text-slate-500 hover:bg-slate-100"><X size={17} /></button></div>
            {detailLoading ? <p className="py-10 text-center text-xs text-slate-500">Đang tải chi tiết…</p> : detailError ? <p role="alert" className="rounded-xl bg-rose-50 p-3 text-xs text-rose-700">Không tải được chi tiết: {detailError}</p> : detail && <div className="grid gap-3 sm:grid-cols-2">{Object.entries(detail).map(([key, value]) => <div key={key} className="rounded-xl bg-slate-50 p-3"><p className="text-[10px] text-slate-400">{formatFieldLabel(key)}</p><p className="mt-1 break-words text-xs font-medium text-slate-800">{formatTableCell(value, key)}</p></div>)}</div>}
          </section>
        </div>
      )}
    </AdminShell>
  )
}

function FilterInput({ label, value, onChange, type = 'text' }: { label: string; value: string; onChange: (value: string) => void; type?: string }) {
  return <label className="block"><span className="mb-1.5 block text-[10px] font-medium text-slate-500">{label}</span><input type={type} value={value} onChange={(event) => onChange(event.target.value)} className="h-9 w-full rounded-lg border border-slate-200 px-3 text-xs outline-none focus:border-blue-400" /></label>
}

function FilterSelect({ label, value, onChange, options }: { label: string; value: string; onChange: (value: string) => void; options: string[] }) {
  return <label className="block"><span className="mb-1.5 block text-[10px] font-medium text-slate-500">{label}</span><select value={value} onChange={(event) => onChange(event.target.value)} className="h-9 w-full rounded-lg border border-slate-200 bg-white px-3 text-xs outline-none">{options.map((option) => <option key={option} value={option}>{formatCell(option)}</option>)}</select></label>
}
