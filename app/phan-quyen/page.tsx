'use client'

import { useCallback, useEffect, useMemo, useState } from 'react'
import {
  AlertTriangle,
  Check,
  RefreshCw,
  Save,
  Search,
  Users,
} from 'lucide-react'
import { AdminShell } from '@/components/admin-shell'
import { formatCell, formatFieldLabel } from '@/components/remote-data'
import { getSupabaseBrowserClient } from '@/lib/supabase-browser'

type DataRow = Record<string, unknown>

const roleIdKeys = ['id', 'role_id', 'vaitro_id', 'ma_vai_tro', 'id_vai_tro']
const roleNameKeys = ['ten_vai_tro', 'vai_tro', 'role_name', 'name', 'ten']
const labelKeys = ['modun_chucnang', 'ten_quyen', 'mo_ta', 'nhom_chuc_nang', 'ten_nhom', 'chuc_nang', 'ten_chuc_nang', 'module', 'resource', 'name', 'ten']

function fieldValue(row: DataRow, keys: string): unknown {
  const wanted = keys.split('|')
  const entry = Object.entries(row).find(([key]) => wanted.includes(key.toLowerCase()))
  return entry?.[1]
}

function toRows(value: unknown): DataRow[] {
  if (Array.isArray(value)) return value.filter((row): row is DataRow => typeof row === 'object' && row !== null)
  if (value && typeof value === 'object') {
    const record = value as DataRow
    for (const key of ['rows', 'data', 'permissions', 'ma_tran']) {
      if (Array.isArray(record[key])) return toRows(record[key])
    }
    return [record]
  }
  return []
}

function isEnabled(value: unknown): boolean {
  return value === true || value === 1 || value === '1' || value === 'true'
}

function display(value: unknown): string {
  if (value == null || value === '') return '—'
  if (typeof value === 'object') return JSON.stringify(value)
  return String(value)
}

function permissionLabel(row: DataRow): string {
  const module = fieldValue(row, 'modun_chucnang|module')
  const name = fieldValue(row, 'ten_quyen|mo_ta|ten_chuc_nang|chuc_nang')
  const moduleLabel = typeof module === 'string' ? formatCell(module) : ''
  const nameLabel = typeof name === 'string' ? name : name == null ? '' : display(name)
  return moduleLabel && nameLabel ? `${moduleLabel} · ${nameLabel}` : nameLabel || moduleLabel || 'Chức năng chưa đặt tên'
}

export default function PermissionPage() {
  const supabase = useMemo(() => getSupabaseBrowserClient(), [])
  const [roles, setRoles] = useState<DataRow[]>([])
  const [rolesLoading, setRolesLoading] = useState(true)
  const [rolesError, setRolesError] = useState('')
  const [selectedRole, setSelectedRole] = useState<DataRow | null>(null)
  const [roleSearch, setRoleSearch] = useState('')
  const [matrix, setMatrix] = useState<DataRow[]>([])
  const [matrixLoading, setMatrixLoading] = useState(false)
  const [matrixError, setMatrixError] = useState('')
  const [saving, setSaving] = useState(false)
  const [saveMessage, setSaveMessage] = useState('')

  const loadRoles = useCallback(async () => {
    if (!supabase) {
      setRolesError('Thiếu cấu hình Supabase. Hãy khai báo NEXT_PUBLIC_SUPABASE_URL và NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY.')
      setRolesLoading(false)
      return
    }
    setRolesLoading(true)
    setRolesError('')
    const { data, error } = await supabase.from('vw_vaitro').select('*')
    if (error) {
      setRolesError(`Không tải được danh sách vai trò: ${error.message}`)
      setRoles([])
    } else {
      const loaded = (data ?? []) as DataRow[]
      setRoles(loaded)
      setSelectedRole((current) => current ?? loaded[0] ?? null)
    }
    setRolesLoading(false)
  }, [supabase])

  useEffect(() => {
    void loadRoles()
  }, [loadRoles])

  useEffect(() => {
    let active = true
    async function loadMatrix() {
      if (!supabase || !selectedRole) {
        setMatrix([])
        return
      }
      const roleId = fieldValue(selectedRole, roleIdKeys.join('|'))
      if (roleId == null) {
        setMatrixError('Không tìm thấy mã vai trò trong dữ liệu vw_vaitro.')
        setMatrix([])
        return
      }
      setMatrixLoading(true)
      setMatrixError('')
      setSaveMessage('')
      const { data, error } = await supabase.rpc('fn_ma_tran_phan_quyen', { p_role_id: roleId })
      if (!active) return
      if (error) {
        setMatrixError(`Không tải được ma trận phân quyền: ${error.message}`)
        setMatrix([])
      } else {
        setMatrix(toRows(data))
      }
      setMatrixLoading(false)
    }
    void loadMatrix()
    return () => { active = false }
  }, [selectedRole, supabase])

  const filteredRoles = useMemo(() => {
    const query = roleSearch.trim().toLocaleLowerCase('vi')
    return roles.filter((role) => display(fieldValue(role, roleNameKeys.join('|'))).toLocaleLowerCase('vi').includes(query))
  }, [roleSearch, roles])
  const permissionColumns = useMemo(() => {
    const labelSet = new Set(labelKeys)
    const keys = Array.from(new Set(matrix.flatMap((row) => Object.keys(row))))
    const editableKeys = keys.filter((key) => {
      const normalized = key.toLowerCase()
      if (labelSet.has(normalized) || ['id', 'role_id', 'vaitro_id', 'ma_vai_tro', 'permission_id'].includes(normalized)) return false
      return matrix.some((row) => typeof row[key] === 'boolean' || row[key] === 0 || row[key] === 1 || row[key] === '0' || row[key] === '1')
    })
    return editableKeys.includes('duoc_phep') ? ['duoc_phep'] : editableKeys
  }, [matrix])

  function changePermission(rowIndex: number, column: string, checked: boolean) {
    setMatrix((current) => current.map((row, index) => {
      if (index !== rowIndex) return row
      const previous = row[column]
      return { ...row, [column]: typeof previous === 'number' ? Number(checked) : typeof previous === 'string' ? String(Number(checked)) : checked }
    }))
    setSaveMessage('')
  }

  async function saveMatrix() {
    if (!supabase || !selectedRole) return
    setSaving(true)
    setSaveMessage('')
    const { data: userData, error: userError } = await supabase.auth.getUser()
    if (userError || !userData.user) {
      setSaveMessage(userError ? `Không xác thực được người dùng: ${userError.message}` : 'Cần đăng nhập để lưu thay đổi phân quyền.')
      setSaving(false)
      return
    }
    const { error } = await supabase.rpc('fn_luu_ma_tran_quyen', {
      p_ds: matrix,
      p_nhan_vien_id: userData.user.id,
    })
    if (error) setSaveMessage(`Lưu ma trận thất bại: ${error.message}`)
    else setSaveMessage('Đã lưu ma trận phân quyền.')
    setSaving(false)
  }

  const selectedName = selectedRole ? display(fieldValue(selectedRole, roleNameKeys.join('|'))) : 'Chưa chọn vai trò'

  return (
    <AdminShell active="Quản lý phân quyền" title="Quản lý phân quyền">
      <div className="mb-6 flex flex-wrap items-end justify-between gap-4">
        <div>
          <p className="text-sm text-slate-500">Thiết lập vai trò và quyền truy cập các chức năng hệ thống.</p>
        </div>
        <button
          onClick={() => { void loadRoles() }}
          className="flex items-center gap-2 rounded-xl border border-slate-200 bg-white px-3.5 py-2.5 text-xs font-semibold text-slate-600 shadow-sm hover:bg-slate-50"
        >
          <RefreshCw size={14} /> Làm mới vai trò
        </button>
      </div>

      {(rolesError && !roles.length) && (
        <div role="alert" className="mb-5 flex items-start gap-2 rounded-xl border border-amber-200 bg-amber-50 p-3 text-xs leading-5 text-amber-800">
          <AlertTriangle size={16} className="mt-0.5 shrink-0" /> {rolesError}
        </div>
      )}

      <div className="grid items-start gap-5 xl:grid-cols-[minmax(260px,0.82fr)_minmax(0,1.8fr)]">
        <section className="rounded-2xl border border-slate-200 bg-white p-5 shadow-sm shadow-slate-100/70">
          <div className="mb-4 flex items-center justify-between">
            <div>
              <h2 className="text-sm font-bold text-slate-900">Danh sách vai trò</h2>
              <p className="mt-1 text-[11px] text-slate-400">Chọn vai trò để xem quyền hiện tại</p>
            </div>
            <Users size={17} className="text-blue-500" />
          </div>
          <div className="relative mb-3">
            <Search size={15} className="absolute left-3 top-1/2 -translate-y-1/2 text-slate-400" />
            <input
              value={roleSearch}
              onChange={(event) => setRoleSearch(event.target.value)}
              className="h-9 w-full rounded-lg border border-slate-200 bg-slate-50 pl-9 pr-3 text-xs outline-none placeholder:text-slate-400 focus:border-blue-400"
              placeholder="Tìm kiếm vai trò…"
            />
          </div>
          {rolesLoading ? <p className="p-5 text-center text-xs text-slate-500">Đang tải vai trò…</p> : rolesError ? (
            <p role="alert" className="rounded-lg bg-rose-50 p-3 text-xs leading-5 text-rose-700">{rolesError}</p>
          ) : roles.length === 0 ? <p className="p-5 text-center text-xs text-slate-500">Chưa có vai trò nào.</p> : (
            <div className="space-y-1">
              {filteredRoles.map((role, index) => {
                const active = selectedRole === role
                const name = display(fieldValue(role, roleNameKeys.join('|')))
                return (
                  <button
                    key={String(fieldValue(role, roleIdKeys.join('|')) ?? index)}
                    onClick={() => setSelectedRole(role)}
                    className={`flex w-full items-center gap-3 rounded-xl p-3 text-left transition ${active ? 'bg-blue-50 ring-1 ring-blue-100' : 'hover:bg-slate-50'}`}
                  >
                    <span className={`flex h-9 w-9 shrink-0 items-center justify-center rounded-xl text-[10px] font-bold ${active ? 'bg-blue-600 text-white' : 'bg-slate-100 text-slate-500'}`}>
                      {name.slice(0, 2).toLocaleUpperCase('vi')}
                    </span>
                    <span className="min-w-0 flex-1 truncate text-xs font-semibold text-slate-800">{name}</span>
                    {active && <Check size={15} className="text-blue-600" />}
                  </button>
                )
              })}
            </div>
          )}
        </section>

        <section className="min-w-0 rounded-2xl border border-slate-200 bg-white p-5 shadow-sm shadow-slate-100/70">
          <div className="mb-4 flex flex-wrap items-center justify-between gap-3">
            <div>
              <h2 className="text-sm font-bold text-slate-900">Ma trận phân quyền</h2>
              <p className="mt-1 text-[11px] text-slate-400">Vai trò: <span className="font-semibold text-slate-600">{selectedName}</span></p>
            </div>
            <button
              onClick={() => void saveMatrix()}
              disabled={saving || matrixLoading || !matrix.length}
              className="flex items-center gap-2 rounded-xl bg-blue-600 px-4 py-2.5 text-xs font-semibold text-white shadow-md shadow-blue-200 transition hover:bg-blue-700 disabled:cursor-not-allowed disabled:opacity-50"
            >
              <Save size={14} /> {saving ? 'Đang lưu…' : 'Lưu thay đổi'}
            </button>
          </div>
          {matrixError && <p role="alert" className="mb-3 rounded-lg bg-rose-50 p-3 text-xs leading-5 text-rose-700">{matrixError}</p>}
          {saveMessage && <p role="status" className={`mb-3 rounded-lg p-3 text-xs leading-5 ${saveMessage.startsWith('Đã lưu') ? 'bg-emerald-50 text-emerald-700' : 'bg-amber-50 text-amber-800'}`}>{saveMessage}</p>}
          {matrixLoading ? <p className="p-8 text-center text-xs text-slate-500">Đang tải ma trận…</p> : matrix.length === 0 ? (
            <p className="rounded-xl bg-slate-50 p-8 text-center text-xs text-slate-500">Chọn vai trò để tải ma trận phân quyền.</p>
          ) : permissionColumns.length === 0 ? (
            <p className="rounded-xl bg-amber-50 p-4 text-xs leading-5 text-amber-800">Dữ liệu ma trận không có cột quyền dạng boolean hoặc 0/1 để chỉnh sửa. Kiểm tra cấu trúc trả về của fn_ma_tran_phan_quyen.</p>
          ) : (
            <div className="overflow-x-auto">
              <table className="w-full min-w-[560px] text-left text-xs">
                <thead>
                  <tr className="border-b border-slate-100 text-[10px] tracking-wide text-slate-400">
                    <th className="px-3 py-3 font-semibold">Nhóm chức năng</th>
                    {permissionColumns.map((column) => <th key={column} className="px-3 py-3 text-center font-semibold">{formatFieldLabel(column)}</th>)}
                  </tr>
                </thead>
                <tbody>
                  {matrix.map((row, rowIndex) => (
                    <tr key={String(fieldValue(row, 'id|chuc_nang_id|ma_chuc_nang') ?? rowIndex)} className="border-b border-slate-50 last:border-0">
                      <td className="px-3 py-3 font-medium text-slate-700">{permissionLabel(row)}</td>
                      {permissionColumns.map((column) => (
                        <td key={column} className="px-3 py-3 text-center">
                          <input
                            type="checkbox"
                            aria-label={`${permissionLabel(row)} - ${formatFieldLabel(column)}`}
                            checked={isEnabled(row[column])}
                            onChange={(event) => changePermission(rowIndex, column, event.target.checked)}
                            className="h-4 w-4 rounded border-slate-300 accent-blue-600"
                          />
                        </td>
                      ))}
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </section>
      </div>

    </AdminShell>
  )
}
