'use client'

import Link from 'next/link'
import { ArrowRight, BarChart3, BookOpen, CircleHelp, MessageSquare, Package, Trophy, Users } from 'lucide-react'
import { AdminShell } from '@/components/admin-shell'

const workspaces = [
  { title: 'Quản lý thí sinh', description: 'Tìm kiếm, lọc và xử lý hồ sơ thí sinh.', href: '/thi-sinh', icon: Users },
  { title: 'Python Master 2026', description: 'Theo dõi vòng thi và các hoạt động học vụ.', href: '/python-master', icon: Trophy },
  { title: 'Đối tác đồng hành', description: 'Quản lý thông tin nhà tài trợ và đối tác.', href: '/doi-tac', icon: Package },
  { title: 'Lịch sử Q&A', description: 'Tra cứu và phản hồi các cuộc hội thoại hỗ trợ.', href: '/qa', icon: MessageSquare },
  { title: 'Quản lý FAQ', description: 'Cập nhật câu hỏi thường gặp và danh mục.', href: '/faq', icon: CircleHelp },
  { title: 'Kho tài liệu RAG', description: 'Quản lý tài liệu và nội dung tham chiếu.', href: '/kho-tai-lieu', icon: BookOpen },
]

export default function DashboardPage() {
  return (
    <AdminShell active="Dashboard quản trị" title="Dashboard quản trị">
      <section className="mb-6 rounded-2xl bg-gradient-to-r from-blue-700 to-indigo-700 p-6 text-white sm:p-8">
        <p className="text-[10px] font-bold uppercase tracking-[0.2em] text-blue-100">TRUNG TÂM ĐIỀU HÀNH</p>
        <h2 className="mt-2 text-2xl font-bold tracking-tight">Không gian làm việc</h2>
        <p className="mt-2 max-w-2xl text-sm leading-6 text-blue-100">
          Chọn phân hệ để xử lý công việc. KPI, biểu đồ và dữ liệu tổng hợp được tập trung tại trang Báo cáo.
        </p>
        <Link href="/bao-cao" className="mt-5 inline-flex min-h-11 items-center gap-2 rounded-xl bg-white px-4 py-2.5 text-sm font-semibold text-blue-700 shadow-sm hover:bg-blue-50">
          <BarChart3 size={15} /> Mở KPI & Báo cáo <ArrowRight size={14} />
        </Link>
      </section>

      <div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-3">
        {workspaces.map(({ title, description, href, icon: Icon }) => (
          <Link key={href} href={href} className="group flex min-h-44 flex-col rounded-2xl border border-slate-200 bg-white p-5 shadow-sm transition hover:-translate-y-0.5 hover:border-blue-200 hover:shadow-md">
            <div className="flex items-start justify-between gap-3">
              <span className="rounded-xl bg-blue-50 p-2.5 text-blue-600"><Icon size={18} /></span>
              <ArrowRight size={15} className="mt-1 text-slate-300 transition group-hover:translate-x-1 group-hover:text-blue-600" />
            </div>
            <h3 className="mt-4 text-sm font-bold text-slate-900">{title}</h3>
            <p className="mt-1 text-sm leading-6 text-slate-600">{description}</p>
          </Link>
        ))}
      </div>
    </AdminShell>
  )
}
