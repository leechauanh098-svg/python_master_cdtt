'use client'

import { useEffect, useMemo, useState, type FormEvent } from 'react'
import { useRouter } from 'next/navigation'
import { ArrowRight, Eye, EyeOff, LockKeyhole, ShieldCheck, UserRound } from 'lucide-react'
import { getSupabaseBrowserClient } from '@/lib/supabase-browser'

function getPostLoginPath() {
  const next = new URLSearchParams(window.location.search).get('next')
  return next?.startsWith('/') && !next.startsWith('//') && !next.includes('\\') ? next : '/'
}

export default function LoginPage() {
  const router = useRouter()
  const supabase = useMemo(() => getSupabaseBrowserClient(), [])
  const [email, setEmail] = useState('nguyen.minhanh@sotatek.com')
  const [password, setPassword] = useState('')
  const [showPassword, setShowPassword] = useState(false)
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState('')

  useEffect(() => {
    if (!supabase) return
    let active = true
    void supabase.auth.getSession().then(({ data, error: sessionError }) => {
      if (active && !sessionError && data.session) router.replace(getPostLoginPath())
    })
    return () => { active = false }
  }, [router, supabase])

  async function signIn(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    if (!supabase) {
      setError('Chưa cấu hình kết nối Supabase. Hãy kiểm tra biến môi trường của ứng dụng.')
      return
    }

    setLoading(true)
    setError('')
    try {
      const { error: signInError } = await supabase.auth.signInWithPassword({
        email: email.trim(),
        password,
      })
      if (signInError) {
        setError(`Không đăng nhập được: ${signInError.message}`)
        setLoading(false)
        return
      }
      router.replace(getPostLoginPath())
      router.refresh()
    } catch (signInError) {
      setError(`Không kết nối được dịch vụ đăng nhập: ${signInError instanceof Error ? signInError.message : String(signInError)}`)
      setLoading(false)
    }
  }

  return (
    <main className="flex min-h-screen items-center justify-center bg-background px-5 py-10 text-slate-800">
      <div className="grid w-full max-w-[980px] overflow-hidden rounded-[28px] border border-slate-200 bg-white shadow-[0_24px_80px_rgba(37,99,235,.12)] lg:grid-cols-[.95fr_1.05fr]">
        <section className="relative hidden overflow-hidden bg-gradient-to-br from-blue-700 to-indigo-700 p-10 text-white lg:flex lg:flex-col lg:justify-between">
          <div className="absolute -right-24 -top-24 h-72 w-72 rounded-full border-[40px] border-white/10" />
          <div className="absolute -bottom-32 -left-20 h-80 w-80 rounded-full border-[50px] border-white/10" />
          <div className="relative">
            <div className="flex items-center gap-3">
              <div className="flex h-11 w-11 items-center justify-center rounded-xl bg-white text-blue-700 shadow-lg"><ShieldCheck size={22} /></div>
              <div><p className="font-bold tracking-tight">Sotauni Admin</p><p className="text-[10px] text-blue-100">Quản trị kỳ thi</p></div>
            </div>
            <div className="mt-24 max-w-[320px]">
              <p className="text-[11px] font-bold uppercase tracking-[.2em] text-blue-100">TRUNG TÂM ĐIỀU HÀNH</p>
              <h1 className="mt-4 text-4xl font-bold leading-tight">Quản lý kỳ thi<br />trong một nơi.</h1>
              <p className="mt-5 text-sm leading-6 text-blue-100">Theo dõi thí sinh, dữ liệu vận hành và hiệu quả chương trình với hệ thống quản trị Sotauni.</p>
            </div>
          </div>
          <div className="relative flex items-center gap-2 text-xs text-blue-100"><span className="h-2 w-2 rounded-full bg-emerald-300" /> Hệ thống quản trị</div>
        </section>
        <section className="p-7 sm:p-12">
          <div className="mb-9 lg:hidden">
            <div className="flex items-center gap-3">
              <div className="flex h-10 w-10 items-center justify-center rounded-xl bg-blue-600 text-white"><ShieldCheck size={20} /></div>
              <div><p className="font-bold text-slate-900">Sotauni Admin</p><p className="text-[10px] text-slate-400">Quản trị kỳ thi</p></div>
            </div>
          </div>
          <div className="mx-auto max-w-[360px]">
            <p className="text-[11px] font-bold uppercase tracking-[.18em] text-blue-600">DÀNH CHO THÀNH VIÊN ĐƯỢC CẤP TÀI KHOẢN</p>
            <h2 className="mt-3 text-3xl font-bold tracking-tight text-slate-900">Đăng nhập</h2>
            <p className="mt-2 text-sm text-slate-500">Dùng email và mật khẩu tài khoản đã được quản trị viên cấp.</p>
            <form className="mt-8 space-y-5" onSubmit={(event) => void signIn(event)}>
              <label className="block">
                <span className="mb-2 block text-xs font-semibold text-slate-700">Email tài khoản</span>
                <div className="relative">
                  <UserRound size={17} className="absolute left-3 top-1/2 -translate-y-1/2 text-slate-400" />
                  <input required type="email" autoComplete="username" value={email} onChange={(event) => setEmail(event.target.value)} placeholder="Nhập email tài khoản" className="h-12 w-full rounded-xl border border-slate-200 pl-10 pr-3 text-sm outline-none transition placeholder:text-slate-300 focus:border-blue-500 focus:ring-4 focus:ring-blue-50" />
                </div>
              </label>
              <label className="block">
                <span className="mb-2 block text-xs font-semibold text-slate-700">Mật khẩu</span>
                <div className="relative">
                  <LockKeyhole size={17} className="absolute left-3 top-1/2 -translate-y-1/2 text-slate-400" />
                  <input required autoComplete="current-password" type={showPassword ? 'text' : 'password'} value={password} onChange={(event) => setPassword(event.target.value)} placeholder="Nhập mật khẩu" className="h-12 w-full rounded-xl border border-slate-200 pl-10 pr-11 text-sm outline-none transition placeholder:text-slate-300 focus:border-blue-500 focus:ring-4 focus:ring-blue-50" />
                  <button type="button" onClick={() => setShowPassword(!showPassword)} className="absolute right-3 top-1/2 -translate-y-1/2 text-slate-400" aria-label={showPassword ? 'Ẩn mật khẩu' : 'Hiện mật khẩu'}>{showPassword ? <EyeOff size={17} /> : <Eye size={17} />}</button>
                </div>
              </label>
              {error && <p role="alert" className="rounded-xl bg-rose-50 p-3 text-xs leading-5 text-rose-700">{error}</p>}
              <button type="submit" disabled={loading} className="flex h-12 w-full items-center justify-center gap-2 rounded-xl bg-blue-600 text-sm font-semibold text-white shadow-lg shadow-blue-200 transition hover:bg-blue-700 disabled:cursor-wait disabled:opacity-60">
                {loading ? 'Đang đăng nhập…' : 'Đăng nhập'}{!loading && <ArrowRight size={17} />}
              </button>
            </form>
            <div className="mt-9 flex items-center gap-3 text-[10px] text-slate-400"><span className="h-px flex-1 bg-slate-100" /> BẢO MẬT HỆ THỐNG <span className="h-px flex-1 bg-slate-100" /></div>
            <p className="mt-4 text-center text-[10px] leading-5 text-slate-400">Chỉ sử dụng tài khoản quản trị được cấp quyền truy cập.</p>
          </div>
        </section>
      </div>
    </main>
  )
}
