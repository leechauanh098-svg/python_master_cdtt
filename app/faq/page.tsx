'use client'

import { useEffect, useMemo, useState } from 'react'
import { Check, FolderTree, RefreshCw, Search, Star } from 'lucide-react'
import { AdminShell } from '@/components/admin-shell'
import { RecordsTable } from '@/components/records-table'
import { formatCell, useRemoteRows, type DataRow } from '@/components/remote-data'

export default function FAQPage() {
  const tree = useRemoteRows({ kind: 'view', name: 'vw_faq_cay_danhmuc' })
  const summary = useRemoteRows({ kind: 'view', name: 'vw_faq_tongquan' })
  const supabase = summary.client
  const [categoryId, setCategoryId] = useState('')
  const [search, setSearch] = useState('')
  const [faqs, setFaqs] = useState<DataRow[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')
  const [selected, setSelected] = useState<DataRow | null>(null)
  const [detail, setDetail] = useState<DataRow | null>(null)
  const [staffId, setStaffId] = useState('')
  const [edit, setEdit] = useState({ question: '', answer: '' })
  const [rating, setRating] = useState(5)
  const [message, setMessage] = useState('')
  const [refresh, setRefresh] = useState(0)
  const [saving, setSaving] = useState(false)

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
      const response = search.trim()
        ? await supabase.rpc('fn_faq_tim_kiem', { p_tu_khoa: search.trim() })
        : await supabase.rpc('fn_faq_danh_sach_theo_danh_muc', { p_danh_muc_id: categoryId || null })
      if (!active) return
      if (response.error) {
        setFaqs([])
        setError(response.error.message)
      } else setFaqs(Array.isArray(response.data) ? response.data as DataRow[] : [])
      setLoading(false)
    }
    void load()
    return () => { active = false }
  }, [categoryId, refresh, search, supabase])

  async function viewFAQ(row: DataRow) {
    const id = row.faq_id
    if (!id || !supabase) return
    setSelected(row)
    setDetail(null)
    setMessage('')
    const { data, error: detailError } = await supabase.rpc('fn_faq_xem_chi_tiet', { p_faq_id: id })
    if (detailError) setMessage(`Không tải được FAQ: ${detailError.message}`)
    else {
      const record = Array.isArray(data) ? data[0] as DataRow | undefined : data as DataRow | null
      setDetail(record ?? null)
      setEdit({ question: String(record?.cau_hoi_chuan ?? ''), answer: String(record?.cau_tra_loi_chuan ?? '') })
    }
  }

  async function saveFAQ() {
    if (!supabase || !selected || !staffId.trim()) {
      setMessage('Nhập mã nhân viên đang hoạt động để chỉnh sửa FAQ.')
      return
    }
    setSaving(true)
    const { error: saveError } = await supabase.rpc('fn_faq_sua', {
      p_faq_id: selected.faq_id,
      p_nguoi_sua: staffId.trim(),
      p_danh_muc_id: null,
      p_cau_hoi_chuan: edit.question.trim(),
      p_cau_tra_loi_chuan: edit.answer.trim(),
    })
    if (saveError) setMessage(`Không lưu được FAQ: ${saveError.message}`)
    else {
      setMessage('Đã lưu nội dung FAQ.')
      setRefresh((value) => value + 1)
      setDetail({ ...detail, cau_hoi_chuan: edit.question, cau_tra_loi_chuan: edit.answer })
    }
    setSaving(false)
  }

  async function rateFAQ() {
    if (!supabase || !selected) return
    const { error: rateError } = await supabase.rpc('fn_faq_danh_gia_hai_long', {
      p_faq_id: selected.faq_id,
      p_diem: rating,
    })
    setMessage(rateError ? `Không gửi được đánh giá: ${rateError.message}` : 'Đã ghi nhận đánh giá hữu ích.')
    if (!rateError) setRefresh((value) => value + 1)
  }

  const metrics = summary.data[0] ? Object.entries(summary.data[0]) : []
  const categories = useMemo(() => [...tree.data].sort((a, b) => Number(a.cap ?? 0) - Number(b.cap ?? 0)), [tree.data])

  return (
    <AdminShell active="Quản lý FAQ" title="Quản lý FAQ">
      <div className="mb-5 flex flex-wrap items-end justify-between gap-3"><p className="text-sm text-slate-500">Quản lý câu hỏi thường gặp và danh mục nội dung.</p><button onClick={() => setRefresh((value) => value + 1)} className="flex h-9 items-center gap-2 rounded-xl border border-slate-200 bg-white px-3 text-xs font-medium text-slate-600"><RefreshCw size={14} /> Làm mới</button></div>
      <div className="mb-5 grid gap-3 md:grid-cols-3">
        {['Tổng câu hỏi đã duyệt', 'Lượt xem tích lũy', 'Tỷ lệ hữu ích (%)'].map((label, index) => <article key={label} className="rounded-2xl border border-slate-200 bg-white p-4"><div className="flex items-center justify-between"><p className="text-[10px] text-slate-500">{label}</p><span className="rounded-lg bg-blue-50 p-2 text-blue-600"><FolderTree size={14} /></span></div><p className="mt-3 text-2xl font-bold text-slate-900">{summary.loading ? '…' : formatCell(metrics[index]?.[1])}{index === 2 && metrics[index] ? '%' : ''}</p>{summary.error && <p className="mt-1 text-[10px] text-rose-600">{summary.error}</p>}</article>)}
      </div>
      <div className="grid items-start gap-4 xl:grid-cols-[minmax(240px,0.65fr)_minmax(0,1.8fr)]">
        <section className="rounded-2xl border border-slate-200 bg-white p-5 shadow-sm shadow-slate-100/70">
          <div className="mb-4 flex items-center gap-2"><FolderTree size={16} className="text-blue-600" /><div><h2 className="text-sm font-bold text-slate-900">Cây danh mục</h2><p className="text-[11px] text-slate-400">Chọn danh mục để lọc FAQ.</p></div></div>
          <button onClick={() => { setCategoryId(''); setSearch('') }} className={`mb-1 flex w-full items-center justify-between rounded-lg px-3 py-2.5 text-left text-xs ${!categoryId ? 'bg-blue-50 font-semibold text-blue-700' : 'text-slate-600 hover:bg-slate-50'}`}><span>Tất cả danh mục</span><span>{categories.reduce((sum, item) => sum + Number(item.so_cau_hoi ?? 0), 0)}</span></button>
          {tree.error ? <p role="alert" className="mt-3 rounded-lg bg-rose-50 p-3 text-xs text-rose-700">{tree.error}</p> : tree.loading ? <p className="p-5 text-xs text-slate-500">Đang tải danh mục…</p> : categories.map((item, index) => <button key={String(item.danh_muc_id ?? index)} onClick={() => { setCategoryId(String(item.danh_muc_id ?? '')); setSearch('') }} className={`mb-1 flex w-full items-center justify-between rounded-lg px-3 py-2.5 text-left text-xs hover:bg-blue-50 ${categoryId === item.danh_muc_id ? 'bg-blue-50 font-semibold text-blue-700' : 'text-slate-600'}`} style={{ paddingLeft: `${12 + Math.min(Number(item.cap ?? 0), 5) * 14}px` }}><span className="truncate">{String(item.ten_danh_muc ?? '')}</span><span className="ml-2 shrink-0 text-[10px] text-slate-400">{formatCell(item.so_cau_hoi)}</span></button>)}
        </section>
        <div className="space-y-4">
          <RecordsTable title="Danh sách FAQ" data={faqs} loading={loading} error={error} query={search} onQueryChange={(value) => { setSearch(value); if (value) setCategoryId('') }} onRowClick={viewFAQ} columns={['faq_id', 'danh_muc', 'cau_hoi_chuan', 'cau_tra_loi_chuan', 'luot_xem', 'trang_thai']} />
          {selected && (
            <section className="rounded-2xl border border-slate-200 bg-white p-5 shadow-sm shadow-slate-100/70">
              <div className="mb-4"><h2 className="text-sm font-bold text-slate-900">Chi tiết và chỉnh sửa FAQ</h2><p className="mt-1 text-[11px] text-slate-400">Mã FAQ: {String(selected.faq_id)}</p></div>
              {message && <p role="status" className="mb-3 rounded-lg bg-blue-50 p-3 text-xs text-blue-800">{message}</p>}
              {!detail ? <p className="py-4 text-xs text-slate-500">Đang tải nội dung chi tiết…</p> : <div className="space-y-3">
                <label className="block"><span className="mb-1.5 block text-[10px] text-slate-500">Câu hỏi chuẩn</span><input value={edit.question} onChange={(event) => setEdit({ ...edit, question: event.target.value })} className="h-10 w-full rounded-lg border border-slate-200 px-3 text-xs" /></label>
                <label className="block"><span className="mb-1.5 block text-[10px] text-slate-500">Câu trả lời chuẩn</span><textarea rows={5} value={edit.answer} onChange={(event) => setEdit({ ...edit, answer: event.target.value })} className="w-full rounded-lg border border-slate-200 p-3 text-xs leading-5" /></label>
                <label className="block"><span className="mb-1.5 block text-[10px] text-slate-500">Mã nhân viên chỉnh sửa</span><input value={staffId} onChange={(event) => setStaffId(event.target.value)} placeholder="Mã nhân viên đang hoạt động" className="h-9 w-full rounded-lg border border-slate-200 px-3 text-xs" /></label>
                <button onClick={() => void saveFAQ()} disabled={saving} className="h-9 rounded-lg bg-blue-600 px-4 text-xs font-semibold text-white disabled:opacity-50">{saving ? 'Đang lưu…' : 'Lưu FAQ'}</button>
                <div className="flex flex-wrap items-center gap-2 border-t border-slate-100 pt-4"><span className="flex items-center gap-1 text-[10px] font-medium text-slate-500"><Star size={13} className="text-amber-500" /> Đánh giá hữu ích</span><select value={rating} onChange={(event) => setRating(Number(event.target.value))} className="h-8 rounded-lg border border-slate-200 bg-white px-2 text-xs">{[1, 2, 3, 4, 5].map((score) => <option key={score} value={score}>{score} / 5</option>)}</select><button onClick={() => void rateFAQ()} className="flex h-8 items-center gap-1 rounded-lg border border-slate-200 px-3 text-xs text-slate-600"><Check size={13} /> Gửi đánh giá</button></div>
              </div>}
            </section>
          )}
        </div>
      </div>
    </AdminShell>
  )
}
