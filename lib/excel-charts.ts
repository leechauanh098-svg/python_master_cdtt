import { strFromU8, strToU8, unzipSync, zipSync } from 'fflate'
import { formatCell } from '@/components/remote-data'

export type ExcelChartSource = {
  sheetIndex: number
  title: string
  visualization?: string
  columns: { key: string; label: string }[]
  rows: Record<string, unknown>[]
  chartData?: {
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
  anchor?: { column: number; row: number; widthColumns?: number; heightRows?: number }
}

type ChartSeries = {
  key: string
  name: string
  values: (number | null)[]
  xValues?: (number | null)[]
  color?: string
  pointColors?: string[]
  chartType?: 'bar' | 'line'
  hidden?: boolean
}

type ChartData = {
  categories: string[]
  series: ChartSeries[]
  type: 'bar' | 'line' | 'pie' | 'doughnut' | 'funnel' | 'combo' | 'gantt' | 'scatter'
  direction?: 'bar' | 'col'
  grouping?: 'clustered' | 'stacked' | 'percentStacked'
  axisMin?: number
  axisMax?: number
  showValues?: boolean
  showPercent?: boolean
}

function numericValue(value: unknown): number | null {
  if (typeof value !== 'number' && (typeof value !== 'string' || value.trim() === '')) return null
  const number = Number(value)
  return Number.isFinite(number) ? number : null
}

const chartNamespace = 'http://schemas.openxmlformats.org/drawingml/2006/chart'
const drawingNamespace = 'http://schemas.openxmlformats.org/drawingml/2006/spreadsheetDrawing'
const officeRelationshipNamespace = 'http://schemas.openxmlformats.org/officeDocument/2006/relationships'
const packageRelationshipNamespace = 'http://schemas.openxmlformats.org/package/2006/relationships'

function xmlEscape(value: unknown): string {
  return formatCell(value)
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&apos;')
}

function chartData(source: ExcelChartSource): ChartData | null {
  if (source.chartData) {
    const data = source.chartData
    if (!data.categories.length || !data.series.length) return null
    return {
      ...data,
      series: data.series.map((series, index) => ({
        key: String(index),
        name: series.name,
        values: series.values,
        xValues: series.xValues,
        color: series.color,
        pointColors: series.pointColors,
        chartType: series.chartType,
        hidden: series.hidden,
      })),
    }
  }
  const isTimeColumn = ({ key, label }: { key: string; label: string }) =>
    /ngay|thoi_gian|date|time|^ky_|period|month/i.test(`${key} ${label}`)
  const isDateColumn = ({ key }: { key: string }) => key.toLowerCase() === 'ngay'
  const numericColumns = source.columns.filter(({ key }) =>
    !/(?:^id$|_id$|^ma_|_ma$)/i.test(key) &&
    source.rows.some((row) => numericValue(row[key]) != null),
  )
  if (!numericColumns.length) return null

  const hasCategoryValues = ({ key }: { key: string; label: string }) =>
    !numericColumns.some((column) => column.key === key) &&
    source.rows.some((row) => row[key] != null && String(row[key]).trim() !== '')
  const categoryColumn = source.columns.find((column) => isTimeColumn(column) && hasCategoryValues(column))
    ?? source.columns.find(hasCategoryValues)
  const metricRow = !categoryColumn && source.rows.length === 1 && numericColumns.length > 1
  const funnel = source.visualization === 'funnel' || /phễu|funnel/i.test(source.title)
  const funnelValueColumn = funnel
    ? numericColumns.find(({ key }) => /so_luong|so_dang_ky|so_thi_sinh|tong|count|total/i.test(key))
    : undefined
  const columns = funnel
    ? funnelValueColumn ? [funnelValueColumn] : numericColumns.slice(0, 1)
    : metricRow ? numericColumns.slice(0, 20) : numericColumns
  let categories = metricRow
    ? columns.map(({ label }) => label)
    : source.rows.slice(0, 20).map((row, index) => {
      const value = categoryColumn ? row[categoryColumn.key] : index + 1
      if (value == null || String(value).trim() === '') return `Mục ${index + 1}`
      if (categoryColumn && isDateColumn(categoryColumn)) {
        const isoDate = String(value).match(/^(\d{4}-\d{2}-\d{2})/)
        if (isoDate) {
          const [year, month, day] = isoDate[1].split('-').map(Number)
          return new Date(Date.UTC(year, month - 1, day)).toLocaleDateString('vi-VN', { timeZone: 'UTC' })
        }
      }
      return String(value)
    })

  if (categories.length < 2) return null

  const series = metricRow
    ? [{
      key: columns[0]?.key ?? '',
      name: source.title,
      values: columns.map(({ key }) => numericValue(source.rows[0][key])),
    }]
    : columns.map(({ key, label }) => ({
      key,
      name: label,
      values: source.rows.slice(0, categories.length).map((row) => numericValue(row[key])),
    })).filter((item) => item.values.some((value) => value != null))

  if (!series.length) return null
  if (metricRow) categories = columns.map(({ label }) => label)
  const timeSeries = categoryColumn != null && isTimeColumn(categoryColumn)
  const distribution = source.title.toLocaleLowerCase('vi').includes('cơ cấu') && series.length === 1
  if (categoryColumn && !funnel && !metricRow) {
    const combined = new Map<string, { category: string; values: (number | null)[] }>()
    source.rows.slice(0, 20).forEach((row, rowIndex) => {
      const category = categories[rowIndex]
      const entry = combined.get(category) ?? { category, values: series.map(() => null) }
      series.forEach((item, seriesIndex) => {
        const value = numericValue(row[item.key])
        if (value != null) entry.values[seriesIndex] = (entry.values[seriesIndex] ?? 0) + value
      })
      combined.set(category, entry)
    })
    const merged = Array.from(combined.values())
    categories = merged.map(({ category }) => category)
    series.forEach((item, seriesIndex) => {
      item.values = merged.map(({ values }) => values[seriesIndex])
    })
  }
  return {
    categories,
    series,
    type: funnel ? 'funnel' : distribution ? 'pie' : timeSeries ? 'line' : 'bar',
    direction: funnel ? 'bar' : 'col',
    grouping: funnel ? 'stacked' : 'clustered',
  }
}

function literalString(values: string[]): string {
  return `<c:strLit><c:ptCount val="${values.length}"/>${values.map((value, index) =>
    `<c:pt idx="${index}"><c:v>${xmlEscape(value)}</c:v></c:pt>`,
  ).join('')}</c:strLit>`
}

function literalNumbers(values: (number | null)[]): string {
  const points = values.flatMap((value, index) =>
    value == null ? [] : [`<c:pt idx="${index}"><c:v>${value}</c:v></c:pt>`],
  )
  return `<c:numLit><c:formatCode>General</c:formatCode><c:ptCount val="${values.length}"/>${points.join('')}</c:numLit>`
}

function chartSeries(series: ChartSeries, index: number, categories: string[], coloredPoints: boolean, data: ChartData): string {
  const pointColors = coloredPoints
    ? categories.map((_, pointIndex) =>
      `<c:dPt><c:idx val="${pointIndex}"/><c:spPr><a:solidFill>${series.pointColors?.[pointIndex]
        ? `<a:srgbClr val="${series.pointColors[pointIndex].replace(/^#/, '')}"/>`
        : `<a:schemeClr val="accent${pointIndex % 6 + 1}"/>`}</a:solidFill></c:spPr></c:dPt>`,
    ).join('')
    : ''
  const seriesFill = series.hidden
    ? '<c:spPr><a:noFill/><a:ln><a:noFill/></a:ln></c:spPr>'
    : series.color
      ? `<c:spPr><a:solidFill><a:srgbClr val="${series.color.replace(/^#/, '')}"/></a:solidFill></c:spPr>`
      : ''
  const dataLabels = data.type !== 'pie' && data.type !== 'doughnut' && (data.showValues || data.showPercent)
    ? `<c:dLbls><c:showLegendKey val="0"/><c:showVal val="${data.showValues ? 1 : 0}"/><c:showCatName val="0"/><c:showSerName val="0"/><c:showPercent val="${data.showPercent ? 1 : 0}"/></c:dLbls>`
    : ''
  const values = data.type === 'scatter'
    ? `<c:xVal>${literalNumbers(series.xValues ?? [])}</c:xVal><c:yVal>${literalNumbers(series.values)}</c:yVal>`
    : `<c:cat>${literalString(categories)}</c:cat><c:val>${literalNumbers(series.values)}</c:val>`
  return `<c:ser><c:idx val="${index}"/><c:order val="${index}"/><c:tx><c:v>${xmlEscape(series.name)}</c:v></c:tx>${seriesFill}${pointColors}${dataLabels}${values}</c:ser>`
}

function funnelSeries(data: ChartData): string {
  const stages = data.series[0]
  if (!stages) return ''
  const maxValue = Math.max(1, ...stages.values.map((value) => value ?? 0))
  const offset = stages.values.map((value) => Math.max(0, (maxValue - (value ?? 0)) / 2))
  const invisibleSeries = `<c:ser><c:idx val="0"/><c:order val="0"/><c:tx><c:v>Funnel offset</c:v></c:tx><c:spPr><a:noFill/><a:ln><a:noFill/></a:ln></c:spPr><c:cat>${literalString(data.categories)}</c:cat><c:val>${literalNumbers(offset)}</c:val></c:ser>`
  const pointColors = data.categories.map((_, index) =>
    `<c:dPt><c:idx val="${index}"/><c:spPr><a:solidFill><a:schemeClr val="accent${index % 6 + 1}"/></a:solidFill></c:spPr></c:dPt>`,
  ).join('')
  const dataLabels = '<c:dLbls><c:dLblPos val="ctr"/><c:showLegendKey val="0"/><c:showVal val="1"/><c:showCatName val="0"/><c:showSerName val="0"/><c:showPercent val="0"/></c:dLbls>'
  const visibleSeries = `<c:ser><c:idx val="1"/><c:order val="1"/><c:tx><c:v>${xmlEscape(stages.name)}</c:v></c:tx>${pointColors}${dataLabels}<c:cat>${literalString(data.categories)}</c:cat><c:val>${literalNumbers(stages.values)}</c:val></c:ser>`
  return `${invisibleSeries}${visibleSeries}`
}

function chartTitle(title: string): string {
  return `<c:title><c:tx><c:rich><a:bodyPr/><a:lstStyle/><a:p><a:pPr><a:defRPr/></a:pPr><a:r><a:rPr lang="vi-VN"/><a:t>${xmlEscape(title)}</a:t></a:r><a:endParaRPr lang="vi-VN"/></a:p></c:rich></c:tx><c:overlay val="0"/></c:title>`
}

function chartXml(title: string, data: ChartData): string {
  const series = data.type === 'funnel'
    ? funnelSeries(data)
    : data.series.map((item, index) => chartSeries(item, index, data.categories, data.type === 'pie' || data.type === 'doughnut', data)).join('')
  const comboBarSeries = data.series
    .map((item, index) => ({ item, index }))
    .filter(({ item }) => item.chartType !== 'line')
    .map(({ item, index }) => chartSeries(item, index, data.categories, false, data))
    .join('')
  const comboLineSeries = data.series
    .map((item, index) => ({ item, index }))
    .filter(({ item }) => item.chartType === 'line')
    .map(({ item, index }) => chartSeries(item, index, data.categories, false, data))
    .join('')
  const pieLabels = `<c:dLbls><c:showLegendKey val="0"/><c:showVal val="0"/><c:showPercent val="${data.showPercent === false ? 0 : 1}"/><c:showCatName val="0"/><c:showSerName val="0"/></c:dLbls>`
  const plot = data.type === 'doughnut'
    ? `<c:doughnutChart><c:varyColors val="1"/>${series}${pieLabels}<c:firstSliceAng val="0"/><c:holeSize val="65"/></c:doughnutChart>`
    : data.type === 'pie'
      ? `<c:pieChart><c:varyColors val="1"/>${series}${pieLabels}<c:firstSliceAng val="0"/></c:pieChart>`
    : data.type === 'funnel'
      ? `<c:barChart><c:barDir val="bar"/><c:grouping val="stacked"/><c:varyColors val="0"/>${series}<c:gapWidth val="35"/><c:overlap val="100"/><c:axId val="48650112"/><c:axId val="48672768"/></c:barChart>`
    : data.type === 'line'
      ? `<c:lineChart><c:grouping val="standard"/><c:varyColors val="0"/>${series}<c:marker val="1"/><c:smooth val="0"/><c:axId val="48650112"/><c:axId val="48672768"/></c:lineChart>`
    : data.type === 'combo'
      ? `<c:barChart><c:barDir val="${data.direction ?? 'col'}"/><c:grouping val="${data.grouping ?? 'clustered'}"/><c:varyColors val="0"/>${comboBarSeries}<c:gapWidth val="80"/><c:overlap val="${data.grouping === 'stacked' || data.grouping === 'percentStacked' ? 100 : 0}"/><c:axId val="48650112"/><c:axId val="48672768"/></c:barChart><c:lineChart><c:grouping val="standard"/><c:varyColors val="0"/>${comboLineSeries}<c:marker val="1"/><c:smooth val="0"/><c:axId val="48650112"/><c:axId val="48672769"/></c:lineChart>`
    : data.type === 'gantt'
      ? `<c:barChart><c:barDir val="bar"/><c:grouping val="stacked"/><c:varyColors val="0"/>${series}<c:gapWidth val="45"/><c:overlap val="100"/><c:axId val="48650112"/><c:axId val="48672768"/></c:barChart>`
      : data.type === 'scatter'
        ? `<c:scatterChart><c:scatterStyle val="marker"/><c:varyColors val="0"/>${series}<c:axId val="48650112"/><c:axId val="48672768"/></c:scatterChart>`
      : `<c:barChart><c:barDir val="${data.direction ?? 'col'}"/><c:grouping val="${data.grouping ?? 'clustered'}"/><c:varyColors val="0"/>${series}<c:gapWidth val="80"/><c:overlap val="${data.grouping === 'stacked' || data.grouping === 'percentStacked' ? 100 : 0}"/><c:axId val="48650112"/><c:axId val="48672768"/></c:barChart>`
  const horizontal = data.direction === 'bar'
  const axes = data.type === 'pie' || data.type === 'doughnut' ? '' : data.type === 'funnel' || data.type === 'gantt'
    ? `<c:catAx><c:axId val="48650112"/><c:scaling><c:orientation val="maxMin"/></c:scaling><c:delete val="0"/><c:axPos val="l"/><c:tickLblPos val="nextTo"/><c:crossAx val="48672768"/><c:crosses val="autoZero"/><c:auto val="1"/><c:lblAlgn val="ctr"/><c:lblOffset val="100"/></c:catAx><c:valAx><c:axId val="48672768"/><c:scaling><c:orientation val="minMax"/>${data.type === 'gantt' && data.axisMin != null ? `<c:min val="${data.axisMin}"/>` : ''}${data.type === 'gantt' && data.axisMax != null ? `<c:max val="${data.axisMax}"/>` : ''}</c:scaling><c:delete val="${data.type === 'funnel' ? 1 : 0}"/><c:axPos val="b"/><c:majorGridlines/><c:numFmt formatCode="${data.type === 'gantt' ? 'd/m/yyyy' : '#,##0'}" sourceLinked="0"/><c:tickLblPos val="${data.type === 'funnel' ? 'none' : 'nextTo'}"/><c:crossAx val="48650112"/><c:crosses val="autoZero"/><c:crossBetween val="between"/></c:valAx>`
    : data.type === 'scatter'
      ? `<c:valAx><c:axId val="48650112"/><c:scaling><c:orientation val="minMax"/></c:scaling><c:delete val="0"/><c:axPos val="b"/><c:majorGridlines/><c:numFmt formatCode="#,##0" sourceLinked="0"/><c:tickLblPos val="nextTo"/><c:crossAx val="48672768"/><c:crosses val="autoZero"/><c:crossBetween val="midCat"/></c:valAx><c:valAx><c:axId val="48672768"/><c:scaling><c:orientation val="minMax"/></c:scaling><c:delete val="0"/><c:axPos val="l"/><c:majorGridlines/><c:numFmt formatCode="#,##0.##" sourceLinked="0"/><c:tickLblPos val="nextTo"/><c:crossAx val="48650112"/><c:crosses val="autoZero"/></c:valAx>`
    : data.type === 'combo'
      ? `<c:catAx><c:axId val="48650112"/><c:scaling><c:orientation val="minMax"/></c:scaling><c:delete val="0"/><c:axPos val="b"/><c:tickLblPos val="nextTo"/><c:txPr><a:bodyPr rot="-2700000"/><a:lstStyle/><a:p><a:pPr><a:defRPr sz="900"/></a:pPr><a:endParaRPr lang="vi-VN"/></a:p></c:txPr><c:crossAx val="48672768"/><c:crosses val="autoZero"/><c:auto val="1"/><c:lblAlgn val="ctr"/><c:lblOffset val="100"/></c:catAx><c:valAx><c:axId val="48672768"/><c:scaling><c:orientation val="minMax"/></c:scaling><c:delete val="0"/><c:axPos val="l"/><c:majorGridlines/><c:numFmt formatCode="#,##0" sourceLinked="0"/><c:tickLblPos val="nextTo"/><c:crossAx val="48650112"/><c:crosses val="autoZero"/><c:crossBetween val="between"/></c:valAx><c:valAx><c:axId val="48672769"/><c:scaling><c:orientation val="minMax"/></c:scaling><c:delete val="0"/><c:axPos val="r"/><c:majorGridlines/><c:numFmt formatCode="#,##0" sourceLinked="0"/><c:tickLblPos val="nextTo"/><c:crossAx val="48650112"/><c:crosses val="max"/><c:crossBetween val="between"/></c:valAx>`
    : horizontal
      ? `<c:catAx><c:axId val="48650112"/><c:scaling><c:orientation val="maxMin"/></c:scaling><c:delete val="0"/><c:axPos val="l"/><c:tickLblPos val="nextTo"/><c:crossAx val="48672768"/><c:crosses val="autoZero"/><c:auto val="1"/><c:lblAlgn val="ctr"/><c:lblOffset val="100"/></c:catAx><c:valAx><c:axId val="48672768"/><c:scaling><c:orientation val="minMax"/></c:scaling><c:delete val="0"/><c:axPos val="b"/><c:majorGridlines/><c:numFmt formatCode="#,##0" sourceLinked="0"/><c:tickLblPos val="nextTo"/><c:crossAx val="48650112"/><c:crosses val="autoZero"/><c:crossBetween val="between"/></c:valAx>`
      : `
    <c:catAx><c:axId val="48650112"/><c:scaling><c:orientation val="minMax"/></c:scaling><c:delete val="0"/><c:axPos val="b"/><c:tickLblPos val="nextTo"/><c:txPr><a:bodyPr rot="-2700000"/><a:lstStyle/><a:p><a:pPr><a:defRPr sz="900"/></a:pPr><a:endParaRPr lang="vi-VN"/></a:p></c:txPr><c:crossAx val="48672768"/><c:crosses val="autoZero"/><c:auto val="1"/><c:lblAlgn val="ctr"/><c:lblOffset val="100"/><c:tickLblSkip val="${data.type === 'line' ? 2 : 1}"/></c:catAx>
    <c:valAx><c:axId val="48672768"/><c:scaling><c:orientation val="minMax"/></c:scaling><c:delete val="0"/><c:axPos val="l"/><c:majorGridlines/><c:numFmt formatCode="#,##0" sourceLinked="0"/><c:tickLblPos val="nextTo"/><c:crossAx val="48650112"/><c:crosses val="autoZero"/><c:crossBetween val="between"/></c:valAx>`

  return `<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<c:chartSpace xmlns:c="${chartNamespace}" xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:r="${officeRelationshipNamespace}"><c:lang val="vi-VN"/><c:chart>${chartTitle(title)}<c:autoTitleDeleted val="0"/><c:plotArea><c:layout/>${plot}${axes}</c:plotArea>${data.type === 'funnel' || data.type === 'gantt' ? '' : `<c:legend><c:legendPos val="b"/><c:layout/><c:overlay val="0"/></c:legend>`}<c:plotVisOnly val="1"/><c:dispBlanksAs val="gap"/><c:showDLblsOverMax val="0"/></c:chart></c:chartSpace>`
}

type DrawingChart = {
  chartNumber: number
  anchor?: ExcelChartSource['anchor']
}

function drawingXml(charts: DrawingChart[]): string {
  const anchors = charts.map(({ chartNumber, anchor }, index) => {
    const startColumn = anchor?.column ?? 0
    const startRow = anchor?.row ?? 0
    const endColumn = startColumn + (anchor?.widthColumns ?? 10)
    const endRow = startRow + (anchor?.heightRows ?? 18)
    const shapeId = index + 2
    const relationshipId = `rId${index + 1}`
    return `<xdr:twoCellAnchor editAs="oneCell"><xdr:from><xdr:col>${startColumn}</xdr:col><xdr:colOff>0</xdr:colOff><xdr:row>${startRow}</xdr:row><xdr:rowOff>0</xdr:rowOff></xdr:from><xdr:to><xdr:col>${endColumn}</xdr:col><xdr:colOff>0</xdr:colOff><xdr:row>${endRow}</xdr:row><xdr:rowOff>0</xdr:rowOff></xdr:to><xdr:graphicFrame macro=""><xdr:nvGraphicFramePr><xdr:cNvPr id="${shapeId}" name="Chart ${chartNumber}"/><xdr:cNvGraphicFramePr><a:graphicFrameLocks noGrp="1"/></xdr:cNvGraphicFramePr></xdr:nvGraphicFramePr><xdr:xfrm><a:off x="0" y="0"/><a:ext cx="0" cy="0"/></xdr:xfrm><a:graphic><a:graphicData uri="${chartNamespace}"><c:chart r:id="${relationshipId}"/></a:graphicData></a:graphic></xdr:graphicFrame><xdr:clientData/></xdr:twoCellAnchor>`
  }).join('')
  return `<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<xdr:wsDr xmlns:xdr="${drawingNamespace}" xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:r="${officeRelationshipNamespace}" xmlns:c="${chartNamespace}">${anchors}</xdr:wsDr>`
}

function drawingRelationshipXml(charts: DrawingChart[]): string {
  const relationships = charts.map(({ chartNumber }, index) =>
    `<Relationship Id="rId${index + 1}" Type="${officeRelationshipNamespace}/chart" Target="../charts/chart${chartNumber}.xml"/>`,
  ).join('')
  return `<Relationships xmlns="${packageRelationshipNamespace}">${relationships}</Relationships>`
}

function nextRelationshipId(xml: string): string {
  const ids = Array.from(xml.matchAll(/\bId="rId(\d+)"/g), (match) => Number(match[1]))
  return `rId${Math.max(0, ...ids) + 1}`
}

function addWorksheetDrawing(xml: string, relationshipId: string): string {
  if (!xml.includes('</worksheet>')) throw new Error('Không thể thêm biểu đồ vào trang tính Excel.')
  return xml.replace('</worksheet>', `<drawing r:id="${relationshipId}"/></worksheet>`)
}

function addRelationship(xml: string, relationshipId: string, target: string): string {
  const relationship = `<Relationship Id="${relationshipId}" Type="${officeRelationshipNamespace}/drawing" Target="${target}"/>`
  if (xml.includes('</Relationships>')) return xml.replace('</Relationships>', `${relationship}</Relationships>`)
  return `<Relationships xmlns="${packageRelationshipNamespace}">${relationship}</Relationships>`
}

export function addExcelCharts(workbook: ArrayBuffer, sources: ExcelChartSource[]): ArrayBuffer {
  const files = unzipSync(new Uint8Array(workbook))
  const contentTypesPath = '[Content_Types].xml'
  const contentTypesFile = files[contentTypesPath]
  if (!contentTypesFile) throw new Error('Không tìm thấy khai báo cấu trúc file Excel.')
  let contentTypes = strFromU8(contentTypesFile)
  if (!contentTypes.includes('</Types>')) throw new Error('Không thể cập nhật khai báo cấu trúc file Excel.')
  let chartNumber = 0
  const chartsBySheet = new Map<number, DrawingChart[]>()

  sources.forEach((source) => {
    const data = chartData(source)
    if (!data) return

    chartNumber += 1
    const sheetCharts = chartsBySheet.get(source.sheetIndex) ?? []
    sheetCharts.push({
      chartNumber,
      anchor: source.anchor ?? { column: 0, row: source.rows.length + 9 },
    })
    chartsBySheet.set(source.sheetIndex, sheetCharts)
    files[`xl/charts/chart${chartNumber}.xml`] = strToU8(chartXml(source.title, data))
    contentTypes = contentTypes.replace(
      '</Types>',
      `<Override PartName="/xl/charts/chart${chartNumber}.xml" ContentType="application/vnd.openxmlformats-officedocument.drawingml.chart+xml"/></Types>`,
    )
  })

  let drawingNumber = 0
  chartsBySheet.forEach((sheetCharts, sheetIndex) => {
    drawingNumber += 1
    const sheetNumber = sheetIndex + 1
    const worksheetPath = `xl/worksheets/sheet${sheetNumber}.xml`
    const worksheetFile = files[worksheetPath]
    if (!worksheetFile) throw new Error(`Không tìm thấy trang tính Excel số ${sheetNumber}.`)

    const worksheetRelationshipsPath = `xl/worksheets/_rels/sheet${sheetNumber}.xml.rels`
    const worksheetRelationships = files[worksheetRelationshipsPath]
      ? strFromU8(files[worksheetRelationshipsPath])
      : ''
    const relationshipId = nextRelationshipId(worksheetRelationships)
    files[worksheetPath] = strToU8(addWorksheetDrawing(strFromU8(worksheetFile), relationshipId))
    files[worksheetRelationshipsPath] = strToU8(
      addRelationship(worksheetRelationships, relationshipId, `../drawings/drawing${drawingNumber}.xml`),
    )
    files[`xl/drawings/drawing${drawingNumber}.xml`] = strToU8(drawingXml(sheetCharts))
    files[`xl/drawings/_rels/drawing${drawingNumber}.xml.rels`] = strToU8(drawingRelationshipXml(sheetCharts))
    contentTypes = contentTypes.replace(
      '</Types>',
      `<Override PartName="/xl/drawings/drawing${drawingNumber}.xml" ContentType="application/vnd.openxmlformats-officedocument.drawing+xml"/></Types>`,
    )
  })

  if (chartNumber) files[contentTypesPath] = strToU8(contentTypes)
  const output = zipSync(files, { level: 6 })
  const result = new ArrayBuffer(output.byteLength)
  new Uint8Array(result).set(output)
  return result
}
