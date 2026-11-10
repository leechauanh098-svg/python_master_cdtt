-- =============================================================================
-- Source: supabase/migrations/005_kpi_rbac.sql
-- =============================================================================

/* ================================================================
   005_kpi_rbac.sql 
   ================================================================ */

/* ========== Nền tảng dùng chung ========== */
CREATE OR REPLACE FUNCTION fn_ky_bao_cao(p_ky varchar DEFAULT NULL) RETURNS TABLE (ky text, tu date, den date)
LANGUAGE plpgsql STABLE AS $$
DECLARE v_ky text := upper(COALESCE(p_ky, to_char(CURRENT_DATE, 'YYYY') || '-Q' || extract(quarter FROM CURRENT_DATE)::int::text)); v_tu date;
BEGIN
  IF v_ky !~ '^[0-9]{4}-Q[1-4]$' THEN RAISE EXCEPTION 'Kỳ báo cáo không hợp lệ. Định dạng đúng: YYYY-Qn (vd 2026-Q3).'; END IF;
  v_tu := make_date(left(v_ky, 4)::int, (substr(v_ky, 7, 1)::int - 1) * 3 + 1, 1);
  RETURN QUERY SELECT v_ky, v_tu, (v_tu + interval '3 months')::date;
END $$;

-- Giao dịch lệ phí thống nhất (THANHTOAN + DANGKYWEB chưa đồng bộ)
CREATE OR REPLACE VIEW vw_giao_dich_le_phi AS
  SELECT 'THANHTOAN'::text AS nguon, tt.thanh_toan_id, tt.giao_dich_id, tt.thi_sinh_id, tt.thi_sinh_id AS nguoi_key,
         tt.thoi_gian_thanh_toan, tt.so_tien, tt.bang_dau, tt.trang_thai_thanh_toan, ts.tinh_thanh, ts.truong_hoc,
         dkw.doanh_nghiep_id, dkw.hoa_hong
  FROM thanhtoan tt JOIN thisinh ts ON ts.thi_sinh_id = tt.thi_sinh_id LEFT JOIN dangkyweb dkw ON dkw.giao_dich_id = tt.giao_dich_id
  UNION ALL
  SELECT 'DANGKYWEB'::text, dkw.thanh_toan_id, dkw.giao_dich_id, dkw.thi_sinh_id, COALESCE(dkw.thi_sinh_id, dkw.giao_dich_id),
         dkw.thoi_gian_thanh_toan, dkw.so_tien, dkw.bang_dau, dkw.trang_thai_thanh_toan,
         COALESCE(ts.tinh_thanh, dkw.tinh_thanh), COALESCE(ts.truong_hoc, dkw.truong_hoc), dkw.doanh_nghiep_id, dkw.hoa_hong
  FROM dangkyweb dkw LEFT JOIN thisinh ts ON ts.thi_sinh_id = dkw.thi_sinh_id
  WHERE NOT EXISTS (SELECT 1 FROM thanhtoan tt WHERE tt.giao_dich_id = dkw.giao_dich_id);

-- Mỗi người và trạng thái chỉ tính một giao dịch, ưu tiên nguồn DANGKYWEB.
CREATE OR REPLACE FUNCTION fn_kpi_gd(p_tu date, p_den date) RETURNS SETOF vw_giao_dich_le_phi LANGUAGE sql STABLE AS $$
  SELECT x.nguon, x.thanh_toan_id, x.giao_dich_id, x.thi_sinh_id, x.nguoi_key, x.thoi_gian_thanh_toan, x.so_tien, x.bang_dau,
         x.trang_thai_thanh_toan, x.tinh_thanh, x.truong_hoc, x.doanh_nghiep_id, x.hoa_hong
  FROM (SELECT g.*, row_number() OVER (PARTITION BY g.nguoi_key, g.trang_thai_thanh_toan
                                       ORDER BY CASE g.nguon WHEN 'DANGKYWEB' THEN 0 ELSE 1 END, g.thoi_gian_thanh_toan) AS rn
        FROM vw_giao_dich_le_phi g WHERE g.thoi_gian_thanh_toan >= p_tu AND g.thoi_gian_thanh_toan < p_den) x
  WHERE x.rn = 1 $$;

CREATE OR REPLACE FUNCTION fn_doanh_thu_le_phi(p_tu date, p_den date) RETURNS numeric LANGUAGE sql STABLE AS $$
  SELECT COALESCE(sum(so_tien), 0) FROM fn_kpi_gd(p_tu, p_den) WHERE trang_thai_thanh_toan = 'THANH_TOAN_THANH_CONG' $$;

CREATE OR REPLACE FUNCTION fn_thuc_thu_tai_tro(p_tu date, p_den date) RETURNS numeric LANGUAGE sql STABLE AS $$
  SELECT COALESCE(sum(so_tien), 0) FROM doanhnghiep_pipeline WHERE giai_doan = 'THUC_THU'$$;

SELECT COALESCE(sum(so_tien),0) AS luy_ke_den_het_q3
FROM doanhnghiep_pipeline
WHERE giai_doan = 'THUC_THU' AND thoi_gian < '2026-10-01';

CREATE OR REPLACE FUNCTION fn_so_thi_sinh_tham_gia(p_tu date, p_den date) RETURNS bigint LANGUAGE sql STABLE AS $$
  SELECT count(DISTINCT nguoi_key) FROM vw_giao_dich_le_phi
  WHERE trang_thai_thanh_toan = 'THANH_TOAN_THANH_CONG' AND thoi_gian_thanh_toan >= p_tu AND thoi_gian_thanh_toan < p_den $$;

CREATE OR REPLACE VIEW vw_bainop_diem_pct AS
  SELECT bn.bai_nop_id, bn.thi_sinh_id, bn.bai_tap_id, bn.trang_thai, bn.thoi_gian_nop, bn.tong_diem, m.diem_toi_da,
         (bn.tong_diem * 100.0 / NULLIF(m.diem_toi_da, 0))::numeric(6,2) AS diem_pct
  FROM bainop bn LEFT JOIN LATERAL (SELECT sum(ch.diem_toi_da) AS diem_toi_da FROM cauhoi ch WHERE ch.bai_tap_id = bn.bai_tap_id) m ON true;

CREATE OR REPLACE FUNCTION fn_kpi_tham_gia(p_tu date, p_den date) RETURNS TABLE (nguoi_key varchar) LANGUAGE sql STABLE AS $$
  SELECT DISTINCT g.nguoi_key::varchar FROM vw_giao_dich_le_phi g
  WHERE g.trang_thai_thanh_toan = 'THANH_TOAN_THANH_CONG' AND g.thoi_gian_thanh_toan >= p_tu AND g.thoi_gian_thanh_toan < p_den $$;

CREATE OR REPLACE FUNCTION fn_kpi_dang_ky(p_tu date, p_den date) RETURNS TABLE (nguoi_key varchar) LANGUAGE sql STABLE AS $$
  SELECT thi_sinh_id::varchar FROM dangky WHERE trang_thai <> 'HUY_DANG_KY' AND ngay_dang_ky >= p_tu AND ngay_dang_ky < p_den
  UNION
  SELECT g.nguoi_key::varchar FROM vw_giao_dich_le_phi g
  WHERE g.trang_thai_thanh_toan IN ('CHO_THANH_TOAN','THANH_TOAN_THANH_CONG') AND g.thoi_gian_thanh_toan >= p_tu AND g.thoi_gian_thanh_toan < p_den $$;

/* ================================================================
   9.1 MÀN HÌNH TỔNG QUAN
   ================================================================ */
CREATE OR REPLACE FUNCTION fn_kpi_tongquan_chiso(p_ky varchar DEFAULT NULL)
RETURNS TABLE (thi_sinh_tham_gia_thuc_te bigint, thuc_thu_tai_tro numeric, doanh_thu_le_phi numeric, tong_thu numeric,
               ky_bao_cao text, tu_ngay date, den_ngay date, thoi_diem_cap_nhat timestamp) LANGUAGE sql STABLE AS $$
  WITH r AS (SELECT * FROM fn_ky_bao_cao(p_ky)),
  v AS (SELECT r.*, fn_thuc_thu_tai_tro(r.tu, r.den) AS tt, fn_doanh_thu_le_phi(r.tu, r.den) AS lp FROM r)
  SELECT fn_so_thi_sinh_tham_gia(v.tu, v.den), v.tt, v.lp, v.lp + v.tt, v.ky, v.tu, (v.den - 1), now()::timestamp FROM v $$;

CREATE OR REPLACE FUNCTION fn_kpi_tongquan_tin_hieu(p_ky varchar DEFAULT NULL) RETURNS TABLE (nhom_tin_hieu text, noi_dung text) LANGUAGE sql STABLE AS $$
  WITH r AS (SELECT * FROM fn_ky_bao_cao(p_ky)),
  v AS (SELECT fn_thuc_thu_tai_tro(r.tu, r.den) AS nay, fn_thuc_thu_tai_tro((r.tu - interval '3 months')::date, r.tu) AS truoc FROM r)
  SELECT 'TÀI TRỢ'::text,
         CASE WHEN v.truoc = 0 THEN 'Thực thu tài trợ ' || to_char(v.nay, 'FM999,999,999,999,990') || ' (kỳ trước chưa có dữ liệu).'
              ELSE 'Tài trợ ' || CASE WHEN v.nay >= v.truoc THEN 'tăng ' ELSE 'giảm ' END
                   || to_char(abs(v.nay - v.truoc) * 100.0 / v.truoc, 'FM990.0') || '% so với kỳ trước.' END
  FROM v
  UNION ALL
  SELECT 'DOANH THU', count(*)::text || ' giao dịch đang chờ đối soát.' FROM vw_giao_dich_le_phi WHERE trang_thai_thanh_toan = 'CHO_THANH_TOAN' $$;

CREATE OR REPLACE FUNCTION fn_kpi_tongquan_tien_do(p_ky varchar DEFAULT NULL)
RETURNS TABLE (kpi_id varchar, nhom varchar, ten_kpi varchar, muc_tieu numeric, gia_tri_hien_tai numeric, hoan_thanh_pct numeric) LANGUAGE sql STABLE AS $$
  WITH r AS (SELECT * FROM fn_ky_bao_cao(p_ky))
  SELECT k.kpi_id, k.nhom, k.ten_kpi, k.muc_tieu, v.gt,
         (CASE WHEN k.muc_tieu > 0 THEN v.gt * 100.0 / k.muc_tieu ELSE 0 END)::numeric(12,2)
  FROM r CROSS JOIN kpi_muctieu k
  CROSS JOIN LATERAL (SELECT CASE k.nhom
      WHEN 'THI_SINH' THEN fn_so_thi_sinh_tham_gia(r.tu, r.den)::numeric
      WHEN 'DOANH_NGHIEP' THEN (SELECT count(DISTINCT doanh_nghiep_id) FROM doanhnghiep_pipeline
                                WHERE giai_doan = 'KY_HOP_DONG' AND thoi_gian >= r.tu AND thoi_gian < r.den)::numeric
      WHEN 'DOANH_THU' THEN fn_doanh_thu_le_phi(r.tu, r.den) END AS gt) v
  WHERE k.ky_bao_cao = r.ky ORDER BY k.nhom, k.kpi_id $$;

/* ================================================================
   9.2 KPI THÍ SINH
   ================================================================ */
CREATE OR REPLACE FUNCTION fn_kpi_thisinh_tong_quan(p_ky varchar DEFAULT NULL)
RETURNS TABLE (tong_tiep_can bigint, dang_ky_thi bigint, tham_gia_thuc_te bigint, ty_le_tham_gia_pct numeric) LANGUAGE sql STABLE AS $$
  WITH r AS (SELECT * FROM fn_ky_bao_cao(p_ky)),
  tc AS (SELECT count(*) AS n FROM r, fn_tiep_can(r.tu, r.den)),
  dk AS (SELECT count(*) AS n FROM r, fn_kpi_dang_ky(r.tu, r.den)),
  tg AS (SELECT count(*) AS n FROM r, fn_kpi_tham_gia(r.tu, r.den))
  SELECT tc.n, dk.n, tg.n, (tg.n * 100.0 / NULLIF(dk.n, 0))::numeric(5,2) FROM tc, dk, tg $$;

CREATE OR REPLACE FUNCTION fn_kpi_thisinh_pheu(p_ky varchar DEFAULT NULL)
RETURNS TABLE (buoc text, so_luong bigint, ty_le_so_voi_tiep_can_pct numeric, thu_tu int) LANGUAGE sql STABLE AS $$
  WITH r AS (SELECT * FROM fn_ky_bao_cao(p_ky)),
  tc AS (SELECT count(*) AS n FROM r, fn_tiep_can(r.tu, r.den)),
  dk AS (SELECT count(*) AS n FROM r, fn_kpi_dang_ky(r.tu, r.den)),
  tg AS (SELECT count(*) AS n FROM r, fn_kpi_tham_gia(r.tu, r.den)),
  ht AS (SELECT count(DISTINCT bn.thi_sinh_id) AS n FROM bainop bn, r
         WHERE bn.trang_thai = 'DA_CHAM_DIEM' AND bn.thoi_gian_nop >= r.tu AND bn.thoi_gian_nop < r.den),
  v(buoc, so_luong, thu_tu) AS (
    SELECT 'Tiếp cận'::text, tc.n, 1 FROM tc
    UNION ALL SELECT 'Đăng ký thi', dk.n, 2 FROM dk
    UNION ALL SELECT 'Tham gia thực tế (thanh toán thành công)', tg.n, 3 FROM tg
    UNION ALL SELECT 'Hoàn thành (bài nộp đã chấm điểm)', ht.n, 4 FROM ht)
  SELECT v.buoc, v.so_luong, (v.so_luong * 100.0 / NULLIF((SELECT n FROM tc), 0))::numeric(6,1), v.thu_tu FROM v ORDER BY v.thu_tu $$;

CREATE OR REPLACE FUNCTION fn_kpi_thisinh_theo_truong(p_ky varchar DEFAULT NULL, p_nguong_xuat_sac_pct numeric DEFAULT 80)
RETURNS TABLE (truong_hoc varchar, tong_thi_sinh bigint, so_dang_ky bigint, so_da_duyet bigint, so_tham_gia bigint, so_xuat_sac bigint,
               ty_le_tham_gia_pct numeric) LANGUAGE sql STABLE AS $$
  WITH r AS (SELECT * FROM fn_ky_bao_cao(p_ky)),
  dk AS (SELECT d.nguoi_key FROM r, fn_kpi_dang_ky(r.tu, r.den) d),
  tg AS (SELECT t.nguoi_key FROM r, fn_kpi_tham_gia(r.tu, r.den) t),
  xs AS (SELECT DISTINCT b.thi_sinh_id FROM vw_bainop_diem_pct b, r
         WHERE b.trang_thai = 'DA_CHAM_DIEM' AND b.thoi_gian_nop >= r.tu AND b.thoi_gian_nop < r.den AND b.diem_pct >= p_nguong_xuat_sac_pct),
  f AS (SELECT ts.truong_hoc, ts.trang_thai_ho_so,
               (ts.thi_sinh_id IN (SELECT nguoi_key FROM dk))::int AS da_dk,
               (ts.thi_sinh_id IN (SELECT nguoi_key FROM tg))::int AS da_tg,
               (ts.thi_sinh_id IN (SELECT thi_sinh_id FROM xs))::int AS xs
        FROM thisinh ts WHERE ts.truong_hoc IS NOT NULL)
  SELECT f.truong_hoc, count(*), sum(f.da_dk), sum(CASE WHEN f.trang_thai_ho_so = 'DA_DUYET' THEN 1 ELSE 0 END), sum(f.da_tg), sum(f.xs),
         (sum(f.da_tg) * 100.0 / NULLIF(sum(f.da_dk), 0))::numeric(5,2)
  FROM f GROUP BY f.truong_hoc ORDER BY sum(f.da_dk) DESC, count(*) DESC $$;

CREATE OR REPLACE FUNCTION fn_kpi_thisinh_top1pct(p_ky varchar DEFAULT NULL)
RETURNS TABLE (thi_sinh_id varchar, ho_ten varchar, truong_hoc varchar, bang_dau varchar, diem_pct numeric) LANGUAGE sql STABLE AS $$
  WITH r AS (SELECT * FROM fn_ky_bao_cao(p_ky)),
  x AS (SELECT b.thi_sinh_id, max(b.diem_pct) AS diem_pct FROM vw_bainop_diem_pct b, r
        WHERE b.trang_thai = 'DA_CHAM_DIEM' AND b.diem_pct IS NOT NULL AND b.thoi_gian_nop >= r.tu AND b.thoi_gian_nop < r.den GROUP BY b.thi_sinh_id),
  rk AS (SELECT x.*, row_number() OVER (ORDER BY x.diem_pct DESC) AS rn, count(*) OVER () AS tot FROM x)
  SELECT ts.thi_sinh_id, ts.ho_ten, ts.truong_hoc, ts.bang_dau, rk.diem_pct
  FROM rk JOIN thisinh ts ON ts.thi_sinh_id = rk.thi_sinh_id WHERE rk.rn <= ceil(rk.tot * 0.01) ORDER BY rk.diem_pct DESC $$;

CREATE OR REPLACE FUNCTION fn_kpi_thisinh_utm_roi(p_ky varchar DEFAULT NULL)
RETURNS TABLE (nguon_utm varchar, chien_dich varchar, luot_tiep_can bigint, so_dang_ky bigint, chi_phi numeric, doanh_thu numeric, roi_pct numeric)
LANGUAGE sql STABLE AS $$
  WITH r AS (SELECT * FROM fn_ky_bao_cao(p_ky))
  SELECT x.nguon_utm, x.chien_dich, x.luot, x.dk, x.chi_phi, x.doanh_thu,
         ((x.doanh_thu - x.chi_phi) * 100.0 / NULLIF(x.chi_phi, 0))::numeric(10,2)
  FROM (
    SELECT qc.nen_tang AS nguon_utm, qc.chien_dich, count(*) AS luot,
           sum(CASE WHEN EXISTS (SELECT 1 FROM vw_giao_dich_le_phi g WHERE g.thi_sinh_id = qc.thi_sinh_id
                                 AND g.trang_thai_thanh_toan IN ('CHO_THANH_TOAN','THANH_TOAN_THANH_CONG')) THEN 1 ELSE 0 END) AS dk,
           sum(COALESCE(qc.chi_phi, 0)) AS chi_phi,
           sum(COALESCE((SELECT sum(g.so_tien) FROM vw_giao_dich_le_phi g WHERE g.thi_sinh_id = qc.thi_sinh_id
                         AND g.trang_thai_thanh_toan = 'THANH_TOAN_THANH_CONG'), 0)) AS doanh_thu
    FROM r, quangcao qc JOIN bieumau bm ON bm.bieu_mau_log = qc.bieu_mau_log
    WHERE bm.dau_thoi_gian >= r.tu AND bm.dau_thoi_gian < r.den
    GROUP BY qc.nen_tang, qc.chien_dich) x
  ORDER BY x.luot DESC $$;

CREATE OR REPLACE FUNCTION fn_kpi_thisinh_pho_diem(p_ky varchar DEFAULT NULL) RETURNS TABLE (khoang_diem text, so_luong bigint) LANGUAGE sql STABLE AS $$
  WITH r AS (SELECT * FROM fn_ky_bao_cao(p_ky)),
  kd(bin, khoang_diem) AS (VALUES (1,'0-20%'),(2,'20-40%'),(3,'40-60%'),(4,'60-80%'),(5,'80-100%')),
  b AS (SELECT CASE WHEN v.diem_pct < 20 THEN 1 WHEN v.diem_pct < 40 THEN 2 WHEN v.diem_pct < 60 THEN 3 WHEN v.diem_pct < 80 THEN 4 ELSE 5 END AS bin
        FROM vw_bainop_diem_pct v, r
        WHERE v.diem_pct IS NOT NULL AND v.trang_thai = 'DA_CHAM_DIEM' AND v.thoi_gian_nop >= r.tu AND v.thoi_gian_nop < r.den)
  SELECT kd.khoang_diem, count(b.bin) FROM kd LEFT JOIN b ON b.bin = kd.bin GROUP BY kd.bin, kd.khoang_diem ORDER BY kd.bin $$;

CREATE OR REPLACE FUNCTION fn_kpi_thisinh_truong_bang(p_ky varchar DEFAULT NULL, p_nguong_xuat_sac_pct numeric DEFAULT 80)
RETURNS TABLE (truong_hoc varchar, bang_dau varchar, so_thi_sinh bigint, ty_le_xuat_sac_pct numeric) LANGUAGE sql STABLE AS $$
  WITH r AS (SELECT * FROM fn_ky_bao_cao(p_ky))
  SELECT ts.truong_hoc, ts.bang_dau, count(DISTINCT ts.thi_sinh_id),
         (count(DISTINCT CASE WHEN b.diem_pct >= p_nguong_xuat_sac_pct THEN b.thi_sinh_id END) * 100.0 / NULLIF(count(DISTINCT b.thi_sinh_id), 0))::numeric(5,2)
  FROM r CROSS JOIN thisinh ts
  LEFT JOIN vw_bainop_diem_pct b ON b.thi_sinh_id = ts.thi_sinh_id AND b.trang_thai = 'DA_CHAM_DIEM' AND b.thoi_gian_nop >= r.tu AND b.thoi_gian_nop < r.den
  WHERE ts.truong_hoc IS NOT NULL GROUP BY ts.truong_hoc, ts.bang_dau ORDER BY count(DISTINCT ts.thi_sinh_id) DESC $$;

CREATE OR REPLACE FUNCTION fn_kpi_thisinh_tien_do(p_ky varchar DEFAULT NULL)
RETURNS TABLE (kpi_id varchar, ten_kpi varchar, muc_tieu numeric, gia_tri_hien_tai bigint, hoan_thanh_pct numeric) LANGUAGE sql STABLE AS $$
  WITH r AS (SELECT * FROM fn_ky_bao_cao(p_ky)), tg AS (SELECT count(*) AS n FROM r, fn_kpi_tham_gia(r.tu, r.den))
  SELECT k.kpi_id, k.ten_kpi, k.muc_tieu, tg.n, (tg.n * 100.0 / NULLIF(k.muc_tieu, 0))::numeric(7,2)
  FROM r CROSS JOIN tg JOIN kpi_muctieu k ON k.nhom = 'THI_SINH' AND k.ky_bao_cao = r.ky $$;

/* ================================================================
   9.3 KPI TÀI TRỢ
   ================================================================ */
CREATE OR REPLACE FUNCTION fn_kpi_taitro_tong_quan(p_ky varchar DEFAULT NULL)
RETURNS TABLE (tong_doanh_nghiep bigint, so_nha_tai_tro bigint, so_doi_tac_cung_cap bigint, thuc_thu_tai_tro numeric,
               doanh_thu_tu_doi_tac numeric, hoa_hong_doi_tac numeric, hop_dong_da_ky bigint, brand_reach numeric) LANGUAGE sql STABLE AS $$
  WITH r AS (SELECT * FROM fn_ky_bao_cao(p_ky))
  SELECT (SELECT count(*) FROM doanhnghiep),
         (SELECT count(*) FROM doanhnghiep WHERE hinh_thuc = 'TAI_TRO_DONG_HANH'),
         (SELECT count(*) FROM doanhnghiep WHERE hinh_thuc = 'CUNG_CAP_THI_SINH'),
         fn_thuc_thu_tai_tro(r.tu, r.den),
         (SELECT COALESCE(sum(so_tien), 0) FROM vw_giao_dich_le_phi WHERE doanh_nghiep_id IS NOT NULL AND trang_thai_thanh_toan = 'THANH_TOAN_THANH_CONG'
            AND thoi_gian_thanh_toan >= r.tu AND thoi_gian_thanh_toan < r.den),
         (SELECT COALESCE(sum(hoa_hong), 0) FROM vw_giao_dich_le_phi WHERE doanh_nghiep_id IS NOT NULL AND trang_thai_thanh_toan = 'THANH_TOAN_THANH_CONG'
            AND thoi_gian_thanh_toan >= r.tu AND thoi_gian_thanh_toan < r.den),
         (SELECT count(DISTINCT doanh_nghiep_id) FROM doanhnghiep_pipeline WHERE giai_doan = 'KY_HOP_DONG' AND thoi_gian >= r.tu AND thoi_gian < r.den),
         (SELECT COALESCE(sum(luot_hien_thi), 0) FROM truyenthong_taitro WHERE ngay >= r.tu AND ngay < r.den)::numeric
  FROM r $$;

CREATE OR REPLACE FUNCTION fn_kpi_taitro_pheu(p_ky varchar DEFAULT NULL)
RETURNS TABLE (giai_doan text, so_doanh_nghiep bigint, ty_le_pct numeric, thu_tu int) LANGUAGE sql STABLE AS $$
  WITH r AS (SELECT * FROM fn_ky_bao_cao(p_ky)),
  tc AS (SELECT count(DISTINCT doanh_nghiep_id) AS n FROM doanhnghiep_pipeline, r WHERE giai_doan = 'TIEP_CAN' AND thoi_gian >= r.tu AND thoi_gian < r.den),
  g(ma, ten, thu_tu) AS (VALUES ('TIEP_CAN','Tiếp cận',1),('DAM_PHAN','Đàm phán',2),('DE_XUAT_GUI','Đã gửi đề xuất',3),('KY_HOP_DONG','Đã ký hợp đồng',4),('THUC_THU','Đã thực thu',5))
  SELECT g.ten::text, COALESCE(x.n, 0), (COALESCE(x.n, 0) * 100.0 / NULLIF((SELECT n FROM tc), 0))::numeric(6,1), g.thu_tu
  FROM g CROSS JOIN r
  LEFT JOIN LATERAL (SELECT count(DISTINCT p.doanh_nghiep_id) AS n FROM doanhnghiep_pipeline p
                     WHERE p.giai_doan = g.ma AND p.thoi_gian >= r.tu AND p.thoi_gian < r.den) x ON true
  ORDER BY g.thu_tu $$;

CREATE OR REPLACE FUNCTION fn_kpi_taitro_co_cau_cap() RETURNS TABLE (cap_do_tai_tro varchar, so_luong bigint) LANGUAGE sql STABLE AS $$
  SELECT cap_do_tai_tro, count(*) FROM doanhnghiep WHERE hinh_thuc = 'TAI_TRO_DONG_HANH' GROUP BY cap_do_tai_tro ORDER BY 2 DESC $$;

CREATE OR REPLACE FUNCTION fn_kpi_taitro_nha_tai_tro(p_ky varchar DEFAULT NULL)
RETURNS TABLE (doanh_nghiep_id varchar, ten_doanh_nghiep varchar, cap_do_tai_tro varchar, loai_tai_tro varchar, thuc_thu numeric,
               brand_reach numeric, luot_tuong_tac numeric) LANGUAGE sql STABLE AS $$
  WITH r AS (SELECT * FROM fn_ky_bao_cao(p_ky))
  SELECT dn.doanh_nghiep_id, dn.ten_doanh_nghiep, dn.cap_do_tai_tro, dn.loai_tai_tro, COALESCE(p.thuc_thu, 0),
         COALESCE(t.hien_thi, 0)::numeric, COALESCE(t.tuong_tac, 0)::numeric
  FROM r CROSS JOIN doanhnghiep dn
  LEFT JOIN LATERAL (SELECT sum(so_tien) AS thuc_thu FROM doanhnghiep_pipeline p WHERE p.doanh_nghiep_id = dn.doanh_nghiep_id
                     AND p.giai_doan = 'THUC_THU' AND p.thoi_gian >= r.tu AND p.thoi_gian < r.den) p ON true
  LEFT JOIN LATERAL (SELECT sum(luot_hien_thi) AS hien_thi, sum(luot_tuong_tac) AS tuong_tac FROM truyenthong_taitro t
                     WHERE t.doanh_nghiep_id = dn.doanh_nghiep_id AND t.ngay >= r.tu AND t.ngay < r.den) t ON true
  WHERE dn.hinh_thuc = 'TAI_TRO_DONG_HANH' ORDER BY 5 DESC $$;

CREATE OR REPLACE FUNCTION fn_kpi_taitro_ds_doi_tac(p_ky varchar DEFAULT NULL)
RETURNS TABLE (doanh_nghiep_id varchar, ten_doanh_nghiep varchar, hinh_thuc varchar, so_thi_sinh_cung_cap bigint, doanh_thu numeric, hoa_hong numeric)
LANGUAGE sql STABLE AS $$
  WITH r AS (SELECT * FROM fn_ky_bao_cao(p_ky)),
  g AS (SELECT v.doanh_nghiep_id, count(DISTINCT v.nguoi_key) AS so_ts, sum(v.so_tien) AS dt, sum(v.hoa_hong) AS hh
        FROM vw_giao_dich_le_phi v, r WHERE v.trang_thai_thanh_toan = 'THANH_TOAN_THANH_CONG' AND v.thoi_gian_thanh_toan >= r.tu AND v.thoi_gian_thanh_toan < r.den
        GROUP BY v.doanh_nghiep_id)
  SELECT dn.doanh_nghiep_id, dn.ten_doanh_nghiep, dn.hinh_thuc, COALESCE(g.so_ts, 0), COALESCE(g.dt, 0), COALESCE(g.hh, 0)
  FROM doanhnghiep dn LEFT JOIN g ON g.doanh_nghiep_id = dn.doanh_nghiep_id ORDER BY 5 DESC $$;

CREATE OR REPLACE FUNCTION fn_kpi_taitro_doanh_thu_tinh(p_ky varchar DEFAULT NULL)
RETURNS TABLE (tinh_thanh text, doanh_thu numeric, ty_le_pct numeric) LANGUAGE sql STABLE AS $$
  WITH r AS (SELECT * FROM fn_ky_bao_cao(p_ky))
  SELECT COALESCE(v.tinh_thanh, 'Chưa xác định')::text, sum(v.so_tien), (sum(v.so_tien) * 100.0 / NULLIF(sum(sum(v.so_tien)) OVER (), 0))::numeric(5,2)
  FROM vw_giao_dich_le_phi v, r
  WHERE v.doanh_nghiep_id IS NOT NULL AND v.trang_thai_thanh_toan = 'THANH_TOAN_THANH_CONG' AND v.thoi_gian_thanh_toan >= r.tu AND v.thoi_gian_thanh_toan < r.den
  GROUP BY COALESCE(v.tinh_thanh, 'Chưa xác định') ORDER BY 2 DESC $$;

CREATE OR REPLACE FUNCTION fn_kpi_taitro_xu_huong(p_ky varchar DEFAULT NULL)
RETURNS TABLE (ngay date, bang_dau varchar, so_dang_ky bigint, doanh_thu numeric) LANGUAGE sql STABLE AS $$
  WITH r AS (SELECT * FROM fn_ky_bao_cao(p_ky)),
  registrations AS (
    SELECT dk.ngay_dang_ky::date AS ngay,
           COALESCE(ct.bang_dau, 'TẤT CẢ (CHUNG KẾT)')::varchar AS bang_dau,
           count(DISTINCT dk.dang_ky_id)::bigint AS so_dang_ky
    FROM dangky dk
    JOIN cuocthi ct ON ct.cuoc_thi_id = dk.cuoc_thi_id
    CROSS JOIN r
    WHERE dk.trang_thai <> 'HUY_DANG_KY'
      AND dk.ngay_dang_ky >= r.tu AND dk.ngay_dang_ky < r.den
    GROUP BY dk.ngay_dang_ky::date, COALESCE(ct.bang_dau, 'TẤT CẢ (CHUNG KẾT)')
  ),
  sponsor_revenue AS (
    SELECT v.thoi_gian_thanh_toan::date AS ngay,
           COALESCE(v.bang_dau, 'TẤT CẢ (CHUNG KẾT)')::varchar AS bang_dau,
           sum(v.so_tien)::numeric AS doanh_thu
    FROM vw_giao_dich_le_phi v
    CROSS JOIN r
    WHERE v.doanh_nghiep_id IS NOT NULL
      AND v.trang_thai_thanh_toan = 'THANH_TOAN_THANH_CONG'
      AND v.thoi_gian_thanh_toan >= r.tu AND v.thoi_gian_thanh_toan < r.den
    GROUP BY v.thoi_gian_thanh_toan::date, COALESCE(v.bang_dau, 'TẤT CẢ (CHUNG KẾT)')
  )
  SELECT COALESCE(registrations.ngay, sponsor_revenue.ngay),
         COALESCE(registrations.bang_dau, sponsor_revenue.bang_dau),
         COALESCE(registrations.so_dang_ky, 0),
         COALESCE(sponsor_revenue.doanh_thu, 0)
  FROM registrations
  FULL OUTER JOIN sponsor_revenue USING (ngay, bang_dau)
  ORDER BY 1, 2 $$;

CREATE OR REPLACE FUNCTION fn_kpi_taitro_doanh_thu_ngay(p_ky varchar DEFAULT NULL)
RETURNS TABLE (ngay date, da_thanh_toan numeric, cho_thanh_toan numeric, hoa_hong_doi_tac numeric, cong_ty_giu_lai numeric) LANGUAGE sql STABLE AS $$
  WITH r AS (SELECT * FROM fn_ky_bao_cao(p_ky))
  SELECT v.thoi_gian_thanh_toan::date,
         COALESCE(sum(CASE WHEN v.trang_thai_thanh_toan = 'THANH_TOAN_THANH_CONG' THEN v.so_tien END), 0),
         COALESCE(sum(CASE WHEN v.trang_thai_thanh_toan = 'CHO_THANH_TOAN' THEN v.so_tien END), 0),
         COALESCE(sum(CASE WHEN v.trang_thai_thanh_toan = 'THANH_TOAN_THANH_CONG' THEN COALESCE(v.hoa_hong, 0) END), 0),
         COALESCE(sum(CASE WHEN v.trang_thai_thanh_toan = 'THANH_TOAN_THANH_CONG' THEN v.so_tien - COALESCE(v.hoa_hong, 0) END), 0)
  FROM vw_giao_dich_le_phi v, r
  WHERE v.doanh_nghiep_id IS NOT NULL AND v.thoi_gian_thanh_toan >= r.tu AND v.thoi_gian_thanh_toan < r.den
  GROUP BY v.thoi_gian_thanh_toan::date ORDER BY 1 $$;

CREATE OR REPLACE FUNCTION fn_kpi_taitro_thi_sinh_khu_vuc(p_ky varchar DEFAULT NULL)
RETURNS TABLE (khu_vuc text, so_thi_sinh bigint) LANGUAGE sql STABLE AS $$
  WITH r AS (SELECT * FROM fn_ky_bao_cao(p_ky))
  SELECT COALESCE(v.tinh_thanh, 'Chưa xác định')::text, count(DISTINCT v.nguoi_key) FROM vw_giao_dich_le_phi v, r
  WHERE v.doanh_nghiep_id IS NOT NULL AND v.trang_thai_thanh_toan = 'THANH_TOAN_THANH_CONG' AND v.thoi_gian_thanh_toan >= r.tu AND v.thoi_gian_thanh_toan < r.den
  GROUP BY COALESCE(v.tinh_thanh, 'Chưa xác định') ORDER BY 2 DESC $$;

CREATE OR REPLACE FUNCTION fn_kpi_taitro_tien_do(p_ky varchar DEFAULT NULL)
RETURNS TABLE (kpi_id varchar, ten_kpi varchar, muc_tieu numeric, gia_tri_hien_tai bigint, hoan_thanh_pct numeric) LANGUAGE sql STABLE AS $$
  WITH r AS (SELECT * FROM fn_ky_bao_cao(p_ky)),
  hd AS (SELECT count(DISTINCT doanh_nghiep_id) AS n FROM doanhnghiep_pipeline, r WHERE giai_doan = 'KY_HOP_DONG' AND thoi_gian >= r.tu AND thoi_gian < r.den)
  SELECT k.kpi_id, k.ten_kpi, k.muc_tieu, hd.n, (hd.n * 100.0 / NULLIF(k.muc_tieu, 0))::numeric(12,2)
  FROM r CROSS JOIN hd JOIN kpi_muctieu k ON k.nhom = 'DOANH_NGHIEP' AND k.ky_bao_cao = r.ky $$;

/* ================================================================
   9.4 KPI DOANH THU (lệ phí thi)
   ================================================================ */
CREATE OR REPLACE FUNCTION fn_kpi_doanhthu_tong_quan(p_ky varchar DEFAULT NULL)
RETURNS TABLE (tong_doanh_thu numeric, giao_dich_thanh_cong bigint, dang_doi_soat bigint, gia_tri_trung_binh numeric) LANGUAGE sql STABLE AS $$
  WITH r AS (SELECT * FROM fn_ky_bao_cao(p_ky)), gd AS (SELECT g.* FROM r, fn_kpi_gd(r.tu, r.den) g),
  s AS (SELECT COALESCE(sum(so_tien) FILTER (WHERE trang_thai_thanh_toan = 'THANH_TOAN_THANH_CONG'), 0) AS dt,
               count(*) FILTER (WHERE trang_thai_thanh_toan = 'THANH_TOAN_THANH_CONG') AS n_tt,
               count(*) FILTER (WHERE trang_thai_thanh_toan = 'CHO_THANH_TOAN') AS n_cho FROM gd)
  SELECT s.dt, s.n_tt, s.n_cho, (s.dt / NULLIF(s.n_tt, 0))::numeric(15,2) FROM s $$;

CREATE OR REPLACE FUNCTION fn_kpi_doanhthu_pheu(p_ky varchar DEFAULT NULL)
RETURNS TABLE (buoc text, so_luong bigint, ty_le_pct numeric, thu_tu int) LANGUAGE sql STABLE AS $$
  WITH r AS (SELECT * FROM fn_ky_bao_cao(p_ky)), gd AS (SELECT g.* FROM r, fn_kpi_gd(r.tu, r.den) g),
  dk AS (SELECT thi_sinh_id AS k FROM dangky, r WHERE trang_thai <> 'HUY_DANG_KY' AND ngay_dang_ky >= r.tu AND ngay_dang_ky < r.den
         UNION SELECT nguoi_key FROM gd WHERE trang_thai_thanh_toan IN ('CHO_THANH_TOAN','THANH_TOAN_THANH_CONG')),
  v(buoc, so_luong, thu_tu) AS (
    SELECT 'Đăng ký'::text, (SELECT count(*) FROM dk), 1
    UNION ALL SELECT 'Có giao dịch thanh toán', (SELECT count(*) FROM gd WHERE trang_thai_thanh_toan IN ('CHO_THANH_TOAN','THANH_TOAN_THANH_CONG')), 2
    UNION ALL SELECT 'Thanh toán thành công', (SELECT count(*) FROM gd WHERE trang_thai_thanh_toan = 'THANH_TOAN_THANH_CONG'), 3)
  SELECT v.buoc, v.so_luong, (v.so_luong * 100.0 / NULLIF((SELECT count(*) FROM dk), 0))::numeric(6,1), v.thu_tu FROM v ORDER BY v.thu_tu $$;

CREATE OR REPLACE FUNCTION fn_kpi_doanhthu_theo_khu_vuc(p_ky varchar DEFAULT NULL) RETURNS TABLE (tinh_thanh text, doanh_thu numeric) LANGUAGE sql STABLE AS $$
  WITH r AS (SELECT * FROM fn_ky_bao_cao(p_ky))
  SELECT COALESCE(g.tinh_thanh, 'Chưa xác định')::text, sum(g.so_tien) FROM r, fn_kpi_gd(r.tu, r.den) g
  WHERE g.trang_thai_thanh_toan = 'THANH_TOAN_THANH_CONG' GROUP BY COALESCE(g.tinh_thanh, 'Chưa xác định') ORDER BY 2 DESC $$;

CREATE OR REPLACE FUNCTION fn_kpi_doanhthu_xu_huong(p_ky varchar DEFAULT NULL)
RETURNS TABLE (ngay date, so_dang_ky bigint, so_giao_dich bigint, doanh_thu numeric) LANGUAGE sql STABLE AS $$
  WITH r AS (SELECT * FROM fn_ky_bao_cao(p_ky)),
  dk AS (SELECT ngay_dang_ky::date AS ngay, count(*) AS so_dk FROM dangky, r
         WHERE trang_thai <> 'HUY_DANG_KY' AND ngay_dang_ky >= r.tu AND ngay_dang_ky < r.den GROUP BY ngay_dang_ky::date),
  dt AS (SELECT g.thoi_gian_thanh_toan::date AS ngay, count(*) AS so_gd, sum(g.so_tien) AS dt FROM r, fn_kpi_gd(r.tu, r.den) g
         WHERE g.trang_thai_thanh_toan = 'THANH_TOAN_THANH_CONG' GROUP BY g.thoi_gian_thanh_toan::date)
  SELECT COALESCE(dk.ngay, dt.ngay), COALESCE(dk.so_dk, 0), COALESCE(dt.so_gd, 0), COALESCE(dt.dt, 0)
  FROM dk FULL OUTER JOIN dt ON dk.ngay = dt.ngay ORDER BY 1 $$;

CREATE OR REPLACE FUNCTION fn_kpi_doanhthu_tien_do(p_ky varchar DEFAULT NULL)
RETURNS TABLE (kpi_id varchar, ten_kpi varchar, muc_tieu numeric, gia_tri_hien_tai numeric, hoan_thanh_pct numeric) LANGUAGE sql STABLE AS $$
  WITH r AS (SELECT * FROM fn_ky_bao_cao(p_ky))
  SELECT k.kpi_id, k.ten_kpi, k.muc_tieu, fn_doanh_thu_le_phi(r.tu, r.den), (fn_doanh_thu_le_phi(r.tu, r.den) * 100.0 / NULLIF(k.muc_tieu, 0))::numeric(12,2)
  FROM r JOIN kpi_muctieu k ON k.nhom = 'DOANH_THU' AND k.ky_bao_cao = r.ky $$;

CREATE OR REPLACE FUNCTION fn_kpi_doanhthu_cho_doi_soat_48h(p_ky varchar DEFAULT NULL)
RETURNS TABLE (nguon text, thanh_toan_id varchar, giao_dich_id varchar, thi_sinh_id varchar, so_tien numeric, thoi_gian_thanh_toan timestamp)
LANGUAGE sql STABLE AS $$
  WITH r AS (SELECT * FROM fn_ky_bao_cao(p_ky))
  SELECT g.nguon, g.thanh_toan_id, g.giao_dich_id, g.thi_sinh_id, g.so_tien, g.thoi_gian_thanh_toan FROM r, fn_kpi_gd(r.tu, r.den) g
  WHERE g.trang_thai_thanh_toan = 'CHO_THANH_TOAN' AND g.thoi_gian_thanh_toan < now() - interval '48 hours' ORDER BY g.thoi_gian_thanh_toan ASC $$;

CREATE OR REPLACE FUNCTION fn_kpi_doanhthu_theo_kenh(p_ky varchar DEFAULT NULL)
RETURNS TABLE (kenh text, so_luong bigint, doanh_thu numeric, ty_le_pct numeric) LANGUAGE sql STABLE AS $$
  WITH r AS (SELECT * FROM fn_ky_bao_cao(p_ky))
  SELECT COALESCE(c.nen_tang, 'Trực tiếp / Không xác định')::text, count(*), sum(g.so_tien), (sum(g.so_tien) * 100.0 / NULLIF(sum(sum(g.so_tien)) OVER (), 0))::numeric(5,2)
  FROM r CROSS JOIN LATERAL fn_kpi_gd(r.tu, r.den) g
  LEFT JOIN LATERAL (SELECT qc.nen_tang FROM quangcao qc LEFT JOIN bieumau bm ON bm.bieu_mau_log = qc.bieu_mau_log
                     WHERE qc.thi_sinh_id = g.thi_sinh_id ORDER BY bm.dau_thoi_gian DESC NULLS LAST LIMIT 1) c ON true
  WHERE g.trang_thai_thanh_toan = 'THANH_TOAN_THANH_CONG' GROUP BY COALESCE(c.nen_tang, 'Trực tiếp / Không xác định') ORDER BY 3 DESC $$;

CREATE OR REPLACE FUNCTION fn_kpi_doanhthu_chi_tiet(p_ky varchar DEFAULT NULL)
RETURNS TABLE (nguon text, thanh_toan_id varchar, giao_dich_id varchar, thi_sinh_id varchar, ho_ten varchar, bang_dau varchar, tinh_thanh varchar,
               le_phi_thi numeric, trang_thai_thanh_toan varchar, thoi_gian_thanh_toan timestamp, kenh text) LANGUAGE sql STABLE AS $$
  WITH r AS (SELECT * FROM fn_ky_bao_cao(p_ky))
  SELECT g.nguon, g.thanh_toan_id, g.giao_dich_id, g.thi_sinh_id, ts.ho_ten, g.bang_dau, g.tinh_thanh, g.so_tien, g.trang_thai_thanh_toan,
         g.thoi_gian_thanh_toan, COALESCE(c.nen_tang, 'Trực tiếp / Không xác định')::text
  FROM r CROSS JOIN LATERAL fn_kpi_gd(r.tu, r.den) g
  LEFT JOIN thisinh ts ON ts.thi_sinh_id = g.thi_sinh_id
  LEFT JOIN LATERAL (SELECT qc.nen_tang FROM quangcao qc LEFT JOIN bieumau bm ON bm.bieu_mau_log = qc.bieu_mau_log
                     WHERE qc.thi_sinh_id = g.thi_sinh_id ORDER BY bm.dau_thoi_gian DESC NULLS LAST LIMIT 1) c ON true
  ORDER BY g.thoi_gian_thanh_toan $$;

/* ================================================================
   MODULE 10. PHÂN QUYỀN RBAC & NHẬT KÝ BẢO MẬT
   (get/assign/check quyền nằm trong 003_crud.sql)
   ================================================================ */
CREATE OR REPLACE VIEW vw_vaitro AS SELECT role_id, ten_vai_tro, mo_ta, trang_thai FROM vaitro;

-- Ma trận phân quyền của 1 vai trò (hiển thị checkbox)
CREATE OR REPLACE FUNCTION fn_ma_tran_phan_quyen(p_role_id varchar)
RETURNS TABLE (modun_chucnang varchar, permission_id varchar, ten_quyen varchar, mo_ta varchar, duoc_phep boolean) LANGUAGE sql STABLE AS $$
  SELECT q.nhom_chuc_nang, q.permission_id, q.ten_quyen, q.mo_ta, (vq.permission_id IS NOT NULL)
  FROM quyen q LEFT JOIN vaitro_quyen vq ON vq.permission_id = q.permission_id AND vq.role_id = p_role_id
  ORDER BY q.nhom_chuc_nang, q.permission_id $$;

-- Lưu thay đổi ma trận. p_ds là mảng JSON: [{"role_id":"MANAGER","permission_id":"XEM_BAO_CAO","duoc_phep":true}, ...]
CREATE OR REPLACE FUNCTION fn_luu_ma_tran_quyen(p_ds jsonb, p_nhan_vien_id varchar DEFAULT NULL) RETURNS void LANGUAGE plpgsql AS $$
BEGIN
  IF EXISTS (SELECT 1 FROM jsonb_to_recordset(p_ds) AS x(role_id text, permission_id text, duoc_phep boolean)
             WHERE x.role_id = 'ADMIN' AND NOT COALESCE(x.duoc_phep, false)) THEN
    RAISE EXCEPTION 'Không được gỡ quyền của vai trò ADMIN (toàn quyền hệ thống).'; END IF;
  IF p_nhan_vien_id IS NOT NULL THEN PERFORM fn_set_audit_context_theo_nhanvien(p_nhan_vien_id); END IF;
  INSERT INTO vaitro_quyen (role_id, permission_id)
  SELECT x.role_id, x.permission_id FROM jsonb_to_recordset(p_ds) AS x(role_id text, permission_id text, duoc_phep boolean)
  WHERE COALESCE(x.duoc_phep, false) ON CONFLICT DO NOTHING;
  DELETE FROM vaitro_quyen vq USING jsonb_to_recordset(p_ds) AS x(role_id text, permission_id text, duoc_phep boolean)
  WHERE vq.role_id = x.role_id AND vq.permission_id = x.permission_id AND NOT COALESCE(x.duoc_phep, false);
END $$;

-- Nhật ký bảo mật: hành động quản trị + đăng nhập + audit
CREATE OR REPLACE FUNCTION fn_nhat_ky_bao_mat(p_gioi_han int DEFAULT 50)
RETURNS TABLE (thoi_gian timestamp, ho_ten text, noi_dung text, trang_thai text) LANGUAGE sql STABLE AS $$
  SELECT h.thoi_gian, h.ho_ten, h.noi_dung, h.trang_thai FROM (
    SELECT nk.thoi_gian::timestamp AS thoi_gian, nv.ho_ten::text AS ho_ten, nk.hanh_dong::text AS noi_dung, nk.trang_thai::text AS trang_thai
      FROM nhatky_hanhdong nk JOIN nhanvien nv ON nv.nhan_vien_id = nk.nhan_vien_id
    UNION ALL
    SELECT l.thoi_gian_dn::timestamp, nv.ho_ten::text, 'Đăng nhập từ ' || COALESCE(l.ip_address, 'không rõ IP'), l.trang_thai::text
      FROM log_dangnhap l JOIN nhanvien nv ON nv.nhan_vien_id = l.nhan_vien_id
    UNION ALL
    SELECT al.thoi_gian::timestamp, al.nguoi_thuc_hien::text, al.hanh_dong || ' trên bảng ' || al.ten_bang, 'THANH_CONG'
      FROM audit_log al
      WHERE NOT (al.ten_bang = 'LOG_DANGNHAP' AND al.hanh_dong = 'DANG_NHAP')) h
  ORDER BY h.thoi_gian DESC LIMIT p_gioi_han $$;

/* ================================================================
   KHÓA QUYỀN TRUY CẬP CÔNG KHAI (Supabase) - chạy lại sau mỗi lần thêm view/function
   ================================================================ */
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'anon') AND EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'authenticated') THEN
    REVOKE ALL ON ALL TABLES    IN SCHEMA public FROM anon, authenticated;
    REVOKE ALL ON ALL FUNCTIONS IN SCHEMA public FROM anon, authenticated, PUBLIC;
    REVOKE ALL ON ALL SEQUENCES IN SCHEMA public FROM anon, authenticated;
    ALTER DEFAULT PRIVILEGES IN SCHEMA public REVOKE ALL ON TABLES    FROM anon, authenticated;
    ALTER DEFAULT PRIVILEGES IN SCHEMA public REVOKE ALL ON FUNCTIONS FROM anon, authenticated;
  END IF;
END $$;

-- =============================================================================
-- Source: supabase/migrations/006_dashboard_public_access.sql
-- =============================================================================

-- Public dashboard access: only aggregate RPC results and aggregate views are exposed.
-- Run this after the reporting functions and dashboard views have been created.

CREATE OR REPLACE FUNCTION public.fn_dashboard_card_public(
  p_so_ngay integer DEFAULT 16
)
RETURNS TABLE (
  tong_luot_dang_ky bigint,
  tong_luot_thanh_toan bigint,
  ty_le_chuyen_doi_thanh_toan numeric,
  doanh_thu_tam_tinh numeric,
  tong_lead_can_cham_soc_lai bigint,
  target_gap bigint
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  WITH period AS (
    SELECT
      CURRENT_DATE AS den,
      CURRENT_DATE - (LEAST(GREATEST(COALESCE(p_so_ngay, 16), 1), 30) - 1) AS tu,
      LEAST(GREATEST(COALESCE(p_so_ngay, 16), 1), 30) AS so_ngay
  ),
  registrations AS (
    SELECT
      count(DISTINCT dk.thi_sinh_id) FILTER (
        WHERE dk.ngay_dang_ky >= p.tu AND dk.ngay_dang_ky < p.den + 1
      ) AS hien_tai,
      count(DISTINCT dk.thi_sinh_id) FILTER (
        WHERE dk.ngay_dang_ky >= p.tu - p.so_ngay AND dk.ngay_dang_ky < p.tu
      ) AS truoc_do
    FROM public.dangky AS dk
    CROSS JOIN period AS p
  ),
  payments AS (
    SELECT
      count(*) FILTER (
        WHERE dk.ngay_dang_ky >= p.tu AND dk.ngay_dang_ky < p.den + 1
          AND dk.trang_thai = 'THANH_CONG'
      ) AS tong_luot_thanh_toan
    FROM public.dangky AS dk
    CROSS JOIN period AS p
  ),
  revenue AS (
    SELECT COALESCE(sum(tt.so_tien), 0) AS doanh_thu_tam_tinh
    FROM public.thanhtoan AS tt
    CROSS JOIN period AS p
    WHERE tt.thoi_gian_thanh_toan >= p.tu
      AND tt.thoi_gian_thanh_toan < p.den + 1
      AND tt.trang_thai_thanh_toan = 'THANH_TOAN_THANH_CONG'
  ),
  leads AS (
    SELECT count(*) AS tong_lead_can_cham_soc_lai
    FROM public.quangcao AS qc
    CROSS JOIN period AS p
    WHERE qc.created_at >= p.tu
      AND qc.created_at < p.den + 1
      AND qc.trang_thai_khach_hang IN ('MOI', 'DANG_LIEN_HE')
  )
  SELECT
    r.hien_tai,
    payments.tong_luot_thanh_toan,
    (CASE
      WHEN r.hien_tai = 0 THEN 0
      ELSE payments.tong_luot_thanh_toan * 100.0 / r.hien_tai
    END)::numeric(10, 2),
    revenue.doanh_thu_tam_tinh,
    leads.tong_lead_can_cham_soc_lai,
    r.hien_tai - r.truoc_do
  FROM registrations AS r
  CROSS JOIN payments
  CROSS JOIN revenue
  CROSS JOIN leads
$$;

CREATE OR REPLACE FUNCTION public.fn_dashboard_xu_huong_16_ngay_public()
RETURNS TABLE (ngay date, so_luot_dang_ky bigint)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT * FROM public.fn_dashboard_xu_huong_16_ngay()
$$;

CREATE OR REPLACE FUNCTION public.fn_dashboard_pheu_chuyen_doi_web_public(
  p_so_ngay integer DEFAULT 16
)
RETURNS TABLE (
  thu_tu integer,
  giai_doan text,
  so_luong bigint,
  ty_le_so_voi_tiep_can numeric
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT
    p.thu_tu,
    p.giai_doan,
    p.so_luong,
    p.ty_le_so_voi_tiep_can
  FROM public.fn_dashboard_pheu_3_tang_web(
    CURRENT_DATE - LEAST(GREATEST(p_so_ngay, 1), 30) + 1,
    CURRENT_DATE
  ) AS p
$$;

CREATE OR REPLACE FUNCTION public.fn_dashboard_phan_bo_nhom_tuoi_public()
RETURNS TABLE (thu_tu integer, nhom_tuoi text, so_luong bigint)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT v.thu_tu, v.nhom_tuoi, v.so_luong
  FROM public.vw_dashboard_phan_bo_nhom_tuoi AS v
$$;

CREATE OR REPLACE FUNCTION public.fn_dashboard_card_q3_public(p_nam integer)
RETURNS TABLE (
  tong_luot_dang_ky bigint,
  tong_luot_thanh_toan bigint,
  ty_le_chuyen_doi_thanh_toan numeric,
  doanh_thu_tam_tinh numeric,
  tong_lead_can_cham_soc_lai bigint,
  target_gap bigint
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  WITH period AS (
    SELECT make_date(p_nam, 7, 1) AS tu, make_date(p_nam, 10, 1) AS den
  ),
  registrations AS (
    SELECT
      count(DISTINCT dk.thi_sinh_id) FILTER (
        WHERE dk.ngay_dang_ky >= p.tu AND dk.ngay_dang_ky < p.den
      ) AS hien_tai,
      count(DISTINCT dk.thi_sinh_id) FILTER (
        WHERE dk.ngay_dang_ky >= p.tu - interval '3 months'
          AND dk.ngay_dang_ky < p.tu
      ) AS truoc_do
    FROM public.dangky AS dk
    CROSS JOIN period AS p
  ),
  payments AS (
    SELECT count(*) AS tong_luot_thanh_toan
    FROM public.dangky AS dk
    CROSS JOIN period AS p
    WHERE dk.ngay_dang_ky >= p.tu
      AND dk.ngay_dang_ky < p.den
      AND dk.trang_thai = 'THANH_CONG'
  ),
  revenue AS (
    SELECT COALESCE(sum(tt.so_tien), 0) AS doanh_thu_tam_tinh
    FROM public.thanhtoan AS tt
    CROSS JOIN period AS p
    WHERE tt.thoi_gian_thanh_toan >= p.tu
      AND tt.thoi_gian_thanh_toan < p.den
      AND tt.trang_thai_thanh_toan = 'THANH_TOAN_THANH_CONG'
  ),
  leads AS (
    SELECT count(*) AS tong_lead_can_cham_soc_lai
    FROM public.quangcao AS qc
    CROSS JOIN period AS p
    WHERE qc.created_at >= p.tu
      AND qc.created_at < p.den
      AND qc.trang_thai_khach_hang IN ('MOI', 'DANG_LIEN_HE')
  )
  SELECT
    r.hien_tai,
    payments.tong_luot_thanh_toan,
    (CASE
      WHEN r.hien_tai = 0 THEN 0
      ELSE payments.tong_luot_thanh_toan * 100.0 / r.hien_tai
    END)::numeric(10, 2),
    revenue.doanh_thu_tam_tinh,
    leads.tong_lead_can_cham_soc_lai,
    r.hien_tai - r.truoc_do
  FROM registrations AS r
  CROSS JOIN payments
  CROSS JOIN revenue
  CROSS JOIN leads
$$;

CREATE OR REPLACE FUNCTION public.fn_dashboard_xu_huong_q3_public(p_nam integer)
RETURNS TABLE (ngay date, so_luot_dang_ky bigint)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  WITH period AS (
    SELECT make_date(p_nam, 7, 1) AS tu, make_date(p_nam, 10, 1) AS den
  ),
  weeks AS (
    SELECT generate_series(
      p.tu::timestamp,
      (p.den - 1)::timestamp,
      interval '7 days'
    )::date AS week_start
    FROM period AS p
  )
  SELECT w.week_start, count(dk.dang_ky_id)
  FROM weeks AS w
  CROSS JOIN period AS p
  LEFT JOIN public.dangky AS dk
    ON dk.ngay_dang_ky >= w.week_start
    AND dk.ngay_dang_ky < LEAST(w.week_start + 7, p.den)
  GROUP BY w.week_start
  ORDER BY w.week_start
$$;

CREATE OR REPLACE FUNCTION public.fn_dashboard_pheu_q3_public(p_nam integer)
RETURNS TABLE (
  thu_tu integer,
  giai_doan text,
  so_luong bigint,
  ty_le_so_voi_tiep_can numeric
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT
    p.thu_tu,
    p.giai_doan,
    p.so_luong,
    p.ty_le_so_voi_tiep_can
  FROM public.fn_dashboard_pheu_3_tang_web(
    make_date(p_nam, 7, 1),
    make_date(p_nam, 9, 30)
  ) AS p
$$;

CREATE OR REPLACE FUNCTION public.fn_dashboard_phan_bo_bang_thi_q3_public(
  p_nam integer
)
RETURNS TABLE (bang_dau varchar, so_luong bigint)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT ts.bang_dau, count(DISTINCT ts.thi_sinh_id)
  FROM public.thisinh AS ts
  JOIN public.dangky AS dk ON dk.thi_sinh_id = ts.thi_sinh_id
  WHERE dk.ngay_dang_ky >= make_date(p_nam, 7, 1)
    AND dk.ngay_dang_ky < make_date(p_nam, 10, 1)
    AND ts.bang_dau IN ('BANG_A', 'BANG_B')
  GROUP BY ts.bang_dau
  ORDER BY ts.bang_dau
$$;

CREATE OR REPLACE FUNCTION public.fn_dashboard_phan_bo_nhom_tuoi_q3_public(
  p_nam integer
)
RETURNS TABLE (thu_tu integer, nhom_tuoi text, so_luong bigint)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  WITH cohort AS (
    SELECT DISTINCT
      ts.thi_sinh_id,
      public.fn_tinh_tuoi_thi(ts.ngay_sinh) AS tuoi
    FROM public.thisinh AS ts
    JOIN public.dangky AS dk ON dk.thi_sinh_id = ts.thi_sinh_id
    WHERE dk.ngay_dang_ky >= make_date(p_nam, 7, 1)
      AND dk.ngay_dang_ky < make_date(p_nam, 10, 1)
      AND ts.ngay_sinh IS NOT NULL
  ),
  grouped AS (
    SELECT
      CASE
        WHEN tuoi < 15 THEN 'DƯỚI 15'
        WHEN tuoi BETWEEN 15 AND 17 THEN '15-17'
        WHEN tuoi BETWEEN 18 AND 20 THEN '18-20'
        ELSE 'TRÊN 20'
      END AS nhom_tuoi,
      CASE
        WHEN tuoi < 15 THEN 1
        WHEN tuoi BETWEEN 15 AND 17 THEN 2
        WHEN tuoi BETWEEN 18 AND 20 THEN 3
        ELSE 4
      END AS thu_tu
    FROM cohort
  )
  SELECT g.thu_tu, g.nhom_tuoi, count(*)::bigint
  FROM grouped AS g
  GROUP BY g.thu_tu, g.nhom_tuoi
  ORDER BY g.thu_tu
$$;

REVOKE ALL ON FUNCTION public.fn_dashboard_card_public(integer) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.fn_dashboard_xu_huong_16_ngay_public() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.fn_dashboard_pheu_chuyen_doi_web_public(integer) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.fn_dashboard_phan_bo_nhom_tuoi_public() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.fn_dashboard_card_q3_public(integer) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.fn_dashboard_xu_huong_q3_public(integer) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.fn_dashboard_pheu_q3_public(integer) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.fn_dashboard_phan_bo_bang_thi_q3_public(integer) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.fn_dashboard_phan_bo_nhom_tuoi_q3_public(integer) FROM PUBLIC;
REVOKE SELECT ON public.vw_dashboard_phan_bo_nhom_tuoi FROM anon;

GRANT EXECUTE ON FUNCTION public.fn_dashboard_card_public(integer) TO anon;
GRANT EXECUTE ON FUNCTION public.fn_dashboard_xu_huong_16_ngay_public() TO anon;
GRANT EXECUTE ON FUNCTION public.fn_dashboard_pheu_chuyen_doi_web_public(integer) TO anon;
GRANT EXECUTE ON FUNCTION public.fn_dashboard_phan_bo_nhom_tuoi_public() TO anon;
GRANT EXECUTE ON FUNCTION public.fn_dashboard_card_q3_public(integer) TO anon;
GRANT EXECUTE ON FUNCTION public.fn_dashboard_xu_huong_q3_public(integer) TO anon;
GRANT EXECUTE ON FUNCTION public.fn_dashboard_pheu_q3_public(integer) TO anon;
GRANT EXECUTE ON FUNCTION public.fn_dashboard_phan_bo_bang_thi_q3_public(integer) TO anon;
GRANT EXECUTE ON FUNCTION public.fn_dashboard_phan_bo_nhom_tuoi_q3_public(integer) TO anon;
GRANT SELECT ON public.vw_dashboard_phan_bo_bang_thi TO anon;

GRANT EXECUTE ON FUNCTION public.fn_dashboard_card_public(integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.fn_dashboard_xu_huong_16_ngay_public() TO authenticated;
GRANT EXECUTE ON FUNCTION public.fn_dashboard_pheu_chuyen_doi_web_public(integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.fn_dashboard_phan_bo_nhom_tuoi_public() TO authenticated;
GRANT SELECT ON TABLE public.vw_dashboard_phan_bo_bang_thi TO authenticated;

NOTIFY pgrst, 'reload schema';

-- =============================================================================
-- Source: supabase/migrations/006_reporting_role_access.sql
-- =============================================================================

ALTER TABLE public.nhanvien
  DROP CONSTRAINT IF EXISTS chk_nv_phanquyen;
ALTER TABLE public.nhanvien
  ADD CONSTRAINT chk_nv_phanquyen
  CHECK (phan_quyen IN ('ADMIN', 'MANAGER', 'SALE_STAFF', 'SUPPORT_STAFF', 'JUDGE'));

ALTER TABLE public.vaitro
  DROP CONSTRAINT IF EXISTS chk_vt_role;
ALTER TABLE public.vaitro
  ADD CONSTRAINT chk_vt_role
  CHECK (role_id IN ('ADMIN', 'MANAGER', 'SALE_STAFF', 'SUPPORT_STAFF', 'JUDGE'));

CREATE OR REPLACE FUNCTION public.sp_insert_vaitro(
  p_role_id varchar,
  p_ten_vai_tro varchar,
  p_mo_ta varchar,
  p_trang_thai varchar DEFAULT 'DANG_AP_DUNG'
) RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
  IF EXISTS (SELECT 1 FROM public.vaitro WHERE role_id = p_role_id) THEN
    RAISE EXCEPTION 'Mã vai trò % đã tồn tại trong hệ thống.', p_role_id;
  END IF;
  IF p_role_id NOT IN ('ADMIN', 'MANAGER', 'SALE_STAFF', 'SUPPORT_STAFF', 'JUDGE') THEN
    RAISE EXCEPTION 'Vai trò không hợp lệ.';
  END IF;
  IF p_trang_thai NOT IN ('DANG_AP_DUNG', 'TAM_KHOA') THEN
    RAISE EXCEPTION 'Trạng thái không hợp lệ.';
  END IF;
  INSERT INTO public.vaitro (role_id, ten_vai_tro, mo_ta, trang_thai)
  VALUES (p_role_id, p_ten_vai_tro, p_mo_ta, p_trang_thai);
END;
$$;

CREATE OR REPLACE FUNCTION public.fn_current_user_report_permissions()
RETURNS TABLE (ho_ten varchar, role_id varchar, ten_vai_tro varchar, permission_id varchar)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, public, auth, pg_temp
AS $$
  SELECT DISTINCT nv.ho_ten, vt.role_id, vt.ten_vai_tro, vq.permission_id
  FROM public.nhanvien nv
  JOIN public.nhanvien_vaitro_ct nvt ON nvt.nhan_vien_id = nv.nhan_vien_id
  JOIN public.vaitro vt ON vt.role_id = nvt.role_id
  JOIN public.vaitro_quyen vq ON vq.role_id = vt.role_id
  WHERE nv.trang_thai = 'ACTIVE'
    AND vt.trang_thai = 'DANG_AP_DUNG'
    AND (
      nv.user_id = auth.uid()
      OR (
        nv.user_id IS NULL
        AND lower(nv.email) = lower(auth.jwt() ->> 'email')
      )
    )
  ORDER BY vt.role_id, vq.permission_id
$$;

CREATE OR REPLACE FUNCTION public.fn_current_user_can_view_student_records()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, public, auth, pg_temp
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.nhanvien nv
    JOIN public.nhanvien_vaitro_ct nvt ON nvt.nhan_vien_id = nv.nhan_vien_id
    JOIN public.vaitro vt ON vt.role_id = nvt.role_id
    JOIN public.vaitro_quyen vq ON vq.role_id = vt.role_id
    WHERE nv.trang_thai = 'ACTIVE'
      AND vt.trang_thai = 'DANG_AP_DUNG'
      AND vq.permission_id IN ('BAO_CAO_THISINH', 'BAO_CAO_HO_TRO')
      AND (
        nv.user_id = auth.uid()
        OR (nv.user_id IS NULL AND lower(nv.email) = lower(auth.jwt() ->> 'email'))
      )
  )
$$;

CREATE OR REPLACE FUNCTION public.fn_xuat_thisinh(
  p_thi_sinh_id varchar DEFAULT NULL,
  p_ho_ten varchar DEFAULT NULL,
  p_sdt varchar DEFAULT NULL,
  p_email varchar DEFAULT NULL,
  p_truong_hoc varchar DEFAULT NULL,
  p_cccd varchar DEFAULT NULL,
  p_trang_thai_ho_so varchar DEFAULT NULL,
  p_sale_phu_trach_id varchar DEFAULT NULL,
  p_bang_dau varchar DEFAULT NULL
)
RETURNS TABLE (
  id varchar,
  ho_va_ten varchar,
  email varchar,
  so_dien_thoai varchar,
  ngay_sinh date,
  nam_sinh integer,
  cccd varchar,
  dia_chi varchar,
  tinh_thanh varchar,
  truong_hoc varchar,
  bang_dau varchar,
  trang_thai_ho_so varchar,
  sale_phu_trach_id varchar,
  sale_phu_trach varchar
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, public, auth, pg_temp
AS $$
  SELECT ts.thi_sinh_id, ts.ho_ten, ts.email, ts.sdt, ts.ngay_sinh,
         extract(year FROM ts.ngay_sinh)::integer, ts.cccd, ts.dia_chi,
         ts.tinh_thanh, ts.truong_hoc, ts.bang_dau, ts.trang_thai_ho_so,
         ts.sale_phu_trach_id, nv.ho_ten
  FROM public.thisinh ts
  LEFT JOIN public.nhanvien nv ON nv.nhan_vien_id = ts.sale_phu_trach_id
  WHERE public.fn_current_user_can_view_student_records()
    AND (p_thi_sinh_id IS NULL OR p_thi_sinh_id = '' OR ts.thi_sinh_id ILIKE '%' || p_thi_sinh_id || '%')
    AND (p_ho_ten IS NULL OR p_ho_ten = '' OR ts.ho_ten ILIKE '%' || p_ho_ten || '%')
    AND (p_sdt IS NULL OR p_sdt = '' OR ts.sdt LIKE '%' || p_sdt || '%')
    AND (p_email IS NULL OR p_email = '' OR ts.email ILIKE '%' || p_email || '%')
    AND (p_truong_hoc IS NULL OR p_truong_hoc = '' OR ts.truong_hoc ILIKE '%' || p_truong_hoc || '%')
    AND (p_cccd IS NULL OR p_cccd = '' OR ts.cccd LIKE '%' || p_cccd || '%')
    AND (p_trang_thai_ho_so IS NULL OR p_trang_thai_ho_so = 'ALL' OR ts.trang_thai_ho_so = p_trang_thai_ho_so)
    AND (p_sale_phu_trach_id IS NULL OR p_sale_phu_trach_id = 'ALL' OR ts.sale_phu_trach_id = p_sale_phu_trach_id)
    AND (p_bang_dau IS NULL OR p_bang_dau = 'ALL' OR ts.bang_dau = p_bang_dau)
  ORDER BY ts.thi_sinh_id
$$;

CREATE OR REPLACE FUNCTION public.fn_loc_thisinh(
  p_thi_sinh_id varchar DEFAULT NULL,
  p_ho_ten varchar DEFAULT NULL,
  p_nam_sinh integer DEFAULT NULL,
  p_truong_hoc varchar DEFAULT NULL,
  p_trang_thai_ho_so varchar DEFAULT NULL,
  p_sale_phu_trach_id varchar DEFAULT NULL,
  p_bang_dau varchar DEFAULT NULL
)
RETURNS TABLE (
  thi_sinh_id varchar,
  ho_ten varchar,
  email varchar,
  sdt varchar,
  nam_sinh integer,
  truong_hoc varchar,
  trang_thai_ho_so varchar,
  bang_dau varchar,
  sale_phu_trach_id varchar,
  ten_sale_phu_trach varchar
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, public, auth, pg_temp
AS $$
  SELECT ts.thi_sinh_id, ts.ho_ten, ts.email, ts.sdt,
         extract(year FROM ts.ngay_sinh)::integer, ts.truong_hoc,
         ts.trang_thai_ho_so, ts.bang_dau, ts.sale_phu_trach_id, nv.ho_ten
  FROM public.thisinh ts
  LEFT JOIN public.nhanvien nv ON nv.nhan_vien_id = ts.sale_phu_trach_id
  WHERE public.fn_current_user_can_view_student_records()
    AND (p_thi_sinh_id IS NULL OR p_thi_sinh_id = '' OR ts.thi_sinh_id ILIKE '%' || p_thi_sinh_id || '%')
    AND (p_ho_ten IS NULL OR p_ho_ten = '' OR ts.ho_ten ILIKE '%' || p_ho_ten || '%')
    AND (p_nam_sinh IS NULL OR extract(year FROM ts.ngay_sinh)::integer = p_nam_sinh)
    AND (p_truong_hoc IS NULL OR p_truong_hoc = '' OR ts.truong_hoc ILIKE '%' || p_truong_hoc || '%')
    AND (p_trang_thai_ho_so IS NULL OR p_trang_thai_ho_so = 'ALL' OR ts.trang_thai_ho_so = p_trang_thai_ho_so)
    AND (p_sale_phu_trach_id IS NULL OR p_sale_phu_trach_id = 'ALL' OR ts.sale_phu_trach_id = p_sale_phu_trach_id)
    AND (p_bang_dau IS NULL OR p_bang_dau = 'ALL' OR ts.bang_dau = p_bang_dau)
  ORDER BY ts.thi_sinh_id
$$;

CREATE OR REPLACE FUNCTION public.fn_xem_chi_tiet_thisinh(p_thi_sinh_id varchar)
RETURNS TABLE (
  ho_ten varchar,
  email varchar,
  nam_sinh integer,
  truong_hoc varchar,
  trang_thai_ho_so varchar,
  so_dien_thoai varchar,
  cccd varchar,
  bang_dau varchar,
  sale_phu_trach_id varchar,
  sale_phu_trach varchar
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, public, auth, pg_temp
AS $$
BEGIN
  IF NOT public.fn_current_user_can_view_student_records() THEN
    RAISE EXCEPTION 'Tài khoản không có quyền xem hồ sơ thí sinh.'
      USING ERRCODE = '42501';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.thisinh WHERE thi_sinh_id = p_thi_sinh_id) THEN
    RAISE EXCEPTION 'Thí sinh % không tồn tại.', p_thi_sinh_id;
  END IF;
  RETURN QUERY
  SELECT ts.ho_ten, ts.email, extract(year FROM ts.ngay_sinh)::integer,
         ts.truong_hoc, ts.trang_thai_ho_so, ts.sdt, ts.cccd,
         ts.bang_dau, ts.sale_phu_trach_id, nv.ho_ten
  FROM public.thisinh ts
  LEFT JOIN public.nhanvien nv ON nv.nhan_vien_id = ts.sale_phu_trach_id
  WHERE ts.thi_sinh_id = p_thi_sinh_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.fn_tim_kiem_thisinh(p_tu_khoa varchar)
RETURNS TABLE (
  id varchar,
  ho_va_ten varchar,
  email varchar,
  so_dien_thoai varchar,
  nam_sinh integer,
  truong_hoc varchar,
  trang_thai_ho_so varchar,
  bang_dau varchar,
  sale_phu_trach_id varchar,
  sale_phu_trach varchar
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, public, auth, pg_temp
AS $$
DECLARE
  v_kw text := NULLIF(btrim(p_tu_khoa), '');
BEGIN
  IF NOT public.fn_current_user_can_view_student_records() THEN
    RAISE EXCEPTION 'Tài khoản không có quyền tìm kiếm hồ sơ thí sinh.'
      USING ERRCODE = '42501';
  END IF;
  IF v_kw IS NULL THEN
    RAISE EXCEPTION 'Vui lòng nhập thông tin cần tìm kiếm.';
  END IF;
  v_kw := '%' || unaccent(lower(v_kw)) || '%';
  RETURN QUERY
  SELECT ts.thi_sinh_id, ts.ho_ten, ts.email, ts.sdt,
         extract(year FROM ts.ngay_sinh)::integer, ts.truong_hoc,
         ts.trang_thai_ho_so, ts.bang_dau, ts.sale_phu_trach_id, nv.ho_ten
  FROM public.thisinh ts
  LEFT JOIN public.nhanvien nv ON nv.nhan_vien_id = ts.sale_phu_trach_id
  WHERE unaccent(lower(ts.thi_sinh_id)) LIKE v_kw
     OR unaccent(lower(ts.ho_ten)) LIKE v_kw
     OR unaccent(lower(ts.email)) LIKE v_kw
     OR unaccent(lower(COALESCE(ts.truong_hoc, ''))) LIKE v_kw
     OR ts.cccd LIKE v_kw
  ORDER BY ts.thi_sinh_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.fn_kpi_thisinh_top_pct(
  p_ky varchar DEFAULT NULL,
  p_ty_le numeric DEFAULT 3
) RETURNS TABLE (thi_sinh_id varchar, ho_ten varchar, truong_hoc varchar, bang_dau varchar, diem_pct numeric)
LANGUAGE plpgsql
STABLE
AS $$
BEGIN
  IF p_ty_le <= 0 OR p_ty_le > 100 THEN
    RAISE EXCEPTION 'Tỷ lệ xếp hạng phải lớn hơn 0 và không vượt quá 100.';
  END IF;

  RETURN QUERY
  WITH r AS (SELECT * FROM public.fn_ky_bao_cao(p_ky)),
  x AS (
    SELECT b.thi_sinh_id, max(b.diem_pct) AS diem_pct
    FROM public.vw_bainop_diem_pct b
    CROSS JOIN r
    WHERE b.trang_thai = 'DA_CHAM_DIEM'
      AND b.diem_pct IS NOT NULL
      AND b.thoi_gian_nop >= r.tu
      AND b.thoi_gian_nop < r.den
    GROUP BY b.thi_sinh_id
  ),
  ranked AS (
    SELECT x.*, row_number() OVER (ORDER BY x.diem_pct DESC) AS position,
           count(*) OVER () AS total
    FROM x
  )
  SELECT ts.thi_sinh_id, ts.ho_ten, ts.truong_hoc, ts.bang_dau, ranked.diem_pct
  FROM ranked
  JOIN public.thisinh ts ON ts.thi_sinh_id = ranked.thi_sinh_id
  WHERE ranked.position <= ceil(ranked.total * p_ty_le / 100.0)
  ORDER BY ranked.diem_pct DESC;
END;
$$;

CREATE OR REPLACE FUNCTION public.fn_bao_cao_du_lieu(
  p_ma_bao_cao varchar,
  p_ky varchar DEFAULT NULL
) RETURNS SETOF jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, public, auth, pg_temp
AS $$
DECLARE
  v_permission varchar;
  v_employee_id varchar;
BEGIN
  v_permission := CASE p_ma_bao_cao
    WHEN 'overview_summary' THEN 'BAO_CAO_TONG_QUAN'
    WHEN 'overview_progress' THEN 'BAO_CAO_TONG_QUAN'
    WHEN 'overview_comparison' THEN 'BAO_CAO_TONG_QUAN'
    WHEN 'overview_enrollment_funnel' THEN 'BAO_CAO_TONG_QUAN'
    WHEN 'overview_registration_trend' THEN 'BAO_CAO_TONG_QUAN'
    WHEN 'student_summary' THEN 'BAO_CAO_THISINH'
    WHEN 'student_status' THEN 'BAO_CAO_THISINH'
    WHEN 'student_schools' THEN 'BAO_CAO_THISINH'
    WHEN 'student_top1' THEN 'BAO_CAO_THISINH'
    WHEN 'student_top3' THEN 'BAO_CAO_THISINH'
    WHEN 'student_school_scores' THEN 'BAO_CAO_THISINH'
    WHEN 'student_utm' THEN 'BAO_CAO_THISINH'
    WHEN 'revenue_summary' THEN 'BAO_CAO_DOANH_THU'
    WHEN 'payment_funnel' THEN 'BAO_CAO_DOANH_THU'
    WHEN 'revenue_by_province' THEN 'BAO_CAO_DOANH_THU'
    WHEN 'revenue_trend' THEN 'BAO_CAO_DOANH_THU'
    WHEN 'revenue_by_channel' THEN 'BAO_CAO_DOANH_THU'
    WHEN 'revenue_reconciliation' THEN 'BAO_CAO_DOANH_THU'
    WHEN 'transaction_details' THEN 'BAO_CAO_DOANH_THU_CHI_TIET'
    WHEN 'sponsor_summary' THEN 'BAO_CAO_DOI_TAC'
    WHEN 'sponsor_funnel' THEN 'BAO_CAO_DOI_TAC'
    WHEN 'sponsor_tiers' THEN 'BAO_CAO_DOI_TAC'
    WHEN 'sponsor_list' THEN 'BAO_CAO_DOI_TAC'
    WHEN 'supplier_list' THEN 'BAO_CAO_DOI_TAC'
    WHEN 'sponsor_revenue_by_province' THEN 'BAO_CAO_DOI_TAC'
    WHEN 'sponsor_trend' THEN 'BAO_CAO_DOI_TAC'
    WHEN 'sponsor_daily_revenue' THEN 'BAO_CAO_DOI_TAC'
    WHEN 'submission_status' THEN 'BAO_CAO_HOC_VU'
    WHEN 'submission_failures' THEN 'BAO_CAO_HOC_VU'
    WHEN 'submission_failures_by_province' THEN 'BAO_CAO_HOC_VU'
    WHEN 'contest_rounds' THEN 'BAO_CAO_HOC_VU'
    WHEN 'contest_results' THEN 'BAO_CAO_HOC_VU'
    WHEN 'contest_top56' THEN 'BAO_CAO_HOC_VU'
    WHEN 'contest_finalists' THEN 'BAO_CAO_HOC_VU'
    WHEN 'submission_details' THEN 'BAO_CAO_HOC_VU'
    WHEN 'support_conversations' THEN 'BAO_CAO_HO_TRO'
    WHEN 'support_by_status' THEN 'BAO_CAO_HO_TRO'
    WHEN 'support_by_entity' THEN 'BAO_CAO_HO_TRO'
    WHEN 'support_faq_summary' THEN 'BAO_CAO_HO_TRO'
    WHEN 'support_faq_categories' THEN 'BAO_CAO_HO_TRO'
    WHEN 'security_log' THEN 'BAO_CAO_AN_NINH'
    WHEN 'import_sessions' THEN 'BAO_CAO_AN_NINH'
    WHEN 'import_errors' THEN 'BAO_CAO_AN_NINH'
    ELSE NULL
  END;

  IF v_permission IS NULL THEN
    RAISE EXCEPTION 'Mã báo cáo không hợp lệ.';
  END IF;

  SELECT nv.nhan_vien_id
  INTO v_employee_id
  FROM public.nhanvien nv
  WHERE nv.trang_thai = 'ACTIVE'
    AND (
      nv.user_id = auth.uid()
      OR (nv.user_id IS NULL AND lower(nv.email) = lower(auth.jwt() ->> 'email'))
    )
  ORDER BY (nv.user_id = auth.uid()) DESC
  LIMIT 1;

  IF v_employee_id IS NULL OR NOT public.fn_check_user_permission(v_employee_id, v_permission) THEN
    RAISE EXCEPTION 'Tài khoản không có quyền xem báo cáo này.'
      USING ERRCODE = '42501';
  END IF;

  IF p_ma_bao_cao = 'transaction_details'
    AND NOT EXISTS (
      SELECT 1
      FROM public.nhanvien_vaitro_ct nvt
      WHERE nvt.nhan_vien_id = v_employee_id
        AND nvt.role_id IN ('ADMIN', 'MANAGER')
    )
  THEN
    RAISE EXCEPTION 'Chỉ ADMIN và MANAGER được xem thông tin giao dịch chi tiết.'
      USING ERRCODE = '42501';
  END IF;

  CASE p_ma_bao_cao
    WHEN 'overview_summary' THEN
      RETURN QUERY SELECT to_jsonb(r) FROM public.fn_kpi_tongquan_chiso(p_ky) r;
      RETURN QUERY SELECT to_jsonb(r) FROM public.fn_kpi_thisinh_tong_quan(p_ky) r;
      RETURN QUERY SELECT to_jsonb(r) FROM public.fn_kpi_doanhthu_tong_quan(p_ky) r;
    WHEN 'overview_progress' THEN
      RETURN QUERY SELECT to_jsonb(r) FROM public.fn_kpi_tongquan_tien_do(p_ky) r;
    WHEN 'overview_comparison' THEN
      RETURN QUERY
      WITH current_period AS (SELECT * FROM public.fn_ky_bao_cao(p_ky)),
      previous_period AS (
        SELECT to_char((r.tu - interval '3 months')::date, 'YYYY')
               || '-Q' || extract(quarter FROM (r.tu - interval '3 months'))::int::text AS ky
        FROM current_period r
      ),
      current_students AS (
        SELECT * FROM public.fn_kpi_thisinh_tong_quan(p_ky)
      ),
      previous_students AS (
        SELECT * FROM public.fn_kpi_thisinh_tong_quan((SELECT ky FROM previous_period))
      )
      SELECT jsonb_build_object(
        'dang_ky_thi', current_students.dang_ky_thi,
        'dang_ky_ky_truoc', previous_students.dang_ky_thi,
        'target_gap', current_students.dang_ky_thi - previous_students.dang_ky_thi
      )
      FROM current_students
      CROSS JOIN previous_students;
    WHEN 'overview_enrollment_funnel' THEN
      RETURN QUERY SELECT to_jsonb(r) FROM public.fn_kpi_thisinh_pheu(p_ky) r;
    WHEN 'overview_registration_trend' THEN
      RETURN QUERY
      WITH period AS (SELECT * FROM public.fn_ky_bao_cao(p_ky)),
      bounds AS (
        SELECT greatest(tu, (least(den - 1, current_date) - 15)::date) AS tu,
               least(den - 1, current_date) AS den
        FROM period
      )
      SELECT jsonb_build_object(
        'ngay', days.ngay,
        'so_dang_ky', count(DISTINCT dk.thi_sinh_id)
      )
      FROM bounds
      CROSS JOIN LATERAL generate_series(bounds.tu, bounds.den, interval '1 day') AS days(ngay)
      LEFT JOIN public.dangky dk ON dk.ngay_dang_ky::date = days.ngay::date
      GROUP BY days.ngay
      ORDER BY days.ngay;
    WHEN 'student_summary' THEN
      RETURN QUERY SELECT to_jsonb(r) FROM public.fn_kpi_thisinh_tong_quan(p_ky) r;
    WHEN 'student_status' THEN
      RETURN QUERY SELECT to_jsonb(r) FROM public.vw_thisinh_bieudo_trangthai r;
    WHEN 'student_schools' THEN
      RETURN QUERY SELECT to_jsonb(r) FROM public.vw_thisinh_bieudo_theo_truong r;
    WHEN 'student_top1' THEN
      RETURN QUERY SELECT to_jsonb(r) FROM public.fn_kpi_thisinh_top1pct(p_ky) r;
    WHEN 'student_top3' THEN
      RETURN QUERY SELECT to_jsonb(r) FROM public.fn_kpi_thisinh_top_pct(p_ky, 3) r;
    WHEN 'student_school_scores' THEN
      RETURN QUERY SELECT to_jsonb(r) FROM public.fn_kpi_thisinh_truong_bang(p_ky) r;
    WHEN 'student_utm' THEN
      RETURN QUERY SELECT to_jsonb(r) FROM public.fn_kpi_thisinh_utm_roi(p_ky) r;
    WHEN 'revenue_summary' THEN
      RETURN QUERY SELECT to_jsonb(r) FROM public.fn_kpi_doanhthu_tong_quan(p_ky) r;
    WHEN 'payment_funnel' THEN
      RETURN QUERY SELECT to_jsonb(r) FROM public.fn_kpi_doanhthu_pheu(p_ky) r;
    WHEN 'revenue_by_province' THEN
      RETURN QUERY SELECT to_jsonb(r) FROM public.fn_kpi_doanhthu_theo_khu_vuc(p_ky) r;
    WHEN 'revenue_trend' THEN
      RETURN QUERY SELECT to_jsonb(r) FROM public.fn_kpi_doanhthu_xu_huong(p_ky) r;
    WHEN 'revenue_by_channel' THEN
      RETURN QUERY SELECT to_jsonb(r) FROM public.fn_kpi_doanhthu_theo_kenh(p_ky) r;
    WHEN 'revenue_reconciliation' THEN
      RETURN QUERY SELECT to_jsonb(r) FROM public.fn_kpi_doanhthu_cho_doi_soat_48h(p_ky) r;
    WHEN 'transaction_details' THEN
      RETURN QUERY SELECT to_jsonb(r) FROM public.fn_kpi_doanhthu_chi_tiet(p_ky) r;
    WHEN 'sponsor_summary' THEN
      RETURN QUERY SELECT to_jsonb(r) FROM public.fn_kpi_taitro_tong_quan(p_ky) r;
    WHEN 'sponsor_funnel' THEN
      RETURN QUERY SELECT to_jsonb(r) FROM public.fn_kpi_taitro_pheu(p_ky) r;
    WHEN 'sponsor_tiers' THEN
      RETURN QUERY SELECT to_jsonb(r) FROM public.fn_kpi_taitro_co_cau_cap() r;
    WHEN 'sponsor_list' THEN
      RETURN QUERY SELECT to_jsonb(r) FROM public.fn_kpi_taitro_nha_tai_tro(p_ky) r;
    WHEN 'supplier_list' THEN
      RETURN QUERY SELECT to_jsonb(r) FROM public.fn_kpi_taitro_ds_doi_tac(p_ky) r;
    WHEN 'sponsor_revenue_by_province' THEN
      RETURN QUERY SELECT to_jsonb(r) FROM public.fn_kpi_taitro_doanh_thu_tinh(p_ky) r;
    WHEN 'sponsor_trend' THEN
      RETURN QUERY SELECT to_jsonb(r) FROM public.fn_kpi_taitro_xu_huong(p_ky) r;
    WHEN 'sponsor_daily_revenue' THEN
      RETURN QUERY SELECT to_jsonb(r) FROM public.fn_kpi_taitro_doanh_thu_ngay(p_ky) r;
    WHEN 'submission_status' THEN
      RETURN QUERY SELECT to_jsonb(r) FROM public.vw_baocao_phanbo_trangthai_bainop r;
    WHEN 'submission_failures' THEN
      RETURN QUERY SELECT to_jsonb(r) FROM public.vw_baitap_tyle_khong_dat_cao r ORDER BY r.tyle_khong_dat_pt DESC;
    WHEN 'submission_failures_by_province' THEN
      RETURN QUERY SELECT to_jsonb(r) FROM public.vw_tyle_khong_dat_theo_khuvuc r ORDER BY r.tyle_khong_dat_pt DESC;
    WHEN 'contest_rounds' THEN
      RETURN QUERY SELECT to_jsonb(r) FROM public.vw_pm_vong_thi r;
    WHEN 'contest_results' THEN
      RETURN QUERY SELECT to_jsonb(r) FROM public.vw_export_ketqua_vongloai r;
    WHEN 'contest_top56' THEN
      RETURN QUERY
      SELECT jsonb_build_object(
        'hang_toan_quoc', r.hang_toan_quoc,
        'thi_sinh_id', r.thi_sinh_id,
        'ho_ten', r.ho_ten,
        'truong_hoc', r.truong_hoc,
        'bang_dau', r.bang_dau,
        'tong_diem', r.tong_diem,
        'thoi_gian_lam_bai_giay', r.thoi_gian_lam_bai_giay
      )
      FROM public.vw_pm_top_vong_loai r
      WHERE r.hang_toan_quoc <= 56
      ORDER BY r.hang_toan_quoc;
    WHEN 'contest_finalists' THEN
      RETURN QUERY
      SELECT jsonb_build_object(
        'thi_sinh_id', r.thi_sinh_id,
        'ho_ten', r.ho_ten,
        'truong_hoc', r.truong_hoc,
        'tinh_thanh', r.tinh_thanh,
        'bang_dau', r.bang_dau,
        'ten_cuoc_thi', r.ten_cuoc_thi,
        'ngay_thi_chung_ket', r.ngay_thi_chung_ket,
        'tinh_trang_xac_nhan', r.tinh_trang_xac_nhan
      )
      FROM public.vw_export_danhsach_chungket r
      ORDER BY r.ho_ten;
    WHEN 'submission_details' THEN
      RETURN QUERY SELECT to_jsonb(r) FROM public.vw_pm_chi_tiet_bai_lam r;
    WHEN 'support_conversations' THEN
      RETURN QUERY SELECT to_jsonb(r) FROM public.vw_ds_hoithoai r ORDER BY r.thoi_gian DESC LIMIT 200;
    WHEN 'support_by_status' THEN
      RETURN QUERY SELECT jsonb_build_object('trang_thai', q.trang_thai, 'so_luong', count(*))
      FROM public.qna q GROUP BY q.trang_thai ORDER BY q.trang_thai;
    WHEN 'support_by_entity' THEN
      RETURN QUERY SELECT jsonb_build_object('loai_doi_tuong', r.loai_doi_tuong, 'so_luong', count(*))
      FROM public.vw_ds_hoithoai r GROUP BY r.loai_doi_tuong ORDER BY r.loai_doi_tuong;
    WHEN 'support_faq_summary' THEN
      RETURN QUERY SELECT to_jsonb(r) FROM public.vw_faq_tongquan r;
    WHEN 'support_faq_categories' THEN
      RETURN QUERY SELECT to_jsonb(r) FROM public.vw_faq_cay_danhmuc r;
    WHEN 'security_log' THEN
      RETURN QUERY SELECT to_jsonb(r) FROM public.fn_nhat_ky_bao_mat(100) r;
    WHEN 'import_sessions' THEN
      RETURN QUERY
      SELECT jsonb_build_object(
        'import_id', i.import_id,
        'ten_file', i.ten_file,
        'ten_bang_dich', i.ten_bang_dich,
        'thoi_gian_bat_dau', i.thoi_gian_bat_dau,
        'thoi_gian_ket_thuc', i.thoi_gian_ket_thuc,
        'tong_so_dong', i.tong_so_dong,
        'so_dong_thanh_cong', i.so_dong_thanh_cong,
        'so_dong_loi', i.so_dong_loi,
        'trang_thai', i.trang_thai
      )
      FROM public.audit_log_import i
      ORDER BY i.thoi_gian_bat_dau DESC
      LIMIT 100;
    WHEN 'import_errors' THEN
      RETURN QUERY
      SELECT jsonb_build_object(
        'import_id', d.import_id,
        'ten_file', i.ten_file,
        'so_dong', d.so_dong,
        'cot_loi', d.cot_loi,
        'vi_tri_loi', d.vi_tri_loi,
        'ma_loi', d.ma_loi,
        'thong_diep_loi', d.thong_diep_loi,
        'thoi_gian_loi', d.thoi_gian_loi
      )
      FROM public.audit_log_import_chitiet d
      JOIN public.audit_log_import i ON i.import_id = d.import_id
      WHERE d.ket_qua = 'LOI'
      ORDER BY d.thoi_gian_loi DESC
      LIMIT 200;
  END CASE;
END;
$$;

REVOKE ALL ON FUNCTION public.fn_current_user_report_permissions() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_current_user_report_permissions() TO authenticated;
REVOKE ALL ON FUNCTION public.fn_current_user_can_view_student_records() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.fn_xuat_thisinh(character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.fn_xuat_thisinh(character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying) TO authenticated;
REVOKE ALL ON FUNCTION public.fn_loc_thisinh(character varying, character varying, integer, character varying, character varying, character varying, character varying) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.fn_loc_thisinh(character varying, character varying, integer, character varying, character varying, character varying, character varying) TO authenticated;
REVOKE ALL ON FUNCTION public.fn_xem_chi_tiet_thisinh(character varying) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.fn_xem_chi_tiet_thisinh(character varying) TO authenticated;
REVOKE ALL ON FUNCTION public.fn_tim_kiem_thisinh(character varying) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.fn_tim_kiem_thisinh(character varying) TO authenticated;
REVOKE ALL ON FUNCTION public.fn_bao_cao_du_lieu(character varying, character varying) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_bao_cao_du_lieu(character varying, character varying) TO authenticated;

DO $$
DECLARE
  routine record;
BEGIN
  FOR routine IN
    SELECT p.oid::regprocedure AS signature
    FROM pg_catalog.pg_proc p
    JOIN pg_catalog.pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.prokind = 'f'
      AND (
        p.proname LIKE 'fn_kpi_%'
        OR p.proname LIKE 'fn_dashboard_%'
        OR p.proname IN ('fn_nhat_ky_bao_mat', 'fn_tiep_can')
      )
  LOOP
    EXECUTE format('REVOKE ALL ON FUNCTION %s FROM PUBLIC, anon, authenticated', routine.signature);
  END LOOP;
END;
$$;

REVOKE ALL ON TABLE public.audit_log_import, public.audit_log_import_chitiet FROM anon, authenticated;
REVOKE ALL ON TABLE
  public.thisinh,
  public.dangky,
  public.dangkyweb,
  public.thanhtoan,
  public.bainop,
  public.quangcao,
  public.doanhnghiep_pipeline,
  public.qna
FROM anon;
REVOKE ALL ON TABLE
  public.vw_giao_dich_le_phi,
  public.vw_doitac_taitro_theo_cap,
  public.vw_doitac_taitro_gia_tri,
  public.vw_doitac_taitro_pheu,
  public.vw_doitac_taitro_tong_quan,
  public.vw_export_baocao_taitro,
  public.vw_doitac_cungcap_tong_quan,
  public.vw_export_baocao_dn_thisinh,
  public.vw_dashboard_phan_bo_bang_thi,
  public.vw_dashboard_phan_bo_nhom_tuoi,
  public.vw_thisinh_bieudo_trangthai,
  public.vw_thisinh_bieudo_theo_truong,
  public.vw_bainop_diem_pct,
  public.vw_baocao_phanbo_trangthai_bainop,
  public.vw_baitap_tyle_khong_dat_cao,
  public.vw_tyle_khong_dat_theo_khuvuc,
  public.vw_pm_tong_quan,
  public.vw_pm_vong_thi,
  public.vw_pm_chi_tiet_vong,
  public.vw_pm_vong_loai_tong_quan,
  public.vw_pm_bxh_tam_thoi,
  public.vw_pm_top_vong_loai,
  public.vw_pm_chi_tiet_bai_lam,
  public.vw_pm_chungket_tong_quan,
  public.vw_export_ketqua_vongloai,
  public.vw_export_danhsach_chungket,
  public.vw_ds_baitap,
  public.vw_ds_bainop,
  public.vw_rag_tongquan,
  public.vw_faq_tongquan
FROM anon, authenticated;

NOTIFY pgrst, 'reload schema';

-- =============================================================================
-- Source: supabase/migrations/admin_module_access.sql
-- =============================================================================

-- Run after 004_reporting.sql and 005_kpi_rbac.sql.
-- This RPC exposes a fixed allowlist of read-only module data to signed-in users.
-- It intentionally does not expose mutation, export, or arbitrary SQL functions.

CREATE OR REPLACE FUNCTION public.fn_admin_module_data(
  p_resource text,
  p_ky text DEFAULT '2026-Q3',
  p_filter text DEFAULT NULL,
  p_limit integer DEFAULT 50
)
RETURNS TABLE (row_data jsonb)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_limit integer := LEAST(GREATEST(COALESCE(p_limit, 50), 1), 100);
  v_ky text := COALESCE(NULLIF(p_ky, ''), '2026-Q3');
  v_filter text := NULLIF(btrim(p_filter), '');
BEGIN
  CASE p_resource
    WHEN 'student_status' THEN
      RETURN QUERY SELECT to_jsonb(v) FROM public.vw_thisinh_bieudo_trangthai v LIMIT v_limit;
    WHEN 'student_schools' THEN
      RETURN QUERY SELECT to_jsonb(v) FROM public.vw_thisinh_bieudo_theo_truong v LIMIT v_limit;
    WHEN 'students' THEN
      RETURN QUERY
        SELECT to_jsonb(v)
        FROM public.fn_loc_thisinh(NULL, v_filter, NULL, NULL, NULL, NULL, NULL) v
        LIMIT v_limit;

    WHEN 'partner_sponsor_summary' THEN
      RETURN QUERY SELECT to_jsonb(v) FROM public.vw_doitac_taitro_tong_quan v LIMIT v_limit;
    WHEN 'partner_sponsors' THEN
      RETURN QUERY SELECT to_jsonb(v) FROM public.vw_doitac_taitro_ds v LIMIT v_limit;
    WHEN 'partner_supplier_summary' THEN
      RETURN QUERY SELECT to_jsonb(v) FROM public.vw_doitac_cungcap_tong_quan v LIMIT v_limit;
    WHEN 'partner_suppliers' THEN
      RETURN QUERY SELECT to_jsonb(v) FROM public.vw_doitac_cungcap_ds v LIMIT v_limit;

    WHEN 'contest_summary' THEN
      RETURN QUERY SELECT to_jsonb(v) FROM public.vw_pm_tong_quan v LIMIT v_limit;
    WHEN 'contests' THEN
      RETURN QUERY SELECT to_jsonb(v) FROM public.vw_pm_vong_thi v LIMIT v_limit;
    WHEN 'contest_round_summary' THEN
      RETURN QUERY SELECT to_jsonb(v) FROM public.vw_pm_vong_loai_tong_quan v LIMIT v_limit;
    WHEN 'final_round_summary' THEN
      RETURN QUERY SELECT to_jsonb(v) FROM public.vw_pm_chungket_tong_quan v LIMIT v_limit;

    WHEN 'assignment_summary' THEN
      RETURN QUERY SELECT to_jsonb(v) FROM public.fn_baitap_tong_quan_kpi(NULL) v LIMIT v_limit;
    WHEN 'assignments' THEN
      RETURN QUERY
        SELECT to_jsonb(v)
        FROM public.fn_baitap_tim_kiem(v_filter, NULL, NULL, 1, v_limit) v
        LIMIT v_limit;
    WHEN 'submission_status' THEN
      RETURN QUERY SELECT to_jsonb(v) FROM public.vw_baocao_phanbo_trangthai_bainop v LIMIT v_limit;
    WHEN 'submissions' THEN
      RETURN QUERY
        SELECT to_jsonb(v)
        FROM public.fn_bainop_tim_kiem(v_filter, NULL, NULL, NULL, 1, v_limit) v
        LIMIT v_limit;
    WHEN 'failure_by_assignment' THEN
      RETURN QUERY SELECT to_jsonb(v) FROM public.vw_baitap_tyle_khong_dat_cao v LIMIT v_limit;
    WHEN 'failure_by_region' THEN
      RETURN QUERY SELECT to_jsonb(v) FROM public.vw_tyle_khong_dat_theo_khuvuc v LIMIT v_limit;

    WHEN 'rag_summary' THEN
      RETURN QUERY SELECT to_jsonb(v) FROM public.vw_rag_tongquan v LIMIT v_limit;
    WHEN 'documents' THEN
      RETURN QUERY
        SELECT to_jsonb(v)
        FROM public.fn_tailieu_tim_kiem_loc(v_filter, NULL, NULL, 1, v_limit) v
        LIMIT v_limit;

    WHEN 'conversations' THEN
      RETURN QUERY
        SELECT to_jsonb(v)
        FROM public.fn_hoithoai_tim_kiem_theo_ten(COALESCE(v_filter, '')) v
        ORDER BY v.thoi_gian DESC
        LIMIT v_limit;
    WHEN 'faq_summary' THEN
      RETURN QUERY SELECT to_jsonb(v) FROM public.vw_faq_tongquan v LIMIT v_limit;
    WHEN 'faq_categories' THEN
      RETURN QUERY SELECT to_jsonb(v) FROM public.vw_faq_cay_danhmuc v LIMIT v_limit;
    WHEN 'faq_list' THEN
      IF v_filter IS NULL THEN
        RETURN QUERY
          SELECT to_jsonb(v)
          FROM public.fn_faq_danh_sach_theo_danh_muc(NULL) v
          LIMIT v_limit;
      ELSE
        RETURN QUERY
          SELECT to_jsonb(v)
          FROM public.fn_faq_tim_kiem(v_filter) v
          LIMIT v_limit;
      END IF;

    WHEN 'kpi_overview' THEN
      RETURN QUERY SELECT to_jsonb(v) FROM public.fn_kpi_tongquan_chiso(v_ky) v LIMIT v_limit;
    WHEN 'kpi_signals' THEN
      RETURN QUERY SELECT to_jsonb(v) FROM public.fn_kpi_tongquan_tin_hieu(v_ky) v LIMIT v_limit;
    WHEN 'kpi_progress' THEN
      RETURN QUERY SELECT to_jsonb(v) FROM public.fn_kpi_tongquan_tien_do(v_ky) v LIMIT v_limit;
    WHEN 'student_kpi' THEN
      RETURN QUERY SELECT to_jsonb(v) FROM public.fn_kpi_thisinh_tong_quan(v_ky) v LIMIT v_limit;
    WHEN 'student_funnel' THEN
      RETURN QUERY SELECT to_jsonb(v) FROM public.fn_kpi_thisinh_pheu(v_ky) v LIMIT v_limit;
    WHEN 'sponsor_kpi' THEN
      RETURN QUERY SELECT to_jsonb(v) FROM public.fn_kpi_taitro_tong_quan(v_ky) v LIMIT v_limit;
    WHEN 'revenue_kpi' THEN
      RETURN QUERY SELECT to_jsonb(v) FROM public.fn_kpi_doanhthu_tong_quan(v_ky) v LIMIT v_limit;
    WHEN 'revenue_funnel' THEN
      RETURN QUERY SELECT to_jsonb(v) FROM public.fn_kpi_doanhthu_pheu(v_ky) v LIMIT v_limit;
    WHEN 'revenue_channels' THEN
      RETURN QUERY SELECT to_jsonb(v) FROM public.fn_kpi_doanhthu_theo_kenh(v_ky) v LIMIT v_limit;
    WHEN 'revenue_trend' THEN
      RETURN QUERY SELECT to_jsonb(v) FROM public.fn_kpi_doanhthu_xu_huong(v_ky) v LIMIT v_limit;
    WHEN 'payment_pending' THEN
      RETURN QUERY SELECT to_jsonb(v) FROM public.fn_kpi_doanhthu_cho_doi_soat_48h(v_ky) v LIMIT v_limit;
    WHEN 'marketing_roi' THEN
      RETURN QUERY SELECT to_jsonb(v) FROM public.fn_kpi_thisinh_utm_roi(v_ky) v LIMIT v_limit;

    WHEN 'roles' THEN
      RETURN QUERY SELECT to_jsonb(v) FROM public.vw_vaitro v LIMIT v_limit;
    WHEN 'permissions' THEN
      RETURN QUERY
        SELECT to_jsonb(v)
        FROM public.fn_ma_tran_phan_quyen(COALESCE(v_filter, 'ADMIN')) v
        LIMIT v_limit;
    WHEN 'security_audit' THEN
      RETURN QUERY SELECT to_jsonb(v) FROM public.fn_nhat_ky_bao_mat(v_limit) v LIMIT v_limit;
    ELSE
      RAISE EXCEPTION 'Unsupported admin module resource: %', p_resource;
  END CASE;
END;
$$;

REVOKE ALL ON FUNCTION public.fn_admin_module_data(text, text, text, integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_admin_module_data(text, text, text, integer) TO authenticated;

-- Q3 dashboard RPCs are read-only and use fixed, aggregate result shapes.
REVOKE ALL ON FUNCTION public.fn_dashboard_card_public(integer) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.fn_dashboard_xu_huong_16_ngay_public() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.fn_dashboard_pheu_chuyen_doi_web_public(integer) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.fn_dashboard_phan_bo_nhom_tuoi_public() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.fn_dashboard_card_q3_public(integer) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.fn_dashboard_xu_huong_q3_public(integer) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.fn_dashboard_pheu_q3_public(integer) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.fn_dashboard_phan_bo_bang_thi_q3_public(integer) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.fn_dashboard_phan_bo_nhom_tuoi_q3_public(integer) FROM PUBLIC, anon;
REVOKE SELECT ON public.vw_dashboard_phan_bo_bang_thi FROM anon;
REVOKE SELECT ON public.vw_dashboard_phan_bo_nhom_tuoi FROM anon;

GRANT EXECUTE ON FUNCTION public.fn_dashboard_card_q3_public(integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.fn_dashboard_xu_huong_q3_public(integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.fn_dashboard_pheu_q3_public(integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.fn_dashboard_phan_bo_bang_thi_q3_public(integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.fn_dashboard_phan_bo_nhom_tuoi_q3_public(integer) TO authenticated;

NOTIFY pgrst, 'reload schema';
