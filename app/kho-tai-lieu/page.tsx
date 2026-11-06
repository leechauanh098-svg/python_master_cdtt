'use client'

import { useEffect, useState } from 'react'
import { FilePlus2, RefreshCw, Search } from 'lucide-react'
import { AdminShell } from '@/components/admin-shell'
import { RecordsTable } from '@/components/records-table'
import { formatCell, useRemoteRows, type DataRow } from '@/components/remote-data'

export default function KnowledgeBasePage() {
  const [refresh, setRefresh] = useState(0)
  const summary = useRemoteRows({ kind: 'view', name: 'vw_rag_tongquan' }, refresh)
  const supabase = summary.client
  const [documents, setDocuments] = useState<DataRow[]>([])
  const [chunks, setChunks] = useState<DataRow[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')
  const [search, setSearch] = useState('')
  const [kind, setKind] = useState('')
  const [status, setStatus] = useState('')
  const [selectedId, setSelectedId] = useState('')
  const [staffId, setStaffId] = useState('')
  const [actionMessage, setActionMessage] = useState('')
  const [newDocument, setNewDocument] = useState({ id: '', title: '', type: '', url: '', file: '', bytes: '' })

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
      const { data, error: responseError } = search.trim()
        ? await supabase.rpc('fn_search_tailieu', { p_tu_khoa: search.trim(), p_gioi_han: 100 })
        : await supabase.rpc('fn_tailieu_tim_kiem_loc', {
          p_tu_khoa: null,
          p_loai_tai_lieu: kind || null,
          p_trang_thai: status || null,
          p_trang: 1,
          p_kich_thuoc_trang: 100,
        })
      if (!active) return
      if (responseError) {
        setDocuments([])
        setError(responseError.message)
      } else setDocuments(Array.isArray(data) ? data as DataRow[] : [])
      setLoading(false)
    }
    void load()
    return () => { active = false }
  }, [kind, search, status, supabase, refresh])

  async function loadChunks(documentId: string) {
    if (!supabase) return
    setSelectedId(documentId)
    setActionMessage('')
    const { data, error: responseError } = await supabase.rpc('fn_tailieu_xem_doan', { p_tai_lieu_id: documentId })
    if (responseError) setActionMessage(`Không tải được các đoạn tài liệu: ${responseError.message}`)
    else setChunks(Array.isArray(data) ? data as DataRow[] : [])
  }

  async function reindex() {
    if (!supabase || !selectedId || !staffId.trim()) {
      setActionMessage('Chọn tài liệu và nhập mã nhân viên đang hoạt động để re-index.')
      return
    }
    const { error: responseError } = await supabase.rpc('fn_tailieu_reindex', {
      p_tai_lieu_id: selectedId,
      p_nguoi_yeu_cau: staffId.trim(),
    })
    setActionMessage(responseError ? `Re-index thất bại: ${responseError.message}` : 'Đã yêu cầu re-index. Nội dung cũ đã được xóa theo quy trình của hệ thống.')
    if (!responseError) {
      setChunks([])
      setRefresh((value) => value + 1)
    }
  }

  async function createDocument(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault()
    if (!supabase || !staffId.trim()) {
      setActionMessage('Nhập mã nhân viên đang hoạt động trước khi thêm tài liệu.')
      return
    }
    const { error: responseError } = await supabase.rpc('fn_tailieu_them_moi', {
      p_tai_lieu_id: newDocument.id,
      p_ten_tai_lieu: newDocument.title,
      p_loai_tai_lieu: newDocument.type,
      p_url_luu_tru: newDocument.url,
      p_tao_boi: staffId.trim(),
      p_danh_muc_id: null,
      p_ten_file_goc: newDocument.file || null,
      p_dung_luong_byte: newDocument.bytes ? Number(newDocument.bytes) : null,
    })
    setActionMessage(responseError ? `Không thêm được tài liệu: ${responseError.message}` : 'Đã thêm tài liệu vào kho.')
    if (!responseError) {
      setNewDocument({ id: '', title: '', type: '', url: '', file: '', bytes: '' })
      setRefresh((value) => value + 1)
    }
  }

  const summaryRow = summary.data[0]
  const metricLabels = ['Tổng tài liệu', 'Tài liệu đã có đoạn', 'Tổng số đoạn', 'Tổng vector embeddings']

  return (
    <AdminShell active="Kho tài liệu RAG" title="Kho Tài liệu RAG">
      <div className="mb-5 flex flex-wrap items-end justify-between gap-3"><p className="text-sm text-slate-500">Quản lý tài liệu, nội dung phân đoạn và chỉ mục tìm kiếm.</p><button onClick={() => setRefresh((value) => value + 1)} className="flex h-9 items-center gap-2 rounded-xl border border-slate-200 bg-white px-3 text-xs font-medium text-slate-600"><RefreshCw size={14} /> Làm mới</button></div>
      <div className="mb-5 grid gap-3 sm:grid-cols-2 xl:grid-cols-4">
        {metricLabels.map((label, index) => {
          const value = summaryRow ? Object.values(summaryRow)[index] : null
          return <article key={label} className="rounded-2xl border border-slate-200 bg-white p-4"><p className="text-[10px] font-medium text-slate-500">{label}</p><p className="mt-2 text-2xl font-bold text-slate-900">{summary.loading ? '…' : summary.error ? '—' : formatCell(value)}</p>{summary.error && <p className="mt-1 text-[10px] text-rose-600">{summary.error}</p>}</article>
        })}
      </div>
      <section className="mb-5 rounded-2xl border border-slate-200 bg-white p-5">
        <div className="mb-3 flex items-center gap-2"><FilePlus2 size={16} className="text-blue-600" /><div><h2 className="text-sm font-bold text-slate-900">Thêm tài liệu mới</h2><p className="text-[11px] text-slate-400">Tài liệu được tạo ở trạng thái nội bộ theo quy trình SQL.</p></div></div>
        <form onSubmit={createDocument} className="grid gap-3 sm:grid-cols-2 xl:grid-cols-3">
          <Input label="Mã tài liệu" value={newDocument.id} onChange={(id) => setNewDocument({ ...newDocument, id })} required />
          <Input label="Tên tài liệu" value={newDocument.title} onChange={(title) => setNewDocument({ ...newDocument, title })} required />
          <Input label="Loại tài liệu" value={newDocument.type} onChange={(type) => setNewDocument({ ...newDocument, type })} required />
          <Input label="URL lưu trữ" value={newDocument.url} onChange={(url) => setNewDocument({ ...newDocument, url })} required />
          <Input label="Tên file gốc" value={newDocument.file} onChange={(file) => setNewDocument({ ...newDocument, file })} />
          <Input label="Dung lượng (byte)" type="number" value={newDocument.bytes} onChange={(bytes) => setNewDocument({ ...newDocument, bytes })} />
          <div className="flex items-end gap-2"><input aria-label="Mã nhân viên" value={staffId} onChange={(event) => setStaffId(event.target.value)} placeholder="Mã nhân viên" className="h-9 min-w-0 flex-1 rounded-lg border border-slate-200 px-3 text-xs" /><button className="h-9 shrink-0 rounded-lg bg-blue-600 px-4 text-xs font-semibold text-white">Thêm tài liệu</button></div>
        </form>
      </section>
      <RecordsTable title="Danh sách tài liệu" data={documents} loading={loading} error={error} query={search} onQueryChange={setSearch} onRowClick={(row) => void loadChunks(String(row.tai_lieu_id ?? ''))} columns={['tai_lieu_id', 'ten_tai_lieu', 'ten_file_goc', 'danh_muc_hien_thi', 'loai_tai_lieu', 'dung_luong_mb', 'trang_thai', 'so_doan', 'ngay_dang_tai']}>
        <select aria-label="Lọc loại tài liệu" value={kind} onChange={(event) => setKind(event.target.value)} className="h-9 rounded-lg border border-slate-200 bg-white px-2 text-xs"><option value="">Tất cả loại</option>{['PDF', 'DOCX', 'DOC', 'XLSX', 'URL', 'TXT'].map((value) => <option key={value} value={value}>{value}</option>)}</select>
        <select aria-label="Lọc trạng thái" value={status} onChange={(event) => setStatus(event.target.value)} className="h-9 rounded-lg border border-slate-200 bg-white px-2 text-xs"><option value="">Tất cả trạng thái</option>{['NOI_BO', 'CONG_KHAI', 'AN'].map((value) => <option key={value} value={value}>{formatCell(value)}</option>)}</select>
      </RecordsTable>
      <section className="mt-5 rounded-2xl border border-slate-200 bg-white p-5">
        <div className="mb-4 flex flex-wrap items-start justify-between gap-3"><div><h2 className="text-sm font-bold text-slate-900">Các đoạn tài liệu</h2><p className="mt-1 text-[11px] text-slate-400">{selectedId || 'Chọn một tài liệu trong danh sách để xem các đoạn.'}</p></div><div className="flex flex-wrap gap-2"><input aria-label="Mã nhân viên re-index" value={staffId} onChange={(event) => setStaffId(event.target.value)} placeholder="Mã nhân viên" className="h-9 w-36 rounded-lg border border-slate-200 px-3 text-xs" /><button onClick={() => void reindex()} disabled={!selectedId} className="h-9 rounded-lg border border-amber-200 bg-amber-50 px-3 text-xs font-semibold text-amber-800 disabled:opacity-40">Re-index</button></div></div>
        {actionMessage && <p role="status" className="mb-3 rounded-lg bg-blue-50 p-3 text-xs leading-5 text-blue-800">{actionMessage}</p>}
        {!selectedId ? <p className="rounded-xl bg-slate-50 p-7 text-center text-xs text-slate-500">Chưa chọn tài liệu.</p> : chunks.length ? <RecordsTable title="Nội dung đoạn" data={chunks} loading={false} error="" columns={['thu_tu_doan', 'vector_id_hien_thi', 'noi_dung_rut_gon', 'da_co_embedding']} /> : <p className="rounded-xl bg-slate-50 p-7 text-center text-xs text-slate-500">Tài liệu chưa có đoạn hoặc chưa tải dữ liệu.</p>}
      </section>
    </AdminShell>
  )
}

function Input({ label, value, onChange, type = 'text', required = false }: { label: string; value: string; onChange: (value: string) => void; type?: string; required?: boolean }) {
  return <label className="block"><span className="mb-1.5 block text-[10px] font-medium text-slate-500">{label}</span><input type={type} required={required} value={value} onChange={(event) => onChange(event.target.value)} className="h-9 w-full rounded-lg border border-slate-200 px-3 text-xs outline-none focus:border-blue-400" /></label>
}
