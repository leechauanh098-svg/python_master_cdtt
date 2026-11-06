'use client'

import { useMemo, useState } from 'react'
import {
  Activity,
  ArrowDownRight,
  ArrowUpRight,
  CalendarDays,
  CreditCard,
  Download,
  RefreshCw,
  Target,
  UserRoundPlus,
  Users,
  Wallet,
} from 'lucide-react'
import { AdminShell } from '@/components/admin-shell'
import { ChartCard } from '@/components/admin-charts'
import { useRemoteRows, type DataRow } from '@/components/remote-data'

function rowDate(row: DataRow, key: string): string {
  const value = row[key]
  return typeof value === 'string' ? value.slice(0, 10) : ''
}

function displayNumber(value: unknown): string {
  if (value == null || value === '') return '—'
  const parsed = Number(value ?? 0)
  return new Intl.NumberFormat('vi-VN', { maximumFractionDigits: 2 }).format(Number.isFinite(parsed) ? parsed : 0)
}

function dashboardStat(row: DataRow | undefined, key: string): unknown {
  if (!row) return null
  const match = Object.entries(row).find(([name]) => name.toLowerCase() === key)
  return match?.[1]
}

const cards = [
  { key: 'tong_luot_dang_ky', title: 'Tổng lượt đăng ký', icon: Users, tone: 'bg-blue-50 text-blue-600', valueTone: 'text-slate-900' },
  { key: 'tong_luot_thanh_toan', title: 'Tổng lượt thanh toán', icon: CreditCard, tone: 'bg-sky-50 text-sky-600', valueTone: 'text-slate-900' },
  { key: 'ty_le_chuyen_doi_thanh_toan', title: 'Tỷ lệ chuyển đổi thanh toán', icon: Activity, tone: 'bg-emerald-50 text-emerald-600', valueTone: 'text-emerald-700', suffix: '%' },
  { key: 'doanh_thu_tam_tinh', title: 'Doanh thu tạm tính', icon: Wallet, tone: 'bg-orange-50 text-orange-600', valueTone: 'text-slate-900', suffix: ' ₫' },
  { key: 'tong_tiep_can', title: 'Tổng lượt tiếp cận', icon: UserRoundPlus, tone: 'bg-rose-50 text-rose-600', valueTone: 'text-rose-700' },
  { key: 'target_gap', title: 'Chênh lệch so với quý 2', icon: Target, tone: 'bg-amber-50 text-amber-600', valueTone: 'text-slate-900', suffix: ' lượt' },
]

const periods = {
  q3_2026: { label: 'Quý 3/2026', from: '2026-07-01', to: '2026-09-30' },
  q4_2026: { label: 'Quý 4/2026', from: '2026-10-01', to: '2026-12-31' },
} as const

export default function DashboardPage() {
  const [periodKey, setPeriodKey] = useState<keyof typeof periods>('q3_2026')
  const [refresh, setRefresh] = useState(0)
  const { label: periodLabel, from: fromDate, to: toDate } = periods[periodKey]
  const reportPeriod = periodKey === 'q3_2026' ? '2026-Q3' : '2026-Q4'

  const registrationKpi = useRemoteRows({ kind: 'rpc', name: 'fn_kpi_thisinh_tong_quan', args: { p_ky: reportPeriod } }, refresh)
  const revenueKpi = useRemoteRows({ kind: 'rpc', name: 'fn_kpi_doanhthu_tong_quan', args: { p_ky: reportPeriod } }, refresh)
  const baselineKpi = useRemoteRows({ kind: 'rpc', name: 'fn_kpi_thisinh_tong_quan', args: { p_ky: '2026-Q2' } }, refresh)
  const trend = useRemoteRows({ kind: 'rpc', name: 'fn_kpi_doanhthu_xu_huong', args: { p_ky: reportPeriod } }, refresh)
  const funnel = useRemoteRows({ kind: 'rpc', name: 'fn_kpi_thisinh_pheu', args: { p_ky: reportPeriod } }, refresh)
  const contestSplit = useRemoteRows({ kind: 'view', name: 'vw_dashboard_phan_bo_bang_thi' }, refresh)
  const ageSplit = useRemoteRows({ kind: 'view', name: 'vw_dashboard_phan_bo_nhom_tuoi' }, refresh)
  const registrationSummary = registrationKpi.data[0]
  const revenueSummary = revenueKpi.data[0]
  const baselineSummary = baselineKpi.data[0]
  const totalRegistrations = Number(registrationSummary?.dang_ky_thi ?? 0)
  const successfulPayments = Number(revenueSummary?.giao_dich_thanh_cong ?? 0)
  const summary: DataRow | undefined = registrationSummary && revenueSummary
    ? {
        tong_luot_dang_ky: totalRegistrations,
        tong_luot_thanh_toan: successfulPayments,
        ty_le_chuyen_doi_thanh_toan: totalRegistrations ? successfulPayments / totalRegistrations * 100 : 0,
        doanh_thu_tam_tinh: revenueSummary.tong_doanh_thu,
        tong_tiep_can: registrationSummary.tong_tiep_can,
        target_gap: baselineSummary ? totalRegistrations - Number(baselineSummary.dang_ky_thi ?? 0) : null,
      }
    : undefined
  const cardError = registrationKpi.error || revenueKpi.error
  const cardLoading = registrationKpi.loading || revenueKpi.loading || baselineKpi.loading
  const trendPoints = useMemo(() => trend.data.map((row) => ({ ...row, ngay_hien_thi: rowDate(row, 'ngay') })), [trend.data])
  const funnelPoints = useMemo<DataRow[]>(() => funnel.data.map((row) => ({
    ...row,
    giai_doan: row.buoc,
    ty_le_so_voi_tiep_can: row.ty_le_so_voi_tiep_can_pct,
  })), [funnel.data])
  const hasQuarterRegistrations = Number(registrationSummary?.tong_tiep_can ?? 0) > 0

  function exportDashboard() {
    const data = [
      ...cards.map((card) => ({ Chỉ_số: card.title, Giá_trị: dashboardStat(summary, card.key) })),
      ...trend.data.map((row) => ({ Chỉ_số: `Giao dịch ngày ${rowDate(row, 'ngay')}`, Giá_trị: row.so_giao_dich })),
    ]
    const headings = Object.keys(data[0] ?? {})
    const csv = [headings.join(','), ...data.map((row) => headings.map((heading) => `"${String(row[heading as keyof typeof row] ?? '').replaceAll('"', '""')}"`).join(','))].join('\r\n')
    const link = document.createElement('a')
    link.href = URL.createObjectURL(new Blob([`\uFEFF${csv}`], { type: 'text/csv;charset=utf-8' }))
    link.download = 'dashboard-quan-tri.csv'
    link.click()
    URL.revokeObjectURL(link.href)
  }

  const dataErrors = [
    ['Chỉ số đăng ký', registrationKpi.error],
    ['Chỉ số thanh toán', revenueKpi.error],
    ['Số liệu đối chiếu quý 2', baselineKpi.error],
    ['Xu hướng giao dịch', trend.error],
    ['Phễu chuyển đổi', funnel.error],
    ['Phân bố bảng thi', contestSplit.error],
    ['Phân bố nhóm tuổi', ageSplit.error],
  ].filter((entry): entry is [string, string] => Boolean(entry[1]))

  return (
    <AdminShell active="Dashboard quản trị" title="Dashboard quản trị">
      <div className="mb-5 flex flex-wrap items-end justify-between gap-4">
        <div>
          <p className="text-[10px] font-bold uppercase tracking-[0.2em] text-blue-500">TRUNG TÂM ĐIỀU HÀNH</p>
          <h2 className="mt-1 text-2xl font-bold tracking-tight text-slate-900">Chào buổi sáng, ADMIN!</h2>
          <p className="mt-1 text-xs text-slate-500">Theo dõi đăng ký, thanh toán và hiệu quả kỳ thi của bạn.</p>
        </div>
        <div className="flex flex-wrap items-center gap-2">
          <label className="flex h-9 items-center gap-2 rounded-xl border border-slate-200 bg-white px-2.5">
            <CalendarDays size={14} className="text-blue-500" />
            <span className="text-[10px] text-slate-500">Kỳ</span>
            <select aria-label="Kỳ thống kê" value={periodKey} onChange={(event) => setPeriodKey(event.target.value as keyof typeof periods)} className="bg-transparent text-[10px] outline-none">
              <option value="q3_2026">Quý 3/2026</option>
              <option value="q4_2026">Quý 4/2026</option>
            </select>
          </label>
          <button onClick={() => setRefresh((value) => value + 1)} className="flex h-9 items-center gap-2 rounded-xl border border-slate-200 bg-white px-3 text-xs font-medium text-slate-600 hover:bg-slate-50"><RefreshCw size={14} /> Làm mới</button>
          <button onClick={exportDashboard} disabled={!summary} className="flex h-9 items-center gap-2 rounded-xl bg-blue-600 px-3 text-xs font-semibold text-white shadow-sm shadow-blue-200 hover:bg-blue-700 disabled:opacity-50"><Download size={14} /> Tải báo cáo</button>
        </div>
      </div>
      <div className="mb-5 flex items-center gap-2 rounded-xl border border-blue-100 bg-white px-4 py-2.5">
        <CalendarDays size={15} className="text-blue-500" />
        <div><p className="text-[10px] font-semibold text-slate-700">Khoảng thời gian thống kê · {periodLabel}</p><p className="text-[10px] text-slate-400">{fromDate} — {toDate} · Nguồn dữ liệu Supabase</p></div>
        <span className="ml-auto rounded-full bg-blue-50 px-2.5 py-1 text-[9px] font-semibold text-blue-700">● Trực tiếp</span>
      </div>
      {dataErrors.length > 0 && (
        <div role="alert" className="mb-4 rounded-xl border border-amber-200 bg-amber-50 p-3 text-xs text-amber-800">
          <p>Một số dữ liệu chưa tải được từ Supabase:</p>
          <ul className="mt-1 list-inside list-disc">
            {dataErrors.map(([title, error]) => <li key={title}>{title}: {error}</li>)}
          </ul>
        </div>
      )}

      <section className="mb-5 grid grid-cols-1 gap-3 sm:grid-cols-2 xl:grid-cols-3 2xl:grid-cols-6">
        {cards.map((card) => {
          const Icon = card.icon
          const value = dashboardStat(summary, card.key)
          return (
            <article key={card.key} className="rounded-2xl border border-slate-200 bg-white p-4 shadow-sm shadow-slate-100/70">
              <div className="flex items-start justify-between gap-2">
                <p className="max-w-[150px] text-[10px] font-medium leading-4 text-slate-500">{card.title}</p>
                <span className={`flex h-8 w-8 shrink-0 items-center justify-center rounded-xl ${card.tone}`}><Icon size={15} /></span>
              </div>
              {cardLoading ? <div className="mt-3 h-7 animate-pulse rounded bg-slate-100" /> : cardError ? <p className="mt-3 text-[10px] text-rose-600">Không tải được</p> : (
                <p className={`mt-3 text-2xl font-bold tracking-tight ${card.valueTone}`}>{displayNumber(value)}{card.suffix ?? ''}</p>
              )}
              <p className="mt-1 text-[9px] text-slate-400">Theo dữ liệu Supabase</p>
            </article>
          )
        })}
      </section>

      <div className="mb-5 grid items-stretch gap-4 2xl:grid-cols-[2fr_1fr]">
        <div className="relative">
          {trend.loading && <span className="absolute right-4 top-4 z-10 text-[10px] text-slate-400">Đang tải…</span>}
          {trend.error ? <ChartError title="Xu hướng giao dịch" error={trend.error} /> : (
            <ChartCard title="Xu hướng giao dịch" description={`Số giao dịch theo ngày trong ${periodLabel}.`} data={trendPoints} kind="line" xKey="ngay_hien_thi" yKey="so_giao_dich" seriesName="Giao dịch" height={330} />
          )}
        </div>
        <section className="rounded-2xl border border-slate-200 bg-white p-5 shadow-sm shadow-slate-100/70">
          <div className="mb-4">
            <h2 className="text-sm font-bold text-slate-900">Phễu chuyển đổi</h2>
            <p className="mt-1 text-[11px] text-slate-400">Từ lượt tiếp cận đến tham gia.</p>
          </div>
          {funnel.loading ? <div className="space-y-4 py-8">{[1, 2, 3].map((item) => <div key={item} className="h-14 animate-pulse rounded-xl bg-slate-100" />)}</div> : funnel.error ? <p role="alert" className="rounded-xl bg-rose-50 p-3 text-xs text-rose-700">{funnel.error}</p> : funnelPoints.length === 0 ? <EmptyState /> : (
            <div className="space-y-3">
              {funnelPoints.map((row, index) => {
                const count = Number(row.so_luong ?? 0)
                const percent = Number(row.ty_le_so_voi_tiep_can ?? 0)
                return (
                  <div key={String(row.giai_doan ?? index)} className={`rounded-xl p-3 ${['bg-blue-50', 'bg-sky-50', 'bg-emerald-50'][index % 3]}`}>
                    <div className="flex items-center justify-between gap-2">
                      <div className="flex items-center gap-2"><span className="flex h-6 w-6 items-center justify-center rounded-full bg-white text-[9px] font-bold text-blue-600">{String(index + 1).padStart(2, '0')}</span><span className="text-[10px] font-semibold text-slate-700">{String(row.giai_doan ?? '')}</span></div>
                      <strong className="text-xs text-slate-800">{percent.toLocaleString('vi-VN')}%</strong>
                    </div>
                    <div className="mt-2 flex items-center justify-between pl-8 text-[10px] text-slate-500"><span>{displayNumber(count)} lượt</span><span>so với tiếp cận</span></div>
                    <div className="ml-8 mt-2 h-1.5 rounded-full bg-white"><div className="h-full rounded-full bg-blue-500" style={{ width: `${Math.min(100, Math.max(0, percent))}%` }} /></div>
                  </div>
                )
              })}
            </div>
          )}
        </section>
      </div>

      <div className="grid gap-4 xl:grid-cols-2">
        {contestSplit.error ? <ChartError title="Phân bố bảng thi" error={contestSplit.error} /> : (
          <section className="rounded-2xl border border-slate-200 bg-white p-5 shadow-sm shadow-slate-100/70">
            <div className="mb-4 flex items-center justify-between"><div><h2 className="text-sm font-bold text-slate-900">Phân bố bảng thi</h2><p className="mt-1 text-[11px] text-slate-400">Tỷ trọng thí sinh trong {periodLabel}.</p></div><span className="rounded-full bg-blue-50 px-2.5 py-1 text-[9px] font-semibold text-blue-700">{displayNumber(hasQuarterRegistrations ? contestSplit.data.reduce((sum, row) => sum + Number(row.so_luong ?? 0), 0) : 0)} thí sinh</span></div>
            {contestSplit.loading ? <ChartSkeleton /> : !hasQuarterRegistrations ? <EmptyState /> : <div className="grid items-center gap-3 md:grid-cols-[1fr_0.8fr]"><ChartCard title="" data={contestSplit.data} kind="pie" xKey="bang_dau" yKey="so_luong" height={240} /><div className="space-y-3">{contestSplit.data.map((row, index) => <div key={`${String(row.bang_dau ?? 'bang')}-${index}`} className="flex items-center justify-between rounded-xl bg-slate-50 p-3"><span className="text-xs font-medium text-slate-600">{String(row.bang_dau ?? '').replace('BANG_', 'BẢNG ')}</span><div className="text-right"><p className="text-sm font-bold text-slate-800">{displayNumber(row.so_luong)} thí sinh</p><p className="text-[10px] text-slate-400">{displayNumber(row.ty_le_phan_tram)}%</p></div></div>)}</div></div>}
          </section>
        )}
        {ageSplit.error ? <ChartError title="Phân bố nhóm tuổi" error={ageSplit.error} /> : (
          <div className="relative">
            {ageSplit.loading && <span className="absolute right-4 top-4 z-10 text-[10px] text-slate-400">Đang tải…</span>}
            <ChartCard title="Phân bố nhóm tuổi" description={`Số lượng thí sinh trong ${periodLabel}.`} data={hasQuarterRegistrations ? ageSplit.data : []} kind="bar" xKey="nhom_tuoi" yKey="so_luong" height={330} />
          </div>
        )}
      </div>
      <footer className="mt-6 flex flex-wrap justify-between gap-2 border-t border-slate-200 py-4 text-[10px] text-slate-400"><span>VietEdu · Trung tâm quản lý kỳ thi</span><span>Đã đồng bộ trực tiếp từ Supabase</span></footer>
    </AdminShell>
  )
}

function ChartSkeleton() {
  return <div className="h-[240px] animate-pulse rounded-xl bg-slate-50" />
}

function EmptyState() {
  return <p className="rounded-xl bg-slate-50 p-8 text-center text-xs text-slate-500">Không có dữ liệu trong khoảng thời gian này.</p>
}

function ChartError({ title, error }: { title: string; error: string }) {
  return <section className="rounded-2xl border border-rose-100 bg-white p-5"><h2 className="text-sm font-bold text-slate-900">{title}</h2><p role="alert" className="mt-3 rounded-xl bg-rose-50 p-3 text-xs text-rose-700">Không tải được dữ liệu: {error}</p></section>
}
