import { formatCell } from '@/components/remote-data'

export type DashboardDataset = {
  reportId: string
  title: string
  rows: Record<string, unknown>[]
}

export type DashboardKpi = {
  label: string
  value: string
  detail?: string
}

export type DashboardChart = {
  title: string
  categories: string[]
  series: { name: string; values: (number | null)[]; xValues?: (number | null)[]; color?: string; pointColors?: string[]; chartType?: 'bar' | 'line'; hidden?: boolean }[]
  type: 'bar' | 'line' | 'pie' | 'doughnut' | 'funnel' | 'combo' | 'gantt' | 'scatter'
  direction?: 'bar' | 'col'
  grouping?: 'clustered' | 'stacked' | 'percentStacked'
  axisMin?: number
  axisMax?: number
  showValues?: boolean
  showPercent?: boolean
}

export type ExcelDashboard = {
  title: string
  kpis: DashboardKpi[]
  notes: string[]
  charts: (DashboardChart & { reportId: string })[]
  customChartReportIds: string[]
}

function rowsFor(datasets: DashboardDataset[], reportId: string): Record<string, unknown>[] {
  return datasets.find((dataset) => dataset.reportId === reportId)?.rows ?? []
}

function numberValue(value: unknown): number | null {
  if (typeof value !== 'number' && (typeof value !== 'string' || value.trim() === '')) return null
  const parsed = Number(value)
  return Number.isFinite(parsed) ? parsed : null
}

function firstValue(rows: Record<string, unknown>[], key: string): unknown {
  return rows.find((row) => row[key] != null)?.[key]
}

function combineRows(rows: Record<string, unknown>[]): Record<string, unknown> {
  return Object.assign({}, ...rows)
}

function money(value: unknown, digits = 1): string {
  const amount = numberValue(value)
  if (amount == null) return '—'
  if (Math.abs(amount) >= 1_000_000) {
    return `${new Intl.NumberFormat('vi-VN', { maximumFractionDigits: digits, minimumFractionDigits: digits }).format(amount / 1_000_000)} tr`
  }
  if (Math.abs(amount) >= 1_000) {
    return `${new Intl.NumberFormat('vi-VN', { maximumFractionDigits: 0 }).format(amount / 1_000)} nghìn`
  }
  return new Intl.NumberFormat('vi-VN', { maximumFractionDigits: digits }).format(amount)
}

function count(value: unknown): string {
  const number = numberValue(value)
  return number == null ? '—' : new Intl.NumberFormat('vi-VN', { maximumFractionDigits: 0 }).format(number)
}

function percent(value: unknown): string {
  const number = numberValue(value)
  return number == null ? '—' : `${new Intl.NumberFormat('vi-VN', { maximumFractionDigits: 2 }).format(number)}%`
}

function chart(
  title: string,
  categories: string[],
  series: DashboardChart['series'],
  type: DashboardChart['type'] = 'bar',
  options: Pick<DashboardChart, 'direction' | 'grouping' | 'showValues' | 'showPercent' | 'axisMin' | 'axisMax'> = {},
): DashboardChart | null {
  if (!categories.length || !series.some((item) => item.values.some((value) => value != null))) return null
  return { title, categories, series, type, ...options }
}

function rowsChart(
  title: string,
  rows: Record<string, unknown>[],
  categoryKey: string,
  valueKeys: { key: string; name: string }[],
  type: DashboardChart['type'] = 'bar',
  options: Pick<DashboardChart, 'direction' | 'grouping' | 'showValues' | 'showPercent' | 'axisMin' | 'axisMax'> = {},
): DashboardChart | null {
  const usable = rows.filter((row) => row[categoryKey] != null && String(row[categoryKey]).trim() !== '')
  const categories = usable.map((row) => formatCell(row[categoryKey]))
  const series = valueKeys.map(({ key, name }) => ({
    name,
    values: usable.map((row) => numberValue(row[key])),
  }))
  return chart(title, categories, series, type, options)
}

function groupedChart(
  title: string,
  rows: Record<string, unknown>[],
  categoryKey: string,
  seriesKey: string,
  valueKey: string,
  options: Pick<DashboardChart, 'direction' | 'grouping' | 'showValues' | 'showPercent'> = {},
): DashboardChart | null {
  const categories = Array.from(new Set(rows.map((row) => formatCell(row[categoryKey])).filter((value) => value !== '—')))
  const seriesNames = Array.from(new Set(rows.map((row) => formatCell(row[seriesKey])).filter((value) => value !== '—')))
  const values = new Map<string, number>()
  rows.forEach((row) => {
    const category = formatCell(row[categoryKey])
    const seriesName = formatCell(row[seriesKey])
    const value = valueKey === '__count__' ? 1 : numberValue(row[valueKey])
    if (value == null) return
    const key = `${seriesName}\u0000${category}`
    values.set(key, (values.get(key) ?? 0) + value)
  })
  return chart(title, categories, seriesNames.map((name) => ({
    name,
    values: categories.map((category) => values.get(`${name}\u0000${category}`) ?? 0),
  })), 'bar', { direction: 'bar', grouping: 'stacked', showValues: true, ...options })
}

function dateLabel(value: unknown): string {
  const text = String(value ?? '')
  const match = text.match(/^(\d{4})-(\d{2})-(\d{2})/)
  return match ? `${Number(match[3])}/${Number(match[2])}` : formatCell(value)
}

function excelDateSerial(value: unknown): number | null {
  const timestamp = new Date(String(value ?? '')).getTime()
  return Number.isNaN(timestamp) ? null : timestamp / 86_400_000 + 25569
}

function dashboardMetrics(
  tab: string,
  period: string,
  datasets: DashboardDataset[],
  rawResults: Record<string, unknown>,
): ExcelDashboard {
  const rawSummary = (value: unknown) =>
    Array.isArray(value)
      ? value.filter((row): row is Record<string, unknown> => typeof row === 'object' && row !== null)
      : value && typeof value === 'object'
        ? [value as Record<string, unknown>]
        : []
  const summary = combineRows(rawSummary(rawResults.overview_summary).concat(rowsFor(datasets, 'overview_summary')))
  const comparison = combineRows(rowsFor(datasets, 'overview_comparison'))
  const charts: (DashboardChart & { reportId: string })[] = []
  const notes: string[] = []
  const addChart = (reportId: string, value: DashboardChart | null) => {
    if (value) charts.push({ ...value, reportId })
  }
  let kpis: DashboardKpi[] = []
  let title = `${tab} ${period.replace('-', '/')}`

  if (tab === 'Tổng quan') {
    title = `Tổng quan ${period.replace('-', '/')}`
    kpis = [
      { label: 'Tổng thu', value: money(summary.tong_thu) },
      { label: 'Doanh thu lệ phí', value: money(summary.doanh_thu_le_phi) },
      { label: 'Thực thu tài trợ', value: money(summary.thuc_thu_tai_tro) },
      { label: 'Thí sinh tham gia thực tế', value: count(summary.thi_sinh_tham_gia_thuc_te ?? summary.tham_gia_thuc_te) },
      { label: 'Đăng ký thi', value: count(summary.dang_ky_thi) },
      { label: 'Tỷ lệ tham gia', value: percent(summary.ty_le_tham_gia_pct) },
      { label: 'Chênh lệch so với kỳ trước', value: count(comparison.target_gap ?? 0) },
    ]
    const composition = chart('Cơ cấu tổng thu', ['Doanh thu lệ phí', 'Thực thu tài trợ'], [{
      name: 'Tổng thu',
      values: [numberValue(summary.doanh_thu_le_phi), numberValue(summary.thuc_thu_tai_tro)],
    }], 'doughnut', { showValues: true, showPercent: true })
    addChart('overview_summary', composition)
    const funnelRows = rowsFor(datasets, 'overview_enrollment_funnel').slice().sort((a, b) => Number(a.thu_tu) - Number(b.thu_tu))
    const funnel = chart('Phễu tuyển sinh', funnelRows.map((row) =>
      `${formatCell(row.buoc)} (${percent(row.ty_le_so_voi_tiep_can_pct)})`,
    ), [{
      name: 'Số lượng',
      values: funnelRows.map((row) => numberValue(row.so_luong)),
    }], 'funnel', { direction: 'bar', showValues: true })
    addChart('overview_enrollment_funnel', funnel)
    const progressRows = rowsFor(datasets, 'overview_progress')
    const progress = chart('Tiến độ chỉ tiêu', progressRows.map((row) =>
      `${formatCell(row.ten_kpi)} (${count(row.gia_tri_hien_tai)} / ${count(row.muc_tieu)})`,
    ), [
      {
        name: 'Tỷ lệ hoàn thành (%)',
        values: progressRows.map((row) => numberValue(row.hoan_thanh_pct)),
        pointColors: progressRows.map((row) => (numberValue(row.hoan_thanh_pct) ?? 0) >= 100 ? '#16A34A' : '#F97316'),
        chartType: 'bar',
      },
    ], 'combo', { direction: 'bar', grouping: 'clustered', showValues: true })
    addChart('overview_progress', progress)
    const leads = rowsFor(datasets, 'lead_pipeline')
    const leadChart = groupedChart('Lead theo nguồn và trạng thái thanh toán', leads, 'nguon', 'trang_thai_thanh_toan', 'so_luong',
      { grouping: 'stacked', showValues: true })
    addChart('lead_pipeline', leadChart)
    if (funnelRows.some((row) => formatCell(row.buoc).toLocaleLowerCase('vi').includes('hoàn thành') && Number(row.so_luong) === 0)) {
      notes.push('Bước “Hoàn thành” bằng 0; số liệu này cần đối chiếu với báo cáo Học vụ.')
    }
  } else if (tab === 'Thí sinh') {
    title = `Thí sinh & Tuyển sinh ${period.replace('-', '/')}`
    const student = combineRows(rowsFor(datasets, 'student_summary'))
    kpis = [
      { label: 'Thí sinh tham gia', value: count(student.tham_gia_thuc_te) },
      { label: 'Đăng ký thi', value: count(student.dang_ky_thi) },
      { label: 'Tỷ lệ tham gia', value: percent(student.ty_le_tham_gia_pct) },
      { label: 'Tổng lượt tiếp cận', value: count(student.tong_tiep_can) },
    ]
    const registered = numberValue(student.dang_ky_thi) ?? 0
    const participated = numberValue(student.tham_gia_thuc_te) ?? 0
    const participation = chart('Tỷ lệ tham gia', ['Đã tham gia', 'Chưa tham gia'], [{
      name: 'Thí sinh',
      values: [participated, Math.max(0, registered - participated)],
    }], 'doughnut', { showValues: true, showPercent: true })
    addChart('student_summary', participation)
    if (student.tong_tiep_can != null) notes.push(`Tổng lượt tiếp cận: ${count(student.tong_tiep_can)}.`)
    const statusRows = rowsFor(datasets, 'student_status').filter((row) => Number(row.so_luong) > 0)
    const status = rowsChart('Trạng thái hồ sơ', statusRows, 'trang_thai', [{ key: 'so_luong', name: 'Số lượng' }], 'doughnut', { showValues: true, showPercent: true })
    addChart('student_status', status)
    const schools = rowsFor(datasets, 'student_schools').slice().sort((a, b) => Number(b.so_luong_thi_sinh) - Number(a.so_luong_thi_sinh)).slice(0, 15)
    const shortenedSchools = schools.map((row) => ({
      ...row,
      truong_hoc: shortenSchoolName(String(row.truong_hoc ?? '')),
    }))
    const schoolChart = rowsChart('Thí sinh theo trường', shortenedSchools, 'truong_hoc', [{ key: 'so_luong_thi_sinh', name: 'Số thí sinh' }], 'bar', { direction: 'bar', showValues: true })
    addChart('student_schools', schoolChart)
    if (schools.length) notes.push(`Tên trường rút gọn trên biểu đồ; danh sách đầy đủ xem tại sheet “Thí sinh theo trường”.`)
    const scoreRows = rowsFor(datasets, 'student_school_scores').filter((row) => numberValue(row.so_thi_sinh) != null)
    const schoolByBracket = groupedChart('Thí sinh theo bảng đấu và trường', scoreRows, 'truong_hoc', 'bang_dau', 'so_thi_sinh',
      { grouping: 'stacked', showValues: true })
    addChart('student_school_scores', schoolByBracket)
    const campaigns = rowsFor(datasets, 'student_utm').slice()
      .sort((a, b) => (numberValue(b.luot_tiep_can) ?? 0) - (numberValue(a.luot_tiep_can) ?? 0))
    const campaignLabels = campaigns.map((row) => [row.nguon_utm, row.chien_dich].filter(Boolean).map(formatCell).join(' / '))
    const campaignChart = chart('Hiệu quả chiến dịch quảng cáo', campaignLabels, [
      { name: 'Lượt tiếp cận', values: campaigns.map((row) => numberValue(row.luot_tiep_can)) },
      { name: 'Số lượt đăng ký', values: campaigns.map((row) => numberValue(row.so_dang_ky)) },
    ], 'bar', { direction: 'col', showValues: true })
    addChart('student_utm', campaignChart)
    const revenueCampaigns = campaigns.filter((row) => Number(row.doanh_thu) > 0)
    const revenueChart = chart('Doanh thu theo chiến dịch', revenueCampaigns.map((row) =>
      [row.nguon_utm, row.chien_dich].filter(Boolean).map(formatCell).join(' / '),
    ), [{ name: 'Doanh thu', values: revenueCampaigns.map((row) => numberValue(row.doanh_thu)) }], 'bar', { direction: 'bar', showValues: true })
    addChart('student_utm', revenueChart)
    if (campaigns.some((row) => Number(row.chi_phi) === 0 || row.chi_phi == null)) notes.push('Chưa nhập chi phí quảng cáo nên chưa tính được ROI.')
  } else if (tab === 'Doanh thu') {
    title = `Doanh thu ${period.replace('-', '/')}`
    const revenue = combineRows(rowsFor(datasets, 'revenue_summary'))
    kpis = [
      { label: 'Tổng doanh thu', value: money(revenue.tong_doanh_thu) },
      { label: 'Giao dịch thành công', value: count(revenue.giao_dich_thanh_cong) },
      { label: 'Giá trị trung bình', value: money(revenue.gia_tri_trung_binh, 0) },
      { label: 'Đang đối soát', value: count(revenue.dang_doi_soat) },
    ]
    const trendRows = rowsFor(datasets, 'revenue_trend')
    const trend = chart('Xu hướng doanh thu theo ngày', trendRows.map((row) => dateLabel(row.ngay)), [
      { name: 'Doanh thu đã thanh toán', values: trendRows.map((row) => numberValue(row.doanh_thu)), chartType: 'bar' },
      { name: 'Số giao dịch thành công', values: trendRows.map((row) => numberValue(row.so_giao_dich)), chartType: 'line' },
      { name: 'Số lượt đăng ký', values: trendRows.map((row) => numberValue(row.so_dang_ky)), chartType: 'line' },
    ], 'combo', { direction: 'col', grouping: 'clustered', showValues: true })
    addChart('revenue_trend', trend)
    const funnelRows = rowsFor(datasets, 'payment_funnel').slice().sort((a, b) => Number(a.thu_tu) - Number(b.thu_tu))
    const funnel = chart('Phễu thanh toán', funnelRows.map((row) => `${formatCell(row.buoc)} (${percent(row.ty_le_pct)})`),
      [{ name: 'Số lượng', values: funnelRows.map((row) => numberValue(row.so_luong)) }], 'funnel', { direction: 'bar', showValues: true })
    addChart('payment_funnel', funnel)
    const province = rowsChart('Doanh thu theo tỉnh/thành', rowsFor(datasets, 'revenue_by_province').slice(0, 15), 'tinh_thanh',
      [{ key: 'doanh_thu', name: 'Doanh thu' }], 'bar', { direction: 'bar', showValues: true })
    addChart('revenue_by_province', province)
    const region = rowsChart('Doanh thu theo 3 miền', rowsFor(datasets, 'revenue_by_region'), 'vung',
      [{ key: 'doanh_thu', name: 'Doanh thu' }], 'doughnut', { showValues: true, showPercent: true })
    addChart('revenue_by_region', region)
    const channelRows = rowsFor(datasets, 'revenue_by_channel')
    const channel = rowsChart('Doanh thu theo kênh', channelRows, 'kenh', [{ key: 'doanh_thu', name: 'Doanh thu' }], 'doughnut', { showValues: true, showPercent: true })
    addChart('revenue_by_channel', channel)
    const reconciliation = rowsFor(datasets, 'revenue_reconciliation')
    const byDate = aggregateTransactionDates(reconciliation)
    const reconChart = chart('Giao dịch chờ đối soát quá 48 giờ', byDate.categories, [
      { name: 'Số giao dịch', values: byDate.counts },
      { name: 'Tổng số tiền', values: byDate.amounts },
    ], 'bar', { direction: 'col', grouping: 'clustered', showValues: true })
    addChart('revenue_reconciliation', reconChart)
    if (reconciliation.some((row) => Number(row.so_tien) === 0)) notes.push('Nhiều giao dịch đang đối soát có số tiền bằng 0.')
    const transactions = rowsFor(datasets, 'transaction_details')
    const transactionStatus = aggregateCount(transactions, 'trang_thai_thanh_toan')
    const transactionStatusChart = rowsChart('Giao dịch theo trạng thái thanh toán', transactionStatus, 'trang_thai_thanh_toan',
      [{ key: 'so_luong', name: 'Số giao dịch' }], 'doughnut', { showValues: true, showPercent: true })
    addChart('transaction_details', transactionStatusChart)
    const channelStatus = groupedChart('Kênh theo trạng thái thanh toán', transactions, 'kenh', 'trang_thai_thanh_toan', '__count__')
    addChart('transaction_details', channelStatus)
    const feeByBracket = aggregateSum(transactions, 'bang_dau', 'le_phi_thi')
    const feeChart = rowsChart('Tổng lệ phí thi theo bảng đấu', feeByBracket, 'bang_dau',
      [{ key: 'tong_gia_tri', name: 'Tổng lệ phí thi' }], 'bar', { direction: 'bar', showValues: true })
    addChart('transaction_details', feeChart)
    const channels = rowsFor(datasets, 'revenue_by_channel')
    const directShare = channels.filter((row) => /trực tiếp|không xác định/i.test(formatCell(row.kenh)))
      .reduce((sum, row) => sum + (numberValue(row.ty_le_pct) ?? 0), 0)
    if (directShare > 0) notes.push(`Trực tiếp/Không xác định chiếm khoảng ${percent(directShare)} doanh thu.`)
  } else if (tab === 'Học vụ') {
    title = `Học vụ & Kết quả thi ${period.replace('-', '/')}`
    const statusRows = rowsFor(datasets, 'submission_status')
    const status = rowsChart('Trạng thái bài nộp', statusRows, 'trang_thai', [{ key: 'so_luong', name: 'Số lượng' }], 'doughnut', { showValues: true, showPercent: true })
    addChart('submission_status', status)
    const failRows = rowsFor(datasets, 'submission_failures')
    const failures = chart('Bài tập có tỷ lệ không đạt cao', failRows.map((row) => formatCell(row.ten_bai_tap)), [
      { name: 'Tổng lượt nộp', values: failRows.map((row) => numberValue(row.tong_luot_nop)), chartType: 'bar' },
      { name: 'Tỷ lệ không đạt (%)', values: failRows.map((row) => numberValue(row.tyle_khong_dat_pt)), chartType: 'line' },
    ], 'combo', { direction: 'col', grouping: 'clustered', showValues: true })
    addChart('submission_failures', failures)
    const province = rowsChart('Tỷ lệ không đạt theo tỉnh/thành', rowsFor(datasets, 'submission_failures_by_province'), 'tinh_thanh', [
      { key: 'tyle_khong_dat_pt', name: 'Tỷ lệ không đạt (%)' },
    ], 'bar', { direction: 'bar', showValues: true })
    addChart('submission_failures_by_province', province)
    const roundRows = rowsFor(datasets, 'contest_rounds')
      .map((row) => ({
        row,
        start: excelDateSerial(row.ngay_bat_dau),
        end: excelDateSerial(row.ngay_ket_thuc),
      }))
      .filter((item): item is { row: Record<string, unknown>; start: number; end: number } =>
        item.start != null && item.end != null && item.end >= item.start,
      )
      .sort((a, b) => a.start - b.start)
    const rounds = chart('Lịch các vòng thi', roundRows.map(({ row }) =>
      `${formatCell(row.ten_cuoc_thi)} · Hạn đăng ký ${dateLabel(row.han_dang_ky)}`,
    ), [
      { name: 'Bắt đầu', values: roundRows.map(({ start }) => start), hidden: true },
      { name: 'Thời lượng (ngày)', values: roundRows.map(({ start, end }) => end - start), color: '4472C4' },
    ], 'gantt', {
      direction: 'bar',
      grouping: 'stacked',
      axisMin: roundRows.length ? Math.min(...roundRows.map(({ start }) => start)) : undefined,
      axisMax: roundRows.length ? Math.max(...roundRows.map(({ end }) => end)) : undefined,
    })
    addChart('contest_rounds', rounds)
    const results = rowsFor(datasets, 'contest_results')
    const outcomes = groupedChart('Đạt yêu cầu / Không đạt theo cuộc thi', results, 'cuoc_thi_id', 'ket_qua_xet', '__count__')
    addChart('contest_results', outcomes)
    const ct02Scores = results.filter((row) => String(row.cuoc_thi_id).toUpperCase() === 'CT02' && numberValue(row.tong_diem) != null)
    const histogram = histogramByHundred(ct02Scores, 'tong_diem')
    const histogramChart = chart('Phân phối tổng điểm vòng CT02', histogram.categories, [
      { name: 'Số thí sinh', values: histogram.values },
    ], 'bar', { direction: 'col', showValues: true })
    addChart('contest_results', histogramChart)
    const schoolAverages = averageByKey(results.filter((row) =>
      String(row.cuoc_thi_id).toUpperCase() === 'CT02' && row.truong_hoc != null,
    ), 'truong_hoc', 'tong_diem').slice(0, 15)
    const schoolAverageChart = rowsChart('Điểm trung bình CT02 theo trường', schoolAverages, 'truong_hoc',
      [{ key: 'gia_tri_trung_binh', name: 'Điểm trung bình' }], 'bar', { direction: 'bar', showValues: true })
    addChart('contest_results', schoolAverageChart)
    const topRows = rowsFor(datasets, 'contest_top56').slice().sort((a, b) => Number(b.tong_diem) - Number(a.tong_diem)).slice(0, 10)
    const top = rowsChart('Top 10 thí sinh theo tổng điểm', topRows, 'ho_ten', [{ key: 'tong_diem', name: 'Tổng điểm' }], 'bar', { direction: 'bar', showValues: true })
    addChart('contest_top56', top)
    const detailRows = rowsFor(datasets, 'submission_details').filter((row) => numberValue(row.diem_toi_da) != null && Number(row.diem_toi_da) > 0)
    const questionTotals = aggregateQuestionScores(detailRows)
    const questionChart = chart('Tỷ lệ điểm đạt được theo câu hỏi', questionTotals.categories,
      [{ name: 'Điểm đạt được / điểm tối đa (%)', values: questionTotals.values }], 'bar', { direction: 'bar', showValues: true })
    addChart('submission_details', questionChart)
    const submittedAnswers = detailRows.filter((row) => typeof row.la_dap_an_dung === 'boolean')
    const answerSummary = aggregateAnswersByType(submittedAnswers)
    const answerChart = chart('Tỷ lệ trả lời đúng theo loại câu hỏi', answerSummary.categories,
      [{ name: 'Tỷ lệ đúng (%)', values: answerSummary.values }], 'bar', { direction: 'bar', showValues: true })
    addChart('submission_details', answerChart)
    const lowestQuestions = aggregateAnswersByQuestion(submittedAnswers).lowestQuestions
    if (lowestQuestions.length) notes.push(`Ba câu có tỷ lệ trả lời đúng thấp nhất: ${lowestQuestions.join('; ')}.`)
    const lowSample = rowsFor(datasets, 'submission_failures_by_province').filter((row) => Number(row.tong_luot_nop) <= 1)
    if (lowSample.length) notes.push(`${lowSample.map((row) => formatCell(row.tinh_thanh)).join(' và ')} chỉ có 1 lượt nộp; tỷ lệ chưa đáng tin cậy.`)
  } else if (tab === 'Đối tác') {
    title = `Tài trợ & Đối tác ${period.replace('-', '/')}`
    const sponsors = combineRows(rowsFor(datasets, 'sponsor_summary'))
    kpis = [
      { label: 'Hợp đồng đã ký', value: count(sponsors.hop_dong_da_ky) },
      { label: 'Số nhà tài trợ', value: count(sponsors.so_nha_tai_tro) },
      { label: 'Thực thu tài trợ', value: money(sponsors.thuc_thu_tai_tro) },
      { label: 'Doanh thu từ đối tác', value: money(sponsors.doanh_thu_tu_doi_tac) },
      { label: 'Hoa hồng đối tác', value: money(sponsors.hoa_hong_doi_tac) },
      { label: 'Đối tác cung cấp thí sinh', value: count(sponsors.so_doi_tac_cung_cap) },
    ]
    const funnelRows = rowsFor(datasets, 'sponsor_funnel').slice().sort((a, b) => Number(a.thu_tu) - Number(b.thu_tu))
    const funnel = chart('Phễu tài trợ', funnelRows.map((row) => `${formatCell(row.giai_doan)} (${percent(row.ty_le_pct)})`),
      [{ name: 'Số doanh nghiệp', values: funnelRows.map((row) => numberValue(row.so_doanh_nghiep)) }], 'funnel', { direction: 'bar', showValues: true })
    addChart('sponsor_funnel', funnel)
    const tiers = rowsChart('Cơ cấu cấp tài trợ', rowsFor(datasets, 'sponsor_tiers'), 'cap_do_tai_tro',
      [{ key: 'so_luong', name: 'Số doanh nghiệp' }], 'doughnut', { showValues: true, showPercent: true })
    addChart('sponsor_tiers', tiers)
    const sponsorsByRevenue = rowsFor(datasets, 'sponsor_list').filter((row) => Number(row.thuc_thu) > 0)
      .sort((a, b) => Number(b.thuc_thu) - Number(a.thuc_thu)).slice(0, 15)
    const sponsorChart = rowsChart('Top 15 doanh nghiệp theo thực thu', sponsorsByRevenue, 'ten_doanh_nghiep',
      [{ key: 'thuc_thu', name: 'Thực thu' }], 'bar', { direction: 'bar', showValues: true })
    addChart('sponsor_list', sponsorChart)
    if (sponsorChart) {
      sponsorChart.series[0].pointColors = sponsorsByRevenue.map((row) => tierColor(row.cap_do_tai_tro))
    }
    const tierRevenue = aggregateSum(sponsorsByRevenue, 'cap_do_tai_tro', 'thuc_thu')
    const tierRevenueChart = rowsChart('Tổng thực thu theo cấp tài trợ', tierRevenue, 'cap_do_tai_tro',
      [{ key: 'tong_gia_tri', name: 'Thực thu' }], 'bar', { direction: 'col', showValues: true })
    addChart('sponsor_list', tierRevenueChart)
    const sponsorTypes = aggregateCount(rowsFor(datasets, 'sponsor_list'), 'loai_tai_tro')
    const sponsorTypeChart = rowsChart('Số doanh nghiệp theo loại tài trợ', sponsorTypes, 'loai_tai_tro',
      [{ key: 'so_luong', name: 'Số doanh nghiệp' }], 'bar', { direction: 'bar', showValues: true })
    addChart('sponsor_list', sponsorTypeChart)
    const suppliers = rowsFor(datasets, 'supplier_list').filter((row) =>
      formatCell(row.hinh_thuc).toLocaleLowerCase('vi').includes('cung cấp') && Number(row.so_thi_sinh_cung_cap) > 0,
    )
    const supplierChart = chart('Số thí sinh cung cấp theo đối tác', suppliers.map((row) => formatCell(row.ten_doanh_nghiep)), [
      { name: 'Số thí sinh cung cấp', values: suppliers.map((row) => numberValue(row.so_thi_sinh_cung_cap)) },
    ], 'bar', { direction: 'bar', showValues: true })
    addChart('supplier_list', supplierChart)
    const supplierRevenue = chart('Doanh thu và hoa hồng theo đối tác', suppliers.map((row) => formatCell(row.ten_doanh_nghiep)), [
      { name: 'Doanh thu', values: suppliers.map((row) => numberValue(row.doanh_thu)) },
      { name: 'Hoa hồng', values: suppliers.map((row) => numberValue(row.hoa_hong)) },
    ], 'bar', { direction: 'col', grouping: 'clustered', showValues: true })
    addChart('supplier_list', supplierRevenue)
    const province = rowsChart('Doanh thu đối tác theo tỉnh/thành', rowsFor(datasets, 'sponsor_revenue_by_province'), 'tinh_thanh',
      [{ key: 'doanh_thu', name: 'Doanh thu' }], 'doughnut', { showValues: true, showPercent: true })
    addChart('sponsor_revenue_by_province', province)
    const trendRows = rowsFor(datasets, 'sponsor_trend')
    const trend = chart('Xu hướng tài trợ', trendRows.map((row) => `${dateLabel(row.ngay)} · ${formatCell(row.bang_dau)}`), [
      { name: 'Doanh thu tài trợ đã thu', values: trendRows.map((row) => numberValue(row.doanh_thu)), chartType: 'bar' },
      { name: 'Lượt đăng ký toàn hệ thống', values: trendRows.map((row) => numberValue(row.so_dang_ky)), chartType: 'line' },
    ], 'combo', { direction: 'col', grouping: 'clustered', showValues: true })
    addChart('sponsor_trend', trend)
    if (trendRows.some((row) => dateLabel(row.ngay) === '3/9')) notes.push('Ngày 3/9 có 21 lượt đăng ký và doanh thu bằng 0.')
    const dailyRows = rowsFor(datasets, 'sponsor_daily_revenue')
    const daily = chart('Doanh thu và hoa hồng theo ngày', dailyRows.map((row) => dateLabel(row.ngay)), [
      { name: 'Doanh thu công ty giữ lại', values: dailyRows.map((row) => numberValue(row.cong_ty_giu_lai)), chartType: 'bar' },
      { name: 'Hoa hồng đối tác', values: dailyRows.map((row) => numberValue(row.hoa_hong_doi_tac)), chartType: 'bar' },
      { name: 'Chờ thanh toán', values: dailyRows.map((row) => numberValue(row.cho_thanh_toan)), chartType: 'line' },
    ], 'combo', { direction: 'col', grouping: 'stacked', showValues: true })
    addChart('sponsor_daily_revenue', daily)
  } else if (tab === 'Bảo mật') {
    title = `Bảo mật & Nhập dữ liệu ${period.replace('-', '/')}`
    const imports = rowsFor(datasets, 'import_sessions')
    const tableByImportId = new Map(imports.map((row) => [String(row.import_id), row.ten_bang_dich]))
    const errors = rowsFor(datasets, 'import_errors').map((row) => ({
      ...row,
      ten_bang_dich: row.ten_bang_dich ?? tableByImportId.get(String(row.import_id)),
    }))
    const sessions = imports.length
    const total = imports.reduce((sum, row) => sum + (numberValue(row.tong_so_dong) ?? 0), 0)
    const succeeded = imports.reduce((sum, row) => sum + (numberValue(row.so_dong_thanh_cong) ?? 0), 0)
    const failed = imports.reduce((sum, row) => sum + (numberValue(row.so_dong_loi) ?? 0), 0)
    const successRate = total ? (succeeded / total) * 100 : null
    kpis = [
      { label: 'Tổng số phiên nhập', value: count(sessions) },
      { label: 'Tổng số dòng nhập', value: count(total) },
      { label: 'Số dòng thành công', value: count(succeeded) },
      { label: 'Số dòng lỗi', value: count(failed) },
      { label: 'Tỷ lệ thành công', value: percent(successRate) },
    ]
    const statusRows = aggregateCount(imports, 'trang_thai')
    const countsByStatus = new Map(statusRows.map((row) => [String(row.trang_thai), Number(row.so_luong)]))
    for (const [statusName, value] of countsByStatus) {
      kpis.push({ label: `Phiên ${statusName.toLocaleLowerCase('vi')}`, value: count(value) })
    }
    const errorTypes = aggregateCount(errors, 'ma_loi')
    const typeChart = rowsChart('Loại lỗi phổ biến', errorTypes.slice().sort((a, b) => Number(b.so_luong) - Number(a.so_luong)), 'ma_loi',
      [{ key: 'so_luong', name: 'Số dòng' }], 'bar', { direction: 'bar', showValues: true })
    addChart('import_errors', typeChart)
    const audits = rowsFor(datasets, 'security_log')
    if (imports.some((row) => Number(row.tong_so_dong) !== Number(row.so_dong_thanh_cong) + Number(row.so_dong_loi))) {
      notes.push('Một số phiên có chênh lệch giữa tổng dòng và dòng thành công + dòng lỗi; vui lòng kiểm tra chi tiết theo tệp.')
    }
    if (audits.some((row) => !row.ho_ten)) notes.push('Cột Họ và tên có dữ liệu trống nên chưa thể thống kê thao tác theo người dùng.')
    if (audits.length && audits.every((row) => formatCell(row.trang_thai) === 'Thành công')) notes.push('100% thao tác trong nhật ký có trạng thái Thành công.')
  } else if (tab === 'Hỗ trợ') {
    title = `Hỗ trợ & FAQ ${period.replace('-', '/')}`
    const supportRows = rowsFor(datasets, 'support_conversations')
    const answered = supportRows.filter((row) => formatCell(row.trang_thai) === 'Đã trả lời').length
    const unansweredCount = supportRows.length - answered
    const ratings = supportRows.map((row) => numberValue(row.danh_gia_hai_long)).filter((value): value is number => value != null)
    const averageRating = ratings.length ? ratings.reduce((sum, value) => sum + value, 0) / ratings.length : null
    const faq = combineRows(rowsFor(datasets, 'support_faq_summary'))
    kpis = [
      { label: 'Tổng hội thoại', value: count(supportRows.length) },
      { label: 'Đã trả lời', value: `${count(answered)} (${percent(supportRows.length ? answered * 100 / supportRows.length : 0)})` },
      { label: 'Chưa trả lời', value: count(unansweredCount) },
      { label: 'Điểm hài lòng trung bình', value: averageRating == null ? '—' : `${averageRating.toFixed(2)} / 5`, detail: `${ratings.length} lượt đánh giá` },
      { label: 'Câu hỏi FAQ', value: count(faq.tong_cau_hoi) },
      { label: 'Lượt xem FAQ', value: count(faq.luot_xem_tich_luy) },
      { label: 'FAQ hữu ích', value: percent(faq.tyle_huu_ich_pt) },
    ]
    const byStatus = rowsFor(datasets, 'support_by_status')
    const status = rowsChart('Hội thoại theo trạng thái', byStatus, 'trang_thai', [{ key: 'so_luong', name: 'Số hội thoại' }], 'doughnut', { showValues: true, showPercent: true })
    addChart('support_by_status', status)
    const byEntity = rowsFor(datasets, 'support_by_entity')
    const entity = rowsChart('Hội thoại theo nhóm đối tượng', byEntity, 'loai_doi_tuong', [{ key: 'so_luong', name: 'Số hội thoại' }], 'doughnut', { showValues: true, showPercent: true })
    addChart('support_by_entity', entity)
    const channel = aggregateConversationRows(supportRows, 'kenh_tuong_tac', 'trang_thai')
    const channelCounts = aggregateCount(supportRows, 'kenh_tuong_tac')
    const channelCountChart = rowsChart('Hội thoại theo kênh tương tác', channelCounts, 'kenh_tuong_tac',
      [{ key: 'so_luong', name: 'Số hội thoại' }], 'bar', { direction: 'bar', showValues: true })
    addChart('support_conversations', channelCountChart)
    const channelChart = chart('Hội thoại theo kênh và trạng thái', channel.categories, channel.series, 'bar',
      { direction: 'bar', grouping: 'stacked', showValues: true })
    addChart('support_conversations', channelChart)
    const unanswered = aggregateUnansweredByChannel(supportRows)
    const unansweredChart = chart('Tỷ lệ trả lời theo kênh', unanswered.categories, [
      { name: 'Đã trả lời', values: unanswered.answered },
      { name: 'Chưa trả lời', values: unanswered.unanswered },
    ], 'bar', { direction: 'bar', grouping: 'percentStacked', showValues: true })
    addChart('support_conversations', unansweredChart)
    const ratingCounts = aggregateRatings(supportRows)
    const ratingChart = chart('Phân bố điểm hài lòng', ratingCounts.categories, [
      { name: 'Số lượt đánh giá', values: ratingCounts.values },
    ], 'bar', { direction: 'col', showValues: true })
    addChart('support_conversations', ratingChart)
    const staff = aggregateStaff(supportRows)
    const staffRatings = new Map(averageByKey(
      supportRows.filter((row) => numberValue(row.danh_gia_hai_long) != null),
      'nhan_vien_id_ho_tro',
      'danh_gia_hai_long',
    ).map((row) => [String(row.nhan_vien_id_ho_tro), numberValue(row.gia_tri_trung_binh)]))
    const staffChart = chart('Khối lượng xử lý và điểm hài lòng theo nhân viên', staff.categories, [
      { name: 'Số hội thoại', values: staff.values, chartType: 'bar' },
      { name: 'Điểm hài lòng trung bình', values: staff.categories.map((name) => staffRatings.get(name) ?? null), chartType: 'line' },
    ], 'combo', { direction: 'bar', showValues: true })
    addChart('support_conversations', staffChart)
    const ratingByChannel = averageByKey(supportRows.filter((row) => numberValue(row.danh_gia_hai_long) != null), 'kenh_tuong_tac', 'danh_gia_hai_long')
    const ratingChannelChart = rowsChart('Điểm hài lòng trung bình theo kênh', ratingByChannel, 'kenh_tuong_tac',
      [{ key: 'gia_tri_trung_binh', name: 'Điểm trung bình' }], 'bar', { direction: 'bar', showValues: true })
    addChart('support_conversations', ratingChannelChart)
    const weeks = aggregateByWeek(supportRows)
    const weeklyChart = chart('Số hội thoại theo tuần', weeks.categories, [
      { name: 'Số hội thoại', values: weeks.values },
    ], 'bar', { direction: 'col', showValues: true })
    addChart('support_conversations', weeklyChart)
    const categories = rowsFor(datasets, 'support_faq_categories').filter((row) => Number(row.cap) === 0)
    const faqCategoryChart = rowsChart('Số câu hỏi FAQ theo danh mục', categories, 'ten_danh_muc',
      [{ key: 'so_cau_hoi', name: 'Số câu hỏi' }], 'bar', { direction: 'bar', showValues: true })
    addChart('support_faq_categories', faqCategoryChart)
    const questionCounts = aggregateCount(supportRows, 'noi_dung_hoi')
      .sort((a, b) => Number(b.so_luong) - Number(a.so_luong)).slice(0, 10)
    const repeatedQuestions = rowsChart('Top 10 câu hỏi lặp lại nhiều nhất', questionCounts, 'noi_dung_hoi',
      [{ key: 'so_luong', name: 'Số lượt hỏi' }], 'bar', { direction: 'bar', showValues: true })
    addChart('support_conversations', repeatedQuestions)
    const usedDocuments = aggregateCount(supportRows.filter((row) => row.tai_lieu_id != null), 'tai_lieu_id')
      .sort((a, b) => Number(b.so_luong) - Number(a.so_luong))
    const faqDocuments = rowsChart('Tài liệu FAQ được dùng để trả lời', usedDocuments, 'tai_lieu_id',
      [{ key: 'so_luong', name: 'Số lần sử dụng' }], 'bar', { direction: 'bar', showValues: true })
    addChart('support_conversations', faqDocuments)
  }

  const customChartReportIdsByTab: Record<string, string[]> = {
    'Tổng quan': ['overview_summary', 'lead_pipeline', 'overview_progress', 'overview_enrollment_funnel'],
    'Thí sinh': ['student_summary', 'student_status', 'student_schools', 'student_school_scores', 'student_utm'],
    'Doanh thu': ['revenue_summary', 'payment_funnel', 'revenue_by_province', 'revenue_by_region', 'revenue_trend', 'revenue_by_channel', 'revenue_reconciliation', 'transaction_details'],
    'Học vụ': ['submission_status', 'submission_failures', 'submission_failures_by_province', 'contest_rounds', 'contest_results', 'contest_top56', 'contest_finalists', 'submission_details', 'practice_top15'],
    'Đối tác': ['sponsor_summary', 'sponsor_funnel', 'sponsor_tiers', 'sponsor_list', 'supplier_list', 'sponsor_revenue_by_province', 'sponsor_trend', 'sponsor_daily_revenue'],
    'Bảo mật': ['import_sessions', 'import_errors', 'security_log'],
    'Hỗ trợ': ['support_by_status', 'support_by_entity', 'support_faq_summary', 'support_faq_categories', 'support_conversations'],
  }
  return { title, kpis, notes, charts, customChartReportIds: customChartReportIdsByTab[tab] ?? [] }
}

function aggregateByDate(
  rows: Record<string, unknown>[],
  dateKey: string,
  valueKey: string,
): { categories: string[]; values: (number | null)[] } {
  const totals = new Map<string, number>()
  rows.forEach((row) => {
    const category = dateLabel(row[dateKey])
    const value = numberValue(row[valueKey])
    if (category !== '—' && value != null) totals.set(category, (totals.get(category) ?? 0) + value)
  })
  const entries = Array.from(totals.entries())
  return { categories: entries.map(([category]) => category), values: entries.map(([, value]) => value) }
}

function aggregateTransactionDates(rows: Record<string, unknown>[]): {
  categories: string[]
  counts: number[]
  amounts: number[]
} {
  const grouped = new Map<string, { count: number; amount: number }>()
  rows.forEach((row) => {
    const category = dateLabel(row.thoi_gian_thanh_toan)
    if (category === '—') return
    const value = grouped.get(category) ?? { count: 0, amount: 0 }
    value.count += 1
    value.amount += numberValue(row.so_tien) ?? 0
    grouped.set(category, value)
  })
  const entries = Array.from(grouped.entries())
  return {
    categories: entries.map(([category]) => category),
    counts: entries.map(([, value]) => value.count),
    amounts: entries.map(([, value]) => value.amount),
  }
}

function aggregateSum(
  rows: Record<string, unknown>[],
  categoryKey: string,
  valueKey: string,
): Record<string, unknown>[] {
  const totals = new Map<string, number>()
  rows.forEach((row) => {
    const category = formatCell(row[categoryKey])
    const value = numberValue(row[valueKey])
    if (category === '—' || value == null) return
    totals.set(category, (totals.get(category) ?? 0) + value)
  })
  return Array.from(totals, ([category, value]) => ({ [categoryKey]: category, tong_gia_tri: value }))
}

function averageByKey(
  rows: Record<string, unknown>[],
  categoryKey: string,
  valueKey: string,
): Record<string, unknown>[] {
  const totals = new Map<string, { sum: number; count: number }>()
  rows.forEach((row) => {
    const category = formatCell(row[categoryKey])
    const value = numberValue(row[valueKey])
    if (category === '—' || value == null) return
    const total = totals.get(category) ?? { sum: 0, count: 0 }
    total.sum += value
    total.count += 1
    totals.set(category, total)
  })
  return Array.from(totals, ([category, total]) => ({
    [categoryKey]: category,
    gia_tri_trung_binh: total.count ? total.sum / total.count : null,
  })).sort((a, b) => Number(b.gia_tri_trung_binh) - Number(a.gia_tri_trung_binh))
}

function histogramByHundred(rows: Record<string, unknown>[], key: string): { categories: string[]; values: number[] } {
  const bins = new Map<number, number>()
  rows.forEach((row) => {
    const score = numberValue(row[key])
    if (score == null) return
    const binStart = Math.floor(score / 100) * 100
    bins.set(binStart, (bins.get(binStart) ?? 0) + 1)
  })
  const entries = Array.from(bins.entries()).sort(([a], [b]) => a - b)
  return {
    categories: entries.map(([start]) => `${start}–${start + 99}`),
    values: entries.map(([, total]) => total),
  }
}

function shortenSchoolName(name: string): string {
  return name
    .replace(/Học viện Công nghệ Bưu chính Viễn thông/gi, 'PTIT')
    .replace(/cơ sở Thành phố Hồ Chí Minh/gi, 'cơ sở TP.HCM')
    .replace(/cơ sở TP Hồ Chí Minh/gi, 'cơ sở TP.HCM')
}

function tierColor(value: unknown): string {
  const tier = formatCell(value).toLocaleLowerCase('vi')
  if (tier.includes('kim cương')) return '#0EA5E9'
  if (tier.includes('vàng')) return '#EAB308'
  if (tier.includes('bạc')) return '#94A3B8'
  if (tier.includes('đồng')) return '#B45309'
  return '#2563EB'
}

function aggregateCount(
  rows: Record<string, unknown>[],
  categoryKey: string,
  valueKey?: string,
): Record<string, unknown>[] {
  const totals = new Map<string, number>()
  rows.forEach((row) => {
    const category = formatCell(row[categoryKey])
    if (category === '—') return
    const value = valueKey ? numberValue(row[valueKey]) ?? 0 : 1
    totals.set(category, (totals.get(category) ?? 0) + value)
  })
  return Array.from(totals, ([category, value]) => ({ [categoryKey]: category, so_luong: value }))
}

function aggregateQuestionScores(rows: Record<string, unknown>[]): { categories: string[]; values: number[] } {
  const totals = new Map<string, { earned: number; maximum: number }>()
  rows.forEach((row) => {
    const question = formatCell(row.cau_hoi_so)
    const earned = numberValue(row.diem_dat_duoc)
    const maximum = numberValue(row.diem_toi_da)
    if (question === '—' || earned == null || maximum == null || maximum <= 0) return
    const entry = totals.get(question) ?? { earned: 0, maximum: 0 }
    entry.earned += earned
    entry.maximum += maximum
    totals.set(question, entry)
  })
  const entries = Array.from(totals.entries())
  return {
    categories: entries.map(([question]) => question),
    values: entries.map(([, score]) => score.earned * 100 / score.maximum),
  }
}

function aggregateAnswersByType(rows: Record<string, unknown>[]): { categories: string[]; values: number[] } {
  const totals = new Map<string, { correct: number; total: number }>()
  rows.forEach((row) => {
    const type = formatCell(row.loai_cau_hoi)
    if (type === '—') return
    const result = totals.get(type) ?? { correct: 0, total: 0 }
    result.total += 1
    if (row.la_dap_an_dung === true) result.correct += 1
    totals.set(type, result)
  })
  const entries = Array.from(totals.entries())
  return {
    categories: entries.map(([type]) => type),
    values: entries.map(([, result]) => result.total ? result.correct * 100 / result.total : 0),
  }
}

function aggregateAnswersByQuestion(rows: Record<string, unknown>[]): { lowestQuestions: string[] } {
  const totals = new Map<string, { correct: number; total: number }>()
  rows.forEach((row) => {
    const question = formatCell(row.cau_hoi_so)
    if (question === '—') return
    const result = totals.get(question) ?? { correct: 0, total: 0 }
    result.total += 1
    if (row.la_dap_an_dung === true) result.correct += 1
    totals.set(question, result)
  })
  return {
    lowestQuestions: Array.from(totals.entries())
      .sort((a, b) => a[1].correct / a[1].total - b[1].correct / b[1].total)
      .slice(0, 3)
      .map(([question, result]) => `${question} (${percent(result.correct * 100 / result.total)})`),
  }
}

function aggregateUnansweredByChannel(rows: Record<string, unknown>[]): {
  categories: string[]
  answered: number[]
  unanswered: number[]
} {
  const grouped = new Map<string, { answered: number; unanswered: number }>()
  rows.forEach((row) => {
    const channel = formatCell(row.kenh_tuong_tac)
    if (channel === '—') return
    const totals = grouped.get(channel) ?? { answered: 0, unanswered: 0 }
    if (formatCell(row.trang_thai) === 'Đã trả lời') totals.answered += 1
    else totals.unanswered += 1
    grouped.set(channel, totals)
  })
  const entries = Array.from(grouped.entries()).sort((a, b) => b[1].unanswered / (b[1].answered + b[1].unanswered) - a[1].unanswered / (a[1].answered + a[1].unanswered))
  return {
    categories: entries.map(([channel]) => channel),
    answered: entries.map(([, totals]) => totals.answered),
    unanswered: entries.map(([, totals]) => totals.unanswered),
  }
}

function aggregateConversationRows(
  rows: Record<string, unknown>[],
  categoryKey: string,
  seriesKey: string,
): { categories: string[]; series: DashboardChart['series'] } {
  const grouped = aggregateCount(rows, categoryKey)
  const categories = grouped.map((row) => String(row[categoryKey]))
  const seriesNames = Array.from(new Set(rows.map((row) => formatCell(row[seriesKey]))).values())
  return {
    categories,
    series: seriesNames.map((name) => ({
      name,
      values: categories.map((category) => rows.filter((row) =>
        formatCell(row[categoryKey]) === category && formatCell(row[seriesKey]) === name,
      ).length),
    })),
  }
}

function aggregateRatings(rows: Record<string, unknown>[]): { categories: string[]; values: number[] } {
  const ratings = new Map<number, number>()
  rows.forEach((row) => {
    const rating = numberValue(row.danh_gia_hai_long)
    if (rating == null) return
    ratings.set(rating, (ratings.get(rating) ?? 0) + 1)
  })
  const categories = [1, 2, 3, 4, 5].filter((rating) => ratings.has(rating))
  return { categories: categories.map((rating) => `${rating} sao`), values: categories.map((rating) => ratings.get(rating) ?? 0) }
}

function aggregateStaff(rows: Record<string, unknown>[]): { categories: string[]; values: number[] } {
  const totals = new Map<string, number>()
  rows.forEach((row) => {
    const staff = formatCell(row.nhan_vien_id_ho_tro)
    if (staff === '—') return
    totals.set(staff, (totals.get(staff) ?? 0) + 1)
  })
  const sorted = Array.from(totals.entries()).sort((a, b) => b[1] - a[1])
  return { categories: sorted.map(([staff]) => staff), values: sorted.map(([, value]) => value) }
}

function aggregateByWeek(rows: Record<string, unknown>[]): { categories: string[]; values: number[] } {
  const totals = new Map<string, number>()
  rows.forEach((row) => {
    const date = new Date(String(row.thoi_gian ?? ''))
    if (Number.isNaN(date.getTime())) return
    const day = new Date(date)
    day.setDate(day.getDate() - ((day.getDay() + 6) % 7))
    const key = `${day.getFullYear()}-${String(day.getMonth() + 1).padStart(2, '0')}-${String(day.getDate()).padStart(2, '0')}`
    totals.set(key, (totals.get(key) ?? 0) + 1)
  })
  const entries = Array.from(totals.entries()).sort(([a], [b]) => a.localeCompare(b))
  return { categories: entries.map(([date]) => dateLabel(date)), values: entries.map(([, value]) => value) }
}

export function buildExcelDashboard(
  tab: string,
  period: string,
  datasets: DashboardDataset[],
  rawResults: Record<string, unknown>,
): ExcelDashboard {
  return dashboardMetrics(tab, period, datasets, rawResults)
}
