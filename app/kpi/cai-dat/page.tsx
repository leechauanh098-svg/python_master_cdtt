'use client'

import Link from 'next/link'
import { useRouter } from 'next/navigation'
import { FormEvent, useMemo, useState } from 'react'
import { ArrowLeft, Save } from 'lucide-react'
import { AdminShell } from '@/components/admin-shell'
import { useReportAccess } from '@/components/report-access'
import { getSupabaseBrowserClient } from '@/lib/supabase-browser'

const KPI_GROUPS = [
  { value: 'THI_SINH', label: 'Thí sinh tham gia thực tế', prefix: 'KPI_TS', group: 'THI_SINH', legacy: true },
  { value: 'DOANH_THU', label: 'Doanh thu lệ phí thi', prefix: 'KPI_DT', group: 'DOANH_THU', legacy: true },
  { value: 'DOANH_NGHIEP', label: 'Doanh nghiệp ký hợp đồng', prefix: 'KPI_DN', group: 'DOANH_NGHIEP', legacy: true },
  { value: 'KPI_HT1', label: 'Nhân viên hỗ trợ — Hồ sơ chưa thanh toán đã liên hệ', group: 'NHAN_VIEN_HO_TRO', prefix: '', legacy: false },
  { value: 'KPI_HT2', label: 'Nhân viên hỗ trợ — Tỷ lệ chuyển đổi sau tư vấn', group: 'NHAN_VIEN_HO_TRO', prefix: '', legacy: false },
  { value: 'KPI_HT3', label: 'Nhân viên hỗ trợ — Thời gian phản hồi đầu tiên', group: 'NHAN_VIEN_HO_TRO', prefix: '', legacy: false },
  { value: 'KPI_HT4', label: 'Nhân viên hỗ trợ — Câu hỏi đã giải đáp', group: 'NHAN_VIEN_HO_TRO', prefix: '', legacy: false },
  { value: 'KPI_HT5', label: 'Nhân viên hỗ trợ — Tỷ lệ FAQ hữu ích', group: 'NHAN_VIEN_HO_TRO', prefix: '', legacy: false },
  { value: 'KPI_GK1', label: 'Giám khảo — Bài đã chấm trên bài được giao', group: 'GIAM_KHAO', prefix: '', legacy: false },
  { value: 'KPI_GK2', label: 'Giám khảo — Thời gian chấm trung bình', group: 'GIAM_KHAO', prefix: '', legacy: false },
  { value: 'KPI_GK3', label: 'Giám khảo — Độ lệch điểm giữa các giám khảo', group: 'GIAM_KHAO', prefix: '', legacy: false },
  { value: 'KPI_GK4', label: 'Giám khảo — Ca nghi gian lận đã xử lý', group: 'GIAM_KHAO', prefix: '', legacy: false },
  { value: 'KPI_TR1', label: 'Trường — Đăng ký so với chỉ tiêu', group: 'TRUONG', prefix: '', legacy: false },
  { value: 'KPI_TR2', label: 'Trường — Số ngày quá hạn chỉ tiêu', group: 'TRUONG', prefix: '', legacy: false },
  { value: 'KPI_TR3', label: 'Trường — Hoa hồng 2% đã đối soát', group: 'TRUONG', prefix: '', legacy: false },
  { value: 'KPI_DN1', label: 'Doanh nghiệp — Thí sinh so với cam kết', group: 'DOANH_NGHIEP', prefix: '', legacy: false },
  { value: 'KPI_DN2', label: 'Doanh nghiệp — Hoa hồng 15% đã thanh toán', group: 'DOANH_NGHIEP', prefix: '', legacy: false },
  { value: 'KPI_TT1', label: 'Nhà tài trợ — Quyền lợi đã trả', group: 'NHA_TAI_TRO', prefix: '', legacy: false },
  { value: 'KPI_TT2', label: 'Nhà tài trợ — Brand reach thực tế', group: 'NHA_TAI_TRO', prefix: '', legacy: false },
  { value: 'KPI_TT3', label: 'Nhà tài trợ — Giá trị đã nhận', group: 'NHA_TAI_TRO', prefix: '', legacy: false },
] as const

function defaultKpiPeriod(): string {
  const now = new Date(Date.now() + 7 * 60 * 60 * 1000)
  return `${now.getUTCFullYear()}-Q${Math.floor(now.getUTCMonth() / 3) + 1}`
}

function getErrorMessage(error: unknown): string {
  if (error instanceof Error) return error.message
  if (typeof error === 'string') return error
  if (typeof error === 'object' && error !== null && 'message' in error && typeof error.message === 'string') {
    return error.message
  }
  return 'Đã xảy ra lỗi khi lưu mục tiêu KPI.'
}

function getPeriods(): string[] {
  const now = new Date(Date.now() + 7 * 60 * 60 * 1000)
  return Array.from({ length: 12 }, (_, index) => {
    const date = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth() - index * 3, 1))
    return `${date.getUTCFullYear()}-Q${Math.floor(date.getUTCMonth() / 3) + 1}`
  })
}

export default function KpiSettingsPage() {
  const access = useReportAccess()
  const router = useRouter()
  const supabase = useMemo(() => getSupabaseBrowserClient(), [])
  const [period, setPeriod] = useState(defaultKpiPeriod)
  const [group, setGroup] = useState<(typeof KPI_GROUPS)[number]['value']>('THI_SINH')
  const [name, setName] = useState<string>(KPI_GROUPS[0].label)
  const [target, setTarget] = useState('')
  const [reason, setReason] = useState('')
  const [saving, setSaving] = useState(false)
  const [error, setError] = useState('')

  const isAdmin = access.roleIds.includes('ADMIN')
  const selectedGroup = KPI_GROUPS.find((item) => item.value === group) ?? KPI_GROUPS[0]
  const kpiId = selectedGroup.legacy
    ? `${selectedGroup.prefix}_${period.replace('-Q', 'Q')}`
    : selectedGroup.value

  async function saveTarget(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    setError('')
    const targetValue = Number(target)
    if (!Number.isFinite(targetValue) || targetValue <= 0) {
      setError('Mục tiêu phải là số lớn hơn 0.')
      return
    }
    if (!supabase) {
      setError('Không thể kết nối nguồn dữ liệu KPI.')
      return
    }

    setSaving(true)
    try {
      const { error: saveError } = await supabase.rpc('fn_kpi_set_target', {
        p_kpi_id: kpiId,
        p_period: period,
        p_group: selectedGroup.group,
        p_name: selectedGroup.legacy ? name : selectedGroup.label.split(' — ').slice(1).join(' — '),
        p_target: targetValue,
        p_reason: reason,
      })
      if (saveError) throw saveError
      router.push('/kpi')
    } catch (saveError) {
      setError(getErrorMessage(saveError))
    } finally {
      setSaving(false)
    }
  }

  return (
    <AdminShell active="KPI" title="Cài đặt KPI">
      <div className="mb-6 flex items-center justify-between gap-3">
        <div>
          <p className="text-sm font-bold uppercase tracking-[0.16em] text-blue-700">CÀI ĐẶT KPI</p>
          <h2 className="mt-1 text-2xl font-bold text-slate-900">Thiết lập mục tiêu</h2>
        </div>
        <Link href="/kpi" className="inline-flex min-h-11 items-center gap-2 rounded-xl border border-slate-200 bg-white px-4 text-sm font-semibold text-slate-700 hover:bg-slate-50">
          <ArrowLeft size={15} /> Quay lại KPI
        </Link>
      </div>

      {!isAdmin ? (
        <div role="alert" className="rounded-xl border border-rose-200 bg-rose-50 p-4 text-sm text-rose-800">
          Chỉ Admin được truy cập cài đặt KPI.
        </div>
      ) : (
        <form onSubmit={saveTarget} className="max-w-3xl rounded-2xl border border-slate-200 bg-white p-6 shadow-sm">
          <p className="mb-5 text-sm leading-6 text-slate-600">
            Mục tiêu được lưu theo kỳ. Hệ thống từ chối giá trị bằng 0 hoặc nhỏ hơn; mọi thay đổi được ghi vào nhật ký.
          </p>
          {error && <p role="alert" className="mb-4 rounded-xl border border-rose-200 bg-rose-50 p-3 text-sm text-rose-800">{error}</p>}

          <div className="grid gap-5 sm:grid-cols-2">
            <label className="text-sm font-semibold text-slate-800">
              KPI
              <select value={group} onChange={(event) => {
                const nextGroup = event.target.value as (typeof KPI_GROUPS)[number]['value']
                setGroup(nextGroup)
                setName(KPI_GROUPS.find((item) => item.value === nextGroup)?.label ?? '')
              }} className="mt-2 min-h-11 w-full rounded-xl border border-slate-200 bg-white px-3 font-normal">
                {KPI_GROUPS.map((item) => <option key={item.value} value={item.value}>{item.label}</option>)}
              </select>
            </label>
            <label className="text-sm font-semibold text-slate-800">
              Kỳ
              <select value={period} onChange={(event) => setPeriod(event.target.value)} className="mt-2 min-h-11 w-full rounded-xl border border-slate-200 bg-white px-3 font-normal">
                {getPeriods().map((option) => <option key={option} value={option}>{option}</option>)}
              </select>
            </label>
            <label className="text-sm font-semibold text-slate-800">
              Tên KPI
              <input value={selectedGroup.legacy ? name : selectedGroup.label.split(' — ').slice(1).join(' — ')} onChange={(event) => setName(event.target.value)} readOnly={!selectedGroup.legacy} required maxLength={200} className="mt-2 min-h-11 w-full rounded-xl border border-slate-200 px-3 font-normal read-only:bg-slate-50 read-only:text-slate-600" />
            </label>
            <label className="text-sm font-semibold text-slate-800">
              Mục tiêu
              <input type="number" min="0.01" step="0.01" value={target} onChange={(event) => setTarget(event.target.value)} required className="mt-2 min-h-11 w-full rounded-xl border border-slate-200 px-3 font-normal" />
            </label>
            <label className="text-sm font-semibold text-slate-800 sm:col-span-2">
              Lý do thay đổi (bắt buộc nếu cập nhật mục tiêu đã có)
              <textarea value={reason} onChange={(event) => setReason(event.target.value)} maxLength={500} rows={3} className="mt-2 w-full rounded-xl border border-slate-200 px-3 py-2 font-normal" />
            </label>
          </div>

          <div className="mt-5 flex flex-wrap items-center justify-between gap-3">
            <p className="text-sm text-slate-600">Mã KPI: <span className="font-semibold text-slate-800">{kpiId}</span></p>
            <button type="submit" disabled={saving} className="inline-flex min-h-11 items-center gap-2 rounded-xl bg-blue-600 px-5 text-sm font-semibold text-white hover:bg-blue-700 disabled:opacity-60">
              <Save size={15} /> {saving ? 'Đang lưu…' : 'Lưu mục tiêu'}
            </button>
          </div>
        </form>
      )}
    </AdminShell>
  )
}
