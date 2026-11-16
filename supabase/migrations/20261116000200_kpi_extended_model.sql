-- Extended KPI catalog, targets, snapshots, and source records.
-- This migration defines structure only; it inserts no operational/sample KPI values.

CREATE TABLE IF NOT EXISTS public.kpi_definition (
  code              varchar(30) PRIMARY KEY,
  group_code        varchar(30) NOT NULL CHECK (group_code IN (
    'BTC', 'NHAN_VIEN_HO_TRO', 'GIAM_KHAO', 'TRUONG',
    'DOANH_NGHIEP', 'NHA_TAI_TRO'
  )),
  name              varchar(200) NOT NULL,
  value_type        varchar(20) NOT NULL CHECK (value_type IN (
    'COUNT', 'MONEY', 'PERCENT', 'TIME', 'SCORE'
  )),
  unit              varchar(30) NOT NULL,
  aggregation       varchar(20) NOT NULL CHECK (aggregation IN (
    'CUMULATIVE', 'AVERAGE', 'STDDEV'
  )),
  direction         varchar(10) NOT NULL CHECK (direction IN ('HIGH', 'LOW')),
  formula_text      text NOT NULL,
  source_tables     text[] NOT NULL DEFAULT '{}',
  active            boolean NOT NULL DEFAULT true,
  created_at        timestamptz NOT NULL DEFAULT now(),
  updated_at        timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.kpi_period (
  period_id         varchar(20) PRIMARY KEY,
  start_date        date NOT NULL,
  end_date          date NOT NULL,
  status            varchar(20) NOT NULL DEFAULT 'DRAFT'
                    CHECK (status IN ('DRAFT', 'RUNNING', 'FINALIZED')),
  created_at        timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT ck_kpi_period_key CHECK (period_id ~ '^[0-9]{4}-Q[1-4]$'),
  CONSTRAINT ck_kpi_period_dates CHECK (start_date < end_date)
);

CREATE TABLE IF NOT EXISTS public.kpi_target (
  target_id         bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  kpi_code          varchar(30) NOT NULL REFERENCES public.kpi_definition(code),
  period_id         varchar(20) NOT NULL REFERENCES public.kpi_period(period_id),
  subject_type      varchar(30) NOT NULL CHECK (subject_type IN (
    'BTC', 'NHAN_VIEN', 'GIAM_KHAO', 'TRUONG',
    'DOANH_NGHIEP', 'NHA_TAI_TRO', 'BO_PHAN'
  )),
  -- Store the source entity key as text; its table depends on subject_type.
  -- Use 'ALL' for an organization-wide target.
  subject_id        varchar(100) NOT NULL,
  target_value      numeric(18, 2) NOT NULL CHECK (target_value > 0),
  due_date          date NOT NULL,
  weight            numeric(5, 2) NOT NULL DEFAULT 1
                    CHECK (weight BETWEEN 0.1 AND 10),
  status            varchar(20) NOT NULL DEFAULT 'PUBLISHED'
                    CHECK (status IN ('DRAFT', 'PUBLISHED', 'EXEMPT', 'FINALIZED')),
  note              varchar(500),
  created_by        uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at        timestamptz NOT NULL DEFAULT now(),
  updated_at        timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT uq_kpi_target_subject UNIQUE (kpi_code, period_id, subject_type, subject_id)
);

CREATE INDEX IF NOT EXISTS ix_kpi_target_period_status
  ON public.kpi_target(period_id, status);
CREATE INDEX IF NOT EXISTS ix_kpi_target_subject
  ON public.kpi_target(subject_type, subject_id);

CREATE TABLE IF NOT EXISTS public.kpi_target_history (
  history_id        bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  target_id         bigint NOT NULL REFERENCES public.kpi_target(target_id) ON DELETE RESTRICT,
  changed_by        uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  changed_at        timestamptz NOT NULL DEFAULT now(),
  old_target_value  numeric(18, 2),
  new_target_value  numeric(18, 2) NOT NULL CHECK (new_target_value > 0),
  old_due_date      date,
  new_due_date      date NOT NULL,
  reason            varchar(500) NOT NULL CHECK (length(btrim(reason)) >= 10)
);

CREATE INDEX IF NOT EXISTS ix_kpi_target_history_target
  ON public.kpi_target_history(target_id, changed_at DESC);

CREATE TABLE IF NOT EXISTS public.kpi_snapshot (
  snapshot_id       bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  target_id         bigint NOT NULL REFERENCES public.kpi_target(target_id) ON DELETE RESTRICT,
  snapshot_date     date NOT NULL,
  value             numeric(18, 4) NOT NULL,
  source_version    varchar(100),
  created_at        timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT uq_kpi_snapshot_day UNIQUE (target_id, snapshot_date)
);

CREATE TABLE IF NOT EXISTS public.kpi_note (
  note_id           bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  target_id         bigint NOT NULL REFERENCES public.kpi_target(target_id) ON DELETE CASCADE,
  author_id         uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  body              varchar(500) NOT NULL CHECK (length(btrim(body)) > 0),
  created_at        timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS ix_kpi_note_target
  ON public.kpi_note(target_id, created_at DESC);

CREATE TABLE IF NOT EXISTS public.kpi_alert (
  alert_id          bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  target_id         bigint NOT NULL REFERENCES public.kpi_target(target_id) ON DELETE CASCADE,
  level             varchar(20) NOT NULL CHECK (level IN (
    'INFO', 'WARNING', 'AT_RISK', 'CRITICAL', 'DATA'
  )),
  status            varchar(20) NOT NULL DEFAULT 'OPEN'
                    CHECK (status IN ('OPEN', 'HANDLED')),
  message           varchar(1000) NOT NULL,
  created_at        timestamptz NOT NULL DEFAULT now(),
  handled_by        uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  handled_at        timestamptz,
  handled_note      varchar(500),
  CONSTRAINT ck_kpi_alert_handled CHECK (
    (status = 'OPEN' AND handled_by IS NULL AND handled_at IS NULL AND handled_note IS NULL)
    OR
    (status = 'HANDLED' AND handled_by IS NOT NULL AND handled_at IS NOT NULL
      AND length(btrim(COALESCE(handled_note, ''))) >= 10)
  )
);

CREATE INDEX IF NOT EXISTS ix_kpi_alert_open
  ON public.kpi_alert(status, level, created_at DESC);

-- Support staff: lead/contact event log. Payment conversion is linked through thi_sinh_id.
CREATE TABLE IF NOT EXISTS public.kpi_lead (
  lead_id           bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  thi_sinh_id       varchar(20) REFERENCES public.thisinh(thi_sinh_id) ON DELETE SET NULL,
  bieu_mau_log      varchar(30) REFERENCES public.bieumau(bieu_mau_log) ON DELETE SET NULL,
  quang_cao_log     varchar(30) REFERENCES public.quangcao(quang_cao_log) ON DELETE SET NULL,
  owner_id          varchar(20) NOT NULL REFERENCES public.nhanvien(nhan_vien_id),
  source_name       varchar(100) NOT NULL,
  source_ref        varchar(100),
  created_at        timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT ck_kpi_lead_source CHECK (
    thi_sinh_id IS NOT NULL OR bieu_mau_log IS NOT NULL
    OR quang_cao_log IS NOT NULL OR source_ref IS NOT NULL
  )
);

CREATE INDEX IF NOT EXISTS ix_kpi_lead_owner_created
  ON public.kpi_lead(owner_id, created_at);
CREATE INDEX IF NOT EXISTS ix_kpi_lead_student
  ON public.kpi_lead(thi_sinh_id);

CREATE TABLE IF NOT EXISTS public.kpi_lead_contact (
  contact_id        bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  lead_id           bigint NOT NULL REFERENCES public.kpi_lead(lead_id) ON DELETE CASCADE,
  employee_id       varchar(20) NOT NULL REFERENCES public.nhanvien(nhan_vien_id),
  contacted_at      timestamptz NOT NULL,
  result_code       varchar(30) NOT NULL CHECK (result_code IN (
    'NO_ANSWER', 'CONTACTED', 'FOLLOW_UP', 'CONVERTED', 'NOT_INTERESTED', 'OTHER'
  )),
  note              varchar(1000),
  created_at        timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS ix_kpi_lead_contact_lead_time
  ON public.kpi_lead_contact(lead_id, contacted_at);
CREATE INDEX IF NOT EXISTS ix_kpi_lead_contact_employee_time
  ON public.kpi_lead_contact(employee_id, contacted_at);

-- First response timestamp supplements qna.thoi_gian and qna.trang_thai.
ALTER TABLE public.qna
  ADD COLUMN IF NOT EXISTS thoi_gian_phan_hoi_dau timestamptz;

-- Judge task assignment and individual score; one row per judge and submission.
CREATE TABLE IF NOT EXISTS public.kpi_judge_assignment (
  assignment_id     bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  bai_nop_id        varchar(30) NOT NULL REFERENCES public.bainop(bai_nop_id) ON DELETE CASCADE,
  judge_id          varchar(20) NOT NULL REFERENCES public.nhanvien(nhan_vien_id),
  assigned_at       timestamptz NOT NULL DEFAULT now(),
  status            varchar(20) NOT NULL DEFAULT 'ASSIGNED'
                    CHECK (status IN ('ASSIGNED', 'SCORED', 'CANCELLED')),
  scored_at         timestamptz,
  score             numeric(8, 2) CHECK (score IS NULL OR score >= 0),
  note              varchar(1000),
  created_at        timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT uq_kpi_judge_submission UNIQUE (bai_nop_id, judge_id),
  CONSTRAINT ck_kpi_judge_scored CHECK (
    status <> 'SCORED' OR (scored_at IS NOT NULL AND score IS NOT NULL)
  ),
  CONSTRAINT ck_kpi_judge_time CHECK (scored_at IS NULL OR scored_at >= assigned_at)
);

CREATE INDEX IF NOT EXISTS ix_kpi_judge_employee_status
  ON public.kpi_judge_assignment(judge_id, status, assigned_at);
CREATE INDEX IF NOT EXISTS ix_kpi_judge_submission
  ON public.kpi_judge_assignment(bai_nop_id);

CREATE TABLE IF NOT EXISTS public.kpi_fraud_case (
  case_id           bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  bai_nop_id        varchar(30) NOT NULL REFERENCES public.bainop(bai_nop_id) ON DELETE RESTRICT,
  judge_id          varchar(20) REFERENCES public.nhanvien(nhan_vien_id),
  reported_by       varchar(20) REFERENCES public.nhanvien(nhan_vien_id),
  reported_at       timestamptz NOT NULL DEFAULT now(),
  status            varchar(20) NOT NULL DEFAULT 'OPEN'
                    CHECK (status IN ('OPEN', 'INVESTIGATING', 'CONCLUDED', 'DISMISSED')),
  conclusion        varchar(1000),
  concluded_at      timestamptz,
  CONSTRAINT ck_kpi_fraud_conclusion CHECK (
    status NOT IN ('CONCLUDED', 'DISMISSED')
    OR (concluded_at IS NOT NULL AND length(btrim(COALESCE(conclusion, ''))) > 0)
  )
);

CREATE INDEX IF NOT EXISTS ix_kpi_fraud_status_time
  ON public.kpi_fraud_case(status, reported_at);

-- Normalize school names for per-school targets and registration counts.
CREATE TABLE IF NOT EXISTS public.kpi_school (
  school_id         bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  name              varchar(200) NOT NULL,
  active            boolean NOT NULL DEFAULT true,
  created_at        timestamptz NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_kpi_school_name_ci
  ON public.kpi_school(lower(btrim(name)));

INSERT INTO public.kpi_school(name)
SELECT DISTINCT btrim(ts.truong_hoc)
FROM public.thisinh ts
WHERE NULLIF(btrim(ts.truong_hoc), '') IS NOT NULL
  AND NOT EXISTS (
    SELECT 1
    FROM public.kpi_school s
    WHERE lower(btrim(s.name)) = lower(btrim(ts.truong_hoc))
  );

ALTER TABLE public.thisinh
  ADD COLUMN IF NOT EXISTS school_id bigint
  REFERENCES public.kpi_school(school_id) ON DELETE SET NULL;

UPDATE public.thisinh ts
SET school_id = s.school_id
FROM public.kpi_school s
WHERE ts.school_id IS NULL
  AND NULLIF(btrim(ts.truong_hoc), '') IS NOT NULL
  AND lower(btrim(ts.truong_hoc)) = lower(btrim(s.name));

CREATE INDEX IF NOT EXISTS ix_thisinh_school_id
  ON public.thisinh(school_id);

-- Commission reconciliation for schools and candidate-sourcing businesses.
CREATE TABLE IF NOT EXISTS public.kpi_commission_settlement (
  settlement_id     bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  partner_type      varchar(20) NOT NULL CHECK (partner_type IN ('SCHOOL', 'BUSINESS')),
  school_id         bigint REFERENCES public.kpi_school(school_id) ON DELETE RESTRICT,
  business_id       varchar(20) REFERENCES public.doanhnghiep(doanh_nghiep_id) ON DELETE RESTRICT,
  source_payment_id varchar(100),
  period_id         varchar(20) NOT NULL REFERENCES public.kpi_period(period_id),
  earned_amount     numeric(18, 2) NOT NULL CHECK (earned_amount >= 0),
  paid_amount       numeric(18, 2) NOT NULL DEFAULT 0 CHECK (paid_amount >= 0),
  reconciled_at     timestamptz,
  note              varchar(1000),
  created_at        timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT ck_kpi_commission_partner CHECK (
    (partner_type = 'SCHOOL' AND school_id IS NOT NULL AND business_id IS NULL)
    OR
    (partner_type = 'BUSINESS' AND business_id IS NOT NULL AND school_id IS NULL)
  )
);

CREATE INDEX IF NOT EXISTS ix_kpi_commission_period_partner
  ON public.kpi_commission_settlement(period_id, partner_type, school_id, business_id);

-- Sponsor benefit delivery; reach is already recorded in truyenthong_taitro.
CREATE TABLE IF NOT EXISTS public.kpi_sponsor_benefit (
  benefit_id        bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  sponsor_id        varchar(20) NOT NULL REFERENCES public.doanhnghiep(doanh_nghiep_id) ON DELETE RESTRICT,
  contract_ref      varchar(100) NOT NULL,
  benefit_name      varchar(300) NOT NULL,
  due_date          date NOT NULL,
  completion_pct    numeric(5, 2) NOT NULL DEFAULT 0
                    CHECK (completion_pct BETWEEN 0 AND 100),
  completed_at      timestamptz,
  note              varchar(1000),
  created_at        timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS ix_kpi_sponsor_benefit_sponsor_due
  ON public.kpi_sponsor_benefit(sponsor_id, due_date);

CREATE TABLE IF NOT EXISTS public.kpi_sponsor_receipt (
  receipt_id        bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  sponsor_id        varchar(20) NOT NULL REFERENCES public.doanhnghiep(doanh_nghiep_id) ON DELETE RESTRICT,
  received_at       timestamptz NOT NULL,
  contribution_type varchar(20) NOT NULL CHECK (contribution_type IN ('CASH', 'IN_KIND')),
  amount_vnd        numeric(18, 2) NOT NULL CHECK (amount_vnd >= 0),
  description       varchar(1000) NOT NULL,
  accepted          boolean NOT NULL DEFAULT false,
  created_at        timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS ix_kpi_sponsor_receipt_sponsor_date
  ON public.kpi_sponsor_receipt(sponsor_id, received_at);

-- Per-FAQ useful votes; faq_canonical.luot_xem remains the view counter.
CREATE TABLE IF NOT EXISTS public.kpi_faq_feedback (
  feedback_id       bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  faq_id            varchar(20) NOT NULL REFERENCES public.faq_canonical(faq_id) ON DELETE CASCADE,
  qna_id            varchar(30) REFERENCES public.qna(qna_id) ON DELETE SET NULL,
  thi_sinh_id       varchar(20) REFERENCES public.thisinh(thi_sinh_id) ON DELETE SET NULL,
  business_id       varchar(20) REFERENCES public.doanhnghiep(doanh_nghiep_id) ON DELETE SET NULL,
  helpful           boolean NOT NULL,
  created_at        timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT ck_kpi_faq_feedback_actor CHECK (
    thi_sinh_id IS NOT NULL OR business_id IS NOT NULL OR qna_id IS NOT NULL
  )
);

CREATE INDEX IF NOT EXISTS ix_kpi_faq_feedback_faq_date
  ON public.kpi_faq_feedback(faq_id, created_at);

INSERT INTO public.kpi_definition
  (code, group_code, name, value_type, unit, aggregation, direction, formula_text, source_tables)
VALUES
  ('KPI_TS', 'BTC', 'Thí sinh tham gia thực tế', 'COUNT', 'thí sinh', 'CUMULATIVE', 'HIGH',
   'Đếm thí sinh tham gia thực tế trong kỳ.', ARRAY['thisinh', 'dangky', 'thanhtoan', 'dangkyweb']),
  ('KPI_DT', 'BTC', 'Doanh thu lệ phí thi', 'MONEY', 'VNĐ', 'CUMULATIVE', 'HIGH',
   'Tổng lệ phí đã thanh toán thành công trong kỳ.', ARRAY['thanhtoan', 'dangkyweb']),
  ('KPI_DN', 'DOANH_NGHIEP', 'Doanh nghiệp ký hợp đồng', 'COUNT', 'doanh nghiệp', 'CUMULATIVE', 'HIGH',
   'Đếm doanh nghiệp có giai đoạn ký hợp đồng trong kỳ.', ARRAY['doanhnghiep_pipeline']),
  ('KPI_HT1', 'NHAN_VIEN_HO_TRO', 'Hồ sơ chưa thanh toán đã liên hệ', 'COUNT', 'hồ sơ', 'CUMULATIVE', 'HIGH',
   'Đếm lead chưa thanh toán có ít nhất một lần liên hệ trong kỳ.', ARRAY['kpi_lead', 'kpi_lead_contact', 'thanhtoan', 'dangkyweb']),
  ('KPI_HT2', 'NHAN_VIEN_HO_TRO', 'Tỷ lệ chuyển đổi sau tư vấn', 'PERCENT', '%', 'AVERAGE', 'HIGH',
   'Lead thanh toán trong 7 ngày sau liên hệ chia cho lead đã liên hệ.', ARRAY['kpi_lead', 'kpi_lead_contact', 'thanhtoan', 'dangkyweb']),
  ('KPI_HT3', 'NHAN_VIEN_HO_TRO', 'Thời gian phản hồi đầu tiên', 'TIME', 'giờ', 'AVERAGE', 'LOW',
   'Trung bình thời gian từ lúc tạo Q&A đến phản hồi đầu tiên, tính bằng giờ.', ARRAY['qna']),
  ('KPI_HT4', 'NHAN_VIEN_HO_TRO', 'Câu hỏi đã giải đáp', 'COUNT', 'câu hỏi', 'CUMULATIVE', 'HIGH',
   'Đếm Q&A có trạng thái đã trả lời trong kỳ.', ARRAY['qna']),
  ('KPI_HT5', 'NHAN_VIEN_HO_TRO', 'Tỷ lệ FAQ hữu ích', 'PERCENT', '%', 'AVERAGE', 'HIGH',
   'Lượt đánh giá hữu ích chia tổng lượt đánh giá FAQ.', ARRAY['faq_canonical', 'kpi_faq_feedback']),
  ('KPI_GK1', 'GIAM_KHAO', 'Bài đã chấm trên bài được giao', 'PERCENT', '%', 'AVERAGE', 'HIGH',
   'Số bài đã chấm chia số bài được giao.', ARRAY['kpi_judge_assignment', 'bainop']),
  ('KPI_GK2', 'GIAM_KHAO', 'Thời gian chấm trung bình', 'TIME', 'giờ', 'AVERAGE', 'LOW',
   'Trung bình thời gian từ lúc nộp bài đến lúc chấm, tính bằng giờ.', ARRAY['kpi_judge_assignment', 'bainop']),
  ('KPI_GK3', 'GIAM_KHAO', 'Độ lệch điểm giữa các giám khảo', 'SCORE', 'điểm', 'STDDEV', 'LOW',
   'Độ lệch chuẩn điểm của cùng một bài được nhiều giám khảo chấm.', ARRAY['kpi_judge_assignment']),
  ('KPI_GK4', 'GIAM_KHAO', 'Ca nghi gian lận đã xử lý', 'PERCENT', '%', 'AVERAGE', 'HIGH',
   'Số ca có kết luận chia số ca được cảnh báo.', ARRAY['kpi_fraud_case']),
  ('KPI_TR1', 'TRUONG', 'Đăng ký so với chỉ tiêu', 'PERCENT', '%', 'CUMULATIVE', 'HIGH',
   'Số đăng ký của trường chia chỉ tiêu được giao.', ARRAY['kpi_school', 'thisinh', 'dangky', 'kpi_target']),
  ('KPI_TR2', 'TRUONG', 'Số ngày quá hạn chỉ tiêu', 'TIME', 'ngày', 'CUMULATIVE', 'LOW',
   'Số ngày sau hạn chỉ tiêu khi trường chưa đạt mục tiêu.', ARRAY['kpi_school', 'kpi_target', 'thisinh', 'dangky']),
  ('KPI_TR3', 'TRUONG', 'Hoa hồng 2% đã đối soát', 'PERCENT', '%', 'AVERAGE', 'HIGH',
   'Hoa hồng đã xác nhận chia hoa hồng phát sinh.', ARRAY['kpi_commission_settlement']),
  ('KPI_DN1', 'DOANH_NGHIEP', 'Thí sinh so với cam kết', 'PERCENT', '%', 'CUMULATIVE', 'HIGH',
   'Thí sinh qua mã giới thiệu chia số thí sinh doanh nghiệp cam kết.', ARRAY['doanhnghiep', 'dangkyweb', 'kpi_target']),
  ('KPI_DN2', 'DOANH_NGHIEP', 'Hoa hồng 15% đã thanh toán', 'PERCENT', '%', 'AVERAGE', 'HIGH',
   'Hoa hồng đã thanh toán chia hoa hồng phát sinh.', ARRAY['kpi_commission_settlement']),
  ('KPI_TT1', 'NHA_TAI_TRO', 'Quyền lợi đã trả', 'PERCENT', '%', 'AVERAGE', 'HIGH',
   'Tỷ lệ hoàn thành quyền lợi theo hợp đồng tài trợ.', ARRAY['kpi_sponsor_benefit']),
  ('KPI_TT2', 'NHA_TAI_TRO', 'Brand reach thực tế', 'PERCENT', '%', 'CUMULATIVE', 'HIGH',
   'Lượt tiếp cận ghi nhận chia lượt tiếp cận cam kết.', ARRAY['truyenthong_taitro', 'kpi_target']),
  ('KPI_TT3', 'NHA_TAI_TRO', 'Giá trị đã nhận', 'MONEY', 'VNĐ', 'CUMULATIVE', 'HIGH',
   'Tổng hiện kim và hiện vật quy đổi đã được xác nhận.', ARRAY['kpi_sponsor_receipt'])
ON CONFLICT (code) DO NOTHING;

-- Keep all new records private until server-side subject-scoped policies/RPCs are added.
ALTER TABLE public.kpi_definition ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.kpi_period ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.kpi_target ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.kpi_target_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.kpi_snapshot ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.kpi_note ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.kpi_alert ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.kpi_lead ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.kpi_lead_contact ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.kpi_judge_assignment ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.kpi_fraud_case ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.kpi_school ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.kpi_commission_settlement ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.kpi_sponsor_benefit ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.kpi_sponsor_receipt ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.kpi_faq_feedback ENABLE ROW LEVEL SECURITY;
