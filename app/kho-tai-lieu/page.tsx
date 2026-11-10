'use client'

import { useEffect, useMemo, useState } from 'react'
import { Download, FilePlus2, RefreshCw, Search, UploadCloud } from 'lucide-react'
import { AdminShell } from '@/components/admin-shell'
import { RecordsTable } from '@/components/records-table'
import { formatCell, type DataRow } from '@/components/remote-data'
import { getSupabaseBrowserClient } from '@/lib/supabase-browser'

const documentTypes = [
  { value: 'QUY_CHE', label: 'Quy chế' },
  { value: 'HO_TRO_KY_THUAT', label: 'Hỗ trợ kỹ thuật' },
  { value: 'DE_THI_MAU', label: 'Đề thi mẫu' },
  { value: 'TAI_TRO_DOI_TAC', label: 'Tài trợ đối tác' },
  { value: 'TAI_LIEU_KY_THUAT', label: 'Tài liệu kỹ thuật' },
]
const documentBucket = 'knowledge-documents'
const maxFileSize = 50 * 1024 * 1024
const allowedExtensions = new Set(['pdf', 'doc', 'docx', 'txt', 'csv', 'xlsx'])

export default function KnowledgeBasePage() {
  const [refresh, setRefresh] = useState(0)
  const supabase = useMemo(() => getSupabaseBrowserClient(), [])
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
  const [formMessage, setFormMessage] = useState('')
  const [uploading, setUploading] = useState(false)
  const [signedDownloadUrl, setSignedDownloadUrl] = useState('')
  const [selectedFile, setSelectedFile] = useState<File | null>(null)
  const [fileInputKey, setFileInputKey] = useState(0)
  const [newDocument, setNewDocument] = useState({ id: '', title: '', type: '' })

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
    setSignedDownloadUrl('')
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
    if (!supabase || !staffId.trim() || !selectedFile) {
      setFormMessage('Nhập mã nhân viên đang hoạt động và chọn tệp cần tải lên.')
      return
    }
    if (selectedFile.size > maxFileSize) {
      setFormMessage('Tệp vượt quá giới hạn 50 MB.')
      return
    }
    const extension = selectedFile.name.split('.').pop()?.toLowerCase() ?? ''
    if (!allowedExtensions.has(extension)) {
      setFormMessage('Định dạng chưa được hỗ trợ. Hãy chọn PDF, DOC, DOCX, TXT, CSV hoặc XLSX.')
      return
    }

    setUploading(true)
    setFormMessage('')
    let uploadedPath: string | null = null
    try {
      const { data: userData, error: userError } = await supabase.auth.getUser()
      if (userError) throw new Error(`Không xác thực được tài khoản tải tệp: ${userError.message}`)
      if (!userData.user) throw new Error('Phiên đăng nhập đã hết hạn. Hãy đăng nhập lại.')

      const safeFileName = selectedFile.name.replace(/[^a-zA-Z0-9._-]/g, '_')
      const objectPath = `${userData.user.id}/${newDocument.id.trim()}/${crypto.randomUUID()}-${safeFileName}`
      const { error: uploadError } = await supabase.storage
        .from(documentBucket)
        .upload(objectPath, selectedFile, {
          contentType: selectedFile.type || 'application/octet-stream',
          upsert: false,
        })
      if (uploadError) throw new Error(`Không tải được tệp lên kho lưu trữ: ${uploadError.message}`)
      uploadedPath = objectPath

      const { data: fileUrl } = supabase.storage.from(documentBucket).getPublicUrl(objectPath)
      const { error: responseError } = await supabase.rpc('fn_tailieu_them_moi', {
        p_tai_lieu_id: newDocument.id.trim(),
        p_ten_tai_lieu: newDocument.title.trim(),
        p_loai_tai_lieu: newDocument.type,
        p_url_luu_tru: fileUrl.publicUrl,
        p_tao_boi: staffId.trim(),
        p_danh_muc_id: null,
        p_ten_file_goc: selectedFile.name,
        p_dung_luong_byte: selectedFile.size,
      })
      if (responseError) {
        const { error: cleanupError } = await supabase.storage.from(documentBucket).remove([objectPath])
        uploadedPath = null
        if (cleanupError) {
          throw new Error(`Không lưu được thông tin tài liệu: ${responseError.message}. Dọn tệp tải lên cũng thất bại: ${cleanupError.message}`)
        }
        throw new Error(`Không lưu được thông tin tài liệu: ${responseError.message}`)
      }

      setFormMessage('Đã tải tệp lên và thêm tài liệu vào kho.')
      setNewDocument({ id: '', title: '', type: '' })
      setSelectedFile(null)
      setFileInputKey((value) => value + 1)
      setRefresh((value) => value + 1)
    } catch (error) {
      if (uploadedPath !== null) {
        const { error: cleanupError } = await supabase.storage.from(documentBucket).remove([uploadedPath])
        const message = error instanceof Error ? error.message : String(error)
        setFormMessage(cleanupError
          ? `${message}. Không dọn được tệp đã tải lên: ${cleanupError.message}`
          : message)
      } else {
        setFormMessage(error instanceof Error ? error.message : String(error))
      }
    } finally {
      setUploading(false)
    }
  }

  async function downloadSelectedFile() {
    if (!supabase || !selectedId) return
    const selectedDocument = documents.find((document) => document.tai_lieu_id === selectedId)
    const storedUrl = selectedDocument?.url_luu_tru
    if (typeof storedUrl !== 'string') {
      setActionMessage('Không tìm thấy đường dẫn tệp của tài liệu này.')
      return
    }

    try {
      const fileUrl = new URL(storedUrl)
      const publicObjectPrefix = `/storage/v1/object/public/${documentBucket}/`
      const prefixIndex = fileUrl.pathname.indexOf(publicObjectPrefix)
      if (prefixIndex < 0) throw new Error('Đường dẫn tệp không thuộc kho tài liệu nội bộ.')
      const objectPath = decodeURIComponent(fileUrl.pathname.slice(prefixIndex + publicObjectPrefix.length))
      const { data, error: signedUrlError } = await supabase.storage
        .from(documentBucket)
        .createSignedUrl(objectPath, 60, { download: String(selectedDocument?.ten_file_goc ?? true) })
      if (signedUrlError) throw new Error(`Không tạo được liên kết tải tệp: ${signedUrlError.message}`)
      setSignedDownloadUrl(data.signedUrl)
      setActionMessage('Liên kết tải tệp đã sẵn sàng và có hiệu lực trong 60 giây.')
    } catch (error) {
      setActionMessage(error instanceof Error ? error.message : String(error))
    }
  }

  return (
    <AdminShell active="Kho tài liệu RAG" title="Kho Tài liệu RAG">
      <div className="mb-5 flex flex-wrap items-end justify-between gap-3"><p className="text-sm text-slate-500">Quản lý tài liệu, nội dung phân đoạn và chỉ mục tìm kiếm.</p><button onClick={() => setRefresh((value) => value + 1)} className="flex h-9 items-center gap-2 rounded-xl border border-slate-200 bg-white px-3 text-xs font-medium text-slate-600"><RefreshCw size={14} /> Làm mới</button></div>
      <section className="mb-5 rounded-2xl border border-slate-200 bg-white p-5 shadow-sm shadow-slate-100/70">
        <div className="mb-3 flex items-center gap-2"><FilePlus2 size={16} className="text-blue-600" /><div><h2 className="text-base font-bold text-slate-900">Thêm tài liệu mới</h2><p className="text-sm text-slate-500">Tệp được lưu riêng tư; chỉ nhân viên đang hoạt động mới có thể truy cập.</p></div></div>
        <form onSubmit={createDocument} className="grid gap-3 sm:grid-cols-2 xl:grid-cols-3">
          <Input label="Mã tài liệu" value={newDocument.id} onChange={(id) => setNewDocument({ ...newDocument, id })} required />
          <Input label="Tên tài liệu" value={newDocument.title} onChange={(title) => setNewDocument({ ...newDocument, title })} required />
          <label className="block">
            <span className="mb-1.5 block text-sm font-medium text-slate-600">Loại tài liệu</span>
            <select
              required
              value={newDocument.type}
              onChange={(event) => setNewDocument({ ...newDocument, type: event.target.value })}
              className="h-10 w-full rounded-lg border border-slate-200 bg-white px-3 text-sm outline-none focus:border-blue-400"
            >
              <option value="" disabled>Chọn loại tài liệu</option>
              {documentTypes.map((item) => <option key={item.value} value={item.value}>{item.label}</option>)}
            </select>
          </label>
          <label className="block sm:col-span-2 xl:col-span-1">
            <span className="mb-1.5 block text-sm font-medium text-slate-600">Tệp tài liệu</span>
            <span className="flex min-h-10 items-center gap-2 rounded-lg border border-slate-200 bg-white px-3 py-2 text-sm text-slate-600">
              <UploadCloud size={16} className="shrink-0 text-blue-600" />
              <input
                key={fileInputKey}
                type="file"
                required
                accept=".pdf,.doc,.docx,.txt,.csv,.xlsx"
                onChange={(event) => setSelectedFile(event.target.files?.[0] ?? null)}
                className="min-w-0 flex-1 text-xs file:mr-3 file:rounded-md file:border-0 file:bg-blue-50 file:px-3 file:py-1.5 file:font-semibold file:text-blue-700"
              />
            </span>
            <span className="mt-1 block text-xs text-slate-500">PDF, DOC, DOCX, TXT, CSV, XLSX · tối đa 50 MB</span>
          </label>
          <label className="block xl:col-span-1"><span className="mb-1.5 block text-sm font-medium text-slate-600">Mã nhân viên tạo tài liệu</span><input value={staffId} onChange={(event) => setStaffId(event.target.value)} placeholder="Nhập mã nhân viên" className="h-10 w-full rounded-lg border border-slate-200 px-3 text-sm outline-none focus:border-blue-400" /></label>
          <div className="flex items-end">
            <button disabled={uploading} className="flex h-10 items-center justify-center gap-2 rounded-lg bg-blue-600 px-4 text-sm font-semibold text-white hover:bg-blue-700 disabled:cursor-wait disabled:opacity-60">
              <UploadCloud size={16} /> {uploading ? 'Đang tải tệp…' : 'Tải tệp lên & thêm tài liệu'}
            </button>
          </div>
        </form>
        {selectedFile && <p className="mt-3 text-sm text-slate-600">Đã chọn: <span className="font-semibold">{selectedFile.name}</span> ({formatCell(Math.ceil(selectedFile.size / 1024))} KB)</p>}
        {formMessage && <p role={formMessage.startsWith('Đã tải') ? 'status' : 'alert'} className={`mt-3 rounded-lg p-3 text-sm leading-6 ${formMessage.startsWith('Đã tải') ? 'bg-blue-50 text-blue-800' : 'bg-rose-50 text-rose-700'}`}>{formMessage}</p>}
      </section>
      <RecordsTable title="Danh sách tài liệu" data={documents} loading={loading} error={error} query={search} onQueryChange={setSearch} onRowClick={(row) => void loadChunks(String(row.tai_lieu_id ?? ''))} columns={['tai_lieu_id', 'ten_tai_lieu', 'ten_file_goc', 'danh_muc_hien_thi', 'loai_tai_lieu', 'dung_luong_mb', 'trang_thai', 'so_doan', 'ngay_dang_tai']}>
        <select aria-label="Lọc loại tài liệu" value={kind} onChange={(event) => setKind(event.target.value)} className="h-9 rounded-lg border border-slate-200 bg-white px-2 text-xs"><option value="">Tất cả loại</option>{documentTypes.map((item) => <option key={item.value} value={item.value}>{item.label}</option>)}</select>
        <select aria-label="Lọc trạng thái" value={status} onChange={(event) => setStatus(event.target.value)} className="h-9 rounded-lg border border-slate-200 bg-white px-2 text-xs"><option value="">Tất cả trạng thái</option>{['NOI_BO', 'CONG_KHAI', 'AN'].map((value) => <option key={value} value={value}>{formatCell(value)}</option>)}</select>
      </RecordsTable>
      <section className="mt-5 rounded-2xl border border-slate-200 bg-white p-5">
        <div className="mb-4 flex flex-wrap items-start justify-between gap-3"><div><h2 className="text-sm font-bold text-slate-900">Các đoạn tài liệu</h2><p className="mt-1 text-[11px] text-slate-400">{selectedId || 'Chọn một tài liệu trong danh sách để xem các đoạn.'}</p></div><div className="flex flex-wrap gap-2">{signedDownloadUrl ? <a href={signedDownloadUrl} target="_blank" rel="noopener noreferrer" className="flex h-9 items-center gap-2 rounded-lg bg-blue-600 px-3 text-xs font-semibold text-white"><Download size={14} /> Tải tệp xuống</a> : <button onClick={() => void downloadSelectedFile()} disabled={!selectedId} className="flex h-9 items-center gap-2 rounded-lg border border-blue-200 bg-blue-50 px-3 text-xs font-semibold text-blue-700 disabled:opacity-40"><Download size={14} /> Tạo liên kết tải tệp</button>}<input aria-label="Mã nhân viên re-index" value={staffId} onChange={(event) => setStaffId(event.target.value)} placeholder="Mã nhân viên" className="h-9 w-36 rounded-lg border border-slate-200 px-3 text-xs" /><button onClick={() => void reindex()} disabled={!selectedId} className="h-9 rounded-lg border border-amber-200 bg-amber-50 px-3 text-xs font-semibold text-amber-800 disabled:opacity-40">Re-index</button></div></div>
        {actionMessage && <p role="status" className="mb-3 rounded-lg bg-blue-50 p-3 text-xs leading-5 text-blue-800">{actionMessage}</p>}
        {!selectedId ? <p className="rounded-xl bg-slate-50 p-7 text-center text-xs text-slate-500">Chưa chọn tài liệu.</p> : chunks.length ? <RecordsTable title="Nội dung đoạn" data={chunks} loading={false} error="" columns={['thu_tu_doan', 'vector_id_hien_thi', 'noi_dung_rut_gon', 'da_co_embedding']} /> : <p className="rounded-xl bg-slate-50 p-7 text-center text-xs text-slate-500">Tài liệu chưa có đoạn hoặc chưa tải dữ liệu.</p>}
      </section>
    </AdminShell>
  )
}

function Input({ label, value, onChange, type = 'text', required = false }: { label: string; value: string; onChange: (value: string) => void; type?: string; required?: boolean }) {
  return <label className="block"><span className="mb-1.5 block text-sm font-medium text-slate-600">{label}</span><input type={type} required={required} value={value} onChange={(event) => onChange(event.target.value)} className="h-10 w-full rounded-lg border border-slate-200 px-3 text-sm outline-none focus:border-blue-400 focus:ring-2 focus:ring-blue-100" /></label>
}
