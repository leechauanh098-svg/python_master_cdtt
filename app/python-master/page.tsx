'use client'

import { useEffect, useMemo, useState } from 'react'
import Link from 'next/link'
import { Activity, ArrowRight, BarChart3, CalendarDays, Clock3, RefreshCw, Trophy } from 'lucide-react'
import { AdminShell } from '@/components/admin-shell'
import { formatCell, formatTableCell, type DataRow } from '@/components/remote-data'
import { getSupabaseBrowserClient } from '@/lib/supabase-browser'

function isDataRow(value: unknown): value is DataRow {
  return typeof value === 'object' && value !== null && !Array.isArray(value)
}

function dateValue(value: unknown): string {
  return typeof value === 'string' || typeof value === 'number'
    ? formatTableCell(String(value))
    : 'Chưa cập nhật'
}

function statusStyle(value: unknown): string {
  const status = String(value ?? '')
  if (status === 'DANG_DIEN_RA') return 'bg-emerald-50 text-emerald-700'
  if (status === 'MO_DANG_KY') return 'bg-blue-50 text-blue-700'
  if (status === 'DA_KET_THUC' || status === 'HUY') return 'bg-slate-100 text-slate-600'
  return 'bg-amber-50 text-amber-700'
}

export default function PythonMasterPage() {
  const supabase = useMemo(() => getSupabaseBrowserClient(), [])
  const [rounds, setRounds] = useState<DataRow[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')
  const [refresh, setRefresh] = useState(0)

  useEffect(() => {
    let active = true
    async function loadRounds() {
      if (!supabase) {
        setError('Chưa cấu hình kết nối Supabase.')
        setRounds([])
        setLoading(false)
        return
      }

      setLoading(true)
      setError('')
      const { data, error: responseError } = await supabase.rpc('fn_bao_cao_du_lieu', {
        p_ma_bao_cao: 'contest_rounds',
        p_ky: null,
      })
      if (!active) return
      if (responseError) {
        setRounds([])
        setError(`Không tải được danh sách vòng thi: ${responseError.message}`)
      } else {
        setRounds(Array.isArray(data) ? data.filter(isDataRow) : isDataRow(data) ? [data] : [])
      }
      setLoading(false)
    }

    void loadRounds()
    return () => { active = false }
  }, [refresh, supabase])

  const summary = useMemo(() => ({
    total: rounds.length,
    open: rounds.filter((round) => round.trang_thai === 'MO_DANG_KY').length,
    ongoing: rounds.filter((round) => round.trang_thai === 'DANG_DIEN_RA').length,
    finished: rounds.filter((round) => round.trang_thai === 'DA_KET_THUC').length,
  }), [rounds])

  const stats = [
    { label: 'Tổng số vòng thi', value: summary.total, icon: Trophy, color: 'text-blue-600 bg-blue-50' },
    { label: 'Đang mở đăng ký', value: summary.open, icon: CalendarDays, color: 'text-blue-600 bg-blue-50' },
    { label: 'Đang diễn ra', value: summary.ongoing, icon: Activity, color: 'text-emerald-600 bg-emerald-50' },
    { label: 'Đã kết thúc', value: summary.finished, icon: Clock3, color: 'text-slate-600 bg-slate-100' },
  ]

  return (
    <AdminShell active="Python Master 2026" title="Python Master 2026">
      <section className="mb-5 overflow-hidden rounded-2xl bg-gradient-to-r from-blue-700 via-indigo-700 to-indigo-800 p-6 text-white shadow-sm sm:p-8">
        <div className="flex flex-wrap items-start justify-between gap-5">
          <div className="max-w-2xl">
            <p className="text-[10px] font-bold uppercase tracking-[0.2em] text-blue-100">ĐIỀU HÀNH CUỘC THI</p>
            <h2 className="mt-2 text-2xl font-bold tracking-tight">Các vòng thi Python Master 2026</h2>
            <p className="mt-2 text-sm leading-6 text-blue-100">
              Theo dõi lịch trình và trạng thái từng vòng thi. Số liệu bên dưới được lấy trực tiếp từ hệ thống.
            </p>
          </div>
          <button
            type="button"
            onClick={() => setRefresh((value) => value + 1)}
            disabled={loading}
            className="inline-flex h-10 items-center gap-2 rounded-xl border border-white/30 bg-white/10 px-3 text-xs font-semibold text-white transition hover:bg-white/20 disabled:opacity-60"
          >
            <RefreshCw size={14} className={loading ? 'animate-spin' : ''} />
            Làm mới
          </button>
        </div>
      </section>

      <section className="mb-5 grid gap-3 sm:grid-cols-2 xl:grid-cols-4" aria-label="Tổng quan cuộc thi">
        {stats.map(({ label, value, icon: Icon, color }) => (
          <article key={label} className="rounded-2xl border border-slate-200 bg-white p-4 shadow-sm">
            <div className="flex items-center justify-between gap-3">
              <p className="text-xs font-medium text-slate-500">{label}</p>
              <span className={`rounded-xl p-2 ${color}`}><Icon size={16} /></span>
            </div>
            <p className="mt-3 text-2xl font-bold tabular-nums text-slate-900">
              {loading ? '—' : new Intl.NumberFormat('vi-VN').format(value)}
            </p>
          </article>
        ))}
      </section>

      <section className="mb-5 rounded-2xl border border-slate-200 bg-white p-5 shadow-sm">
        <div className="mb-4 flex flex-wrap items-start justify-between gap-3">
          <div>
            <h2 className="text-sm font-bold text-slate-900">Lịch trình các vòng thi</h2>
            <p className="mt-1 text-xs text-slate-500">Hạn đăng ký, thời gian tổ chức và trạng thái hiện tại.</p>
          </div>
          <Link href="/bao-cao" className="inline-flex items-center gap-1.5 rounded-lg border border-slate-200 px-3 py-2 text-xs font-semibold text-blue-700 hover:bg-blue-50">
            <BarChart3 size={14} /> Xem kết quả &amp; báo cáo <ArrowRight size={13} />
          </Link>
        </div>

        {loading ? (
          <p className="rounded-xl bg-slate-50 px-4 py-8 text-center text-xs text-slate-500">Đang tải lịch trình cuộc thi…</p>
        ) : error ? (
          <p role="alert" className="rounded-xl bg-rose-50 px-4 py-3 text-xs leading-5 text-rose-700">{error}</p>
        ) : rounds.length ? (
          <div className="grid gap-3 lg:grid-cols-2">
            {rounds.map((round, index) => (
              <article key={String(round.cuoc_thi_id ?? index)} className="rounded-xl border border-slate-100 bg-slate-50/70 p-4">
                <div className="flex flex-wrap items-start justify-between gap-2">
                  <div>
                    <p className="text-[10px] font-semibold uppercase tracking-wide text-slate-400">
                      {formatCell(round.bang_dau)}
                    </p>
                    <h3 className="mt-1 text-sm font-bold text-slate-900">
                      {String(round.ten_cuoc_thi ?? 'Vòng thi chưa đặt tên')}
                    </h3>
                  </div>
                  <span className={`rounded-full px-2.5 py-1 text-[10px] font-semibold ${statusStyle(round.trang_thai)}`}>
                    {formatCell(round.trang_thai)}
                  </span>
                </div>
                {typeof round.mo_ta === 'string' && round.mo_ta && (
                  <p className="mt-2 text-xs leading-5 text-slate-500">{round.mo_ta}</p>
                )}
                <dl className="mt-4 grid gap-3 border-t border-slate-200/70 pt-3 sm:grid-cols-3">
                  <div>
                    <dt className="text-[10px] text-slate-400">Hạn đăng ký</dt>
                    <dd className="mt-1 text-xs font-medium text-slate-700">{dateValue(round.han_dang_ky)}</dd>
                  </div>
                  <div>
                    <dt className="text-[10px] text-slate-400">Ngày bắt đầu</dt>
                    <dd className="mt-1 text-xs font-medium text-slate-700">{dateValue(round.ngay_bat_dau)}</dd>
                  </div>
                  <div>
                    <dt className="text-[10px] text-slate-400">Ngày kết thúc</dt>
                    <dd className="mt-1 text-xs font-medium text-slate-700">{dateValue(round.ngay_ket_thuc)}</dd>
                  </div>
                </dl>
              </article>
            ))}
          </div>
        ) : (
          <div className="rounded-xl border border-dashed border-slate-300 bg-slate-50 px-5 py-10 text-center">
            <Trophy size={22} className="mx-auto text-slate-400" />
            <h3 className="mt-3 text-sm font-semibold text-slate-700">Chưa có dữ liệu vòng thi</h3>
            <p className="mx-auto mt-1 max-w-lg text-xs leading-5 text-slate-500">
              Khi thông tin cuộc thi được tạo trong hệ thống, lịch trình và trạng thái sẽ hiển thị tại đây.
              Báo cáo thứ hạng và bài thi có thể xem ở mục KPI &amp; Báo cáo.
            </p>
            <Link href="/bao-cao" className="mt-4 inline-flex items-center gap-2 rounded-xl bg-blue-600 px-4 py-2.5 text-xs font-semibold text-white hover:bg-blue-700">
              <BarChart3 size={14} /> Mở KPI &amp; Báo cáo <ArrowRight size={13} />
            </Link>
          </div>
        )}
      </section>
    </AdminShell>
  )
}
