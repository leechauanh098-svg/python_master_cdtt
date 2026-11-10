CREATE TABLE IF NOT EXISTS public.dm_tinh_thanh_vung (
  tinh_thanh varchar(100) PRIMARY KEY,
  vung varchar(20) NOT NULL CHECK (vung IN ('MIEN_BAC', 'MIEN_TRUNG', 'MIEN_NAM'))
);

INSERT INTO public.dm_tinh_thanh_vung (tinh_thanh, vung) VALUES
  ('An Giang', 'MIEN_NAM'), ('Bắc Ninh', 'MIEN_BAC'), ('Cà Mau', 'MIEN_NAM'),
  ('Cao Bằng', 'MIEN_BAC'), ('Cần Thơ', 'MIEN_NAM'), ('Đà Nẵng', 'MIEN_TRUNG'),
  ('Đắk Lắk', 'MIEN_TRUNG'), ('Điện Biên', 'MIEN_BAC'), ('Đồng Nai', 'MIEN_NAM'),
  ('Đồng Tháp', 'MIEN_NAM'), ('Gia Lai', 'MIEN_TRUNG'), ('Hà Nội', 'MIEN_BAC'),
  ('Hà Tĩnh', 'MIEN_TRUNG'), ('Hải Phòng', 'MIEN_BAC'), ('Huế', 'MIEN_TRUNG'),
  ('Thành phố Huế', 'MIEN_TRUNG'), ('Thừa Thiên-Huế', 'MIEN_TRUNG'),
  ('Thừa Thiên Huế', 'MIEN_TRUNG'), ('Hưng Yên', 'MIEN_BAC'),
  ('Khánh Hòa', 'MIEN_TRUNG'), ('Lai Châu', 'MIEN_BAC'), ('Lạng Sơn', 'MIEN_BAC'),
  ('Lào Cai', 'MIEN_BAC'), ('Lâm Đồng', 'MIEN_TRUNG'), ('Nghệ An', 'MIEN_TRUNG'),
  ('Ninh Bình', 'MIEN_BAC'), ('Phú Thọ', 'MIEN_BAC'), ('Quảng Ngãi', 'MIEN_TRUNG'),
  ('Quảng Ninh', 'MIEN_BAC'), ('Quảng Trị', 'MIEN_TRUNG'), ('Sơn La', 'MIEN_BAC'),
  ('Tây Ninh', 'MIEN_NAM'), ('Thái Nguyên', 'MIEN_BAC'), ('Thanh Hóa', 'MIEN_TRUNG'),
  ('Thành phố Hồ Chí Minh', 'MIEN_NAM'), ('TP. Hồ Chí Minh', 'MIEN_NAM'),
  ('Hồ Chí Minh', 'MIEN_NAM'), ('Tuyên Quang', 'MIEN_BAC'), ('Vĩnh Long', 'MIEN_NAM'),
  ('Hà Giang', 'MIEN_BAC'), ('Yên Bái', 'MIEN_BAC'), ('Bắc Kạn', 'MIEN_BAC'),
  ('Vĩnh Phúc', 'MIEN_BAC'), ('Bắc Giang', 'MIEN_BAC'), ('Hải Dương', 'MIEN_BAC'),
  ('Hà Nam', 'MIEN_BAC'), ('Nam Định', 'MIEN_BAC'), ('Thái Bình', 'MIEN_BAC'),
  ('Hòa Bình', 'MIEN_BAC'), ('Quảng Bình', 'MIEN_TRUNG'), ('Quảng Nam', 'MIEN_TRUNG'),
  ('Bình Định', 'MIEN_TRUNG'), ('Phú Yên', 'MIEN_TRUNG'), ('Ninh Thuận', 'MIEN_TRUNG'),
  ('Bình Thuận', 'MIEN_TRUNG'), ('Kon Tum', 'MIEN_TRUNG'), ('Đắk Nông', 'MIEN_TRUNG'),
  ('Bình Phước', 'MIEN_NAM'), ('Bình Dương', 'MIEN_NAM'), ('Bà Rịa - Vũng Tàu', 'MIEN_NAM'),
  ('Long An', 'MIEN_NAM'), ('Tiền Giang', 'MIEN_NAM'), ('Bến Tre', 'MIEN_NAM'),
  ('Trà Vinh', 'MIEN_NAM'), ('Kiên Giang', 'MIEN_NAM'), ('Hậu Giang', 'MIEN_NAM'),
  ('Sóc Trăng', 'MIEN_NAM'), ('Bạc Liêu', 'MIEN_NAM')
ON CONFLICT (tinh_thanh) DO NOTHING;

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
