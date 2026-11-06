'use client'

import { useEffect, useMemo, useState } from 'react'
import { FileText, RefreshCw, Search, Users } from 'lucide-react'
import { AdminShell } from '@/components/admin-shell'
import { ChartCard } from '@/components/admin-charts'
import { RecordsTable } from '@/components/records-table'
import { useRemoteRows, type DataRow } from '@/components/remote-data'
import { getSupabaseBrowserClient } from '@/lib/supabase-browser'

type PartnerTab = 'Tài trợ đồng hành' | 'Cung cấp thí sinh'

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

  const sponsorSummary = useRemoteRows({ kind: 'view', name: 'vw_doitac_taitro_tong_quan' }, refresh)
  const pipeline = useRemoteRows({ kind: 'view', name: 'vw_doitac_taitro_pheu' }, refresh)
  const tiers = useRemoteRows({ kind: 'view', name: 'vw_doitac_taitro_theo_cap' }, refresh)
  const supplySummary = useRemoteRows({ kind: 'view', name: 'vw_doitac_cungcap_tong_quan' }, refresh)

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
      let response
      if (tab === 'Cung cấp thí sinh') {
        response = await supabase.from('vw_doitac_cungcap_ds').select('*')
      } else if (search.trim()) {
        response = await supabase.rpc('fn_doitac_taitro_tim_kiem', { p_tu_khoa: search.trim() })
      } else if (tier || sponsorType) {
        response = await supabase.rpc('fn_doitac_taitro_loc', {
          p_cap_do: tier || null,
          p_loai_tai_tro: sponsorType || null,
        })
      } else {
        response = await supabase.from('vw_doitac_taitro_ds').select('*')
      }
      if (!active) return
      if (response.error) {
        setRows([])
        setError(response.error.message)
      } else {
        const result = Array.isArray(response.data) ? response.data as DataRow[] : []
        const query = search.trim().toLocaleLowerCase('vi')
        setRows(result.filter((row) => {
          const matchesTier = !tier || String(row.cap_do_tai_tro ?? '') === tier
          const matchesType = !sponsorType || String(row.loai_tai_tro ?? '') === sponsorType
          const matchesText = !query || JSON.stringify(row).toLocaleLowerCase('vi').includes(query)
          return matchesTier && matchesType && matchesText
        }))
      }
      setLoading(false)
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
          <div className="mb-5 grid gap-3 sm:grid-cols-2 xl:grid-cols-4">
            <Stats source={sponsorSummary} labels={['Tổng số doanh nghiệp tài trợ', 'Tổng tiền hiện kim (VND)', 'Tổng quy đổi hiện vật (VND)', 'Tỷ lệ hoàn thành quyền lợi (%)']} />
          </div>
          <div className="mb-5 grid items-stretch gap-4 xl:grid-cols-2">
            <ChartCard title="Phễu tài trợ" description="Doanh nghiệp qua từng giai đoạn hợp tác." data={pipeline.data} kind="bar" horizontal xKey="giai_doan" yKey="so_luong" height={290} />
            <ChartCard title="Cơ cấu theo cấp độ" description="Tỷ trọng nhà tài trợ theo cấp." data={tiers.data} kind="pie" xKey="cap_do_tai_tro" yKey="so_luong_doanh_nghiep" height={290} />
          </div>
          <RecordsTable title="Danh sách nhà tài trợ" data={rows} loading={loading} error={error} query={search} onQueryChange={setSearch}>
            <select aria-label="Lọc cấp độ" value={tier} onChange={(event) => setTier(event.target.value)} className="h-9 rounded-lg border border-slate-200 bg-white px-2 text-xs"><option value="">Tất cả cấp độ</option>{tiers.data.map((row) => <option key={String(row.cap_do_tai_tro)} value={String(row.cap_do_tai_tro)}>{String(row.cap_do_tai_tro)}</option>)}</select>
            <select aria-label="Lọc loại tài trợ" value={sponsorType} onChange={(event) => setSponsorType(event.target.value)} className="h-9 rounded-lg border border-slate-200 bg-white px-2 text-xs"><option value="">Tất cả loại</option><option value="HIEN_KIM">Hiện kim</option><option value="HIEN_VAT">Hiện vật</option></select>
          </RecordsTable>
        </>
      ) : (
        <>
          <div className="mb-5 grid gap-3 sm:grid-cols-2 xl:grid-cols-4"><Stats source={supplySummary} labels={['Tổng số doanh nghiệp', 'Thí sinh từ doanh nghiệp', 'Lệ phí thu được (VND)', 'Hoa hồng cần chi trả (VND)']} /></div>
          <section className="mb-5 rounded-2xl border border-slate-200 bg-white p-5 shadow-sm shadow-slate-100/70">
            <div className="mb-3 flex items-center gap-2"><FileText size={16} className="text-blue-600" /><div><h2 className="text-sm font-bold text-slate-900">Hóa đơn hoa hồng</h2><p className="text-[11px] text-slate-400">Nhập mã đối tác để xem thông tin và in hóa đơn.</p></div></div>
            <div className="flex flex-wrap gap-2"><input value={invoiceId} onChange={(event) => setInvoiceId(event.target.value)} placeholder="Mã doanh nghiệp" className="h-9 min-w-[220px] rounded-lg border border-slate-200 px-3 text-xs outline-none focus:border-blue-400" /><button onClick={() => void loadInvoice()} className="h-9 rounded-lg bg-blue-600 px-4 text-xs font-semibold text-white">Tải hóa đơn</button><button onClick={() => window.print()} disabled={!invoice} className="h-9 rounded-lg border border-slate-200 px-4 text-xs font-semibold text-slate-600 disabled:opacity-40">In / lưu PDF</button></div>
            {invoiceError && <p role="alert" className="mt-3 rounded-lg bg-rose-50 p-3 text-xs text-rose-700">Không tải được hóa đơn: {invoiceError}</p>}
            {invoice && <div className="mt-4 grid gap-2 sm:grid-cols-2">{invoiceItems.map(([key, value]) => <div key={key} className="rounded-lg bg-slate-50 p-3"><p className="text-[10px] text-slate-400">{key.replaceAll('_', ' ')}</p><p className="mt-1 text-xs font-medium text-slate-800">{String(value ?? '—')}</p></div>)}</div>}
          </section>
          <RecordsTable title="Danh sách đối tác cung cấp" data={rows} loading={loading} error={error} query={search} onQueryChange={setSearch} columns={['ma_gioi_thieu', 'ten_doanh_nghiep', 'so_luong_thi_sinh', 'tong_le_phi_thu_duoc', 'hoa_hong_phai_tra', 'trang_thai_doi_soat']} />
        </>
      )}
    </AdminShell>
  )
}

function Stats({ source, labels }: { source: ReturnType<typeof useRemoteRows>; labels: string[] }) {
  const row = source.data[0]
  const values = row ? Object.entries(row) : []
  const icons = [Users, FileText, FileText, FileText]
  const colors = ['bg-blue-50 text-blue-600', 'bg-emerald-50 text-emerald-600', 'bg-sky-50 text-sky-600', 'bg-amber-50 text-amber-600']
  return <>{labels.map((label, index) => {
    const Icon = icons[index % icons.length]
    return <article key={label} className="rounded-2xl border border-slate-200 bg-white p-4"><div className="flex items-center justify-between"><p className="text-[10px] text-slate-500">{label}</p><span className={`rounded-lg p-2 ${colors[index % colors.length]}`}><Icon size={14} /></span></div>{source.loading ? <div className="mt-3 h-6 animate-pulse rounded bg-slate-100" /> : source.error ? <p className="mt-2 text-[10px] text-rose-600">Lỗi tải dữ liệu</p> : <p className="mt-2 text-xl font-bold text-slate-900">{new Intl.NumberFormat('vi-VN').format(Number(values[index]?.[1] ?? 0))}</p>}<p className="mt-1 text-[9px] text-slate-400">Theo dữ liệu Supabase</p></article>
  })}</>
}
