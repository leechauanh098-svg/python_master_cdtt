/* ================================================================
   004_reporting.sql
   ================================================================ */

/* ================================================================
   MODULE 1. DASHBOARD
   ================================================================ */
CREATE OR REPLACE FUNCTION fn_dashboard_card(p_so_ngay int DEFAULT 200)
RETURNS TABLE (tong_luot_dang_ky bigint, tong_luot_thanh_toan bigint, ty_le_chuyen_doi_thanh_toan numeric,
               doanh_thu_tam_tinh numeric, tong_lead_can_cham_soc_lai bigint, target_gap bigint)
LANGUAGE sql STABLE AS $$
  WITH p AS (SELECT CURRENT_DATE AS d, CURRENT_DATE - p_so_ngay AS t),
  dk  AS (SELECT count(DISTINCT thi_sinh_id) AS n FROM dangky, p WHERE ngay_dang_ky >= p.t AND ngay_dang_ky < p.d + 1),
  tc  AS (SELECT count(*) AS n FROM dangky, p WHERE ngay_dang_ky >= p.t AND ngay_dang_ky < p.d + 1 AND trang_thai = 'THANH_CONG'),
  dt  AS (SELECT COALESCE(sum(so_tien), 0) AS n FROM thanhtoan, p
          WHERE thoi_gian_thanh_toan >= p.t AND thoi_gian_thanh_toan < p.d + 1 AND trang_thai_thanh_toan = 'THANH_TOAN_THANH_CONG'),
  ld  AS (SELECT count(*) AS n FROM quangcao, p WHERE created_at >= p.t AND created_at < p.d + 1 AND trang_thai_khach_hang IN ('MOI','DANG_LIEN_HE')),
  dkp AS (SELECT count(DISTINCT thi_sinh_id) AS n FROM dangky, p WHERE ngay_dang_ky >= p.t - 16 AND ngay_dang_ky < p.t)
  SELECT dk.n, tc.n, (CASE WHEN dk.n = 0 THEN 0 ELSE tc.n * 100.0 / dk.n END)::numeric(10,2), dt.n, ld.n, dk.n - dkp.n
  FROM dk, tc, dt, ld, dkp $$;

SELECT * FROM fn_dashboard_card();

CREATE OR REPLACE FUNCTION fn_dashboard_xu_huong_16_ngay()
RETURNS TABLE (ngay date, so_luot_dang_ky bigint) LANGUAGE sql STABLE AS $$
  SELECT (CURRENT_DATE - 15 + g) AS ngay, count(dk.dang_ky_id)
  FROM generate_series(0, 15) g
  LEFT JOIN dangky dk ON dk.ngay_dang_ky::date = (CURRENT_DATE - 15 + g)
  GROUP BY g ORDER BY g $$;

-- Tiếp cận (khóa liên hệ duy nhất) từ 5 nguồn
CREATE OR REPLACE FUNCTION fn_tiep_can(p_tu date, p_den date) RETURNS TABLE (lien_he_key text) LANGUAGE sql STABLE AS $$
  WITH raw AS (
    SELECT qc.so_dien_thoai::text AS sdt, lower(qc.email)::text AS email
      FROM quangcao qc JOIN bieumau bm ON bm.bieu_mau_log = qc.bieu_mau_log
      WHERE bm.dau_thoi_gian >= p_tu AND bm.dau_thoi_gian < p_den
    UNION ALL SELECT sdt::text, lower(email)::text FROM bieumau WHERE dau_thoi_gian >= p_tu AND dau_thoi_gian < p_den
    UNION ALL SELECT sdt::text, lower(email)::text FROM thisinh WHERE created_at >= p_tu AND created_at < p_den
    UNION ALL SELECT sdt::text, lower(email)::text FROM dangkyweb WHERE thoi_gian_thanh_toan >= p_tu AND thoi_gian_thanh_toan < p_den
    UNION ALL SELECT ts.sdt::text, lower(ts.email)::text FROM qna q JOIN thisinh ts ON ts.thi_sinh_id = q.thi_sinh_id
      WHERE q.thoi_gian >= p_tu AND q.thoi_gian < p_den)
  SELECT DISTINCT COALESCE(NULLIF(sdt, ''), NULLIF(email, '')) FROM raw
  WHERE COALESCE(NULLIF(sdt, ''), NULLIF(email, '')) IS NOT NULL $$;

CREATE OR REPLACE FUNCTION fn_dashboard_pheu_chuyen_doi_web(p_tu date DEFAULT NULL, p_den date DEFAULT NULL)
RETURNS TABLE (tu_ngay date, den_ngay date, tiep_can bigint, dang_ky bigint, tham_gia bigint, ty_le_dang_ky numeric, ty_le_tham_gia numeric)
LANGUAGE sql STABLE AS $$
  WITH r AS (SELECT COALESCE(p_den, CURRENT_DATE) AS den),
  p AS (SELECT COALESCE(p_tu, r.den - 15) AS tu, r.den FROM r),
  d AS (
    SELECT p.tu, p.den,
      (SELECT count(*) FROM fn_tiep_can(p.tu, p.den + 1)) AS tiep_can,
      (SELECT count(DISTINCT dk.thi_sinh_id) FROM dangky dk JOIN cuocthi ct ON ct.cuoc_thi_id = dk.cuoc_thi_id
        WHERE dk.ngay_dang_ky >= p.tu AND dk.ngay_dang_ky < p.den + 1 AND dk.ngay_dang_ky <= ct.han_dang_ky) AS dang_ky,
      (SELECT count(*) FROM dangky dk JOIN cuocthi ct ON ct.cuoc_thi_id = dk.cuoc_thi_id
        WHERE dk.ngay_dang_ky >= p.tu AND dk.ngay_dang_ky < p.den + 1 AND dk.trang_thai = 'THANH_CONG'
          AND dk.ngay_dang_ky <= ct.han_dang_ky) AS tham_gia
    FROM p)
  SELECT d.tu, d.den, d.tiep_can, d.dang_ky, d.tham_gia,
         (CASE WHEN d.tiep_can = 0 THEN 0 ELSE d.dang_ky * 100.0 / d.tiep_can END)::numeric(10,2),
         (CASE WHEN d.tiep_can = 0 THEN 0 ELSE d.tham_gia * 100.0 / d.tiep_can END)::numeric(10,2)
  FROM d $$;

CREATE OR REPLACE FUNCTION fn_dashboard_pheu_3_tang_web(p_tu date DEFAULT NULL, p_den date DEFAULT NULL)
RETURNS TABLE (thu_tu int, giai_doan text, so_luong bigint, ty_le_so_voi_tiep_can numeric) LANGUAGE sql STABLE AS $$
  SELECT 1, 'TIẾP CẬN'::text, p.tiep_can, 100.00::numeric FROM fn_dashboard_pheu_chuyen_doi_web(p_tu, p_den) p
  UNION ALL SELECT 2, 'ĐĂNG KÝ'::text, p.dang_ky, p.ty_le_dang_ky FROM fn_dashboard_pheu_chuyen_doi_web(p_tu, p_den) p
  UNION ALL SELECT 3, 'THAM GIA'::text, p.tham_gia, p.ty_le_tham_gia FROM fn_dashboard_pheu_chuyen_doi_web(p_tu, p_den) p
  ORDER BY 1 $$;

CREATE OR REPLACE VIEW vw_dashboard_phan_bo_bang_thi AS
  WITH d AS (SELECT bang_dau, count(*) AS so_luong FROM thisinh WHERE bang_dau IN ('BANG_A','BANG_B') GROUP BY bang_dau),
  t AS (SELECT sum(so_luong) AS tong FROM d)
  SELECT d.bang_dau, d.so_luong, (CASE WHEN t.tong = 0 THEN 0 ELSE d.so_luong * 100.0 / t.tong END)::numeric(10,2) AS ty_le_phan_tram
  FROM d CROSS JOIN t ORDER BY d.bang_dau;

CREATE OR REPLACE VIEW vw_dashboard_phan_bo_nhom_tuoi AS
  WITH t AS (SELECT fn_tinh_tuoi_thi(ngay_sinh) AS tuoi FROM thisinh WHERE ngay_sinh IS NOT NULL),
  n AS (SELECT CASE WHEN tuoi < 15 THEN 'DƯỚI 15' WHEN tuoi BETWEEN 15 AND 17 THEN '15-17'
                    WHEN tuoi BETWEEN 18 AND 20 THEN '18-20' ELSE 'TRÊN 20' END AS nhom_tuoi,
               CASE WHEN tuoi < 15 THEN 1 WHEN tuoi BETWEEN 15 AND 17 THEN 2 WHEN tuoi BETWEEN 18 AND 20 THEN 3 ELSE 4 END AS thu_tu
        FROM t)
  SELECT nhom_tuoi, thu_tu, count(*) AS so_luong FROM n GROUP BY nhom_tuoi, thu_tu ORDER BY thu_tu;

/* ================================================================
   MODULE 2. QUẢN LÝ THÍ SINH
   ================================================================ */
CREATE OR REPLACE VIEW vw_thisinh_bieudo_trangthai AS
  WITH dm(thu_tu, trang_thai) AS (VALUES (1,'ĐÃ ĐÓNG PHÍ'),(2,'CHỜ HỒ SƠ'),(3,'ĐANG XÉT DUYỆT'),(4,'ĐÃ NỘP BÀI'),(5,'BỊ LOẠI')),
  pl AS (
    SELECT ts.thi_sinh_id,
      CASE
        WHEN ts.trang_thai_ho_so IN ('KHONG_HOP_LE','KHOA') THEN 'BỊ LOẠI'
        WHEN EXISTS (SELECT 1 FROM bainop bn WHERE bn.thi_sinh_id = ts.thi_sinh_id AND bn.trang_thai IN ('DA_NOP','DA_CHAM_DIEM','QUA_HAN_NOP')) THEN 'ĐÃ NỘP BÀI'
        WHEN EXISTS (SELECT 1 FROM dangky dk WHERE dk.thi_sinh_id = ts.thi_sinh_id AND dk.trang_thai = 'THANH_CONG')
             THEN CASE WHEN ts.trang_thai_ho_so = 'CHO_DUYET' THEN 'ĐANG XÉT DUYỆT' ELSE 'ĐÃ ĐÓNG PHÍ' END
        ELSE 'CHỜ HỒ SƠ' END AS trang_thai
    FROM thisinh ts),
  sl AS (SELECT trang_thai, count(*) AS so_luong FROM pl GROUP BY trang_thai),
  tong AS (SELECT COALESCE(sum(so_luong), 0) AS tong FROM sl)
  SELECT dm.thu_tu, dm.trang_thai, COALESCE(sl.so_luong, 0) AS so_luong,
         (CASE WHEN t.tong = 0 THEN 0 ELSE COALESCE(sl.so_luong, 0) * 100.0 / t.tong END)::numeric(10,2) AS ty_le_phan_tram
  FROM dm LEFT JOIN sl ON sl.trang_thai = dm.trang_thai CROSS JOIN tong t ORDER BY dm.thu_tu;

CREATE OR REPLACE VIEW vw_thisinh_bieudo_theo_truong AS
  SELECT truong_hoc, count(*) AS so_luong_thi_sinh FROM thisinh
  WHERE truong_hoc IS NOT NULL AND btrim(truong_hoc) <> '' GROUP BY truong_hoc ORDER BY so_luong_thi_sinh DESC, truong_hoc;

CREATE OR REPLACE FUNCTION fn_xuat_thisinh(
  p_thi_sinh_id varchar DEFAULT NULL, p_ho_ten varchar DEFAULT NULL, p_sdt varchar DEFAULT NULL, p_email varchar DEFAULT NULL,
  p_truong_hoc varchar DEFAULT NULL, p_cccd varchar DEFAULT NULL, p_trang_thai_ho_so varchar DEFAULT NULL,
  p_sale_phu_trach_id varchar DEFAULT NULL, p_bang_dau varchar DEFAULT NULL)
RETURNS TABLE (id varchar, ho_va_ten varchar, email varchar, so_dien_thoai varchar, ngay_sinh date, nam_sinh int, cccd varchar,
               dia_chi varchar, tinh_thanh varchar, truong_hoc varchar, bang_dau varchar, trang_thai_ho_so varchar,
               sale_phu_trach_id varchar, sale_phu_trach varchar) LANGUAGE sql STABLE AS $$
  SELECT ts.thi_sinh_id, ts.ho_ten, ts.email, ts.sdt, ts.ngay_sinh, extract(year FROM ts.ngay_sinh)::int, ts.cccd, ts.dia_chi,
         ts.tinh_thanh, ts.truong_hoc, ts.bang_dau, ts.trang_thai_ho_so, ts.sale_phu_trach_id, nv.ho_ten
  FROM thisinh ts LEFT JOIN nhanvien nv ON nv.nhan_vien_id = ts.sale_phu_trach_id
  WHERE (p_thi_sinh_id IS NULL OR p_thi_sinh_id = '' OR ts.thi_sinh_id ILIKE '%' || p_thi_sinh_id || '%')
    AND (p_ho_ten IS NULL OR p_ho_ten = '' OR ts.ho_ten ILIKE '%' || p_ho_ten || '%')
    AND (p_sdt IS NULL OR p_sdt = '' OR ts.sdt LIKE '%' || p_sdt || '%')
    AND (p_email IS NULL OR p_email = '' OR ts.email ILIKE '%' || p_email || '%')
    AND (p_truong_hoc IS NULL OR p_truong_hoc = '' OR ts.truong_hoc ILIKE '%' || p_truong_hoc || '%')
    AND (p_cccd IS NULL OR p_cccd = '' OR ts.cccd LIKE '%' || p_cccd || '%')
    AND (p_trang_thai_ho_so IS NULL OR p_trang_thai_ho_so = 'ALL' OR ts.trang_thai_ho_so = p_trang_thai_ho_so)
    AND (p_sale_phu_trach_id IS NULL OR p_sale_phu_trach_id = 'ALL' OR ts.sale_phu_trach_id = p_sale_phu_trach_id)
    AND (p_bang_dau IS NULL OR p_bang_dau = 'ALL' OR ts.bang_dau = p_bang_dau)
  ORDER BY ts.thi_sinh_id $$;

CREATE OR REPLACE FUNCTION fn_loc_thisinh(
  p_thi_sinh_id varchar DEFAULT NULL, p_ho_ten varchar DEFAULT NULL, p_nam_sinh int DEFAULT NULL, p_truong_hoc varchar DEFAULT NULL,
  p_trang_thai_ho_so varchar DEFAULT NULL, p_sale_phu_trach_id varchar DEFAULT NULL, p_bang_dau varchar DEFAULT NULL)
RETURNS TABLE (thi_sinh_id varchar, ho_ten varchar, email varchar, sdt varchar, nam_sinh int, truong_hoc varchar,
               trang_thai_ho_so varchar, bang_dau varchar, sale_phu_trach_id varchar, ten_sale_phu_trach varchar) LANGUAGE sql STABLE AS $$
  SELECT ts.thi_sinh_id, ts.ho_ten, ts.email, ts.sdt, extract(year FROM ts.ngay_sinh)::int, ts.truong_hoc,
         ts.trang_thai_ho_so, ts.bang_dau, ts.sale_phu_trach_id, nv.ho_ten
  FROM thisinh ts LEFT JOIN nhanvien nv ON nv.nhan_vien_id = ts.sale_phu_trach_id
  WHERE (p_thi_sinh_id IS NULL OR p_thi_sinh_id = '' OR ts.thi_sinh_id ILIKE '%' || p_thi_sinh_id || '%')
    AND (p_ho_ten IS NULL OR p_ho_ten = '' OR ts.ho_ten ILIKE '%' || p_ho_ten || '%')
    AND (p_nam_sinh IS NULL OR extract(year FROM ts.ngay_sinh)::int = p_nam_sinh)
    AND (p_truong_hoc IS NULL OR p_truong_hoc = '' OR ts.truong_hoc ILIKE '%' || p_truong_hoc || '%')
    AND (p_trang_thai_ho_so IS NULL OR p_trang_thai_ho_so = 'ALL' OR ts.trang_thai_ho_so = p_trang_thai_ho_so)
    AND (p_sale_phu_trach_id IS NULL OR p_sale_phu_trach_id = 'ALL' OR ts.sale_phu_trach_id = p_sale_phu_trach_id)
    AND (p_bang_dau IS NULL OR p_bang_dau = 'ALL' OR ts.bang_dau = p_bang_dau)
  ORDER BY ts.thi_sinh_id $$;

CREATE OR REPLACE FUNCTION fn_xem_chi_tiet_thisinh(p_thi_sinh_id varchar)
RETURNS TABLE (ho_ten varchar, email varchar, nam_sinh int, truong_hoc varchar, trang_thai_ho_so varchar, so_dien_thoai varchar,
               cccd varchar, bang_dau varchar, sale_phu_trach_id varchar, sale_phu_trach varchar) LANGUAGE plpgsql STABLE AS $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM thisinh WHERE thi_sinh_id = p_thi_sinh_id) THEN RAISE EXCEPTION 'Thí sinh % không tồn tại.', p_thi_sinh_id; END IF;
  RETURN QUERY SELECT ts.ho_ten, ts.email, extract(year FROM ts.ngay_sinh)::int, ts.truong_hoc, ts.trang_thai_ho_so, ts.sdt, ts.cccd,
                      ts.bang_dau, ts.sale_phu_trach_id, nv.ho_ten
               FROM thisinh ts LEFT JOIN nhanvien nv ON nv.nhan_vien_id = ts.sale_phu_trach_id WHERE ts.thi_sinh_id = p_thi_sinh_id;
END $$;

-- Tìm kiếm không phân biệt hoa thường và dấu tiếng Việt
CREATE OR REPLACE FUNCTION fn_tim_kiem_thisinh(p_tu_khoa varchar)
RETURNS TABLE (id varchar, ho_va_ten varchar, email varchar, so_dien_thoai varchar, nam_sinh int, truong_hoc varchar,
               trang_thai_ho_so varchar, bang_dau varchar, sale_phu_trach_id varchar, sale_phu_trach varchar) LANGUAGE plpgsql STABLE AS $$
DECLARE v_kw text := NULLIF(btrim(p_tu_khoa), '');
BEGIN
  IF v_kw IS NULL THEN RAISE EXCEPTION 'Vui lòng nhập thông tin cần tìm kiếm.'; END IF;
  v_kw := '%' || unaccent(lower(v_kw)) || '%';
  RETURN QUERY
  SELECT ts.thi_sinh_id, ts.ho_ten, ts.email, ts.sdt, extract(year FROM ts.ngay_sinh)::int, ts.truong_hoc, ts.trang_thai_ho_so,
         ts.bang_dau, ts.sale_phu_trach_id, nv.ho_ten
  FROM thisinh ts LEFT JOIN nhanvien nv ON nv.nhan_vien_id = ts.sale_phu_trach_id
  WHERE unaccent(lower(ts.thi_sinh_id)) LIKE v_kw OR unaccent(lower(ts.ho_ten)) LIKE v_kw OR unaccent(lower(ts.email)) LIKE v_kw
     OR unaccent(lower(COALESCE(ts.truong_hoc, ''))) LIKE v_kw OR ts.cccd LIKE v_kw
  ORDER BY ts.thi_sinh_id;
END $$;

/* ================================================================
   MODULE 3. QUẢN LÝ ĐỐI TÁC
   ================================================================ */
-- 3.1 Tài trợ đồng hành
CREATE OR REPLACE VIEW vw_doitac_taitro_theo_cap AS
  SELECT cap_do_tai_tro, count(*) AS so_luong_doanh_nghiep,
         round(count(*) * 100.0 / NULLIF(sum(count(*)) OVER (), 0), 2) AS ty_trong_phan_tram
  FROM doanhnghiep WHERE hinh_thuc = 'TAI_TRO_DONG_HANH' GROUP BY cap_do_tai_tro ORDER BY so_luong_doanh_nghiep DESC;

CREATE OR REPLACE VIEW vw_doitac_taitro_gia_tri AS
  SELECT dn.doanh_nghiep_id, dn.ten_doanh_nghiep, dn.cap_do_tai_tro, dn.loai_tai_tro, COALESCE(p.thuc_thu, 0) AS gia_tri_tai_tro_vnd
  FROM doanhnghiep dn
  LEFT JOIN LATERAL (SELECT sum(so_tien) AS thuc_thu FROM doanhnghiep_pipeline
                     WHERE doanh_nghiep_id = dn.doanh_nghiep_id AND giai_doan = 'THUC_THU') p ON true
  WHERE dn.hinh_thuc = 'TAI_TRO_DONG_HANH' ORDER BY gia_tri_tai_tro_vnd DESC;

CREATE OR REPLACE VIEW vw_doitac_taitro_pheu AS
  SELECT '1. Tiếp cận' AS giai_doan, count(DISTINCT doanh_nghiep_id) AS so_luong FROM doanhnghiep_pipeline WHERE giai_doan = 'TIEP_CAN'
  UNION ALL SELECT '2. Đàm phán', count(DISTINCT doanh_nghiep_id) FROM doanhnghiep_pipeline WHERE giai_doan = 'DAM_PHAN'
  UNION ALL SELECT '3. Đã gửi đề xuất', count(DISTINCT doanh_nghiep_id) FROM doanhnghiep_pipeline WHERE giai_doan = 'DE_XUAT_GUI'
  UNION ALL SELECT '4. Đã ký Hợp đồng', count(DISTINCT doanh_nghiep_id) FROM doanhnghiep_pipeline WHERE giai_doan = 'KY_HOP_DONG'
  UNION ALL SELECT '5. Thực thu / Hoàn tất', count(DISTINCT doanh_nghiep_id) FROM doanhnghiep_pipeline WHERE giai_doan = 'THUC_THU';

CREATE OR REPLACE VIEW vw_doitac_taitro_tong_quan AS
  SELECT count(*) AS tong_so_doanh_nghiep_tai_tro,
         COALESCE(sum(CASE WHEN dn.loai_tai_tro = 'HIEN_KIM' THEN COALESCE(p.thuc_thu, 0) END), 0) AS tong_tien_hien_kim_vnd,
         COALESCE(sum(CASE WHEN dn.loai_tai_tro = 'HIEN_VAT' THEN COALESCE(p.thuc_thu, 0) END), 0) AS tong_quy_doi_hien_vat_vnd,
         round(count(*) FILTER (WHERE EXISTS (SELECT 1 FROM doanhnghiep_pipeline x WHERE x.doanh_nghiep_id = dn.doanh_nghiep_id AND x.giai_doan = 'THUC_THU'))
               * 100.0 / NULLIF(count(*), 0), 2) AS ty_le_hoan_thanh_quyen_loi_pct
  FROM doanhnghiep dn
  LEFT JOIN LATERAL (SELECT sum(so_tien) AS thuc_thu FROM doanhnghiep_pipeline
                     WHERE doanh_nghiep_id = dn.doanh_nghiep_id AND giai_doan = 'THUC_THU') p ON true
  WHERE dn.hinh_thuc = 'TAI_TRO_DONG_HANH';

CREATE OR REPLACE VIEW vw_doitac_taitro_ds AS
  SELECT dn.doanh_nghiep_id, dn.ten_doanh_nghiep, dn.ma_so_thue, dn.cap_do_tai_tro, dn.hinh_thuc, dn.loai_tai_tro,
         COALESCE(p.thuc_thu, 0) AS gia_tri_quy_doi,
         CASE WHEN EXISTS (SELECT 1 FROM doanhnghiep_pipeline x WHERE x.doanh_nghiep_id = dn.doanh_nghiep_id AND x.giai_doan = 'THUC_THU')
                THEN '100% (Đã thực thu & bàn giao)'
              WHEN EXISTS (SELECT 1 FROM doanhnghiep_pipeline x WHERE x.doanh_nghiep_id = dn.doanh_nghiep_id AND x.giai_doan = 'KY_HOP_DONG')
                THEN '40% (Đang thực hiện)'
              ELSE '0% (Chưa ký hợp đồng)' END AS ti_le_hoan_thanh_quyen_loi
  FROM doanhnghiep dn
  LEFT JOIN LATERAL (SELECT sum(so_tien) AS thuc_thu FROM doanhnghiep_pipeline
                     WHERE doanh_nghiep_id = dn.doanh_nghiep_id AND giai_doan = 'THUC_THU') p ON true
  WHERE dn.hinh_thuc = 'TAI_TRO_DONG_HANH';

CREATE OR REPLACE FUNCTION fn_doitac_xem_chi_tiet(p_doanh_nghiep_id varchar) RETURNS SETOF doanhnghiep LANGUAGE sql STABLE AS $$
  SELECT * FROM doanhnghiep WHERE doanh_nghiep_id = p_doanh_nghiep_id $$;

CREATE OR REPLACE FUNCTION fn_doitac_taitro_tim_kiem(p_tu_khoa varchar) RETURNS SETOF doanhnghiep LANGUAGE sql STABLE AS $$
  SELECT * FROM doanhnghiep WHERE hinh_thuc = 'TAI_TRO_DONG_HANH'
    AND (unaccent(ten_doanh_nghiep) ILIKE '%' || unaccent(p_tu_khoa) || '%' OR ma_so_thue LIKE '%' || p_tu_khoa || '%') $$;

CREATE OR REPLACE FUNCTION fn_doitac_taitro_loc(p_cap_do varchar DEFAULT NULL, p_loai_tai_tro varchar DEFAULT NULL) RETURNS SETOF doanhnghiep LANGUAGE sql STABLE AS $$
  SELECT * FROM doanhnghiep WHERE hinh_thuc = 'TAI_TRO_DONG_HANH'
    AND (p_cap_do IS NULL OR cap_do_tai_tro = p_cap_do) AND (p_loai_tai_tro IS NULL OR loai_tai_tro = p_loai_tai_tro) $$;

CREATE OR REPLACE VIEW vw_export_baocao_taitro AS
  SELECT doanh_nghiep_id, ten_doanh_nghiep, ma_so_thue, cap_do_tai_tro, loai_tai_tro, email_lien_he, sdt_lien_he, hop_dong, created_at AS ngay_ky_ket
  FROM doanhnghiep WHERE hinh_thuc = 'TAI_TRO_DONG_HANH';

-- 3.2 Doanh nghiệp cung cấp thí sinh
CREATE OR REPLACE VIEW vw_doitac_cungcap_tong_quan AS
  SELECT count(DISTINCT dn.doanh_nghiep_id) AS tong_so_doanh_nghiep,
         count(dkw.thanh_toan_id) AS tong_thi_sinh_tu_doanh_nghiep,
         COALESCE(sum(CASE WHEN dkw.trang_thai_thanh_toan = 'THANH_TOAN_THANH_CONG' THEN dkw.so_tien END), 0) AS tong_le_phi_thu_duoc,
         COALESCE(sum(CASE WHEN dkw.trang_thai_thanh_toan = 'THANH_TOAN_THANH_CONG'
                           THEN COALESCE(dkw.hoa_hong, dkw.so_tien * fn_ty_le_hoa_hong()) END), 0) AS tong_hoa_hong_can_chi_tra
  FROM doanhnghiep dn LEFT JOIN dangkyweb dkw ON dkw.doanh_nghiep_id = dn.doanh_nghiep_id
  WHERE dn.hinh_thuc = 'CUNG_CAP_THI_SINH';

CREATE OR REPLACE VIEW vw_doitac_cungcap_ds AS
  SELECT dn.doanh_nghiep_id AS ma_gioi_thieu, dn.ten_doanh_nghiep,
         count(dkw.thanh_toan_id) AS so_luong_thi_sinh,
         COALESCE(sum(CASE WHEN dkw.trang_thai_thanh_toan = 'THANH_TOAN_THANH_CONG' THEN dkw.so_tien END), 0) AS tong_le_phi_thu_duoc,
         COALESCE(sum(CASE WHEN dkw.trang_thai_thanh_toan = 'THANH_TOAN_THANH_CONG'
                           THEN COALESCE(dkw.hoa_hong, dkw.so_tien * fn_ty_le_hoa_hong()) END), 0) AS hoa_hong_phai_tra,
         CASE WHEN count(dkw.thanh_toan_id) = 0 THEN 'Chưa phát sinh'
              WHEN sum(CASE WHEN dkw.trang_thai_thanh_toan = 'CHO_THANH_TOAN' THEN 1 ELSE 0 END) > 0 THEN 'Đang đối soát'
              ELSE 'Đã đối soát hoàn tất' END AS trang_thai_doi_soat,
         CASE WHEN count(dkw.thanh_toan_id) = 0 THEN 'CHUA_PHAT_SINH'
              WHEN sum(CASE WHEN dkw.trang_thai_thanh_toan = 'CHO_THANH_TOAN' THEN 1 ELSE 0 END) > 0 THEN 'DANG_DOI_SOAT'
              ELSE 'DA_DOI_SOAT' END AS ma_trang_thai_doi_soat   -- dùng để lọc: WHERE ma_trang_thai_doi_soat = ...
  FROM doanhnghiep dn LEFT JOIN dangkyweb dkw ON dkw.doanh_nghiep_id = dn.doanh_nghiep_id
  WHERE dn.hinh_thuc = 'CUNG_CAP_THI_SINH' GROUP BY dn.doanh_nghiep_id, dn.ten_doanh_nghiep;

CREATE OR REPLACE VIEW vw_doitac_cungcap_chi_tiet AS
  SELECT dn.doanh_nghiep_id, dn.ten_doanh_nghiep, dn.ma_so_thue, dn.dia_chi, dn.email_lien_he, dn.sdt_lien_he,
         dn.hop_dong AS file_thoa_thuan_mou, count(dkw.thanh_toan_id) AS so_luong_thi_sinh_da_gioi_thieu
  FROM doanhnghiep dn LEFT JOIN dangkyweb dkw ON dkw.doanh_nghiep_id = dn.doanh_nghiep_id
  WHERE dn.hinh_thuc = 'CUNG_CAP_THI_SINH'
  GROUP BY dn.doanh_nghiep_id, dn.ten_doanh_nghiep, dn.ma_so_thue, dn.dia_chi, dn.email_lien_he, dn.sdt_lien_he, dn.hop_dong;

-- Dữ liệu hóa đơn hoa hồng (xuất PDF ở tầng ứng dụng). Dùng tỷ lệ trong cauhinh_he_thong thay vì cố định 15%.
CREATE OR REPLACE FUNCTION fn_doitac_cungcap_hoa_don(p_doanh_nghiep_id varchar)
RETURNS TABLE (ma_doi_tac varchar, ten_doanh_nghiep varchar, ma_so_thue varchar, dia_chi varchar, so_luong_giao_dich bigint,
               tong_gia_tri_dang_ky_vnd numeric, tien_hoa_hong_phai_tra_vnd numeric, ngay_lap_hoa_don date, dien_giai text)
LANGUAGE sql STABLE AS $$
  SELECT dn.doanh_nghiep_id, dn.ten_doanh_nghiep, dn.ma_so_thue, dn.dia_chi, count(dkw.thanh_toan_id),
         COALESCE(sum(dkw.so_tien), 0),
         COALESCE(sum(COALESCE(dkw.hoa_hong, dkw.so_tien * fn_ty_le_hoa_hong())), 0)::numeric(15,2),
         CURRENT_DATE, 'Chi trả hoa hồng giới thiệu thí sinh tham gia Python Master 2026'::text
  FROM doanhnghiep dn
  LEFT JOIN dangkyweb dkw ON dkw.doanh_nghiep_id = dn.doanh_nghiep_id AND dkw.trang_thai_thanh_toan = 'THANH_TOAN_THANH_CONG'
  WHERE dn.doanh_nghiep_id = p_doanh_nghiep_id
  GROUP BY dn.doanh_nghiep_id, dn.ten_doanh_nghiep, dn.ma_so_thue, dn.dia_chi $$;

CREATE OR REPLACE FUNCTION fn_doitac_cungcap_tim_kiem(p_tu_khoa varchar) RETURNS SETOF doanhnghiep LANGUAGE sql STABLE AS $$
  SELECT * FROM doanhnghiep WHERE hinh_thuc = 'CUNG_CAP_THI_SINH'
    AND (unaccent(ten_doanh_nghiep) ILIKE '%' || unaccent(p_tu_khoa) || '%' OR doanh_nghiep_id ILIKE '%' || p_tu_khoa || '%') $$;

CREATE OR REPLACE VIEW vw_export_baocao_dn_thisinh AS
  SELECT dn.doanh_nghiep_id AS ma_doanh_nghiep, dn.ten_doanh_nghiep, dn.ma_so_thue, dn.email_lien_he, dn.sdt_lien_he,
         count(dkw.thanh_toan_id) AS tong_thi_sinh, COALESCE(sum(dkw.so_tien), 0) AS tong_doanh_thu_mang_lai,
         COALESCE(sum(COALESCE(dkw.hoa_hong, dkw.so_tien * fn_ty_le_hoa_hong())), 0) AS tien_hoa_hong
  FROM doanhnghiep dn
  LEFT JOIN dangkyweb dkw ON dkw.doanh_nghiep_id = dn.doanh_nghiep_id AND dkw.trang_thai_thanh_toan = 'THANH_TOAN_THANH_CONG'
  WHERE dn.hinh_thuc = 'CUNG_CAP_THI_SINH'
  GROUP BY dn.doanh_nghiep_id, dn.ten_doanh_nghiep, dn.ma_so_thue, dn.email_lien_he, dn.sdt_lien_he;

/* ================================================================
   MODULE 4. PYTHON MASTER 2026
   ================================================================ */
CREATE OR REPLACE VIEW vw_pm_tong_quan AS
  SELECT count(DISTINCT thi_sinh_id) AS so_thi_sinh_hoan_tat_thanh_toan,
         COALESCE(sum(so_tien), 0) AS tong_doanh_thu_cuoc_thi_vnd,
         count(DISTINCT thi_sinh_id) AS tai_khoan_sotauni_kich_hoat
  FROM thanhtoan WHERE trang_thai_thanh_toan = 'THANH_TOAN_THANH_CONG';

CREATE OR REPLACE VIEW vw_pm_vong_thi AS
  SELECT cuoc_thi_id, ten_cuoc_thi, COALESCE(bang_dau, 'TẤT CẢ (CHUNG KẾT)') AS bang_dau, mo_ta, han_dang_ky, ngay_bat_dau, ngay_ket_thuc, trang_thai
  FROM cuocthi ORDER BY ngay_bat_dau;

CREATE OR REPLACE VIEW vw_pm_chi_tiet_vong AS    -- WHERE cuoc_thi_id = ...
  SELECT ct.cuoc_thi_id, ct.ten_cuoc_thi, ct.bang_dau, ct.trang_thai, bt.bai_tap_id, bt.ten_bai_tap,
         bt.thoi_gian_lam_bai, bt.diem_dat, bt.so_lan_nop_bai_toi_da
  FROM cuocthi ct LEFT JOIN baitap bt ON bt.cuoc_thi_id = ct.cuoc_thi_id;

CREATE OR REPLACE VIEW vw_pm_vong_loai_tong_quan AS   -- WHERE cuoc_thi_id = ...
  SELECT bt.cuoc_thi_id,
         count(DISTINCT CASE WHEN bn.trang_thai = 'DANG_LAM' THEN bn.thi_sinh_id END) AS thi_sinh_dang_thi,
         count(DISTINCT CASE WHEN bn.trang_thai IN ('DA_NOP','DA_CHAM_DIEM') THEN bn.bai_nop_id END) AS so_bai_da_nop,
         COALESCE(max(bn.tong_diem), 0.00) AS diem_cao_nhat
  FROM baitap bt LEFT JOIN bainop bn ON bn.bai_tap_id = bt.bai_tap_id GROUP BY bt.cuoc_thi_id;

CREATE OR REPLACE VIEW vw_pm_bxh_tam_thoi AS
  SELECT dense_rank() OVER (ORDER BY bn.tong_diem DESC NULLS LAST, bn.thoi_gian_lam_bai_giay ASC) AS xep_hang,
         ts.thi_sinh_id, ts.ho_ten, ts.truong_hoc, ts.tinh_thanh, bt.ten_bai_tap, bn.tong_diem,
         bn.thoi_gian_lam_bai_giay AS thoi_gian_lam_giay, bn.thoi_gian_nop, bn.trang_thai
  FROM bainop bn JOIN thisinh ts ON ts.thi_sinh_id = bn.thi_sinh_id JOIN baitap bt ON bt.bai_tap_id = bn.bai_tap_id
  ORDER BY xep_hang;

CREATE OR REPLACE VIEW vw_pm_chi_tiet_bai_lam AS   -- WHERE bai_nop_id = ...
  SELECT bn.bai_nop_id, ts.thi_sinh_id, ts.ho_ten, ch.thu_tu AS cau_hoi_so, ch.noi_dung_cau_hoi, ch.loai_cau_hoi,
         COALESCE(da.noi_dung_dap_an, ct.noi_dung_tra_loi) AS cau_tra_loi_cua_thi_sinh,
         ct.la_dap_an_dung, ct.diem_dat_duoc, ch.diem_toi_da, ct.nhan_xet_cau_hoi
  FROM chi_tiet_dap_an_nop ct
  JOIN bainop bn ON bn.bai_nop_id = ct.bai_nop_id JOIN thisinh ts ON ts.thi_sinh_id = bn.thi_sinh_id
  JOIN cauhoi ch ON ch.cau_hoi_id = ct.cau_hoi_id LEFT JOIN lua_chon_dap_an da ON da.dap_an_id = ct.dap_an_chon_id;

CREATE OR REPLACE VIEW vw_export_ketqua_vongloai AS
  SELECT bt.cuoc_thi_id, ct.ten_cuoc_thi, ts.bang_dau,
         dense_rank() OVER (PARTITION BY bt.cuoc_thi_id ORDER BY bn.tong_diem DESC NULLS LAST, bn.thoi_gian_lam_bai_giay ASC) AS thu_hang,
         ts.thi_sinh_id, ts.ho_ten, ts.email, ts.sdt, ts.truong_hoc, bn.tong_diem, bn.thoi_gian_lam_bai_giay, bn.thoi_gian_nop,
         CASE WHEN bn.tong_diem >= bt.diem_dat THEN 'ĐẠT YÊU CẦU' ELSE 'KHÔNG ĐẠT' END AS ket_qua_xet
  FROM bainop bn JOIN thisinh ts ON ts.thi_sinh_id = bn.thi_sinh_id
  JOIN baitap bt ON bt.bai_tap_id = bn.bai_tap_id JOIN cuocthi ct ON ct.cuoc_thi_id = bt.cuoc_thi_id;

-- Vòng chung kết
CREATE OR REPLACE VIEW vw_pm_chungket_tong_quan AS
  SELECT dk.cuoc_thi_id, count(*) AS tong_chi_so_thi_sinh_vao_chung_ket,
         count(CASE WHEN dk.trang_thai = 'THANH_CONG' THEN 1 END) AS so_luong_da_xac_nhan,
         count(CASE WHEN dk.trang_thai = 'CHO_THANH_TOAN' THEN 1 END) AS so_luong_cho_xac_nhan
  FROM dangky dk JOIN cuocthi ct ON ct.cuoc_thi_id = dk.cuoc_thi_id
  WHERE ct.ten_cuoc_thi ILIKE '%Chung kết%' OR ct.cuoc_thi_id ILIKE '%CK%' GROUP BY dk.cuoc_thi_id;

-- Xếp hạng toàn quốc vòng sơ loại (app lấy top: WHERE hang_toan_quoc <= 56)
CREATE OR REPLACE VIEW vw_pm_top_vong_loai AS
  WITH best AS (
    SELECT ts.thi_sinh_id, ts.ho_ten, ts.email, ts.sdt, ts.truong_hoc, ts.bang_dau,
           max(bn.tong_diem) AS tong_diem, min(bn.thoi_gian_lam_bai_giay) AS thoi_gian_lam_bai_giay
    FROM bainop bn JOIN thisinh ts ON ts.thi_sinh_id = bn.thi_sinh_id
    WHERE bn.trang_thai = 'DA_CHAM_DIEM' AND bn.tong_diem IS NOT NULL
    GROUP BY ts.thi_sinh_id, ts.ho_ten, ts.email, ts.sdt, ts.truong_hoc, ts.bang_dau)
  SELECT row_number() OVER (ORDER BY tong_diem DESC, thoi_gian_lam_bai_giay ASC) AS hang_toan_quoc, * FROM best;

-- Gửi thư mời Top N: ghi nhận đăng ký chung kết dạng chờ xác nhận. Trả về số thí sinh được thêm.
-- (Bản gốc dùng TOP 56 không có ORDER BY nên có thể chọn sai người; bản này đã sắp xếp đúng.)
CREATE OR REPLACE FUNCTION fn_gui_thu_moi_top56(p_chung_ket_id varchar DEFAULT NULL, p_so_luong int DEFAULT 56)
RETURNS int LANGUAGE plpgsql AS $$
DECLARE v_ck varchar; v_n int := 0; r record;
BEGIN
  v_ck := COALESCE(p_chung_ket_id, (SELECT cuoc_thi_id FROM cuocthi
          WHERE ten_cuoc_thi ILIKE '%Chung kết%' OR cuoc_thi_id ILIKE '%CK%' OR cuoc_thi_id = 'CT03' ORDER BY ngay_bat_dau LIMIT 1));
  IF v_ck IS NULL THEN RAISE EXCEPTION 'Không tìm thấy cuộc thi Chung kết.'; END IF;
  FOR r IN
    SELECT t.thi_sinh_id FROM vw_pm_top_vong_loai t
    WHERE t.hang_toan_quoc <= p_so_luong
      AND NOT EXISTS (SELECT 1 FROM dangky dk WHERE dk.thi_sinh_id = t.thi_sinh_id AND dk.cuoc_thi_id = v_ck)
    ORDER BY t.hang_toan_quoc
  LOOP
    INSERT INTO dangky (dang_ky_id, thi_sinh_id, cuoc_thi_id, ngay_dang_ky, trang_thai)
    VALUES (fn_sinh_id('DK', 'dangky', 'dang_ky_id'), r.thi_sinh_id, v_ck, now(), 'CHO_THANH_TOAN');
    v_n := v_n + 1;
  END LOOP;
  RETURN v_n;
END $$;

CREATE OR REPLACE VIEW vw_export_danhsach_chungket AS
  SELECT dk.dang_ky_id, ts.thi_sinh_id, ts.ho_ten, ts.email, ts.sdt, ts.truong_hoc, ts.tinh_thanh, ts.bang_dau, ct.ten_cuoc_thi,
         ct.ngay_bat_dau AS ngay_thi_chung_ket,
         CASE WHEN dk.trang_thai = 'THANH_CONG' THEN 'ĐÃ XÁC NHẬN THAM GIA' ELSE 'CHỜ XÁC NHẬN / ĐÃ GỬI THƯ MỜI' END AS tinh_trang_xac_nhan
  FROM dangky dk JOIN thisinh ts ON ts.thi_sinh_id = dk.thi_sinh_id JOIN cuocthi ct ON ct.cuoc_thi_id = dk.cuoc_thi_id
  WHERE ct.ten_cuoc_thi ILIKE '%Chung kết%' OR ct.cuoc_thi_id ILIKE '%CK%';

/* ================================================================
   MODULE 5. BÀI TẬP & BÀI NỘP
   ================================================================ */
CREATE OR REPLACE FUNCTION fn_baitap_tong_quan_kpi(p_cuoc_thi_id varchar DEFAULT NULL)
RETURNS TABLE (tong_bai_da_nop bigint, bai_qua_han bigint, tyle_dat_pt numeric, so_bai_dang_cham bigint) LANGUAGE sql STABLE AS $$
  SELECT COALESCE(sum(CASE WHEN bn.trang_thai IN ('DA_NOP','DA_CHAM_DIEM') THEN 1 ELSE 0 END), 0)::bigint,
         COALESCE(sum(CASE WHEN bn.trang_thai = 'QUA_HAN_NOP' THEN 1 ELSE 0 END), 0)::bigint,
         round(100.0 * sum(CASE WHEN bn.trang_thai = 'DA_CHAM_DIEM' AND bn.tong_diem IS NOT NULL AND bt.diem_dat IS NOT NULL AND bn.tong_diem >= bt.diem_dat THEN 1 ELSE 0 END)
               / NULLIF(sum(CASE WHEN bn.trang_thai = 'DA_CHAM_DIEM' AND bn.tong_diem IS NOT NULL AND bt.diem_dat IS NOT NULL THEN 1 ELSE 0 END), 0), 1),
         COALESCE(sum(CASE WHEN bn.trang_thai = 'DA_NOP' THEN 1 ELSE 0 END), 0)::bigint
  FROM bainop bn JOIN baitap bt ON bt.bai_tap_id = bn.bai_tap_id
  WHERE (p_cuoc_thi_id IS NULL OR bt.cuoc_thi_id = p_cuoc_thi_id) $$;

CREATE OR REPLACE VIEW vw_ds_baitap AS
  SELECT bt.bai_tap_id, bt.cuoc_thi_id, bt.ten_bai_tap, bt.bang_dau AS bang, bt.mo_ta, bt.thoi_gian_lam_bai, bt.so_lan_nop_bai_toi_da,
         bt.diem_dat, bt.ngay_bat_dau, bt.ngay_het_han, bt.trang_thai,
         (SELECT count(*) FROM cauhoi ch WHERE ch.bai_tap_id = bt.bai_tap_id) AS so_cau_hoi,
         (SELECT COALESCE(sum(ch.diem_toi_da), 0) FROM cauhoi ch WHERE ch.bai_tap_id = bt.bai_tap_id) AS tong_diem_toi_da,
         (SELECT count(*) FROM bainop bn WHERE bn.bai_tap_id = bt.bai_tap_id) AS so_luong_da_nop
  FROM baitap bt;

CREATE OR REPLACE FUNCTION fn_baitap_tim_kiem(p_tu_khoa varchar DEFAULT NULL, p_trang_thai varchar DEFAULT NULL,
  p_cuoc_thi_id varchar DEFAULT NULL, p_trang int DEFAULT 1, p_kich_thuoc_trang int DEFAULT 30)
RETURNS SETOF vw_ds_baitap LANGUAGE sql STABLE AS $$
  SELECT * FROM vw_ds_baitap
  WHERE (p_tu_khoa IS NULL OR ten_bai_tap ILIKE '%' || p_tu_khoa || '%' OR bai_tap_id ILIKE '%' || p_tu_khoa || '%')
    AND (p_trang_thai IS NULL OR trang_thai = p_trang_thai) AND (p_cuoc_thi_id IS NULL OR cuoc_thi_id = p_cuoc_thi_id)
  ORDER BY bai_tap_id LIMIT GREATEST(p_kich_thuoc_trang, 1) OFFSET (GREATEST(p_trang, 1) - 1) * GREATEST(p_kich_thuoc_trang, 1) $$;

CREATE OR REPLACE FUNCTION fn_baitap_xem_chi_tiet(p_bai_tap_id varchar) RETURNS SETOF vw_ds_baitap LANGUAGE sql STABLE AS $$
  SELECT * FROM vw_ds_baitap WHERE bai_tap_id = p_bai_tap_id $$;
CREATE OR REPLACE FUNCTION fn_baitap_cauhoi(p_bai_tap_id varchar) RETURNS SETOF cauhoi LANGUAGE sql STABLE AS $$
  SELECT * FROM cauhoi WHERE bai_tap_id = p_bai_tap_id ORDER BY thu_tu $$;

CREATE OR REPLACE VIEW vw_ds_bainop AS
  SELECT bn.bai_nop_id, ts.thi_sinh_id, ts.ho_ten AS ten_thi_sinh, ts.tinh_thanh, bt.cuoc_thi_id, bt.bai_tap_id, bt.ten_bai_tap, bt.bang_dau AS bang,
         bn.lan_nop, bn.tong_diem, bt.diem_dat,
         CASE WHEN bn.tong_diem IS NULL THEN 'CHUA_CO_DIEM' WHEN bt.diem_dat IS NULL THEN 'CHUA_XAC_DINH'
              WHEN bn.tong_diem >= bt.diem_dat THEN 'DAT' ELSE 'KHONG_DAT' END AS ket_qua,
         bn.nhan_xet_chung, bn.thoi_gian_bat_dau, bn.thoi_gian_nop, bn.thoi_gian_lam_bai_giay, bn.trang_thai
  FROM bainop bn JOIN thisinh ts ON ts.thi_sinh_id = bn.thi_sinh_id JOIN baitap bt ON bt.bai_tap_id = bn.bai_tap_id;

CREATE OR REPLACE FUNCTION fn_bainop_tim_kiem(p_tu_khoa varchar DEFAULT NULL, p_ket_qua varchar DEFAULT NULL, p_bai_tap_id varchar DEFAULT NULL,
  p_trang_thai varchar DEFAULT NULL, p_trang int DEFAULT 1, p_kich_thuoc_trang int DEFAULT 30)
RETURNS SETOF vw_ds_bainop LANGUAGE sql STABLE AS $$
  SELECT * FROM vw_ds_bainop
  WHERE (p_tu_khoa IS NULL OR bai_nop_id ILIKE '%' || p_tu_khoa || '%' OR ten_thi_sinh ILIKE '%' || p_tu_khoa || '%')
    AND (p_ket_qua IS NULL OR ket_qua = p_ket_qua) AND (p_bai_tap_id IS NULL OR bai_tap_id = p_bai_tap_id)
    AND (p_trang_thai IS NULL OR trang_thai = p_trang_thai)
  ORDER BY thoi_gian_nop DESC NULLS LAST, bai_nop_id
  LIMIT GREATEST(p_kich_thuoc_trang, 1) OFFSET (GREATEST(p_trang, 1) - 1) * GREATEST(p_kich_thuoc_trang, 1) $$;

CREATE OR REPLACE FUNCTION fn_bainop_xem_chi_tiet(p_bai_nop_id varchar) RETURNS SETOF vw_ds_bainop LANGUAGE sql STABLE AS $$
  SELECT * FROM vw_ds_bainop WHERE bai_nop_id = p_bai_nop_id $$;
CREATE OR REPLACE FUNCTION fn_bainop_chi_tiet_dapan(p_bai_nop_id varchar) RETURNS SETOF chi_tiet_dap_an_nop LANGUAGE sql STABLE AS $$
  SELECT * FROM chi_tiet_dap_an_nop WHERE bai_nop_id = p_bai_nop_id ORDER BY chi_tiet_id $$;

CREATE OR REPLACE FUNCTION sp_bainop_chinh_sua_trang_thai(p_bai_nop_id varchar, p_ly_do varchar, p_nhan_vien_id varchar,
  p_diem_moi numeric DEFAULT NULL, p_trang_thai_moi varchar DEFAULT NULL, p_nhan_xet_moi text DEFAULT NULL)
RETURNS void LANGUAGE plpgsql AS $$
DECLARE v_max numeric;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM bainop WHERE bai_nop_id = p_bai_nop_id) THEN RAISE EXCEPTION 'Không tìm thấy bài nộp.'; END IF;
  IF NOT EXISTS (SELECT 1 FROM nhanvien WHERE nhan_vien_id = p_nhan_vien_id AND trang_thai = 'ACTIVE') THEN RAISE EXCEPTION 'Nhân viên thực hiện không tồn tại hoặc đã INACTIVE.'; END IF;
  IF p_ly_do IS NULL OR btrim(p_ly_do) = '' THEN RAISE EXCEPTION 'Bắt buộc nhập lý do chỉnh sửa.'; END IF;
  IF p_trang_thai_moi IS NOT NULL AND p_trang_thai_moi NOT IN ('DANG_LAM','DA_NOP','DA_CHAM_DIEM','QUA_HAN_NOP') THEN RAISE EXCEPTION 'Trạng thái bài nộp không hợp lệ.'; END IF;
  SELECT NULLIF(sum(ch.diem_toi_da), 0) INTO v_max FROM bainop bn JOIN cauhoi ch ON ch.bai_tap_id = bn.bai_tap_id WHERE bn.bai_nop_id = p_bai_nop_id;
  IF p_diem_moi IS NOT NULL AND v_max IS NOT NULL AND p_diem_moi > v_max THEN RAISE EXCEPTION 'Điểm mới vượt quá tổng điểm tối đa của bài tập.'; END IF;
  PERFORM fn_set_audit_context_theo_nhanvien(p_nhan_vien_id);
  UPDATE bainop SET tong_diem = COALESCE(p_diem_moi, tong_diem), trang_thai = COALESCE(p_trang_thai_moi, trang_thai),
         nhan_xet_chung = COALESCE(p_nhan_xet_moi, nhan_xet_chung) WHERE bai_nop_id = p_bai_nop_id;
  UPDATE audit_log SET ghi_chu = p_ly_do
  WHERE audit_log_id = (SELECT max(audit_log_id) FROM audit_log WHERE ten_bang = 'BAINOP' AND id_ban_ghi = p_bai_nop_id AND hanh_dong = 'SUA');
END $$;

CREATE OR REPLACE FUNCTION fn_bainop_xuat_bao_cao(p_cuoc_thi_id varchar DEFAULT NULL, p_tu_ngay timestamp DEFAULT NULL, p_den_ngay timestamp DEFAULT NULL)
RETURNS SETOF vw_ds_bainop LANGUAGE sql STABLE AS $$
  SELECT * FROM vw_ds_bainop
  WHERE (p_cuoc_thi_id IS NULL OR cuoc_thi_id = p_cuoc_thi_id) AND (p_tu_ngay IS NULL OR thoi_gian_nop >= p_tu_ngay)
    AND (p_den_ngay IS NULL OR thoi_gian_nop <= p_den_ngay) ORDER BY thoi_gian_nop $$;

CREATE OR REPLACE VIEW vw_baocao_phanbo_trangthai_bainop AS SELECT trang_thai, count(*) AS so_luong FROM bainop GROUP BY trang_thai;

CREATE OR REPLACE FUNCTION fn_tyle_khong_dat_baitap(p_bai_tap_id varchar) RETURNS numeric LANGUAGE sql STABLE AS $$
  SELECT COALESCE(round(100.0 * sum(CASE WHEN bn.tong_diem IS NOT NULL AND bt.diem_dat IS NOT NULL AND bn.tong_diem < bt.diem_dat THEN 1 ELSE 0 END)
         / NULLIF(sum(CASE WHEN bn.tong_diem IS NOT NULL AND bt.diem_dat IS NOT NULL THEN 1 ELSE 0 END), 0), 2), 0)
  FROM bainop bn JOIN baitap bt ON bt.bai_tap_id = bn.bai_tap_id WHERE bn.bai_tap_id = p_bai_tap_id $$;

CREATE OR REPLACE VIEW vw_baitap_tyle_khong_dat_cao AS
  SELECT bt.bai_tap_id, bt.ten_bai_tap, bt.bang_dau,
         (SELECT count(*) FROM bainop bn WHERE bn.bai_tap_id = bt.bai_tap_id) AS tong_luot_nop,
         fn_tyle_khong_dat_baitap(bt.bai_tap_id) AS tyle_khong_dat_pt
  FROM baitap bt WHERE EXISTS (SELECT 1 FROM bainop bn WHERE bn.bai_tap_id = bt.bai_tap_id);

CREATE OR REPLACE VIEW vw_tyle_khong_dat_theo_khuvuc AS
  SELECT ts.tinh_thanh, count(*) AS tong_luot_nop,
         round(100.0 * sum(CASE WHEN bn.tong_diem IS NOT NULL AND bt.diem_dat IS NOT NULL AND bn.tong_diem < bt.diem_dat THEN 1 ELSE 0 END)
               / NULLIF(sum(CASE WHEN bn.tong_diem IS NOT NULL AND bt.diem_dat IS NOT NULL THEN 1 ELSE 0 END), 0), 2) AS tyle_khong_dat_pt
  FROM bainop bn JOIN thisinh ts ON ts.thi_sinh_id = bn.thi_sinh_id JOIN baitap bt ON bt.bai_tap_id = bn.bai_tap_id
  WHERE ts.tinh_thanh IS NOT NULL GROUP BY ts.tinh_thanh;

/* ================================================================
   MODULE 6. KHO TÀI LIỆU RAG
   ================================================================ */
CREATE OR REPLACE VIEW vw_rag_tongquan AS
  SELECT (SELECT count(*) FROM tailieu WHERE trang_thai <> 'DA_XOA') AS tong_tai_lieu,
         (SELECT count(DISTINCT td.tai_lieu_id) FROM tailieu_doan td JOIN tailieu t ON t.tai_lieu_id = td.tai_lieu_id WHERE t.trang_thai <> 'DA_XOA') AS tai_lieu_da_co_doan,
         (SELECT count(*) FROM tailieu_doan td JOIN tailieu t ON t.tai_lieu_id = td.tai_lieu_id WHERE t.trang_thai <> 'DA_XOA') AS tong_so_doan,
         (SELECT count(*) FROM tailieu_doan td JOIN tailieu t ON t.tai_lieu_id = td.tai_lieu_id WHERE t.trang_thai <> 'DA_XOA' AND td.embedding IS NOT NULL) AS tong_vector_embeddings;

CREATE OR REPLACE VIEW vw_ds_tailieu AS
  SELECT tl.tai_lieu_id, tl.ten_tai_lieu, tl.ten_file_goc, dm.ten_danh_muc AS danh_muc_hien_thi, tl.loai_tai_lieu,
         round(tl.dung_luong_byte / 1048576.0, 2) AS dung_luong_mb, tl.trang_thai,
         (SELECT count(*) FROM tailieu_doan td WHERE td.tai_lieu_id = tl.tai_lieu_id) AS so_doan, tl.created_at AS ngay_dang_tai
  FROM tailieu tl LEFT JOIN danhmuc dm ON dm.danh_muc_id = tl.danh_muc_id WHERE tl.trang_thai <> 'DA_XOA';

CREATE OR REPLACE FUNCTION fn_tailieu_tim_kiem_loc(p_tu_khoa varchar DEFAULT NULL, p_loai_tai_lieu varchar DEFAULT NULL,
  p_trang_thai varchar DEFAULT NULL, p_trang int DEFAULT 1, p_kich_thuoc_trang int DEFAULT 30)
RETURNS SETOF vw_ds_tailieu LANGUAGE sql STABLE AS $$
  SELECT * FROM vw_ds_tailieu
  WHERE (p_tu_khoa IS NULL OR unaccent(ten_tai_lieu) ILIKE '%' || unaccent(p_tu_khoa) || '%')
    AND (p_loai_tai_lieu IS NULL OR loai_tai_lieu = p_loai_tai_lieu) AND (p_trang_thai IS NULL OR trang_thai = p_trang_thai)
  ORDER BY ngay_dang_tai DESC, tai_lieu_id
  LIMIT GREATEST(p_kich_thuoc_trang, 1) OFFSET (GREATEST(p_trang, 1) - 1) * GREATEST(p_kich_thuoc_trang, 1) $$;

CREATE OR REPLACE FUNCTION fn_tailieu_xem_doan(p_tai_lieu_id varchar)
RETURNS TABLE (thu_tu_doan int, vector_id_hien_thi text, noi_dung_rut_gon text, da_co_embedding int) LANGUAGE sql STABLE AS $$
  SELECT td.thu_tu_doan, 'vec_' || td.doan_id, left(td.noi_dung_doan, 300), CASE WHEN td.embedding IS NULL THEN 0 ELSE 1 END
  FROM tailieu_doan td WHERE td.tai_lieu_id = p_tai_lieu_id ORDER BY td.thu_tu_doan $$;

CREATE OR REPLACE FUNCTION fn_tailieu_reindex(p_tai_lieu_id varchar, p_nguoi_yeu_cau varchar) RETURNS void LANGUAGE plpgsql AS $$
DECLARE v_max bigint;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM tailieu WHERE tai_lieu_id = p_tai_lieu_id AND trang_thai <> 'DA_XOA') THEN RAISE EXCEPTION 'Tài liệu không tồn tại hoặc đã bị xóa.'; END IF;
  IF NOT EXISTS (SELECT 1 FROM nhanvien WHERE nhan_vien_id = p_nguoi_yeu_cau AND trang_thai = 'ACTIVE') THEN RAISE EXCEPTION 'Người yêu cầu không tồn tại hoặc đã INACTIVE.'; END IF;
  PERFORM fn_set_audit_context_theo_nhanvien(p_nguoi_yeu_cau);
  SELECT COALESCE(max(audit_log_id), 0) INTO v_max FROM audit_log;
  DELETE FROM tailieu_doan WHERE tai_lieu_id = p_tai_lieu_id;   -- trigger tự ghi audit từng đoạn
  UPDATE audit_log SET ghi_chu = 'Yêu cầu re-index: đã xóa các đoạn tài liệu cũ'
  WHERE audit_log_id > v_max AND ten_bang = 'TAILIEU_DOAN' AND hanh_dong = 'XOA';
END $$;

CREATE OR REPLACE FUNCTION fn_tailieu_them_moi(p_tai_lieu_id varchar, p_ten_tai_lieu varchar, p_loai_tai_lieu varchar, p_url_luu_tru varchar,
  p_tao_boi varchar, p_danh_muc_id varchar DEFAULT NULL, p_ten_file_goc varchar DEFAULT NULL, p_dung_luong_byte bigint DEFAULT NULL)
RETURNS void LANGUAGE plpgsql AS $$
BEGIN
  PERFORM fn_set_audit_context_theo_nhanvien(p_tao_boi);
  PERFORM sp_insert_tailieu(p_tai_lieu_id => p_tai_lieu_id, p_ten_tai_lieu => p_ten_tai_lieu, p_loai_tai_lieu => p_loai_tai_lieu,
    p_url_luu_tru => p_url_luu_tru, p_tao_boi => p_tao_boi, p_ten_file_goc => p_ten_file_goc, p_danh_muc_id => p_danh_muc_id,
    p_dung_luong_byte => p_dung_luong_byte, p_trang_thai => 'NOI_BO');
END $$;

-- Tìm tài liệu (tiếng Việt không dấu, có xếp hạng gần đúng bằng pg_trgm)
CREATE OR REPLACE FUNCTION fn_search_tailieu(p_tu_khoa varchar, p_gioi_han int DEFAULT 20)
RETURNS TABLE (tai_lieu_id varchar, ten_tai_lieu varchar, loai_tai_lieu varchar, danh_muc_id varchar, mo_ta varchar, tu_khoa_ai varchar,
               url_luu_tru varchar, quyen_truy_cap varchar, trang_thai varchar, diem_phu_hop real) LANGUAGE sql STABLE AS $$
  SELECT t.tai_lieu_id, t.ten_tai_lieu, t.loai_tai_lieu, t.danh_muc_id, t.mo_ta, t.tu_khoa_ai, t.url_luu_tru, t.quyen_truy_cap, t.trang_thai,
         greatest(similarity(unaccent(t.ten_tai_lieu), unaccent(p_tu_khoa)),
                  similarity(unaccent(COALESCE(t.tu_khoa_ai, '')), unaccent(p_tu_khoa)))
  FROM tailieu t
  WHERE t.trang_thai NOT IN ('DA_XOA','AN') AND btrim(COALESCE(p_tu_khoa, '')) <> ''
    AND (unaccent(t.ten_tai_lieu) ILIKE '%' || unaccent(p_tu_khoa) || '%' OR unaccent(COALESCE(t.mo_ta, '')) ILIKE '%' || unaccent(p_tu_khoa) || '%'
         OR unaccent(COALESCE(t.tu_khoa_ai, '')) ILIKE '%' || unaccent(p_tu_khoa) || '%')
  ORDER BY 10 DESC, t.updated_at DESC LIMIT p_gioi_han $$;

-- Tìm đoạn tài liệu gần nghĩa nhất (RAG) bằng pgvector: truyền embedding dạng '[0.1,0.2,...]'
CREATE OR REPLACE FUNCTION fn_tim_doan_tuong_dong(p_embedding vector(1536), p_gioi_han int DEFAULT 5)
RETURNS TABLE (doan_id bigint, tai_lieu_id varchar, ten_tai_lieu varchar, noi_dung_doan text, khoang_cach double precision) LANGUAGE sql STABLE AS $$
  SELECT d.doan_id, d.tai_lieu_id, t.ten_tai_lieu, d.noi_dung_doan, (d.embedding <=> p_embedding)::double precision
  FROM tailieu_doan d JOIN tailieu t ON t.tai_lieu_id = d.tai_lieu_id
  WHERE d.embedding IS NOT NULL AND t.trang_thai NOT IN ('DA_XOA','AN')
  ORDER BY d.embedding <=> p_embedding LIMIT p_gioi_han $$;

/* ================================================================
   MODULE 7. LỊCH SỬ Q&A
   ================================================================ */
CREATE OR REPLACE VIEW vw_ds_hoithoai AS
  SELECT q.qna_id, q.thi_sinh_id, q.doanh_nghiep_id, COALESCE(q.thi_sinh_id, q.doanh_nghiep_id) AS doi_tuong_id,
         CASE WHEN q.thi_sinh_id IS NOT NULL THEN 'THI_SINH' ELSE 'DOANH_NGHIEP' END AS loai_doi_tuong,
         COALESCE(ts.ho_ten, dn.ten_doanh_nghiep) AS ten_hien_thi, q.noi_dung_hoi, q.noi_dung_tra_loi, q.tai_lieu_id, q.thoi_gian,
         q.kenh_tuong_tac, q.trang_thai, q.danh_gia_hai_long, q.nhan_vien_id_ho_tro
  FROM qna q LEFT JOIN thisinh ts ON ts.thi_sinh_id = q.thi_sinh_id LEFT JOIN doanhnghiep dn ON dn.doanh_nghiep_id = q.doanh_nghiep_id;

CREATE OR REPLACE FUNCTION fn_hoithoai_chi_tiet(p_thi_sinh_id varchar DEFAULT NULL, p_doanh_nghiep_id varchar DEFAULT NULL)
RETURNS SETOF vw_ds_hoithoai LANGUAGE sql STABLE AS $$
  SELECT * FROM vw_ds_hoithoai WHERE (p_thi_sinh_id IS NOT NULL AND thi_sinh_id = p_thi_sinh_id)
     OR (p_doanh_nghiep_id IS NOT NULL AND doanh_nghiep_id = p_doanh_nghiep_id) ORDER BY thoi_gian ASC $$;

CREATE OR REPLACE FUNCTION fn_hoithoai_tim_kiem_theo_ten(p_tu_khoa varchar) RETURNS SETOF vw_ds_hoithoai LANGUAGE sql STABLE AS $$
  SELECT * FROM vw_ds_hoithoai WHERE unaccent(ten_hien_thi) ILIKE '%' || unaccent(p_tu_khoa) || '%' ORDER BY thoi_gian DESC $$;

CREATE OR REPLACE FUNCTION fn_hoithoai_nhanvien_gui_tin_nhan(p_qna_id varchar, p_nhan_vien_id varchar, p_noi_dung text) RETURNS void LANGUAGE plpgsql AS $$
BEGIN
  IF p_noi_dung IS NULL OR btrim(p_noi_dung) = '' THEN RAISE EXCEPTION 'Nội dung trả lời không được rỗng.'; END IF;
  PERFORM fn_set_audit_context_theo_nhanvien(p_nhan_vien_id);
  PERFORM sp_update_qna(p_qna_id => p_qna_id, p_noi_dung_tra_loi => p_noi_dung, p_nhan_vien_id_ho_tro => p_nhan_vien_id, p_trang_thai => 'DA_TRA_LOI');
END $$;

CREATE OR REPLACE FUNCTION fn_hoithoai_ai_tra_loi(p_qna_id varchar, p_noi_dung text, p_nhan_vien_id_ho_tro varchar, p_tai_lieu_id varchar DEFAULT NULL)
RETURNS void LANGUAGE plpgsql AS $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM qna WHERE qna_id = p_qna_id) THEN RAISE EXCEPTION 'Tương tác Q&A không tồn tại.'; END IF;
  IF p_tai_lieu_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM tailieu WHERE tai_lieu_id = p_tai_lieu_id) THEN RAISE EXCEPTION 'Tài liệu nguồn không tồn tại.'; END IF;
  IF NOT EXISTS (SELECT 1 FROM nhanvien WHERE nhan_vien_id = p_nhan_vien_id_ho_tro AND trang_thai = 'ACTIVE' AND phong_ban IN ('CUSTOMER_SUPPORT','BAN_TO_CHUC','ACADEMIC')) THEN
    RAISE EXCEPTION 'Nhân viên phụ trách không hợp lệ hoặc không thuộc phòng ban hỗ trợ.'; END IF;
  PERFORM fn_set_audit_context_theo_nhanvien(p_nhan_vien_id_ho_tro);
  UPDATE qna SET noi_dung_tra_loi = p_noi_dung, tai_lieu_id = p_tai_lieu_id, nhan_vien_id_ho_tro = p_nhan_vien_id_ho_tro, trang_thai = 'DA_TRA_LOI'
  WHERE qna_id = p_qna_id;
END $$;

/* ================================================================
   MODULE 8. QUẢN LÝ FAQ
   ================================================================ */
CREATE OR REPLACE VIEW vw_faq_tongquan AS
  SELECT (SELECT count(*) FROM faq_canonical WHERE trang_thai = 'DA_DUYET') AS tong_cau_hoi,
         (SELECT COALESCE(sum(luot_xem), 0) FROM faq_canonical WHERE trang_thai = 'DA_DUYET') AS luot_xem_tich_luy,
         (SELECT round(100.0 * sum(CASE WHEN q.danh_gia_hai_long >= 4 THEN 1 ELSE 0 END) / NULLIF(count(q.danh_gia_hai_long), 0))::int
            FROM faq_canonical f JOIN qna q ON q.qna_id = f.nguon_qna_id WHERE f.trang_thai = 'DA_DUYET') AS tyle_huu_ich_pt;

CREATE OR REPLACE VIEW vw_faq_cay_danhmuc AS
  WITH RECURSIVE c AS (
    SELECT danh_muc_id, ten_danh_muc, danh_muc_cha_id, 0 AS cap, ten_danh_muc::text AS duong_dan FROM danhmuc WHERE danh_muc_cha_id IS NULL
    UNION ALL
    SELECT d.danh_muc_id, d.ten_danh_muc, d.danh_muc_cha_id, c.cap + 1, c.duong_dan || ' > ' || d.ten_danh_muc
    FROM danhmuc d JOIN c ON d.danh_muc_cha_id = c.danh_muc_id)
  SELECT c.*, (SELECT count(*) FROM faq_canonical f WHERE f.danh_muc = c.ten_danh_muc AND f.trang_thai = 'DA_DUYET') AS so_cau_hoi FROM c;

CREATE OR REPLACE FUNCTION fn_faq_danh_sach_theo_danh_muc(p_danh_muc_id varchar DEFAULT NULL) RETURNS SETOF faq_canonical LANGUAGE sql STABLE AS $$
  WITH RECURSIVE con AS (
    SELECT danh_muc_id, ten_danh_muc FROM danhmuc WHERE danh_muc_id = p_danh_muc_id
    UNION ALL SELECT d.danh_muc_id, d.ten_danh_muc FROM danhmuc d JOIN con c ON d.danh_muc_cha_id = c.danh_muc_id)
  SELECT f.* FROM faq_canonical f
  WHERE f.trang_thai = 'DA_DUYET' AND (p_danh_muc_id IS NULL OR f.danh_muc IN (SELECT ten_danh_muc FROM con))
  ORDER BY f.danh_muc, f.cau_hoi_chuan $$;

CREATE OR REPLACE FUNCTION fn_faq_tim_kiem(p_tu_khoa varchar) RETURNS SETOF faq_canonical LANGUAGE sql STABLE AS $$
  SELECT * FROM faq_canonical WHERE trang_thai = 'DA_DUYET'
    AND (unaccent(cau_hoi_chuan) ILIKE '%' || unaccent(p_tu_khoa) || '%' OR unaccent(cau_tra_loi_chuan) ILIKE '%' || unaccent(p_tu_khoa) || '%'
         OR unaccent(danh_muc) ILIKE '%' || unaccent(p_tu_khoa) || '%')
  ORDER BY luot_xem DESC $$;

CREATE OR REPLACE FUNCTION fn_faq_xem_chi_tiet(p_faq_id varchar) RETURNS SETOF faq_canonical LANGUAGE plpgsql AS $$
BEGIN
  UPDATE faq_canonical SET luot_xem = luot_xem + 1 WHERE faq_id = p_faq_id AND trang_thai = 'DA_DUYET';
  RETURN QUERY SELECT * FROM faq_canonical WHERE faq_id = p_faq_id;
END $$;

CREATE OR REPLACE FUNCTION fn_faq_sua(p_faq_id varchar, p_nguoi_sua varchar, p_danh_muc_id varchar DEFAULT NULL,
  p_cau_hoi_chuan varchar DEFAULT NULL, p_cau_tra_loi_chuan text DEFAULT NULL) RETURNS void LANGUAGE plpgsql AS $$
DECLARE v_ten_dm varchar;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM faq_canonical WHERE faq_id = p_faq_id) THEN RAISE EXCEPTION 'FAQ không tồn tại.'; END IF;
  IF NOT EXISTS (SELECT 1 FROM nhanvien WHERE nhan_vien_id = p_nguoi_sua AND trang_thai = 'ACTIVE') THEN RAISE EXCEPTION 'Người sửa không tồn tại hoặc đã INACTIVE.'; END IF;
  IF p_danh_muc_id IS NOT NULL THEN
    SELECT ten_danh_muc INTO v_ten_dm FROM danhmuc WHERE danh_muc_id = p_danh_muc_id;
    IF v_ten_dm IS NULL THEN RAISE EXCEPTION 'Danh mục không tồn tại.'; END IF;
  END IF;
  IF (p_cau_hoi_chuan IS NOT NULL AND btrim(p_cau_hoi_chuan) = '') OR (p_cau_tra_loi_chuan IS NOT NULL AND btrim(p_cau_tra_loi_chuan) = '') THEN
    RAISE EXCEPTION 'Câu hỏi / câu trả lời chuẩn không được để rỗng.'; END IF;
  PERFORM fn_set_audit_context_theo_nhanvien(p_nguoi_sua);
  UPDATE faq_canonical SET danh_muc = COALESCE(v_ten_dm, danh_muc), cau_hoi_chuan = COALESCE(p_cau_hoi_chuan, cau_hoi_chuan),
         cau_tra_loi_chuan = COALESCE(p_cau_tra_loi_chuan, cau_tra_loi_chuan) WHERE faq_id = p_faq_id;
END $$;

DROP FUNCTION IF EXISTS fn_faq_danh_gia_hai_long(varchar, smallint);
CREATE OR REPLACE FUNCTION fn_faq_danh_gia_hai_long(p_faq_id varchar, p_diem int) RETURNS void LANGUAGE plpgsql AS $$
BEGIN
  IF p_diem < 1 OR p_diem > 5 THEN RAISE EXCEPTION 'Điểm đánh giá phải từ 1 đến 5.'; END IF;
  IF NOT EXISTS (SELECT 1 FROM faq_canonical WHERE faq_id = p_faq_id AND nguon_qna_id IS NOT NULL) THEN
    RAISE EXCEPTION 'FAQ không tồn tại hoặc không có Q&A nguồn để ghi đánh giá.'; END IF;
  UPDATE qna q SET danh_gia_hai_long = p_diem::smallint FROM faq_canonical f WHERE f.nguon_qna_id = q.qna_id AND f.faq_id = p_faq_id;
END $$;