'use client'

import {
  Bar,
  BarChart,
  CartesianGrid,
  Cell,
  Legend,
  Line,
  LineChart,
  Pie,
  PieChart,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis,
} from 'recharts'
import { formatCell, type DataRow } from '@/components/remote-data'

const palette = ['#2563eb', '#38bdf8', '#34d399', '#fb923c', '#f87171', '#6366f1']

export function ChartCard({
  title,
  description,
  data,
  kind,
  xKey,
  yKey,
  seriesName = 'Lượt đăng ký',
  height = 280,
  horizontal = false,
}: {
  title: string
  description?: string
  data: DataRow[]
  kind: 'line' | 'bar' | 'pie'
  xKey: string
  yKey: string
  seriesName?: string
  height?: number
  horizontal?: boolean
}) {
  return (
    <section className="rounded-2xl border border-slate-200 bg-white p-5 shadow-sm shadow-slate-100/70">
      <div className="mb-4">
        <h2 className="text-sm font-bold text-slate-900">{title}</h2>
        {description && <p className="mt-1 text-[11px] text-slate-400">{description}</p>}
      </div>
      {!data.length ? (
        <div className="flex items-center justify-center rounded-xl bg-slate-50 text-xs text-slate-400" style={{ height }}>
          Chưa có dữ liệu để hiển thị
        </div>
      ) : (
        <ResponsiveContainer width="100%" height={height}>
          {kind === 'line' ? (
            <LineChart data={data} margin={{ top: 8, right: 12, bottom: 4, left: -12 }}>
              <CartesianGrid stroke="#eef0f6" strokeDasharray="4 4" vertical={false} />
              <XAxis dataKey={xKey} tickFormatter={formatCell} tick={{ fontSize: 10, fill: '#94a3b8' }} axisLine={false} tickLine={false} />
              <YAxis allowDecimals={false} tick={{ fontSize: 10, fill: '#94a3b8' }} axisLine={false} tickLine={false} />
              <Tooltip
                labelFormatter={formatCell}
                formatter={(value, name) => [formatCell(value), formatCell(name)]}
              />
              <Line type="monotone" dataKey={yKey} name={seriesName} stroke="#2563eb" strokeWidth={3} dot={{ r: 3, fill: '#2563eb' }} activeDot={{ r: 5 }} />
            </LineChart>
          ) : kind === 'bar' ? (
            <BarChart data={data} layout={horizontal ? 'vertical' : 'horizontal'} margin={{ top: 8, right: 12, bottom: 4, left: horizontal ? 24 : -12 }}>
              <CartesianGrid stroke="#eef0f6" strokeDasharray="4 4" horizontal={!horizontal} vertical={horizontal} />
              {horizontal ? (
                <>
                  <XAxis type="number" allowDecimals={false} tick={{ fontSize: 10, fill: '#94a3b8' }} axisLine={false} tickLine={false} />
                  <YAxis type="category" dataKey={xKey} tickFormatter={formatCell} width={110} tick={{ fontSize: 10, fill: '#64748b' }} axisLine={false} tickLine={false} />
                </>
              ) : (
                <>
                  <XAxis dataKey={xKey} tickFormatter={formatCell} tick={{ fontSize: 10, fill: '#94a3b8' }} axisLine={false} tickLine={false} />
                  <YAxis allowDecimals={false} tick={{ fontSize: 10, fill: '#94a3b8' }} axisLine={false} tickLine={false} />
                </>
              )}
              <Tooltip
                labelFormatter={formatCell}
                formatter={(value, name) => [formatCell(value), formatCell(name)]}
              />
              <Bar dataKey={yKey} name="Số lượng" fill="#2563eb" radius={horizontal ? [0, 7, 7, 0] : [7, 7, 0, 0]} maxBarSize={38} />
            </BarChart>
          ) : (
            <PieChart>
              <Pie data={data} dataKey={yKey} nameKey={xKey} cx="50%" cy="50%" innerRadius="54%" outerRadius="82%" paddingAngle={3}>
                {data.map((row, index) => <Cell key={`${String(row[xKey] ?? 'segment')}-${index}`} fill={palette[index % palette.length]} />)}
              </Pie>
              <Tooltip
                labelFormatter={formatCell}
                formatter={(value, name) => [formatCell(value), formatCell(name)]}
              />
              <Legend formatter={formatCell} verticalAlign="bottom" height={28} wrapperStyle={{ fontSize: 10 }} />
            </PieChart>
          )}
        </ResponsiveContainer>
      )}
    </section>
  )
}
