'use client'

import { useEffect, useMemo, useState } from 'react'
import { FileText, RefreshCw } from 'lucide-react'
import { AdminShell } from '@/components/admin-shell'
import { RecordsTable } from '@/components/records-table'
import { formatCell, formatFieldLabel, type DataRow } from '@/components/remote-data'
import { getSupabaseBrowserClient } from '@/lib/supabase-browser'

type PartnerTab = 'Tài trợ đồng hành' | 'Cung cấp thí sinh'

const sponsorTiers = [
  { value: 'KIM_CUONG', label: 'Kim cương' },
  { value: 'VANG', label: 'Vàng' },
  { value: 'BAC', label: 'Bạc' },
  { value: 'DONG', label: 'Đồng' },
  { value: 'DONG_HANH', label: 'Đồng hành' },
]

export default function PartnersPage() {
  const supabase = useMemo(() => getSupabaseBrowserClient(), [])
  const [tab, setTab] = useState<PartnerTab>('Tài trợ đồng hành')
  const [search, setSearch] = useState('')
  const [tier, setTier] = useState('')
  const [sponsorType, setSponsorType] = useState('')
  const [rows, setRows] = useState<DataRow[]>([])
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState('')
  const [invoiceId, setInvoiceId] = useState('')
  const [invoice, setInvoice] = useState<DataRow | null>(null)
  const [invoiceError, setInvoiceError] = useState('')
  const [refresh, setRefresh] = useState(0)

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
        let result: DataRow[] = []
        if (tab === 'Cung cấp thí sinh') {
          const { data, error: responseError } = await supabase.from('vw_doitac_cungcap_ds').select('*')
          if (responseError) throw new Error(responseError.message)
          result = Array.isArray(data) ? data as DataRow[] : []
        } else {
          let matchingIds: string[] | null = null
          if (search.trim()) {
            const { data, error: searchError } = await supabase.rpc('fn_doitac_taitro_tim_kiem', { p_tu_khoa: search.trim() })
            if (searchError) throw new Error(searchError.message)
            matchingIds = (Array.isArray(data) ? data as DataRow[] : [])
              .map((row) => row.doanh_nghiep_id)
              .filter((id): id is string => typeof id === 'string')
            if (matchingIds.length === 0) {
              if (active) setRows([])
              return
            }
          }

          let request = supabase.from('vw_doitac_taitro_ds').select('*')
          if (tier) request = request.eq('cap_do_tai_tro', tier)
          if (sponsorType) request = request.eq('loai_tai_tro', sponsorType)
          if (matchingIds) request = request.in('doanh_nghiep_id', matchingIds)

          const { data, error: responseError } = await request
          if (responseError) throw new Error(responseError.message)
          result = Array.isArray(data) ? data as DataRow[] : []
        }
        if (active) {
          setRows(result)
          setError('')
        }
      } catch (loadError) {
        if (active) {
          setRows([])
          setError(loadError instanceof Error ? loadError.message : String(loadError))
        }
      } finally {
        if (active) setLoading(false)
      }
    }
    void load()
    return () => { active = false }
  }, [search, sponsorType, supabase, tab, tier, refresh])

  async function loadInvoice() {
    if (!supabase || !invoiceId.trim()) return
    setInvoiceError('')
    const { data, error: responseError } = await supabase.rpc('fn_doitac_cungcap_hoa_don', { p_doanh_nghiep_id: invoiceId.trim() })
    if (responseError) {
      setInvoice(null)
      setInvoiceError(responseError.message)
    } else {
      setInvoice(Array.isArray(data) ? data[0] ?? null : data as DataRow | null)
    }
  }

  const invoiceItems = invoice ? Object.entries(invoice) : []

  return (
    <AdminShell active="Đối tác đồng hành" title="Quản lý Đối tác">
      <div className="mb-5 flex flex-wrap items-end justify-between gap-3">
        <p className="text-sm text-slate-500">Quản lý nhà tài trợ đồng hành và đối tác cung cấp thí sinh.</p>
        <button onClick={() => setRefresh((value) => value + 1)} className="flex h-9 items-center gap-2 rounded-xl border border-slate-200 bg-white px-3 text-xs font-medium text-slate-600"><RefreshCw size={14} /> Làm mới</button>
      </div>
      <div className="mb-5 flex gap-2 border-b border-slate-200">
        {(['Tài trợ đồng hành', 'Cung cấp thí sinh'] as PartnerTab[]).map((item) => <button key={item} onClick={() => { setTab(item); setSearch(''); setTier(''); setSponsorType('') }} className={`border-b-2 px-4 py-3 text-xs font-semibold ${tab === item ? 'border-blue-600 text-blue-700' : 'border-transparent text-slate-500'}`}>{item}</button>)}
      </div>

      {tab === 'Tài trợ đồng hành' ? (
        <>
          <RecordsTable title="Danh sách nhà tài trợ" data={rows} loading={loading} error={error} query={search} onQueryChange={setSearch} emptyText={tier || sponsorType || search ? 'Không có nhà tài trợ phù hợp với các bộ lọc đã chọn.' : 'Chưa có nhà tài trợ trong danh sách.'}>
            <select aria-label="Lọc cấp độ" value={tier} onChange={(event) => setTier(event.target.value)} className="h-9 rounded-lg border border-slate-200 bg-white px-2 text-xs"><option value="">Tất cả cấp độ</option>{sponsorTiers.map((item) => <option key={item.value} value={item.value}>{item.label}</option>)}</select>
            <select aria-label="Lọc loại tài trợ" value={sponsorType} onChange={(event) => setSponsorType(event.target.value)} className="h-9 rounded-lg border border-slate-200 bg-white px-2 text-xs"><option value="">Tất cả loại</option><option value="HIEN_KIM">Hiện kim</option><option value="HIEN_VAT">Hiện vật</option></select>
          </RecordsTable>
        </>
      ) : (
        <>
          <section className="mb-5 rounded-2xl border border-slate-200 bg-white p-5 shadow-sm shadow-slate-100/70">
            <div className="mb-3 flex items-center gap-2"><FileText size={16} className="text-blue-600" /><div><h2 className="text-sm font-bold text-slate-900">Hóa đơn hoa hồng</h2><p className="text-[11px] text-slate-400">Nhập mã đối tác để xem thông tin và in hóa đơn.</p></div></div>
            <div className="flex flex-wrap gap-2"><input value={invoiceId} onChange={(event) => setInvoiceId(event.target.value)} placeholder="Mã doanh nghiệp" className="h-9 min-w-[220px] rounded-lg border border-slate-200 px-3 text-xs outline-none focus:border-blue-400" /><button onClick={() => void loadInvoice()} className="h-9 rounded-lg bg-blue-600 px-4 text-xs font-semibold text-white">Tải hóa đơn</button><button onClick={() => window.print()} disabled={!invoice} className="h-9 rounded-lg border border-slate-200 px-4 text-xs font-semibold text-slate-600 disabled:opacity-40">In / lưu PDF</button></div>
            {invoiceError && <p role="alert" className="mt-3 rounded-lg bg-rose-50 p-3 text-xs text-rose-700">Không tải được hóa đơn: {invoiceError}</p>}
            {invoice && <div className="mt-4 grid gap-2 sm:grid-cols-2">{invoiceItems.map(([key, value]) => <div key={key} className="rounded-lg bg-slate-50 p-3"><p className="text-[10px] text-slate-400">{formatFieldLabel(key)}</p><p className="mt-1 text-xs font-medium text-slate-800">{formatCell(value)}</p></div>)}</div>}
          </section>
          <RecordsTable title="Danh sách đối tác cung cấp" data={rows} loading={loading} error={error} query={search} onQueryChange={setSearch} columns={['ma_gioi_thieu', 'ten_doanh_nghiep', 'so_luong_thi_sinh', 'tong_le_phi_thu_duoc', 'hoa_hong_phai_tra', 'trang_thai_doi_soat']} />
        </>
      )}
    </AdminShell>
  )
}
