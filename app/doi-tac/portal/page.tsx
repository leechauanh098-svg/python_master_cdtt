'use client'

import { useEffect, useMemo, useState } from 'react'
import { LogOut, RefreshCw, ShieldCheck } from 'lucide-react'
import { useRouter } from 'next/navigation'
import { getSupabaseBrowserClient } from '@/lib/supabase-browser'

type PartnerOverview = {
  ten_doanh_nghiep: string
  ma_so_thue: string
  dia_chi: string
  email_lien_he: string
  sdt_lien_he: string
  hinh_thuc: string
  loai_tai_tro: string
  cap_do_tai_tro: string
  so_luong_thi_sinh: number
  tong_le_phi_thu_duoc: number
  hoa_hong_phai_tra: number
  thuc_thu_tai_tro: number
  luot_hien_thi: number
  luot_tuong_tac: number
}

const portalLogin = '/login?next=%2Fdoi-tac%2Fportal'
const money = new Intl.NumberFormat('vi-VN', { maximumFractionDigits: 0 })

export default function PartnerPortalPage() {
  const router = useRouter()
  const supabase = useMemo(() => getSupabaseBrowserClient(), [])
  const [userId, setUserId] = useState('')
  const [authReady, setAuthReady] = useState(false)
  const [company, setCompany] = useState<PartnerOverview | null>(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')
  const [refresh, setRefresh] = useState(0)

  useEffect(() => {
    let active = true
    if (!supabase) {
      setError('Chưa cấu hình kết nối Supabase.')
      setLoading(false)
      setAuthReady(true)
      return () => { active = false }
    }

    function handleSession(session: { user: { id: string } } | null) {
      if (!active) return
      if (!session) {
        setAuthReady(false)
        router.replace(portalLogin)
        return
      }
      setUserId(session.user.id)
      setAuthReady(true)
    }

    const { data: { subscription } } = supabase.auth.onAuthStateChange((_event, session) => {
      handleSession(session)
    })
    void supabase.auth.getSession().then(({ data, error: sessionError }) => {
      if (!active) return
      if (sessionError) {
        setError(`Không xác thực được tài khoản: ${sessionError.message}`)
        setLoading(false)
        return
      }
      handleSession(data.session)
    })

    return () => {
      active = false
      subscription.unsubscribe()
    }
  }, [router, supabase])

  useEffect(() => {
    let active = true
    if (!authReady || !userId || !supabase) return () => { active = false }

    setLoading(true)
    setError('')
    void supabase.rpc('fn_partner_portal_overview').then(({ data, error: responseError }) => {
      if (!active) return
      if (responseError) {
        setCompany(null)
        setError(`Không tải được dữ liệu đối tác: ${responseError.message}`)
      } else {
        const rows = Array.isArray(data) ? data as PartnerOverview[] : []
        setCompany(rows[0] ?? null)
      }
      setLoading(false)
    }, (loadError: unknown) => {
      if (!active) return
      setCompany(null)
      setError(loadError instanceof Error ? loadError.message : String(loadError))
      setLoading(false)
    })

    return () => { active = false }
  }, [authReady, refresh, supabase, userId])

  async function signOut() {
    if (!supabase) return
    const { error: signOutError } = await supabase.auth.signOut()
    if (signOutError) setError(`Không đăng xuất được: ${signOutError.message}`)
    else router.replace('/login')
  }

  const isSupplier = company?.hinh_thuc === 'CUNG_CAP_THI_SINH'
  const stats = isSupplier
    ? [
        ['Thí sinh được giới thiệu', company?.so_luong_thi_sinh],
        ['Lệ phí đã thu', company?.tong_le_phi_thu_duoc],
        ['Hoa hồng phải trả', company?.hoa_hong_phai_tra],
      ] as const
    : [
        ['Tài trợ đã thực thu', company?.thuc_thu_tai_tro],
        ['Lượt hiển thị', company?.luot_hien_thi],
        ['Lượt tương tác', company?.luot_tuong_tac],
      ] as const

  return (
    <main className="min-h-screen bg-background px-4 py-8 text-slate-800 sm:px-8">
      <div className="mx-auto max-w-5xl">
        <header className="mb-6 flex flex-wrap items-center justify-between gap-3 rounded-2xl border border-slate-200 bg-white p-5 shadow-sm">
          <div className="flex items-center gap-3">
            <span className="flex h-11 w-11 items-center justify-center rounded-xl bg-blue-600 text-white"><ShieldCheck size={21} /></span>
            <div>
              <p className="text-xs font-semibold uppercase tracking-wide text-blue-600">Cổng thông tin đối tác</p>
              <h1 className="mt-1 text-xl font-bold text-slate-900">{company?.ten_doanh_nghiep ?? 'Thông tin doanh nghiệp'}</h1>
            </div>
          </div>
          <div className="flex gap-2">
            <button type="button" onClick={() => setRefresh((value) => value + 1)} disabled={loading || !userId} className="flex h-9 items-center gap-2 rounded-lg border border-slate-200 px-3 text-xs font-medium text-slate-600 disabled:opacity-50">
              <RefreshCw size={14} /> Làm mới
            </button>
            <button type="button" onClick={() => void signOut()} className="flex h-9 items-center gap-2 rounded-lg border border-slate-200 px-3 text-xs font-medium text-slate-600">
              <LogOut size={14} /> Đăng xuất
            </button>
          </div>
        </header>

        <p className="mb-5 text-xs text-slate-500">Chỉ xem thông tin của doanh nghiệp được quản trị viên liên kết với tài khoản này. Cổng đối tác không hỗ trợ chỉnh sửa dữ liệu.</p>

        {error && <p role="alert" className="mb-5 rounded-xl bg-rose-50 p-4 text-sm text-rose-700">{error}</p>}
        {loading && <p className="rounded-xl border border-slate-200 bg-white p-8 text-center text-sm text-slate-500">Đang tải thông tin doanh nghiệp…</p>}
        {!loading && !error && !company && (
          <section className="rounded-2xl border border-amber-200 bg-amber-50 p-5 text-sm leading-6 text-amber-950">
            <h2 className="font-bold">Tài khoản chưa được liên kết với doanh nghiệp</h2>
            <p className="mt-2">Quản trị viên cần tạo hoặc mời người dùng trong Supabase Auth, sau đó gắn Auth UID vào đúng hồ sơ doanh nghiệp. Trang này không tạo tài khoản hoặc cấp thông tin đăng nhập.</p>
            <p className="mt-3">Ví dụ thao tác liên kết do quản trị viên thực hiện trong SQL Editor sau khi xác minh người dùng và mã doanh nghiệp:</p>
            <code className="mt-2 block overflow-x-auto rounded-lg bg-white p-3 text-xs">UPDATE public.doanhnghiep SET auth_user_id = '&lt;Supabase Auth UID&gt;' WHERE doanh_nghiep_id = '&lt;mã doanh nghiệp&gt;';</code>
          </section>
        )}

        {!loading && company && (
          <>
            <section className="mb-5 rounded-2xl border border-slate-200 bg-white p-5 shadow-sm">
              <h2 className="text-sm font-bold text-slate-900">Hồ sơ doanh nghiệp</h2>
              <dl className="mt-4 grid gap-4 text-sm sm:grid-cols-2">
                <div><dt className="text-xs text-slate-400">Mã số thuế</dt><dd className="mt-1 font-medium">{company.ma_so_thue}</dd></div>
                <div><dt className="text-xs text-slate-400">Hình thức hợp tác</dt><dd className="mt-1 font-medium">{company.hinh_thuc}</dd></div>
                <div><dt className="text-xs text-slate-400">Địa chỉ</dt><dd className="mt-1 font-medium">{company.dia_chi}</dd></div>
                <div><dt className="text-xs text-slate-400">Email liên hệ</dt><dd className="mt-1 font-medium">{company.email_lien_he}</dd></div>
                <div><dt className="text-xs text-slate-400">Điện thoại liên hệ</dt><dd className="mt-1 font-medium">{company.sdt_lien_he}</dd></div>
                {!isSupplier && <div><dt className="text-xs text-slate-400">Cấp độ tài trợ</dt><dd className="mt-1 font-medium">{company.cap_do_tai_tro} · {company.loai_tai_tro}</dd></div>}
              </dl>
            </section>

            <section className="grid gap-3 sm:grid-cols-3">
              {stats.map(([label, value]) => (
                <article key={label} className="rounded-2xl border border-slate-200 bg-white p-5 shadow-sm">
                  <p className="text-xs text-slate-500">{label}</p>
                  <p className="mt-3 text-xl font-bold text-slate-900">{money.format(Number(value ?? 0))}{label.includes('Lượt') || label.includes('Thí sinh') ? '' : ' ₫'}</p>
                </article>
              ))}
            </section>
          </>
        )}
      </div>
    </main>
  )
}
