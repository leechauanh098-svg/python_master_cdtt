'use client'

import Link from 'next/link'
import { useRouter } from 'next/navigation'
import { useEffect, useMemo, useState } from 'react'
import {
  Activity,
  Bot,
  BarChart3,
  BookOpen,
  ChevronRight,
  ClipboardCheck,
  LayoutDashboard,
  LogOut,
  Menu,
  MessageSquare,
  Package,
  Search,
  ShieldCheck,
  Trophy,
  Users,
  CircleHelp,
  X,
} from 'lucide-react'
import { getSupabaseBrowserClient } from '@/lib/supabase-browser'

const navigation = [
  {
    title: 'TỔNG QUAN',
    items: [{ label: 'Dashboard quản trị', icon: LayoutDashboard, href: '/' }],
  },
  {
    title: 'VẬN HÀNH',
    items: [
      { label: 'Quản lý thí sinh', icon: Users, href: '/thi-sinh' },
      { label: 'Python Master 2026', icon: Trophy, href: '/python-master' },
      { label: 'Bài tập & bài nộp', icon: ClipboardCheck, href: '/bai-tap' },
      { label: 'Đối tác đồng hành', icon: Package, href: '/doi-tac' },
      { label: 'Kho tài liệu RAG', icon: BookOpen, href: '/kho-tai-lieu' },
      { label: 'Lịch sử Q&A', icon: MessageSquare, href: '/qa' },
      { label: 'Quản lý FAQ', icon: CircleHelp, href: '/faq' },
    ],
  },
  {
    title: 'BÁO CÁO & HỆ THỐNG',
    items: [
      { label: 'KPI & Báo cáo', icon: BarChart3, href: '/bao-cao' },
      { label: 'Phân quyền & Nhật ký', icon: ShieldCheck, href: '/phan-quyen' },
    ],
  },
]

export function AdminShell({
  active,
  title,
  children,
}: {
  active: string
  title: string
  children: React.ReactNode
}) {
  const router = useRouter()
  const supabase = useMemo(() => getSupabaseBrowserClient(), [])
  const [mobileOpen, setMobileOpen] = useState(false)
  const [authReady, setAuthReady] = useState(false)
  const [authError, setAuthError] = useState('')

  useEffect(() => {
    let active = true
    if (!supabase) {
      router.replace('/login')
      return () => { active = false }
    }

    const { data: { subscription } } = supabase.auth.onAuthStateChange((_event, session) => {
      if (!active) return
      if (session) setAuthReady(true)
      else {
        setAuthReady(false)
        router.replace('/login')
      }
    })
    void supabase.auth.getSession().then(({ data, error }) => {
      if (!active) return
      if (error || !data.session) router.replace('/login')
      else setAuthReady(true)
    })
    return () => {
      active = false
      subscription.unsubscribe()
    }
  }, [router, supabase])

  async function signOut() {
    if (!supabase) return
    setAuthError('')
    try {
      const { error } = await supabase.auth.signOut()
      if (error) {
        setAuthError(`Không đăng xuất được: ${error.message}`)
        return
      }
      router.replace('/login')
    } catch (error) {
      setAuthError(`Không đăng xuất được: ${error instanceof Error ? error.message : String(error)}`)
    }
  }

  if (!authReady) {
    return <main className="flex min-h-screen items-center justify-center bg-[#f5f7fb] text-sm text-slate-500">Đang xác thực tài khoản…</main>
  }

  return (
    <main className="min-h-screen bg-[#f5f7fb] text-slate-800">
      {mobileOpen && (
        <button
          className="fixed inset-0 z-20 bg-slate-950/30 lg:hidden"
          onClick={() => setMobileOpen(false)}
          aria-label="Đóng menu"
        />
      )}
      <button
        className="fixed left-4 top-4 z-30 flex h-10 w-10 items-center justify-center rounded-xl bg-white text-slate-700 shadow-sm lg:hidden"
        onClick={() => setMobileOpen(true)}
        aria-label="Mở menu"
      >
        <Menu size={20} />
      </button>
      <aside
        className={`fixed inset-y-0 left-0 z-30 flex w-[246px] flex-col border-r border-slate-200 bg-white transition-transform lg:translate-x-0 ${
          mobileOpen ? 'translate-x-0' : '-translate-x-full'
        }`}
      >
        <div className="flex h-[76px] items-center gap-3 border-b border-slate-100 px-6">
          <div className="flex h-9 w-9 items-center justify-center rounded-xl bg-indigo-600 text-white shadow-lg shadow-indigo-200">
            <ShieldCheck size={19} />
          </div>
          <div>
            <p className="text-[15px] font-bold tracking-tight text-slate-900">Sotauni Admin</p>
            <p className="text-[10px] font-medium uppercase tracking-[0.17em] text-slate-400">
              Trung tâm điều hành
            </p>
          </div>
          <button
            className="ml-auto text-slate-400 lg:hidden"
            onClick={() => setMobileOpen(false)}
            aria-label="Đóng menu"
          >
            <X size={18} />
          </button>
        </div>
        <nav className="flex-1 overflow-y-auto px-3 py-5">
          {navigation.map((section) => (
            <div key={section.title} className="mb-6">
              <p className="mb-2 px-3 text-[10px] font-bold tracking-[0.14em] text-slate-400">
                {section.title}
              </p>
              {section.items.map((item) => {
                const Icon = item.icon
                const isActive = active === item.label
                return (
                  <Link
                    key={item.label}
                    href={item.href}
                    onClick={() => setMobileOpen(false)}
                    className={`mb-1 flex w-full items-center gap-3 rounded-xl px-3 py-2.5 text-left text-[12px] font-medium transition ${
                      isActive
                        ? 'bg-indigo-600 text-white shadow-md shadow-indigo-200'
                        : 'text-slate-500 hover:bg-slate-50 hover:text-slate-800'
                    }`}
                  >
                    <Icon size={16} strokeWidth={isActive ? 2.2 : 1.8} />
                    <span>{item.label}</span>
                    {isActive && <ChevronRight size={14} className="ml-auto opacity-80" />}
                  </Link>
                )
              })}
            </div>
          ))}
        </nav>
        <div className="m-3 rounded-2xl bg-slate-900 p-4 text-white">
          <div className="mb-3 flex items-center justify-between">
            <span className="rounded-lg bg-white/10 p-1.5">
              <Activity size={15} />
            </span>
            <span className="text-[10px] text-emerald-300">● Trung tâm điều hành</span>
          </div>
          <p className="text-xs font-semibold">Hệ thống quản trị</p>
          <p className="mt-1 text-[10px] leading-4 text-slate-400">
            Theo dõi dữ liệu và hoạt động hệ thống.
          </p>
        </div>
      </aside>

      <section className="lg:pl-[246px]">
        <header className="flex min-h-[76px] items-center justify-between border-b border-slate-200 bg-white px-5 sm:px-8">
          <div className="pl-12 lg:pl-0">
            <div className="flex items-center gap-2 text-xs text-slate-400">
              <span>Hệ thống</span>
              <ChevronRight size={13} />
              <span className="text-slate-700">{title}</span>
            </div>
            <h1 className="mt-1 text-lg font-bold tracking-tight text-slate-900">{title}</h1>
          </div>
          <div className="flex items-center gap-2 sm:gap-3">
            <div className="flex h-9 w-9 items-center justify-center rounded-full bg-indigo-100 text-xs font-bold text-indigo-700">
              AD
            </div>
            <div className="hidden sm:block">
              <p className="text-xs font-semibold text-slate-800">ADMIN</p>
              <p className="text-[10px] text-slate-400">Quản trị viên</p>
            </div>
            <button onClick={() => void signOut()} className="ml-1 flex h-9 items-center gap-1.5 rounded-lg border border-slate-200 px-2.5 text-[11px] font-medium text-slate-600 transition hover:bg-slate-50" aria-label="Đăng xuất">
              <LogOut size={14} /><span className="hidden sm:inline">Đăng xuất</span>
            </button>
          </div>
        </header>
        {authError && <p role="alert" className="mx-5 mt-4 rounded-lg bg-rose-50 p-3 text-xs text-rose-700 sm:mx-8">{authError}</p>}
        <div className="p-5 sm:p-8">{children}</div>
      </section>
    </main>
  )
}
