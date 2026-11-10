/* ================================================================
   005_kpi_rbac.sql 
   ================================================================ */

/* ---------- Nền tảng dùng chung ---------- */
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

-- Mỗi (người, trạng thái) chỉ giữ 1 giao dịch, ưu tiên nguồn DANGKYWEB
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
  WITH r AS (SELECT * FROM fn_ky_bao_cao(p_ky))
  SELECT v.thoi_gian_thanh_toan::date, v.bang_dau, count(*), sum(v.so_tien) FROM vw_giao_dich_le_phi v, r
  WHERE v.doanh_nghiep_id IS NOT NULL AND v.trang_thai_thanh_toan = 'THANH_TOAN_THANH_CONG' AND v.thoi_gian_thanh_toan >= r.tu AND v.thoi_gian_thanh_toan < r.den
  GROUP BY v.thoi_gian_thanh_toan::date, v.bang_dau ORDER BY 1, 2 $$;

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