'use client'

import { useEffect, useMemo, useState } from 'react'
import { RefreshCw, Save, X } from 'lucide-react'
import { AdminShell } from '@/components/admin-shell'
import { ChartCard } from '@/components/admin-charts'
import { RecordsTable } from '@/components/records-table'
import { formatCell, useRemoteRows, type DataRow } from '@/components/remote-data'
import { getSupabaseBrowserClient } from '@/lib/supabase-browser'

type AssignmentTab = 'Bài tập' | 'Bài nộp'

export default function AssignmentsPage() {
  const supabase = useMemo(() => getSupabaseBrowserClient(), [])
  const [tab, setTab] = useState<AssignmentTab>('Bài tập')
  const [search, setSearch] = useState('')
  const [competitionId, setCompetitionId] = useState('')
  const [status, setStatus] = useState('')
  const [result, setResult] = useState('')
  const [rows, setRows] = useState<DataRow[]>([])
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState('')
  const [refresh, setRefresh] = useState(0)
  const [selected, setSelected] = useState<DataRow | null>(null)
  const [editForm, setEditForm] = useState({ staffId: '', reason: '', score: '', state: '', comment: '' })
  const [saving, setSaving] = useState(false)
  const [message, setMessage] = useState('')

  const submissionStatus = useRemoteRows({ kind: 'view', name: 'vw_baocao_phanbo_trangthai_bainop' }, refresh)
  const failByAssignment = useRemoteRows({ kind: 'view', name: 'vw_baitap_tyle_khong_dat_cao' }, refresh)
  const failByRegion = useRemoteRows({ kind: 'view', name: 'vw_tyle_khong_dat_theo_khuvuc' }, refresh)
  const competitions = useRemoteRows({ kind: 'view', name: 'vw_pm_vong_thi' }, refresh)

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
      try {
        const response = tab === 'Bài tập'
          ? await supabase.rpc('fn_baitap_tim_kiem', {
            p_tu_khoa: search || null,
            p_trang_thai: status || null,
            p_cuoc_thi_id: competitionId || null,
            p_trang: 1,
            p_kich_thuoc_trang: 100,
          })
          : await supabase.rpc('fn_bainop_tim_kiem', {
            p_tu_khoa: search || null,
            p_ket_qua: result || null,
            p_bai_tap_id: null,
            p_trang_thai: status || null,
            p_trang: 1,
            p_kich_thuoc_trang: 100,
          })
        if (!active) return
        if (response.error) {
          setRows([])
          setError(response.error.message)
        } else setRows(Array.isArray(response.data) ? response.data as DataRow[] : [])
      } catch (loadError) {
        if (!active) return
        setRows([])
        setError(loadError instanceof Error ? loadError.message : String(loadError))
      } finally {
        if (active) setLoading(false)
      }
    }
    void load()
    return () => { active = false }
  }, [competitionId, result, search, status, supabase, tab, refresh])

  async function saveSubmission() {
    if (!selected || !supabase) return
    const submissionId = selected.bai_nop_id
    if (!submissionId || !editForm.staffId || !editForm.reason.trim()) {
      setMessage('Cần nhập mã nhân viên đang hoạt động và lý do chỉnh sửa.')
      return
    }
    setSaving(true)
    setMessage('')
    const { error: saveError } = await supabase.rpc('sp_bainop_chinh_sua_trang_thai', {
      p_bai_nop_id: submissionId,
      p_ly_do: editForm.reason.trim(),
      p_nhan_vien_id: editForm.staffId.trim(),
      p_diem_moi: editForm.score === '' ? null : Number(editForm.score),
      p_trang_thai_moi: editForm.state || null,
      p_nhan_xet_moi: editForm.comment || null,
    })
    if (saveError) setMessage(`Không lưu được: ${saveError.message}`)
    else {
      setMessage('Đã cập nhật bài nộp.')
      setSelected(null)
      setRefresh((value) => value + 1)
    }
    setSaving(false)
  }

  return (
    <AdminShell active="Bài tập & bài nộp" title="Bài tập & Bài nộp">
      <div className="mb-5 flex flex-wrap items-end justify-between gap-3"><p className="text-sm text-slate-500">Theo dõi bài tập, kết quả làm bài và tiến độ chấm.</p><button onClick={() => setRefresh((value) => value + 1)} className="flex h-9 items-center gap-2 rounded-xl border border-slate-200 bg-white px-3 text-xs font-medium text-slate-600"><RefreshCw size={14} /> Làm mới</button></div>
      <div className="mb-5 grid gap-4 xl:grid-cols-3">
        <ChartCard title="Phân bố trạng thái bài nộp" data={submissionStatus.data} kind="pie" xKey="trang_thai" yKey="so_luong" height={260} />
        <ChartCard title="Tỷ lệ không đạt theo bài tập" data={failByAssignment.data} kind="bar" horizontal xKey="ten_bai_tap" yKey="tyle_khong_dat_pt" height={260} />
        <ChartCard title="Tỷ lệ không đạt theo khu vực" data={failByRegion.data} kind="bar" horizontal xKey="tinh_thanh" yKey="tyle_khong_dat_pt" height={260} />
      </div>
      <div className="mb-4 flex gap-2 border-b border-slate-200">
        {(['Bài tập', 'Bài nộp'] as AssignmentTab[]).map((item) => <button key={item} onClick={() => { setTab(item); setSearch(''); setStatus(''); setResult('') }} className={`border-b-2 px-4 py-3 text-xs font-semibold ${tab === item ? 'border-blue-600 text-blue-700' : 'border-transparent text-slate-500'}`}>{item}</button>)}
      </div>
      <RecordsTable title={`Danh sách ${tab.toLocaleLowerCase('vi')}`} data={rows} loading={loading} error={error} emptyText={search ? `Không tìm thấy ${tab.toLocaleLowerCase('vi')} phù hợp.` : `Chưa có dữ liệu ${tab.toLocaleLowerCase('vi')}.`} query={search} onQueryChange={setSearch} onRowClick={tab === 'Bài nộp' ? (row) => { setSelected(row); setMessage('') } : undefined} columns={tab === 'Bài tập' ? ['bai_tap_id', 'ten_bai_tap', 'cuoc_thi_id', 'bang', 'thoi_gian_lam_bai', 'diem_dat', 'so_cau_hoi', 'so_luong_da_nop', 'trang_thai'] : ['bai_nop_id', 'thi_sinh_id', 'ten_thi_sinh', 'ten_bai_tap', 'bang', 'lan_nop', 'tong_diem', 'diem_dat', 'ket_qua', 'thoi_gian_nop', 'trang_thai']}>
        <select aria-label="Lọc theo cuộc thi" value={competitionId} onChange={(event) => setCompetitionId(event.target.value)} className="h-9 rounded-lg border border-slate-200 bg-white px-2 text-xs"><option value="">Tất cả cuộc thi</option>{competitions.data.map((item) => <option key={String(item.cuoc_thi_id)} value={String(item.cuoc_thi_id)}>{String(item.ten_cuoc_thi)}</option>)}</select>
        <select aria-label="Lọc trạng thái" value={status} onChange={(event) => setStatus(event.target.value)} className="h-9 rounded-lg border border-slate-200 bg-white px-2 text-xs"><option value="">Tất cả trạng thái</option>{['DANG_MO', 'DANG_LAM', 'DA_NOP', 'DA_CHAM_DIEM', 'QUA_HAN_NOP'].map((state) => <option key={state} value={state}>{formatCell(state)}</option>)}</select>
        {tab === 'Bài nộp' && <select aria-label="Lọc kết quả" value={result} onChange={(event) => setResult(event.target.value)} className="h-9 rounded-lg border border-slate-200 bg-white px-2 text-xs"><option value="">Mọi kết quả</option><option value="DAT">Đạt</option><option value="KHONG_DAT">Không đạt</option><option value="CHUA_CO_DIEM">Chưa có điểm</option></select>}
      </RecordsTable>

      {selected && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-slate-950/40 p-4">
          <section role="dialog" aria-modal="true" className="w-full max-w-xl rounded-2xl bg-white p-5 shadow-xl">
            <div className="mb-4 flex items-center justify-between"><div><h2 className="text-sm font-bold text-slate-900">Chỉnh sửa bài nộp</h2><p className="mt-1 text-[11px] text-slate-400">{String(selected.bai_nop_id)}</p></div><button onClick={() => setSelected(null)} aria-label="Đóng" className="rounded-lg p-2 hover:bg-slate-100"><X size={17} /></button></div>
            <div className="grid gap-3 sm:grid-cols-2">
              <Input label="Mã nhân viên" value={editForm.staffId} onChange={(staffId) => setEditForm({ ...editForm, staffId })} required />
              <Input label="Điểm mới" type="number" value={editForm.score} onChange={(score) => setEditForm({ ...editForm, score })} />
              <label className="block"><span className="mb-1.5 block text-[10px] text-slate-500">Trạng thái mới</span><select value={editForm.state} onChange={(event) => setEditForm({ ...editForm, state: event.target.value })} className="h-9 w-full rounded-lg border border-slate-200 bg-white px-3 text-xs"><option value="">Giữ nguyên</option>{['DANG_LAM', 'DA_NOP', 'DA_CHAM_DIEM', 'QUA_HAN_NOP'].map((state) => <option key={state} value={state}>{formatCell(state)}</option>)}</select></label>
              <Input label="Nhận xét" value={editForm.comment} onChange={(comment) => setEditForm({ ...editForm, comment })} />
              <div className="sm:col-span-2"><Input label="Lý do chỉnh sửa (bắt buộc)" value={editForm.reason} onChange={(reason) => setEditForm({ ...editForm, reason })} required /></div>
            </div>
            {message && <p role="status" className="mt-3 rounded-lg bg-amber-50 p-3 text-xs text-amber-800">{message}</p>}
            <button onClick={() => void saveSubmission()} disabled={saving} className="mt-4 flex h-10 w-full items-center justify-center gap-2 rounded-xl bg-blue-600 text-xs font-semibold text-white disabled:opacity-50"><Save size={14} />{saving ? 'Đang lưu…' : 'Lưu thay đổi'}</button>
          </section>
        </div>
      )}
    </AdminShell>
  )
}

function Input({ label, value, onChange, type = 'text', required = false }: { label: string; value: string; onChange: (value: string) => void; type?: string; required?: boolean }) {
  return <label className="block"><span className="mb-1.5 block text-[10px] font-medium text-slate-500">{label}{required ? ' *' : ''}</span><input type={type} value={value} onChange={(event) => onChange(event.target.value)} className="h-9 w-full rounded-lg border border-slate-200 px-3 text-xs outline-none focus:border-blue-400" /></label>
}
