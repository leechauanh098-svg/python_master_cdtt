UPDATE public.kpi_definition
SET value_type = 'COUNT',
    unit = 'thí sinh',
    formula_text = 'Số thí sinh đăng ký thành công từ doanh nghiệp trong kỳ; mục tiêu là số thí sinh doanh nghiệp cam kết.',
    updated_at = now()
WHERE code = 'KPI_DN1';

UPDATE public.kpi_definition
SET value_type = 'COUNT',
    unit = 'thí sinh',
    formula_text = 'Số đăng ký hợp lệ của trường trong kỳ; mục tiêu là số thí sinh trường cam kết.',
    updated_at = now()
WHERE code = 'KPI_TR1';

UPDATE public.kpi_definition
SET value_type = 'COUNT',
    unit = 'lượt hiển thị',
    formula_text = 'Tổng lượt hiển thị thực tế trong kỳ; mục tiêu là lượt hiển thị đã cam kết.',
    updated_at = now()
WHERE code = 'KPI_TT2';

CREATE OR REPLACE FUNCTION public.fn_kpi_set_target(
  p_kpi_id varchar,
  p_period varchar,
  p_group varchar,
  p_name varchar,
  p_target numeric,
  p_reason varchar DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, auth, pg_temp
AS $$
DECLARE
  v_employee_id varchar(20);
  v_employee_name varchar(100);
  v_old_target numeric(18,2);
  v_old_due_date date;
  v_target_id bigint;
  v_exists boolean;
  v_expected_prefix text;
  v_group_code varchar(30);
  v_kpi_name varchar(200);
  v_start_date date;
  v_end_date date;
BEGIN
  SELECT nv.nhan_vien_id, nv.ho_ten
  INTO v_employee_id, v_employee_name
  FROM public.nhanvien nv
  JOIN public.nhanvien_vaitro_ct nvt ON nvt.nhan_vien_id = nv.nhan_vien_id
  JOIN public.vaitro vt ON vt.role_id = nvt.role_id AND vt.trang_thai = 'DANG_AP_DUNG'
  WHERE nv.trang_thai = 'ACTIVE'
    AND vt.role_id = 'ADMIN'
    AND (
      nv.user_id = auth.uid()
      OR (
        nv.user_id IS NULL
        AND lower(nv.email) = lower(auth.jwt() ->> 'email')
      )
    )
  LIMIT 1;

  IF auth.uid() IS NULL OR v_employee_id IS NULL THEN
    RAISE EXCEPTION 'Chỉ Admin mới được thiết lập mục tiêu KPI.' USING ERRCODE = '42501';
  END IF;
  IF p_target IS NULL OR p_target <= 0 THEN
    RAISE EXCEPTION 'Mục tiêu phải lớn hơn 0.';
  END IF;
  IF p_period IS NULL OR p_period !~ '^[0-9]{4}-Q[1-4]$' THEN
    RAISE EXCEPTION 'Kỳ KPI không hợp lệ.';
  END IF;
  IF p_name IS NULL OR btrim(p_name) = '' THEN
    RAISE EXCEPTION 'Tên KPI không được để trống.';
  END IF;

  v_expected_prefix := CASE p_group
    WHEN 'THI_SINH' THEN 'KPI_TS_'
    WHEN 'DOANH_THU' THEN 'KPI_DT_'
    WHEN 'DOANH_NGHIEP' THEN 'KPI_DN_'
    ELSE NULL
  END;

  IF p_kpi_id IN (
    'KPI_TS_' || replace(p_period, '-Q', 'Q'),
    'KPI_DT_' || replace(p_period, '-Q', 'Q'),
    'KPI_DN_' || replace(p_period, '-Q', 'Q')
  ) THEN
    IF v_expected_prefix IS NULL OR p_kpi_id <> v_expected_prefix || replace(p_period, '-Q', 'Q') THEN
      RAISE EXCEPTION 'Mã KPI không khớp nhóm và kỳ được chọn.';
    END IF;
    IF EXISTS (
      SELECT 1 FROM public.kpi_muctieu k
      WHERE k.ky_bao_cao = p_period
        AND k.nhom = p_group
        AND k.ten_kpi = btrim(p_name)
        AND k.kpi_id <> p_kpi_id
    ) THEN
      RAISE EXCEPTION 'KPI này đã có mục tiêu trong kỳ.';
    END IF;

    SELECT k.muc_tieu
    INTO v_old_target
    FROM public.kpi_muctieu k
    WHERE k.kpi_id = p_kpi_id
    FOR UPDATE;
    v_exists := FOUND;
    IF v_exists AND length(btrim(COALESCE(p_reason, ''))) < 10 THEN
      RAISE EXCEPTION 'Lý do thay đổi phải có ít nhất 10 ký tự.';
    END IF;

    INSERT INTO public.kpi_muctieu (kpi_id, ky_bao_cao, nhom, ten_kpi, muc_tieu)
    VALUES (p_kpi_id, p_period, p_group, btrim(p_name), p_target)
    ON CONFLICT (kpi_id) DO UPDATE
      SET ky_bao_cao = EXCLUDED.ky_bao_cao,
          nhom = EXCLUDED.nhom,
          ten_kpi = EXCLUDED.ten_kpi,
          muc_tieu = EXCLUDED.muc_tieu;

    INSERT INTO public.audit_log (
      nguoi_thuc_hien_id, nguoi_thuc_hien, actor_role_id, vai_tro,
      ten_bang, id_ban_ghi, hanh_dong, du_lieu_cu, du_lieu_moi, ghi_chu
    ) VALUES (
      v_employee_id, v_employee_name, 'ADMIN', 'Quản trị viên',
      'kpi_muctieu', p_kpi_id, CASE WHEN v_exists THEN 'SUA' ELSE 'THEM' END,
      CASE WHEN v_exists THEN v_old_target::text ELSE NULL END,
      p_target::text,
      NULLIF(btrim(p_reason), '')
    );
    RETURN;
  END IF;

  SELECT d.group_code, d.name
  INTO v_group_code, v_kpi_name
  FROM public.kpi_definition d
  WHERE d.code = p_kpi_id
    AND d.active
    AND d.code NOT IN ('KPI_TS', 'KPI_DT', 'KPI_DN');
  IF NOT FOUND OR p_group <> v_group_code OR btrim(p_name) <> v_kpi_name THEN
    RAISE EXCEPTION 'Mã KPI, nhóm hoặc tên KPI không khớp danh mục.';
  END IF;

  v_start_date := make_date(
    substring(p_period from 1 for 4)::integer,
    ((substring(p_period from 7 for 1)::integer - 1) * 3) + 1,
    1
  );
  v_end_date := (v_start_date + interval '3 months')::date;
  INSERT INTO public.kpi_period (period_id, start_date, end_date, status)
  VALUES (p_period, v_start_date, v_end_date, 'RUNNING')
  ON CONFLICT (period_id) DO NOTHING;

  SELECT t.target_id, t.target_value, t.due_date
  INTO v_target_id, v_old_target, v_old_due_date
  FROM public.kpi_target t
  WHERE t.kpi_code = p_kpi_id
    AND t.period_id = p_period
    AND t.subject_type = 'BO_PHAN'
    AND t.subject_id = 'ALL'
  FOR UPDATE;
  v_exists := FOUND;
  IF v_exists AND length(btrim(COALESCE(p_reason, ''))) < 10 THEN
    RAISE EXCEPTION 'Lý do thay đổi phải có ít nhất 10 ký tự.';
  END IF;

  IF v_exists THEN
    INSERT INTO public.kpi_target_history (
      target_id, changed_by, old_target_value, new_target_value,
      old_due_date, new_due_date, reason
    ) VALUES (
      v_target_id, auth.uid(), v_old_target, p_target,
      v_old_due_date, v_end_date - 1, btrim(p_reason)
    );
    UPDATE public.kpi_target
    SET target_value = p_target,
        due_date = v_end_date - 1,
        status = 'PUBLISHED',
        updated_at = now()
    WHERE target_id = v_target_id;
  ELSE
    INSERT INTO public.kpi_target (
      kpi_code, period_id, subject_type, subject_id, target_value, due_date,
      status, created_by
    ) VALUES (
      p_kpi_id, p_period, 'BO_PHAN', 'ALL', p_target, v_end_date - 1,
      'PUBLISHED', auth.uid()
    )
    RETURNING target_id INTO v_target_id;
  END IF;

  INSERT INTO public.audit_log (
    nguoi_thuc_hien_id, nguoi_thuc_hien, actor_role_id, vai_tro,
    ten_bang, id_ban_ghi, hanh_dong, du_lieu_cu, du_lieu_moi, ghi_chu
  ) VALUES (
    v_employee_id, v_employee_name, 'ADMIN', 'Quản trị viên',
    'kpi_target', v_target_id::text, CASE WHEN v_exists THEN 'SUA' ELSE 'THEM' END,
    CASE WHEN v_exists THEN v_old_target::text ELSE NULL END,
    p_target::text,
    NULLIF(btrim(p_reason), '')
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.fn_kpi_dashboard_snapshot_progress(p_period varchar)
RETURNS TABLE (
  kpi_id varchar,
  nhom varchar,
  ten_kpi varchar,
  muc_tieu numeric,
  gia_tri_hien_tai numeric,
  don_vi varchar,
  huong varchar,
  kieu_cong_don varchar,
  trong_so numeric,
  han_chot date,
  chu_the varchar,
  dinh_nghia text,
  cong_thuc text,
  thoi_diem_cap_nhat timestamptz
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, public, auth, pg_temp
AS $$
BEGIN
  IF auth.uid() IS NULL OR NOT public.fn_current_user_can_view_kpi_dashboard() THEN
    RAISE EXCEPTION 'Bạn không có quyền xem dữ liệu KPI.' USING ERRCODE = '42501';
  END IF;

  IF p_period IS NULL OR p_period !~ '^[0-9]{4}-Q[1-4]$' THEN
    RAISE EXCEPTION 'Kỳ KPI không hợp lệ.';
  END IF;

  RETURN QUERY
  SELECT
    (d.code || '_T' || t.target_id::text)::varchar,
    d.group_code,
    d.name,
    t.target_value,
    COALESCE(source_value.value, latest_snapshot.value),
    d.unit,
    CASE d.direction WHEN 'LOW' THEN 'THAP' ELSE 'CAO' END::varchar,
    d.aggregation,
    t.weight,
    t.due_date,
    CASE
      WHEN t.subject_id = 'ALL' THEN 'Toàn bộ'
      ELSE COALESCE(nv.ho_ten, t.subject_id, t.subject_type)
    END::varchar,
    d.formula_text,
    d.formula_text,
    now()
  FROM public.kpi_target t
  JOIN public.kpi_definition d ON d.code = t.kpi_code AND d.active
  JOIN public.kpi_period p ON p.period_id = t.period_id
  LEFT JOIN public.nhanvien nv
    ON t.subject_type = 'NHAN_VIEN'
    AND nv.nhan_vien_id::text = t.subject_id
  LEFT JOIN LATERAL (
    SELECT s.value, s.created_at
    FROM public.kpi_snapshot s
    WHERE s.target_id = t.target_id
      AND s.snapshot_date >= p.start_date
      AND s.snapshot_date < p.end_date
      AND s.snapshot_date <= CURRENT_DATE
    ORDER BY s.snapshot_date DESC, s.created_at DESC
    LIMIT 1
  ) latest_snapshot ON true
  CROSS JOIN LATERAL (
    SELECT
      CASE d.code
        WHEN 'KPI_HT1' THEN (
          SELECT count(DISTINCT l.lead_id)::numeric
          FROM public.kpi_lead l
          JOIN public.kpi_lead_contact c ON c.lead_id = l.lead_id
          WHERE c.contacted_at >= p.start_date
            AND c.contacted_at < p.end_date
            AND (t.subject_type <> 'NHAN_VIEN' OR c.employee_id = t.subject_id)
            AND NOT EXISTS (
              SELECT 1 FROM public.thanhtoan tt
              WHERE tt.thi_sinh_id = l.thi_sinh_id
                AND tt.trang_thai_thanh_toan = 'THANH_TOAN_THANH_CONG'
            )
        )
        WHEN 'KPI_HT2' THEN (
          SELECT count(DISTINCT l.lead_id) FILTER (WHERE EXISTS (
                   SELECT 1 FROM public.thanhtoan tt
                   WHERE tt.thi_sinh_id = l.thi_sinh_id
                     AND tt.trang_thai_thanh_toan = 'THANH_TOAN_THANH_CONG'
                     AND tt.thoi_gian_thanh_toan >= c.contacted_at
                     AND tt.thoi_gian_thanh_toan < c.contacted_at + interval '7 days'
                 ))::numeric * 100
                 / NULLIF(count(DISTINCT l.lead_id), 0)
          FROM public.kpi_lead l
          JOIN public.kpi_lead_contact c ON c.lead_id = l.lead_id
          WHERE c.contacted_at >= p.start_date
            AND c.contacted_at < p.end_date
            AND (t.subject_type <> 'NHAN_VIEN' OR c.employee_id = t.subject_id)
        )
        WHEN 'KPI_HT3' THEN (
          SELECT avg(extract(epoch FROM (q.thoi_gian_phan_hoi_dau - q.thoi_gian::timestamptz)) / 3600)::numeric
          FROM public.qna q
          WHERE q.thoi_gian_phan_hoi_dau >= p.start_date
            AND q.thoi_gian_phan_hoi_dau < p.end_date
            AND (t.subject_type <> 'NHAN_VIEN' OR q.nhan_vien_id_ho_tro = t.subject_id)
        )
        WHEN 'KPI_HT4' THEN (
          SELECT count(*)::numeric
          FROM public.qna q
          WHERE q.trang_thai = 'DA_TRA_LOI'
            AND COALESCE(q.thoi_gian_phan_hoi_dau, q.updated_at) >= p.start_date
            AND COALESCE(q.thoi_gian_phan_hoi_dau, q.updated_at) < p.end_date
            AND (t.subject_type <> 'NHAN_VIEN' OR q.nhan_vien_id_ho_tro = t.subject_id)
        )
        WHEN 'KPI_HT5' THEN (
          SELECT count(*) FILTER (WHERE f.helpful)::numeric * 100 / NULLIF(count(*), 0)
          FROM public.kpi_faq_feedback f
          WHERE f.created_at >= p.start_date
            AND f.created_at < p.end_date
        )
        WHEN 'KPI_GK1' THEN (
          SELECT count(*) FILTER (WHERE a.status = 'SCORED')::numeric * 100
                 / NULLIF(count(*) FILTER (WHERE a.status <> 'CANCELLED'), 0)
          FROM public.kpi_judge_assignment a
          WHERE a.assigned_at >= p.start_date
            AND a.assigned_at < p.end_date
            AND (t.subject_type <> 'GIAM_KHAO' OR a.judge_id = t.subject_id)
        )
        WHEN 'KPI_GK2' THEN (
          SELECT avg(extract(epoch FROM (a.scored_at - b.thoi_gian_nop)) / 3600)::numeric
          FROM public.kpi_judge_assignment a
          JOIN public.bainop b ON b.bai_nop_id = a.bai_nop_id
          WHERE a.status = 'SCORED'
            AND a.scored_at >= p.start_date
            AND a.scored_at < p.end_date
            AND b.thoi_gian_nop IS NOT NULL
            AND (t.subject_type <> 'GIAM_KHAO' OR a.judge_id = t.subject_id)
        )
        WHEN 'KPI_GK3' THEN (
          SELECT avg(rater_scores.score_spread)::numeric
          FROM (
            SELECT stddev_pop(a.score) AS score_spread
            FROM public.kpi_judge_assignment a
            WHERE a.status = 'SCORED'
              AND a.scored_at >= p.start_date
              AND a.scored_at < p.end_date
              AND a.score IS NOT NULL
              AND (t.subject_type <> 'GIAM_KHAO' OR a.judge_id = t.subject_id)
            GROUP BY a.bai_nop_id
            HAVING count(*) > 1
          ) rater_scores
        )
        WHEN 'KPI_GK4' THEN (
          SELECT count(*) FILTER (WHERE f.status IN ('CONCLUDED', 'DISMISSED'))::numeric * 100
                 / NULLIF(count(*), 0)
          FROM public.kpi_fraud_case f
          WHERE f.reported_at >= p.start_date
            AND f.reported_at < p.end_date
            AND (t.subject_type <> 'GIAM_KHAO' OR f.judge_id = t.subject_id)
        )
        WHEN 'KPI_TR1' THEN (
          SELECT count(DISTINCT dk.thi_sinh_id)::numeric
          FROM public.dangky dk
          JOIN public.thisinh ts ON ts.thi_sinh_id = dk.thi_sinh_id
          WHERE dk.trang_thai <> 'HUY_DANG_KY'
            AND dk.ngay_dang_ky >= p.start_date
            AND dk.ngay_dang_ky < p.end_date
            AND (t.subject_type <> 'TRUONG' OR ts.school_id::text = t.subject_id)
        )
        WHEN 'KPI_TR2' THEN (
          SELECT CASE
            WHEN registrations.target_value IS NULL THEN NULL::numeric
            WHEN CURRENT_DATE > t.due_date AND registrations.total < registrations.target_value
              THEN (CURRENT_DATE - t.due_date)::numeric
            ELSE 0::numeric
          END
          FROM (
            SELECT count(DISTINCT dk.thi_sinh_id)::numeric AS total,
              (
                SELECT school_target.target_value
                FROM public.kpi_target school_target
                WHERE school_target.kpi_code = 'KPI_TR1'
                  AND school_target.period_id = t.period_id
                  AND school_target.subject_type = t.subject_type
                  AND school_target.subject_id = t.subject_id
                  AND school_target.status IN ('PUBLISHED', 'FINALIZED')
              ) AS target_value
            FROM public.dangky dk
            JOIN public.thisinh ts ON ts.thi_sinh_id = dk.thi_sinh_id
            WHERE dk.trang_thai <> 'HUY_DANG_KY'
              AND dk.ngay_dang_ky >= p.start_date
              AND dk.ngay_dang_ky < p.end_date
              AND (t.subject_type <> 'TRUONG' OR ts.school_id::text = t.subject_id)
          ) registrations
        )
        WHEN 'KPI_TR3' THEN (
          SELECT sum(c.paid_amount)::numeric * 100 / NULLIF(sum(c.earned_amount), 0)
          FROM public.kpi_commission_settlement c
          WHERE c.period_id = t.period_id
            AND c.partner_type = 'SCHOOL'
            AND (t.subject_type <> 'TRUONG' OR c.school_id::text = t.subject_id)
        )
        WHEN 'KPI_DN1' THEN (
          SELECT count(DISTINCT COALESCE(w.thi_sinh_id, w.thanh_toan_id))::numeric
          FROM public.dangkyweb w
          WHERE w.trang_thai_thanh_toan = 'THANH_TOAN_THANH_CONG'
            AND w.thoi_gian_thanh_toan >= p.start_date
            AND w.thoi_gian_thanh_toan < p.end_date
            AND w.doanh_nghiep_id IS NOT NULL
            AND (t.subject_type <> 'DOANH_NGHIEP' OR w.doanh_nghiep_id = t.subject_id)
        )
        WHEN 'KPI_DN2' THEN (
          SELECT sum(c.paid_amount)::numeric * 100 / NULLIF(sum(c.earned_amount), 0)
          FROM public.kpi_commission_settlement c
          WHERE c.period_id = t.period_id
            AND c.partner_type = 'BUSINESS'
            AND (t.subject_type <> 'DOANH_NGHIEP' OR c.business_id = t.subject_id)
        )
        WHEN 'KPI_TT1' THEN (
          SELECT avg(b.completion_pct)::numeric
          FROM public.kpi_sponsor_benefit b
          WHERE b.due_date >= p.start_date
            AND b.due_date < p.end_date
            AND (t.subject_type <> 'NHA_TAI_TRO' OR b.sponsor_id = t.subject_id)
        )
        WHEN 'KPI_TT2' THEN (
          SELECT COALESCE(sum(m.luot_hien_thi), 0)::numeric
          FROM public.truyenthong_taitro m
          WHERE m.ngay >= p.start_date
            AND m.ngay < p.end_date
            AND (t.subject_type <> 'NHA_TAI_TRO' OR m.doanh_nghiep_id = t.subject_id)
        )
        WHEN 'KPI_TT3' THEN (
          SELECT COALESCE(sum(r.amount_vnd), 0)::numeric
          FROM public.kpi_sponsor_receipt r
          WHERE r.accepted
            AND r.received_at >= p.start_date
            AND r.received_at < p.end_date
            AND (t.subject_type <> 'NHA_TAI_TRO' OR r.sponsor_id = t.subject_id)
        )
        ELSE NULL::numeric
      END AS value
  ) source_value
  WHERE t.period_id = p_period
    AND t.status IN ('PUBLISHED', 'FINALIZED')
    AND d.code NOT IN ('KPI_TS', 'KPI_DT', 'KPI_DN')
    AND COALESCE(source_value.value, latest_snapshot.value) IS NOT NULL
  ORDER BY d.group_code, d.name, t.subject_type, t.subject_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.fn_kpi_dashboard_readiness(p_period varchar)
RETURNS TABLE (
  kpi_id varchar,
  nhom varchar,
  ten_kpi varchar,
  ly_do varchar
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, public, auth, pg_temp
AS $$
BEGIN
  IF auth.uid() IS NULL OR NOT public.fn_current_user_can_view_kpi_dashboard() THEN
    RAISE EXCEPTION 'Bạn không có quyền xem trạng thái cấu hình KPI.' USING ERRCODE = '42501';
  END IF;

  IF p_period IS NULL OR p_period !~ '^[0-9]{4}-Q[1-4]$' THEN
    RAISE EXCEPTION 'Kỳ KPI không hợp lệ.';
  END IF;

  RETURN QUERY
  WITH legacy_progress AS (
    SELECT * FROM public.fn_kpi_tongquan_tien_do(p_period)
  ),
  extended_progress AS (
    SELECT * FROM public.fn_kpi_dashboard_snapshot_progress(p_period)
  ),
  readiness AS (
    SELECT
      d.code,
      d.group_code,
      d.name,
      CASE
        WHEN d.code = 'KPI_TS' THEN EXISTS (
          SELECT 1 FROM public.kpi_muctieu k WHERE k.ky_bao_cao = p_period AND k.nhom = 'THI_SINH'
        )
        WHEN d.code = 'KPI_DT' THEN EXISTS (
          SELECT 1 FROM public.kpi_muctieu k WHERE k.ky_bao_cao = p_period AND k.nhom = 'DOANH_THU'
        )
        WHEN d.code = 'KPI_DN' THEN EXISTS (
          SELECT 1 FROM public.kpi_muctieu k WHERE k.ky_bao_cao = p_period AND k.nhom = 'DOANH_NGHIEP'
        )
        ELSE EXISTS (
          SELECT 1
          FROM public.kpi_target t
          WHERE t.kpi_code = d.code
            AND t.period_id = p_period
            AND t.status IN ('PUBLISHED', 'FINALIZED')
        )
      END AS has_target,
      CASE
        WHEN d.code = 'KPI_TS' THEN EXISTS (SELECT 1 FROM legacy_progress l WHERE l.nhom = 'THI_SINH')
        WHEN d.code = 'KPI_DT' THEN EXISTS (SELECT 1 FROM legacy_progress l WHERE l.nhom = 'DOANH_THU')
        WHEN d.code = 'KPI_DN' THEN EXISTS (SELECT 1 FROM legacy_progress l WHERE l.nhom = 'DOANH_NGHIEP')
        ELSE EXISTS (
          SELECT 1
          FROM extended_progress e
          WHERE e.kpi_id LIKE d.code || '_T%'
        )
      END AS has_value
    FROM public.kpi_definition d
    WHERE d.active
  )
  SELECT
    r.code,
    r.group_code,
    r.name,
    CASE
      WHEN NOT r.has_target THEN 'Chưa thiết lập mục tiêu'::varchar
      ELSE 'Chưa đủ dữ liệu nguồn trong kỳ'::varchar
    END
  FROM readiness r
  WHERE NOT r.has_target OR NOT r.has_value
  ORDER BY r.group_code, r.name;
END;
$$;

REVOKE ALL ON FUNCTION public.fn_kpi_set_target(varchar, varchar, varchar, varchar, numeric, varchar) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_kpi_set_target(varchar, varchar, varchar, varchar, numeric, varchar) TO authenticated;
REVOKE ALL ON FUNCTION public.fn_kpi_dashboard_snapshot_progress(varchar) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_kpi_dashboard_snapshot_progress(varchar) TO authenticated;
REVOKE ALL ON FUNCTION public.fn_kpi_dashboard_readiness(varchar) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_kpi_dashboard_readiness(varchar) TO authenticated;

NOTIFY pgrst, 'reload schema';
