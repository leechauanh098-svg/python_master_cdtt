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
import { emptyReportAccess, ReportAccessContext, type ReportAccess } from '@/components/report-access'
import { getSupabaseBrowserClient } from '@/lib/supabase-browser'

const navigation = [
  {
    title: 'WORKSPACE',
    items: [{ label: 'Dashboard quản trị', icon: LayoutDashboard, href: '/' }],
  },
  {
    title: 'TUYỂN SINH & HỌC VỤ',
    items: [
      { label: 'Quản lý thí sinh', icon: Users, href: '/thi-sinh' },
      { label: 'Python Master 2026', icon: Trophy, href: '/python-master' },
    ],
  },
  {
    title: 'ĐỐI TÁC & TRI THỨC',
    items: [
      { label: 'Đối tác đồng hành', icon: Package, href: '/doi-tac' },
      { label: 'Kho tài liệu RAG', icon: BookOpen, href: '/kho-tai-lieu' },
      { label: 'Lịch sử Q&A', icon: MessageSquare, href: '/qa' },
      { label: 'Quản lý FAQ', icon: CircleHelp, href: '/faq' },
    ],
  },
  {
    title: 'PHÂN TÍCH & HỆ THỐNG',
    items: [
      { label: 'KPI & Báo cáo', icon: BarChart3, href: '/bao-cao' },
      { label: 'Quản lý phân quyền', icon: ShieldCheck, href: '/phan-quyen' },
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
  const [authRedirecting, setAuthRedirecting] = useState(false)
  const [authError, setAuthError] = useState('')
  const [reportAccess, setReportAccess] = useState<ReportAccess>(emptyReportAccess)

  useEffect(() => {
    let active = true

    const redirectToLogin = () => {
      if (!active) return
      setAuthRedirecting(true)
      router.replace('/login')
    }

    if (!supabase) {
      redirectToLogin()
      return () => { active = false }
    }

    const { data: { subscription } } = supabase.auth.onAuthStateChange((_event, session) => {
      if (!active) return
      if (session) {
        setAuthRedirecting(false)
        setAuthReady(true)
      }
      else redirectToLogin()
    })
    void supabase.auth.getSession().then(({ data, error }) => {
      if (!active) return
      if (error || !data.session) redirectToLogin()
      else {
        setAuthRedirecting(false)
        setAuthReady(true)
      }
    })
    return () => {
      active = false
      subscription.unsubscribe()
    }
  }, [router, supabase])

  useEffect(() => {
    let active = true
    if (!authReady || !supabase) return () => { active = false }

    setReportAccess(emptyReportAccess)
    void supabase.rpc('fn_current_user_report_permissions').then(({ data, error }) => {
      if (!active) return
      if (error) {
        setReportAccess({
          ...emptyReportAccess,
          loading: false,
          error: `Không xác định được quyền báo cáo: ${error.message}`,
        })
        return
      }

      const rows = Array.isArray(data) ? data as Record<string, unknown>[] : []
      const firstRow = rows[0]
      const roleIds = Array.from(new Set(rows.flatMap((row) =>
        typeof row.role_id === 'string' ? [row.role_id] : [],
      )))
      const roleNames = Array.from(new Set(rows.flatMap((row) =>
        typeof row.ten_vai_tro === 'string' ? [row.ten_vai_tro] : [],
      )))
      const permissions = Array.from(new Set(rows.flatMap((row) =>
        typeof row.permission_id === 'string' ? [row.permission_id] : [],
      )))

      setReportAccess({
        loading: false,
        error: '',
        employeeName: typeof firstRow?.ho_ten === 'string' ? firstRow.ho_ten : '',
        roleIds,
        roleNames,
        permissions,
      })
    }, (error: unknown) => {
      if (!active) return
      setReportAccess({
        ...emptyReportAccess,
        loading: false,
        error: `Không xác định được quyền báo cáo: ${error instanceof Error ? error.message : String(error)}`,
      })
    })

    return () => { active = false }
  }, [authReady, supabase])

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
    return <main className="flex min-h-screen items-center justify-center bg-background text-sm text-slate-500">{authRedirecting ? 'Đang chuyển đến trang đăng nhập…' : 'Đang xác thực tài khoản…'}</main>
  }

  return (
    <main className="min-h-screen bg-background text-slate-800">
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
        className={`fixed inset-y-0 left-0 z-30 flex w-[280px] flex-col border-r border-slate-200/80 bg-white transition-transform lg:translate-x-0 ${
          mobileOpen ? 'translate-x-0' : '-translate-x-full'
        }`}
      >
        <div className="flex h-[76px] items-center gap-3 border-b border-slate-100 px-5">
          <div className="flex h-10 w-10 items-center justify-center rounded-[14px] bg-gradient-to-br from-blue-600 to-indigo-600 text-white shadow-lg shadow-blue-200/70">
            <ShieldCheck size={19} />
          </div>
          <div>
            <p className="text-[15px] font-bold tracking-tight text-slate-900">Python Master</p>
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
              <p className="mb-2 px-3 text-[10px] font-bold tracking-[0.14em] text-slate-500">
                {section.title}
              </p>
              {section.items
                .filter((item) => item.href !== '/bao-cao' || reportAccess.permissions.length > 0)
                .map((item) => {
                const Icon = item.icon
                const isActive = active === item.label
                return (
                  <Link
                    key={item.label}
                    href={item.href}
                    onClick={() => setMobileOpen(false)}
                    className={`mb-1 flex w-full items-center gap-3 rounded-xl px-3 py-3 text-left text-sm font-medium transition ${
                      isActive
                        ? 'bg-blue-50 text-blue-700 ring-1 ring-blue-100'
                        : 'text-slate-500 hover:bg-slate-50 hover:text-slate-900'
                    }`}
                  >
                    <span className={`flex h-8 w-8 items-center justify-center rounded-lg ${isActive ? 'bg-white text-blue-600 shadow-sm' : 'text-slate-400'}`}>
                      <Icon size={16} strokeWidth={isActive ? 2.2 : 1.8} />
                    </span>
                    <span>{item.label}</span>
                    {isActive && <ChevronRight size={14} className="ml-auto text-blue-400" />}
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

      <section className="lg:pl-[280px]">
      <header className="sticky top-0 z-20 flex min-h-[76px] items-center justify-between border-b border-slate-200/80 bg-white/90 px-5 backdrop-blur-xl sm:px-8">
          <div className="pl-12 lg:pl-0">
            <div className="flex items-center gap-2 text-xs text-slate-400">
              <span>Hệ thống</span>
              <ChevronRight size={13} />
              <span className="text-slate-700">{title}</span>
            </div>
            <h1 className="mt-1 text-2xl font-bold tracking-tight text-slate-900">{title}</h1>
          </div>
          <div className="flex items-center gap-2 sm:gap-3">
            <div className="flex h-9 w-9 items-center justify-center rounded-full bg-blue-100 text-xs font-bold text-blue-700">
              {(reportAccess.employeeName || 'NV').split(/\s+/).slice(-1)[0].slice(0, 2).toLocaleUpperCase('vi')}
            </div>
            <div className="hidden sm:block">
              <p className="text-sm font-semibold text-slate-800">{reportAccess.employeeName || 'Nhân viên'}</p>
              <p className="text-xs text-slate-500">{reportAccess.roleNames.join(', ') || 'Tài khoản hệ thống'}</p>
            </div>
            <button onClick={() => void signOut()} className="ml-1 flex h-9 items-center gap-1.5 rounded-lg border border-slate-200 px-2.5 text-[11px] font-medium text-slate-600 transition hover:bg-slate-50" aria-label="Đăng xuất">
              <LogOut size={14} /><span className="hidden sm:inline">Đăng xuất</span>
            </button>
          </div>
        </header>
        {authError && <p role="alert" className="mx-5 mt-4 rounded-lg bg-rose-50 p-3 text-xs text-rose-700 sm:mx-8">{authError}</p>}
        <ReportAccessContext.Provider value={reportAccess}>
          <div className="mx-auto w-full max-w-[1920px] p-5 sm:p-7 2xl:px-10 2xl:py-8">{children}</div>
        </ReportAccessContext.Provider>
      </section>
    </main>
  )
}
