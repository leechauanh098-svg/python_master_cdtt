'use client'

import { useEffect, useMemo, useState } from 'react'
import { Bot, MessageSquare, RefreshCw, Send, UserRound } from 'lucide-react'
import { AdminShell } from '@/components/admin-shell'
import { ChartCard } from '@/components/admin-charts'
import { formatCell, useRemoteRows, type DataRow } from '@/components/remote-data'

export default function ConversationPage() {
  const listSource = useRemoteRows({ kind: 'view', name: 'vw_ds_hoithoai' })
  const supabase = listSource.client
  const [conversations, setConversations] = useState<DataRow[]>([])
  const [thread, setThread] = useState<DataRow[]>([])
  const [selected, setSelected] = useState<DataRow | null>(null)
  const [search, setSearch] = useState('')
  const [staffId, setStaffId] = useState('')
  const [documentId, setDocumentId] = useState('')
  const [reply, setReply] = useState('')
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')
  const [actionMessage, setActionMessage] = useState('')
  const [refresh, setRefresh] = useState(0)
  const [sending, setSending] = useState(false)

  useEffect(() => {
    let active = true
    async function loadList() {
      if (!supabase) {
        setError('Chưa cấu hình kết nối Supabase.')
        setLoading(false)
        return
      }
      setLoading(true)
      const { data, error: responseError } = search.trim()
        ? await supabase.rpc('fn_hoithoai_tim_kiem_theo_ten', { p_tu_khoa: search.trim() })
        : await supabase.from('vw_ds_hoithoai').select('*').order('thoi_gian', { ascending: false }).limit(200)
      if (!active) return
      if (responseError) {
        setConversations([])
        setError(responseError.message)
      } else {
        const result = Array.isArray(data) ? data as DataRow[] : []
        setConversations(result)
        if (selected) {
          const current = result.find((row) => row.qna_id === selected.qna_id)
          if (current) setSelected(current)
        }
      }
      setLoading(false)
    }
    void loadList()
    return () => { active = false }
  }, [refresh, search, selected?.qna_id, supabase])

  useEffect(() => {
    let active = true
    async function loadThread() {
      if (!supabase || !selected) {
        setThread([])
        return
      }
      const { data, error: responseError } = await supabase.rpc('fn_hoithoai_chi_tiet', {
        p_thi_sinh_id: selected.thi_sinh_id ?? null,
        p_doanh_nghiep_id: selected.doanh_nghiep_id ?? null,
      })
      if (!active) return
      if (responseError) setActionMessage(`Không tải được hội thoại: ${responseError.message}`)
      else setThread(Array.isArray(data) ? data as DataRow[] : [])
    }
    void loadThread()
    return () => { active = false }
  }, [selected?.thi_sinh_id, selected?.doanh_nghiep_id, supabase, refresh])

  async function submitReply(isAi: boolean) {
    if (!supabase || !selected || !reply.trim() || !staffId.trim()) {
      setActionMessage('Chọn hội thoại, nhập nội dung và mã nhân viên đang hoạt động.')
      return
    }
    setSending(true)
    setActionMessage('')
    const response = isAi
      ? await supabase.rpc('fn_hoithoai_ai_tra_loi', {
        p_qna_id: selected.qna_id,
        p_noi_dung: reply.trim(),
        p_nhan_vien_id_ho_tro: staffId.trim(),
        p_tai_lieu_id: documentId.trim() || null,
      })
      : await supabase.rpc('fn_hoithoai_nhanvien_gui_tin_nhan', {
        p_qna_id: selected.qna_id,
        p_nhan_vien_id: staffId.trim(),
        p_noi_dung: reply.trim(),
      })
    if (response.error) setActionMessage(`Không gửi được: ${response.error.message}`)
    else {
      setActionMessage(isAi ? 'Đã lưu câu trả lời AI đã duyệt.' : 'Đã gửi câu trả lời.')
      setReply('')
      setRefresh((value) => value + 1)
    }
    setSending(false)
  }

  const otherConversations = useMemo(() => conversations.filter((row) => row.qna_id !== selected?.qna_id), [conversations, selected?.qna_id])
  const conversationsByStatus = useMemo(() => {
    const counts = new Map<string, number>()
    for (const conversation of conversations) {
      const status = String(conversation.trang_thai ?? 'Chưa xác định')
      counts.set(status, (counts.get(status) ?? 0) + 1)
    }
    return Array.from(counts, ([trang_thai, so_luong]) => ({ trang_thai, so_luong }))
  }, [conversations])
  const conversationsByEntity = useMemo(() => {
    const counts = new Map<string, number>()
    for (const conversation of conversations) {
      const entity = String(conversation.loai_doi_tuong ?? 'Chưa phân loại')
      counts.set(entity, (counts.get(entity) ?? 0) + 1)
    }
    return Array.from(counts, ([loai_doi_tuong, so_luong]) => ({ loai_doi_tuong, so_luong }))
  }, [conversations])

  return (
    <AdminShell active="Lịch sử Q&A" title="Lịch sử Q&A">
      <div className="mb-5 flex flex-wrap items-end justify-between gap-3"><p className="text-sm text-slate-500">Tìm kiếm và phản hồi trao đổi với thí sinh, doanh nghiệp.</p><button onClick={() => setRefresh((value) => value + 1)} className="flex h-9 items-center gap-2 rounded-xl border border-slate-200 bg-white px-3 text-xs font-medium text-slate-600"><RefreshCw size={14} /> Làm mới</button></div>
      <div className="mb-5 grid items-stretch gap-4 xl:grid-cols-2">
        <ChartCard title="Hội thoại theo trạng thái" description="Cơ cấu trạng thái trong kết quả truy vấn hiện tại." data={conversationsByStatus} kind="pie" xKey="trang_thai" yKey="so_luong" height={260} />
        <ChartCard title="Hội thoại theo nhóm đối tượng" description="So sánh lượng trao đổi từ thí sinh và doanh nghiệp trong kết quả hiện tại." data={conversationsByEntity} kind="bar" xKey="loai_doi_tuong" yKey="so_luong" height={260} />
      </div>
      <div className="grid min-h-[650px] gap-4 xl:grid-cols-[minmax(280px,0.8fr)_minmax(0,1.8fr)]">
        <section className="overflow-hidden rounded-2xl border border-slate-200 bg-white shadow-sm shadow-slate-100/70">
          <div className="border-b border-slate-100 p-4"><h2 className="text-sm font-bold text-slate-900">Danh sách hội thoại</h2><input value={search} onChange={(event) => setSearch(event.target.value)} placeholder="Tìm theo tên đối tượng…" className="mt-3 h-9 w-full rounded-lg border border-slate-200 px-3 text-xs outline-none focus:border-blue-400" /></div>
          <div className="max-h-[570px] overflow-y-auto">
            {error ? <p role="alert" className="m-4 rounded-lg bg-rose-50 p-3 text-xs text-rose-700">{error}</p> : loading ? <p className="p-8 text-center text-xs text-slate-500">Đang tải hội thoại…</p> : conversations.length ? conversations.map((row, index) => <button key={`${String(row.qna_id ?? 'qna')}-${index}`} onClick={() => { setSelected(row); setActionMessage('') }} className={`block w-full border-b border-slate-50 p-4 text-left hover:bg-blue-50/50 ${selected?.qna_id === row.qna_id ? 'bg-blue-50' : ''}`}><div className="flex items-center justify-between gap-2"><strong className="truncate text-xs text-slate-800">{String(row.ten_hien_thi ?? row.doi_tuong_id ?? 'Không rõ đối tượng')}</strong><span className="shrink-0 rounded-full bg-slate-100 px-2 py-1 text-[9px] text-slate-500">{String(row.loai_doi_tuong ?? '')}</span></div><p className="mt-2 line-clamp-2 text-[11px] leading-5 text-slate-500">{String(row.noi_dung_hoi ?? '')}</p><div className="mt-2 flex justify-between gap-2 text-[9px] text-slate-400"><span>{formatCell(row.trang_thai)}</span><span>{String(row.thoi_gian ?? '')}</span></div></button>) : <p className="p-8 text-center text-xs text-slate-500">Chưa có hội thoại phù hợp.</p>}
          </div>
        </section>
        <section className="flex min-h-[650px] flex-col rounded-2xl border border-slate-200 bg-white shadow-sm shadow-slate-100/70">
          <div className="flex items-center gap-3 border-b border-slate-100 p-4"><span className="flex h-9 w-9 items-center justify-center rounded-full bg-blue-100 text-blue-700"><UserRound size={16} /></span><div><h2 className="text-sm font-bold text-slate-900">{String(selected?.ten_hien_thi ?? 'Chọn một hội thoại')}</h2><p className="text-[10px] text-slate-400">{String(selected?.loai_doi_tuong ?? '')} {selected?.kenh_tuong_tac ? `· ${String(selected.kenh_tuong_tac)}` : ''}</p></div></div>
          <div className="flex-1 space-y-4 overflow-y-auto bg-slate-50/60 p-5">
            {selected ? (thread.length ? thread.map((item, index) => <div key={`${String(item.qna_id ?? 'qna')}-${index}`} className="space-y-3"><div className="mr-8 rounded-2xl rounded-tl-sm bg-white p-4 shadow-sm"><p className="mb-1 text-[9px] font-semibold uppercase text-slate-400">Câu hỏi</p><p className="whitespace-pre-wrap text-xs leading-5 text-slate-700">{String(item.noi_dung_hoi ?? '')}</p></div>{Boolean(item.noi_dung_tra_loi) && <div className="ml-8 rounded-2xl rounded-tr-sm bg-blue-100 p-4"><p className="mb-1 text-[9px] font-semibold uppercase text-blue-500">Câu trả lời</p><p className="whitespace-pre-wrap text-xs leading-5 text-slate-700">{String(item.noi_dung_tra_loi)}</p></div>}<p className="text-center text-[9px] text-slate-400">{String(item.thoi_gian ?? '')} · {formatCell(item.trang_thai)}</p></div>) : <p className="text-center text-xs text-slate-500">Chưa có nội dung chi tiết.</p>) : <p className="m-auto text-center text-xs text-slate-400">Chọn hội thoại ở danh sách bên trái để xem chi tiết.</p>}
          </div>
          <div className="border-t border-slate-100 p-4">
            {actionMessage && <p role="status" className="mb-3 rounded-lg bg-amber-50 p-3 text-xs text-amber-800">{actionMessage}</p>}
            <label className="mb-3 block"><span className="mb-1.5 block text-[10px] text-slate-500">Mã nhân viên hỗ trợ</span><input value={staffId} onChange={(event) => setStaffId(event.target.value)} placeholder="Nhập mã nhân viên đang hoạt động" className="h-9 w-full rounded-lg border border-slate-200 px-3 text-xs" /></label>
            <textarea value={reply} onChange={(event) => setReply(event.target.value)} disabled={!selected} placeholder="Nhập nội dung trả lời…" rows={3} className="w-full resize-y rounded-xl border border-slate-200 p-3 text-xs outline-none focus:border-blue-400 disabled:bg-slate-50" />
            <div className="mt-2 flex flex-wrap items-center justify-between gap-2"><label className="flex items-center gap-2 text-[10px] text-slate-500"><Bot size={14} /><span>Tài liệu tham chiếu (tùy chọn)</span><input value={documentId} onChange={(event) => setDocumentId(event.target.value)} placeholder="Mã tài liệu" className="h-8 w-32 rounded-lg border border-slate-200 px-2 text-[10px]" /></label><div className="flex gap-2"><button disabled={!selected || sending} onClick={() => void submitReply(true)} className="flex h-9 items-center gap-2 rounded-lg border border-blue-200 px-3 text-xs font-semibold text-blue-700 disabled:opacity-40"><Bot size={14} /> Lưu câu trả lời AI</button><button disabled={!selected || sending} onClick={() => void submitReply(false)} className="flex h-9 items-center gap-2 rounded-lg bg-blue-600 px-3 text-xs font-semibold text-white disabled:opacity-40"><Send size={14} /> Gửi</button></div></div>
            <p className="mt-2 text-[9px] text-slate-400">Chức năng AI lưu nội dung đã nhập; không tự sinh câu trả lời.</p>
          </div>
        </section>
      </div>
      <div className="sr-only" aria-hidden="true">{otherConversations.length} hội thoại khác</div>
    </AdminShell>
  )
}
