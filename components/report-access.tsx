'use client'

import { createContext, useContext } from 'react'

export type ReportAccess = {
  loading: boolean
  error: string
  employeeName: string
  roleIds: string[]
  roleNames: string[]
  permissions: string[]
  canViewKpi: boolean
  kpiAccessError: string
}

export const emptyReportAccess: ReportAccess = {
  loading: true,
  error: '',
  employeeName: '',
  roleIds: [],
  roleNames: [],
  permissions: [],
  canViewKpi: false,
  kpiAccessError: '',
}

export const ReportAccessContext = createContext<ReportAccess>(emptyReportAccess)

export function useReportAccess(): ReportAccess {
  return useContext(ReportAccessContext)
}
