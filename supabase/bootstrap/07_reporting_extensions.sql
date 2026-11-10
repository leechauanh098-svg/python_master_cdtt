-- =============================================================================
-- Source: supabase/migrations/20261110000000_reporting_gaps.sql
-- =============================================================================

CREATE TABLE IF NOT EXISTS public.dm_tinh_thanh_vung (
  tinh_thanh varchar(100) PRIMARY KEY,
  vung varchar(20) NOT NULL CHECK (vung IN ('MIEN_BAC', 'MIEN_TRUNG', 'MIEN_NAM'))
);

ALTER TABLE public.baitap
  ADD COLUMN IF NOT EXISTS loai_bai_tap varchar(20) NOT NULL DEFAULT 'CUOC_THI';

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_catalog.pg_constraint
    WHERE conrelid = 'public.baitap'::regclass AND conname = 'chk_baitap_loai'
  ) THEN
    ALTER TABLE public.baitap
      ADD CONSTRAINT chk_baitap_loai CHECK (loai_bai_tap IN ('LUYEN_TAP', 'CUOC_THI'));
  END IF;
END;
$$;

CREATE OR REPLACE FUNCTION public.fn_report_revenue_by_region(p_ky varchar DEFAULT NULL)
RETURNS TABLE (vung text, doanh_thu numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = pg_catalog, public, auth, pg_temp
AS $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.fn_current_user_report_permissions()
    WHERE permission_id = 'BAO_CAO_DOANH_THU'
  ) THEN
    RAISE EXCEPTION 'Tài khoản không có quyền xem báo cáo doanh thu.';
  END IF;

  RETURN QUERY
  WITH period AS (SELECT tu, den FROM public.fn_ky_bao_cao(p_ky))
  SELECT CASE dm.vung
           WHEN 'MIEN_BAC' THEN 'Miền Bắc'
           WHEN 'MIEN_TRUNG' THEN 'Miền Trung'
           WHEN 'MIEN_NAM' THEN 'Miền Nam'
           ELSE 'Chưa xác định'
         END::text,
         COALESCE(sum(g.so_tien), 0)::numeric
  FROM public.fn_kpi_gd((SELECT tu FROM period), (SELECT den FROM period)) g
  LEFT JOIN public.dm_tinh_thanh_vung dm
    ON lower(unaccent(btrim(dm.tinh_thanh))) = lower(unaccent(btrim(g.tinh_thanh)))
  WHERE g.trang_thai_thanh_toan = 'THANH_TOAN_THANH_CONG'
  GROUP BY dm.vung
  ORDER BY dm.vung;
END;
$$;

CREATE OR REPLACE FUNCTION public.fn_report_practice_top15(p_ky varchar DEFAULT NULL)
RETURNS TABLE (
  hang bigint,
  thi_sinh_id varchar,
  ho_ten varchar,
  truong_hoc varchar,
  so_bai_hoan_thanh bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = pg_catalog, public, auth, pg_temp
AS $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.fn_current_user_report_permissions()
    WHERE permission_id = 'BAO_CAO_HOC_VU'
  ) THEN
    RAISE EXCEPTION 'Tài khoản không có quyền xem báo cáo học vụ.';
  END IF;

  RETURN QUERY
  WITH period AS (SELECT tu, den FROM public.fn_ky_bao_cao(p_ky)),
  completed AS (
    SELECT bn.thi_sinh_id, count(DISTINCT bn.bai_tap_id)::bigint AS total
    FROM public.bainop bn
    JOIN public.baitap bt ON bt.bai_tap_id = bn.bai_tap_id
    CROSS JOIN period
    WHERE bt.loai_bai_tap = 'LUYEN_TAP'
      AND bn.trang_thai IN ('DA_NOP', 'DA_CHAM_DIEM')
      AND bn.thoi_gian_nop >= period.tu AND bn.thoi_gian_nop < period.den
    GROUP BY bn.thi_sinh_id
    HAVING count(DISTINCT bn.bai_tap_id) > 30
  ),
  ranked AS (
    SELECT row_number() OVER (ORDER BY c.total DESC, ts.thi_sinh_id)::bigint AS place,
           ts.thi_sinh_id, ts.ho_ten, ts.truong_hoc, c.total
    FROM completed c
    JOIN public.thisinh ts ON ts.thi_sinh_id = c.thi_sinh_id
  )
  SELECT r.place, r.thi_sinh_id, r.ho_ten, r.truong_hoc, r.total
  FROM ranked r
  WHERE r.place <= 15
  ORDER BY r.place;
END;
$$;

CREATE OR REPLACE FUNCTION public.fn_report_lead_pipeline(p_ky varchar DEFAULT NULL)
RETURNS TABLE (
  nguon text,
  trang_thai_lead text,
  trang_thai_ho_so text,
  trang_thai_thanh_toan text,
  so_luong bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = pg_catalog, public, auth, pg_temp
AS $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.fn_current_user_report_permissions()
    WHERE permission_id = 'BAO_CAO_TONG_QUAN'
  ) THEN
    RAISE EXCEPTION 'Tài khoản không có quyền xem báo cáo tổng quan.';
  END IF;

  RETURN QUERY
  WITH period AS (SELECT tu, den FROM public.fn_ky_bao_cao(p_ky)),
  raw AS (
    SELECT 'Google Form'::text AS source,
           COALESCE(NULLIF(regexp_replace(b.sdt, '[^0-9]', '', 'g'), ''), NULLIF(lower(b.email), '')) AS contact_key,
           b.trang_thai_ghi_danh::text AS lead_status,
           COALESCE(ts.trang_thai_ho_so, 'CHUA_CO_HO_SO')::text AS profile_status,
           COALESCE(tt.trang_thai_thanh_toan, 'CHUA_THANH_TOAN')::text AS payment_status,
           b.dau_thoi_gian AS event_at
    FROM public.bieumau b
    CROSS JOIN period p
    LEFT JOIN public.thisinh ts
      ON ts.thi_sinh_id = b.thi_sinh_id OR lower(ts.email) = lower(b.email)
      OR regexp_replace(ts.sdt, '[^0-9]', '', 'g') = regexp_replace(b.sdt, '[^0-9]', '', 'g')
    LEFT JOIN LATERAL (
      SELECT t.trang_thai_thanh_toan FROM public.thanhtoan t
      WHERE t.thi_sinh_id = ts.thi_sinh_id
      ORDER BY t.thoi_gian_thanh_toan DESC LIMIT 1
    ) tt ON true
    WHERE b.dau_thoi_gian >= p.tu AND b.dau_thoi_gian < p.den

    UNION ALL

    SELECT 'Lead Ads'::text,
           COALESCE(NULLIF(regexp_replace(q.so_dien_thoai, '[^0-9]', '', 'g'), ''),
                    NULLIF(lower(q.email), ''),
                    NULLIF(regexp_replace(b.sdt, '[^0-9]', '', 'g'), ''),
                    NULLIF(lower(b.email), '')),
           q.trang_thai_khach_hang::text,
           COALESCE(ts.trang_thai_ho_so, 'CHUA_CO_HO_SO')::text,
           COALESCE(tt.trang_thai_thanh_toan, 'CHUA_THANH_TOAN')::text,
           q.created_at
    FROM public.quangcao q
    CROSS JOIN period p
    LEFT JOIN public.bieumau b ON b.bieu_mau_log = q.bieu_mau_log
    LEFT JOIN public.thisinh ts
      ON ts.thi_sinh_id = q.thi_sinh_id
      OR lower(ts.email) = lower(COALESCE(q.email, b.email))
      OR regexp_replace(ts.sdt, '[^0-9]', '', 'g')
         = regexp_replace(COALESCE(q.so_dien_thoai, b.sdt), '[^0-9]', '', 'g')
    LEFT JOIN LATERAL (
      SELECT t.trang_thai_thanh_toan FROM public.thanhtoan t
      WHERE t.thi_sinh_id = ts.thi_sinh_id
      ORDER BY t.thoi_gian_thanh_toan DESC LIMIT 1
    ) tt ON true
    WHERE q.created_at >= p.tu AND q.created_at < p.den

    UNION ALL

    SELECT 'Web'::text,
           COALESCE(NULLIF(regexp_replace(w.sdt, '[^0-9]', '', 'g'), ''), NULLIF(lower(w.email), '')),
           CASE WHEN w.trang_thai_thanh_toan = 'THANH_TOAN_THANH_CONG'
                THEN 'DA_THANH_TOAN' ELSE 'DA_DANG_KY' END,
           COALESCE(ts.trang_thai_ho_so, 'CHUA_CO_HO_SO')::text,
           w.trang_thai_thanh_toan::text,
           w.thoi_gian_thanh_toan
    FROM public.dangkyweb w
    CROSS JOIN period p
    LEFT JOIN public.thisinh ts ON ts.thi_sinh_id = w.thi_sinh_id
    WHERE w.thoi_gian_thanh_toan >= p.tu AND w.thoi_gian_thanh_toan < p.den
  ),
  source_rollup AS (
    SELECT contact_key, string_agg(DISTINCT source, ', ' ORDER BY source) AS sources
    FROM raw WHERE contact_key IS NOT NULL GROUP BY contact_key
  ),
  latest_status AS (
    SELECT DISTINCT ON (contact_key) contact_key, lead_status, profile_status, payment_status
    FROM raw WHERE contact_key IS NOT NULL
    ORDER BY contact_key, event_at DESC, source
  )
  SELECT s.sources, latest.lead_status, latest.profile_status, latest.payment_status, count(*)::bigint
  FROM source_rollup s
  JOIN latest_status latest USING (contact_key)
  GROUP BY s.sources, latest.lead_status, latest.profile_status, latest.payment_status
  ORDER BY s.sources, latest.lead_status, latest.profile_status, latest.payment_status;
END;
$$;

CREATE OR REPLACE FUNCTION public.fn_export_school_reconciliation(p_ky varchar DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = pg_catalog, public, auth, pg_temp
AS $$
DECLARE
  school_sheet jsonb;
  student_sheet jsonb;
  payment_sheet jsonb;
  period record;
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.fn_current_user_report_permissions()
    WHERE permission_id IN ('BAO_CAO_THISINH', 'BAO_CAO_TONG_QUAN')
  ) OR NOT EXISTS (
    SELECT 1 FROM public.fn_current_user_report_permissions()
    WHERE permission_id IN ('BAO_CAO_DOANH_THU', 'BAO_CAO_TONG_QUAN')
  ) THEN
    RAISE EXCEPTION 'Cần quyền báo cáo thí sinh và doanh thu để xuất đối soát trường học.';
  END IF;

  SELECT * INTO period FROM public.fn_ky_bao_cao(p_ky);

  WITH school_students AS (
    SELECT COALESCE(ts.truong_hoc, 'Chưa xác định') AS truong_hoc,
           count(DISTINCT ts.thi_sinh_id)::bigint AS so_thi_sinh,
           (count(DISTINCT ts.thi_sinh_id) FILTER (WHERE EXISTS (
             SELECT 1 FROM public.dangky dk
             WHERE dk.thi_sinh_id = ts.thi_sinh_id AND dk.trang_thai = 'THANH_CONG'
           )))::bigint AS so_da_dang_ky,
           (count(DISTINCT ts.thi_sinh_id) FILTER (WHERE ts.trang_thai_ho_so = 'DA_DUYET'))::bigint AS so_ho_so_duyet
    FROM public.thisinh ts
    WHERE ts.created_at >= period.tu AND ts.created_at < period.den
    GROUP BY COALESCE(ts.truong_hoc, 'Chưa xác định')
  ),
  school_payments AS (
    SELECT COALESCE(g.truong_hoc, 'Chưa xác định') AS truong_hoc,
           (count(*) FILTER (WHERE g.trang_thai_thanh_toan = 'THANH_TOAN_THANH_CONG'))::bigint AS so_giao_dich_thanh_cong,
           COALESCE((sum(g.so_tien) FILTER (
             WHERE g.trang_thai_thanh_toan = 'THANH_TOAN_THANH_CONG'
           )), 0)::numeric AS tong_thu
    FROM public.vw_giao_dich_le_phi g
    WHERE g.thoi_gian_thanh_toan >= period.tu AND g.thoi_gian_thanh_toan < period.den
    GROUP BY COALESCE(g.truong_hoc, 'Chưa xác định')
  )
  SELECT COALESCE(jsonb_agg(to_jsonb(s) ORDER BY s.truong_hoc), '[]'::jsonb)
  INTO school_sheet
  FROM (
    SELECT ss.*, COALESCE(sp.so_giao_dich_thanh_cong, 0) AS so_giao_dich_thanh_cong,
           COALESCE(sp.tong_thu, 0) AS tong_thu
    FROM school_students ss LEFT JOIN school_payments sp USING (truong_hoc)
  ) s;

  SELECT COALESCE(jsonb_agg(to_jsonb(s) ORDER BY s.truong_hoc, s.thi_sinh_id), '[]'::jsonb)
  INTO student_sheet
  FROM (
    SELECT COALESCE(ts.truong_hoc, 'Chưa xác định') AS truong_hoc,
           ts.thi_sinh_id, ts.ho_ten,
           CASE WHEN ts.email IS NULL THEN NULL
                ELSE left(ts.email, 1) || '***' || substring(ts.email FROM position('@' IN ts.email)) END AS email_da_an,
           CASE WHEN ts.sdt IS NULL THEN NULL
                ELSE left(ts.sdt, 2) || '******' || right(ts.sdt, 2) END AS sdt_da_an,
           ts.trang_thai_ho_so
    FROM public.thisinh ts
    WHERE ts.created_at >= period.tu AND ts.created_at < period.den
  ) s;

  SELECT COALESCE(jsonb_agg(to_jsonb(p) ORDER BY p.truong_hoc, p.thoi_gian_thanh_toan), '[]'::jsonb)
  INTO payment_sheet
  FROM (
    SELECT COALESCE(g.truong_hoc, 'Chưa xác định') AS truong_hoc,
           CASE WHEN length(g.giao_dich_id) > 4
                THEN repeat('*', length(g.giao_dich_id) - 4) || right(g.giao_dich_id, 4)
                ELSE g.giao_dich_id END AS giao_dich_da_an,
           g.thoi_gian_thanh_toan, g.so_tien, g.trang_thai_thanh_toan AS trang_thai
    FROM public.vw_giao_dich_le_phi g
    WHERE g.thoi_gian_thanh_toan >= period.tu AND g.thoi_gian_thanh_toan < period.den
  ) p;

  RETURN jsonb_build_object(
    'truong_hoc', school_sheet,
    'thi_sinh', student_sheet,
    'doi_soat_phi', payment_sheet
  );
END;
$$;

REVOKE ALL ON FUNCTION public.fn_report_revenue_by_region(varchar) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.fn_report_practice_top15(varchar) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.fn_report_lead_pipeline(varchar) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.fn_export_school_reconciliation(varchar) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_report_revenue_by_region(varchar) TO authenticated;
GRANT EXECUTE ON FUNCTION public.fn_report_practice_top15(varchar) TO authenticated;
GRANT EXECUTE ON FUNCTION public.fn_report_lead_pipeline(varchar) TO authenticated;
GRANT EXECUTE ON FUNCTION public.fn_export_school_reconciliation(varchar) TO authenticated;

NOTIFY pgrst, 'reload schema';

-- =============================================================================
-- Source: supabase/migrations/20261110000200_knowledge_document_storage.sql
-- =============================================================================

CREATE POLICY "Active employees can read knowledge documents"
ON storage.objects
FOR SELECT
TO authenticated
USING (
  bucket_id = 'knowledge-documents'
  AND EXISTS (
    SELECT 1
    FROM public.nhanvien nv
    WHERE lower(nv.email) = lower(auth.jwt() ->> 'email')
      AND nv.trang_thai = 'ACTIVE'
  )
);

CREATE POLICY "Active employees can upload their knowledge documents"
ON storage.objects
FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'knowledge-documents'
  AND (storage.foldername(name))[1] = auth.uid()::text
  AND EXISTS (
    SELECT 1
    FROM public.nhanvien nv
    WHERE lower(nv.email) = lower(auth.jwt() ->> 'email')
      AND nv.trang_thai = 'ACTIVE'
  )
);

CREATE POLICY "Employees can remove their own knowledge documents"
ON storage.objects
FOR DELETE
TO authenticated
USING (
  bucket_id = 'knowledge-documents'
  AND (storage.foldername(name))[1] = auth.uid()::text
  AND EXISTS (
    SELECT 1
    FROM public.nhanvien nv
    WHERE lower(nv.email) = lower(auth.jwt() ->> 'email')
      AND nv.trang_thai = 'ACTIVE'
  )
);

-- =============================================================================
-- Source: supabase/migrations/20261110000300_company_kpi_target.sql
-- =============================================================================

UPDATE public.kpi_muctieu
SET muc_tieu = 30
WHERE kpi_id = 'KPI_DN_2026Q3'
  AND muc_tieu IS DISTINCT FROM 30;

-- =============================================================================
-- Source: supabase/migrations/20261110000400_report_permissions_grant.sql
-- =============================================================================

REVOKE ALL ON FUNCTION public.fn_current_user_report_permissions() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_current_user_report_permissions() TO authenticated;

REVOKE ALL ON FUNCTION public.fn_bao_cao_du_lieu(character varying, character varying) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_bao_cao_du_lieu(character varying, character varying) TO authenticated;

REVOKE ALL ON FUNCTION public.fn_report_lead_pipeline(character varying) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_report_lead_pipeline(character varying) TO authenticated;

REVOKE ALL ON FUNCTION public.fn_report_revenue_by_region(character varying) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_report_revenue_by_region(character varying) TO authenticated;

REVOKE ALL ON FUNCTION public.fn_report_practice_top15(character varying) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_report_practice_top15(character varying) TO authenticated;

REVOKE ALL ON FUNCTION public.fn_export_school_reconciliation(character varying) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_export_school_reconciliation(character varying) TO authenticated;

-- =============================================================================
-- Source: supabase/migrations/20261110000500_registration_peak_trend.sql
-- =============================================================================

CREATE OR REPLACE FUNCTION public.fn_report_registration_peak_trend(p_ky varchar DEFAULT NULL)
RETURNS TABLE (ngay date, so_dang_ky bigint)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, public, auth, pg_temp
AS $$
DECLARE
  v_tu date;
  v_den date;
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM public.fn_current_user_report_permissions()
    WHERE permission_id = 'BAO_CAO_TONG_QUAN'
  ) THEN
    RAISE EXCEPTION 'Tài khoản không có quyền xem báo cáo tổng quan.';
  END IF;

  SELECT r.tu, LEAST(r.den - 1, CURRENT_DATE)
  INTO v_tu, v_den
  FROM public.fn_ky_bao_cao(p_ky) r;

  IF v_tu IS NULL OR v_den < v_tu THEN
    RETURN;
  END IF;

  RETURN QUERY
  WITH days AS (
    SELECT generated.day::date AS ngay
    FROM generate_series(v_tu::timestamp, v_den::timestamp, interval '1 day') generated(day)
  )
  SELECT days.ngay, count(DISTINCT dk.thi_sinh_id)::bigint
  FROM days
  LEFT JOIN public.dangky dk ON dk.ngay_dang_ky::date = days.ngay
  GROUP BY days.ngay
  ORDER BY days.ngay;
END;
$$;

REVOKE ALL ON FUNCTION public.fn_report_registration_peak_trend(character varying) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_report_registration_peak_trend(character varying) TO authenticated;

NOTIFY pgrst, 'reload schema';

-- =============================================================================
-- Source: supabase/migrations/20261110000600_fix_school_excellence_rate.sql
-- =============================================================================

CREATE OR REPLACE FUNCTION public.fn_kpi_thisinh_truong_bang(
  p_ky varchar DEFAULT NULL,
  p_nguong_xuat_sac_pct numeric DEFAULT 80
)
RETURNS TABLE (
  truong_hoc varchar,
  bang_dau varchar,
  so_thi_sinh bigint,
  ty_le_xuat_sac_pct numeric
)
LANGUAGE sql
STABLE
AS $$
  WITH r AS (
    SELECT * FROM public.fn_ky_bao_cao(p_ky)
  ),
  scores AS (
    SELECT b.thi_sinh_id, max(b.diem_pct) AS diem_pct
    FROM public.vw_bainop_diem_pct b
    CROSS JOIN r
    WHERE b.trang_thai = 'DA_CHAM_DIEM'
      AND b.thoi_gian_nop >= r.tu
      AND b.thoi_gian_nop < r.den
      AND b.diem_pct IS NOT NULL
    GROUP BY b.thi_sinh_id
  )
  SELECT
    ts.truong_hoc,
    ts.bang_dau,
    count(DISTINCT ts.thi_sinh_id),
    COALESCE(
      (
        count(DISTINCT CASE
          WHEN scores.diem_pct >= p_nguong_xuat_sac_pct THEN ts.thi_sinh_id
        END) * 100.0
        / NULLIF(count(DISTINCT scores.thi_sinh_id), 0)
      )::numeric(5,2),
      0::numeric
    )
  FROM r
  CROSS JOIN public.thisinh ts
  LEFT JOIN scores ON scores.thi_sinh_id = ts.thi_sinh_id
  WHERE ts.truong_hoc IS NOT NULL
  GROUP BY ts.truong_hoc, ts.bang_dau
  ORDER BY count(DISTINCT ts.thi_sinh_id) DESC;
$$;

NOTIFY pgrst, 'reload schema';

-- =============================================================================
-- Source: supabase/migrations/20261110000700_recalculate_school_excellence_rate.sql
-- =============================================================================

CREATE OR REPLACE FUNCTION public.fn_kpi_thisinh_truong_bang(
  p_ky varchar DEFAULT NULL,
  p_nguong_xuat_sac_pct numeric DEFAULT 80
)
RETURNS TABLE (
  truong_hoc varchar,
  bang_dau varchar,
  so_thi_sinh bigint,
  ty_le_xuat_sac_pct numeric
)
LANGUAGE sql
STABLE
AS $$
  WITH period AS (
    SELECT r.tu, r.den
    FROM public.fn_ky_bao_cao(p_ky) r
  ),
  graded_submissions AS (
    SELECT
      bn.thi_sinh_id,
      (
        bn.tong_diem * 100.0
        / NULLIF(question_totals.diem_toi_da, 0)
      )::numeric(6,2) AS diem_pct
    FROM public.bainop bn
    JOIN public.thisinh ts ON ts.thi_sinh_id = bn.thi_sinh_id
    CROSS JOIN period
    CROSS JOIN LATERAL (
      SELECT sum(ch.diem_toi_da) AS diem_toi_da
      FROM public.cauhoi ch
      WHERE ch.bai_tap_id = bn.bai_tap_id
    ) question_totals
    WHERE bn.trang_thai IN ('DA_NOP', 'DA_CHAM_DIEM')
      AND bn.tong_diem IS NOT NULL
      AND ts.truong_hoc IS NOT NULL
      AND COALESCE(bn.thoi_gian_nop, bn.updated_at, bn.created_at) >= period.tu
      AND COALESCE(bn.thoi_gian_nop, bn.updated_at, bn.created_at) < period.den
  ),
  best_score AS (
    SELECT graded_submissions.thi_sinh_id, max(graded_submissions.diem_pct) AS diem_pct
    FROM graded_submissions
    WHERE graded_submissions.diem_pct IS NOT NULL
    GROUP BY graded_submissions.thi_sinh_id
  )
  SELECT
    ts.truong_hoc,
    ts.bang_dau,
    count(DISTINCT ts.thi_sinh_id)::bigint,
    (
      count(DISTINCT CASE
        WHEN best_score.diem_pct >= p_nguong_xuat_sac_pct THEN ts.thi_sinh_id
      END) * 100.0
      / NULLIF(count(DISTINCT best_score.thi_sinh_id), 0)
    )::numeric(5,2)
  FROM public.thisinh ts
  LEFT JOIN best_score ON best_score.thi_sinh_id = ts.thi_sinh_id
  WHERE ts.truong_hoc IS NOT NULL
  GROUP BY ts.truong_hoc, ts.bang_dau
  ORDER BY count(DISTINCT ts.thi_sinh_id) DESC;
$$;

NOTIFY pgrst, 'reload schema';

