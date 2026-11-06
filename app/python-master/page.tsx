'use client'

import { useMemo, useState } from 'react'
import { RefreshCw, Trophy } from 'lucide-react'
import { AdminShell } from '@/components/admin-shell'
import { RecordsTable } from '@/components/records-table'
import { useRemoteRows, type DataRow } from '@/components/remote-data'

export default function PythonMasterPage() {
  const [refresh, setRefresh] = useState(0)
  const summary = useRemoteRows({ kind: 'view', name: 'vw_pm_tong_quan' }, refresh)
  const rounds = useRemoteRows({ kind: 'view', name: 'vw_pm_vong_thi' }, refresh)
  const ranking = useRemoteRows({ kind: 'view', name: 'vw_pm_bxh_tam_thoi' }, refresh)
  const topQualifiers = useRemoteRows({ kind: 'view', name: 'vw_pm_top_vong_loai' }, refresh)
  const top56 = useMemo(() => topQualifiers.data.filter((row) => Number(row.hang_toan_quoc ?? 999999) <= 56), [topQualifiers.data])
  const summaryRow = summary.data[0]

  const metrics = [
    ['Số thí sinh hoàn tất thanh toán', 'so_thi_sinh_hoan_tat_thanh_toan', 'bg-blue-50 text-blue-600'],
    ['Tổng doanh thu cuộc thi', 'tong_doanh_thu_cuoc_thi_vnd', 'bg-emerald-50 text-emerald-600'],
    ['Tài khoản Sotauni đã kích hoạt', 'tai_khoan_sotauni_kich_hoat', 'bg-sky-50 text-sky-600'],
  ]

  return (
    <AdminShell active="Python Master 2026" title="Python Master 2026">
      <div className="mb-5 flex flex-wrap items-end justify-between gap-3"><p className="text-sm text-slate-500">Tổng quan cuộc thi, các vòng thi và bảng xếp hạng.</p><button onClick={() => setRefresh((value) => value + 1)} className="flex h-9 items-center gap-2 rounded-xl border border-slate-200 bg-white px-3 text-xs font-medium text-slate-600"><RefreshCw size={14} /> Làm mới</button></div>
      <div className="mb-5 grid gap-3 md:grid-cols-3">
        {metrics.map(([label, key, tone]) => <article key={key} className="rounded-2xl border border-slate-200 bg-white p-5"><div className="flex items-center justify-between"><p className="text-xs text-slate-500">{label}</p><span className={`rounded-lg p-2 ${tone}`}><Trophy size={15} /></span></div><p className="mt-3 text-2xl font-bold text-slate-900">{summary.loading ? '…' : summary.error ? '—' : new Intl.NumberFormat('vi-VN').format(Number(summaryRow?.[key] ?? 0))}{key === 'tong_doanh_thu_cuoc_thi_vnd' ? ' ₫' : ''}</p>{summary.error && <p className="mt-1 text-[10px] text-rose-600">{summary.error}</p>}</article>)}
      </div>
      <div className="mb-5">
        <RecordsTable title="Danh sách vòng thi" data={rounds.data} loading={rounds.loading} error={rounds.error} columns={['ten_cuoc_thi', 'bang_dau', 'han_dang_ky', 'ngay_bat_dau', 'ngay_ket_thuc', 'trang_thai']} />
      </div>
      <div className="mb-5 grid items-start gap-4 xl:grid-cols-2">
        <RecordsTable title="Bảng xếp hạng tạm thời" data={ranking.data.slice(0, 100)} loading={ranking.loading} error={ranking.error} columns={['xep_hang', 'thi_sinh_id', 'ho_ten', 'truong_hoc', 'tinh_thanh', 'ten_bai_tap', 'tong_diem', 'thoi_gian_lam_giay', 'trang_thai']} />
        <RecordsTable title="Top 56 vòng loại" data={top56} loading={topQualifiers.loading} error={topQualifiers.error} columns={['hang_toan_quoc', 'thi_sinh_id', 'ho_ten', 'truong_hoc', 'bang_dau', 'tong_diem']} />
      </div>
    </AdminShell>
  )
}
