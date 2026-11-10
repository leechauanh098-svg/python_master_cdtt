-- =============================================================================
-- Source: supabase/migrations/002_triggers_audit.sql
-- =============================================================================

/* ================================================================
   002_triggers_audit.sql
   ================================================================ */

/* ========== Tự cập nhật updated_at ========== */
CREATE OR REPLACE FUNCTION fn_touch_updated_at() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN NEW.updated_at := now(); RETURN NEW; END $$;

DO $$ DECLARE r record; BEGIN
  FOR r IN SELECT c.table_name FROM information_schema.columns c
           JOIN pg_tables t ON t.tablename = c.table_name AND t.schemaname = 'public'
           WHERE c.table_schema = 'public' AND c.column_name = 'updated_at'
  LOOP
    EXECUTE format('CREATE TRIGGER trg_touch_%1$s BEFORE UPDATE ON %1$I FOR EACH ROW EXECUTE FUNCTION fn_touch_updated_at()', r.table_name);
  END LOOP;
END $$;

/* ========== Audit context (thay SESSION_CONTEXT) ========== */
CREATE OR REPLACE FUNCTION fn_set_audit_context(
  p_user_id varchar, p_user_name varchar DEFAULT NULL, p_role_id varchar DEFAULT NULL,
  p_role_name varchar DEFAULT NULL, p_client_ip varchar DEFAULT NULL) RETURNS void LANGUAGE plpgsql AS $$
BEGIN
  PERFORM set_config('app.user_id',   COALESCE(p_user_id,''),   true);
  PERFORM set_config('app.user_name', COALESCE(p_user_name,''), true);
  PERFORM set_config('app.role_id',   COALESCE(p_role_id,''),   true);
  PERFORM set_config('app.role_name', COALESCE(p_role_name,''), true);
  PERFORM set_config('app.client_ip', COALESCE(p_client_ip,''), true);
END $$;

CREATE OR REPLACE FUNCTION fn_set_audit_context_theo_nhanvien(p_nhan_vien_id varchar, p_client_ip varchar DEFAULT NULL)
RETURNS void LANGUAGE plpgsql AS $$
DECLARE v_ten varchar; v_role varchar; v_role_ten varchar;
BEGIN
  SELECT ho_ten INTO v_ten FROM nhanvien WHERE nhan_vien_id = p_nhan_vien_id;
  SELECT vt.role_id, vt.ten_vai_tro INTO v_role, v_role_ten
  FROM nhanvien_vaitro_ct ct JOIN vaitro vt ON vt.role_id = ct.role_id
  WHERE ct.nhan_vien_id = p_nhan_vien_id AND vt.trang_thai = 'DANG_AP_DUNG'
  ORDER BY ct.ngay_gan LIMIT 1;
  PERFORM fn_set_audit_context(p_nhan_vien_id, v_ten, v_role, v_role_ten, p_client_ip);
END $$;

CREATE OR REPLACE FUNCTION fn_ctx(p_key text) RETURNS text LANGUAGE sql STABLE AS
$$ SELECT NULLIF(current_setting('app.' || p_key, true), '') $$;

/* ========== Hàm nghiệp vụ dùng chung ========== */
CREATE OR REPLACE FUNCTION fn_tinh_tuoi_thi(p_ngay_sinh date) RETURNS int LANGUAGE sql STABLE AS $$
  SELECT date_part('year', age(
    COALESCE((SELECT gia_tri::date FROM cauhinh_he_thong WHERE khoa_cau_hinh = 'MOC_TINH_TUOI'), DATE '2026-09-23'),
    p_ngay_sinh))::int $$;

CREATE OR REPLACE FUNCTION fn_ty_le_hoa_hong() RETURNS numeric LANGUAGE sql STABLE AS $$
  SELECT COALESCE((SELECT gia_tri::numeric(5,4) FROM cauhinh_he_thong WHERE khoa_cau_hinh = 'TY_LE_HOA_HONG'), 0.10) $$;

CREATE OR REPLACE FUNCTION fn_le_phi_tai(p_thoi_diem timestamp DEFAULT now()::timestamp) RETURNS numeric
LANGUAGE plpgsql STABLE AS $$
DECLARE v_eb date; v_han date; v_phi numeric;
BEGIN
  SELECT gia_tri::date INTO v_eb  FROM cauhinh_he_thong WHERE khoa_cau_hinh = 'HAN_EARLY_BIRD';
  SELECT gia_tri::date INTO v_han FROM cauhinh_he_thong WHERE khoa_cau_hinh = 'HAN_THANH_TOAN';
  IF v_eb IS NULL OR v_han IS NULL THEN
    RAISE EXCEPTION 'Chưa cấu hình HAN_EARLY_BIRD / HAN_THANH_TOAN trong cauhinh_he_thong.'; END IF;
  IF p_thoi_diem < (v_eb + 1)::timestamp THEN
    SELECT gia_tri::numeric INTO v_phi FROM cauhinh_he_thong WHERE khoa_cau_hinh = 'LE_PHI_EARLY_BIRD';
  ELSIF p_thoi_diem < (v_han + 1)::timestamp THEN
    SELECT gia_tri::numeric INTO v_phi FROM cauhinh_he_thong WHERE khoa_cau_hinh = 'LE_PHI_CHUAN';
  ELSE
    RAISE EXCEPTION 'Đã hết hạn thanh toán lệ phí cuộc thi (hạn cuối: %).', to_char(v_han, 'DD/MM/YYYY');
  END IF;
  IF v_phi IS NULL OR v_phi <= 0 THEN
    RAISE EXCEPTION 'Chưa cấu hình lệ phí (LE_PHI_EARLY_BIRD / LE_PHI_CHUAN) trong cauhinh_he_thong.'; END IF;
  RETURN v_phi;
END $$;

/* ========== THISINH: ngày sinh + độ tuổi theo bảng đấu ========== */
CREATE OR REPLACE FUNCTION trg_thisinh_check_tuoi() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE v_tuoi int;
BEGIN
  IF NEW.ngay_sinh > CURRENT_DATE THEN RAISE EXCEPTION 'Ngày sinh không được lớn hơn ngày hiện tại.'; END IF;
  IF TG_OP = 'INSERT' OR NEW.ngay_sinh IS DISTINCT FROM OLD.ngay_sinh
     OR NEW.bang_dau IS DISTINCT FROM OLD.bang_dau OR NEW.trang_thai_ho_so IS DISTINCT FROM OLD.trang_thai_ho_so THEN
    IF NEW.trang_thai_ho_so IN ('CHO_DUYET','DA_DUYET') THEN
      v_tuoi := fn_tinh_tuoi_thi(NEW.ngay_sinh);
      IF v_tuoi NOT BETWEEN 12 AND 24
         OR (NEW.bang_dau = 'BANG_A' AND v_tuoi NOT BETWEEN 12 AND 18)
         OR (NEW.bang_dau = 'BANG_B' AND v_tuoi NOT BETWEEN 19 AND 24) THEN
        RAISE EXCEPTION 'Lỗi: Thí sinh % (% tuổi) không đủ điều kiện độ tuổi/bảng đấu (tổng 12-24, Bảng A: 12-18, Bảng B: 19-24).', NEW.thi_sinh_id, v_tuoi;
      END IF;
    END IF;
  END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER trg_thisinh_check_tuoi BEFORE INSERT OR UPDATE ON thisinh FOR EACH ROW EXECUTE FUNCTION trg_thisinh_check_tuoi();

/* ========== CUOCTHI: hạn đăng ký > thời điểm tạo ========== */
CREATE OR REPLACE FUNCTION trg_cuocthi_check_han_dk() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF NEW.han_dang_ky <= COALESCE(NEW.created_at, now()) THEN
    RAISE EXCEPTION 'Lỗi: Hạn đăng ký phải lớn hơn thời điểm tạo cuộc thi (BR_CT_02).'; END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER trg_cuocthi_check_han_dk BEFORE INSERT ON cuocthi FOR EACH ROW EXECUTE FUNCTION trg_cuocthi_check_han_dk();

/* ========== DANGKY: thời gian đăng ký <= hạn ========== */
CREATE OR REPLACE FUNCTION trg_dangky_check_han() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF EXISTS (SELECT 1 FROM cuocthi c WHERE c.cuoc_thi_id = NEW.cuoc_thi_id AND NEW.ngay_dang_ky > c.han_dang_ky) THEN
    RAISE EXCEPTION 'Lỗi: Thời gian đăng ký vượt quá hạn đăng ký cuộc thi'; END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER trg_dangky_check_han BEFORE INSERT ON dangky FOR EACH ROW EXECUTE FUNCTION trg_dangky_check_han();

/* ========== THANHTOAN: khớp bảng đấu, lệ phí; thanh toán xong => đăng ký THANH_CONG ========== */
CREATE OR REPLACE FUNCTION trg_thanhtoan_rules() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE v_bang varchar; v_eb numeric; v_chuan numeric; v_check boolean;
BEGIN
  SELECT bang_dau INTO v_bang FROM thisinh WHERE thi_sinh_id = NEW.thi_sinh_id;
  IF NEW.bang_dau IS NOT NULL AND v_bang IS NOT NULL AND NEW.bang_dau <> v_bang THEN
    RAISE EXCEPTION 'Lỗi: Bảng đấu thanh toán không khớp bảng đấu của thí sinh (BR_TT_03).'; END IF;
 
  IF TG_OP = 'INSERT' THEN v_check := true; ELSE v_check := NEW.so_tien IS DISTINCT FROM OLD.so_tien; END IF;
  IF v_check THEN
    SELECT gia_tri::numeric INTO v_eb    FROM cauhinh_he_thong WHERE khoa_cau_hinh = 'LE_PHI_EARLY_BIRD';
    SELECT gia_tri::numeric INTO v_chuan FROM cauhinh_he_thong WHERE khoa_cau_hinh = 'LE_PHI_CHUAN';
    IF (v_eb IS NOT NULL OR v_chuan IS NOT NULL) AND NEW.so_tien <> 0
       AND NEW.so_tien IS DISTINCT FROM v_eb AND NEW.so_tien IS DISTINCT FROM v_chuan THEN
      RAISE EXCEPTION 'Lỗi: Số tiền thanh toán không khớp lệ phí đã cấu hình (BR_TT_01).'; END IF;
  END IF;
 
  IF NEW.trang_thai_thanh_toan = 'THANH_TOAN_THANH_CONG' THEN
    UPDATE dangky SET trang_thai = 'THANH_CONG'
    WHERE thi_sinh_id = NEW.thi_sinh_id AND cuoc_thi_id = NEW.cuoc_thi_id AND trang_thai = 'CHO_THANH_TOAN';
  ELSIF NEW.trang_thai_thanh_toan = 'HOAN_TIEN' THEN
    UPDATE dangky SET trang_thai = 'HUY_DANG_KY'
    WHERE thi_sinh_id = NEW.thi_sinh_id AND cuoc_thi_id = NEW.cuoc_thi_id AND trang_thai <> 'HUY_DANG_KY';
  END IF;
  RETURN NULL;
END $$;

/* ========== BAINOP ========== */
CREATE OR REPLACE FUNCTION trg_bainop_rules() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE b baitap%ROWTYPE; v_bang varchar;
BEGIN
  SELECT * INTO b FROM baitap WHERE bai_tap_id = NEW.bai_tap_id;
  IF TG_OP = 'INSERT' THEN
    SELECT bang_dau INTO v_bang FROM thisinh WHERE thi_sinh_id = NEW.thi_sinh_id;
    IF v_bang IS NOT NULL AND b.bang_dau <> v_bang THEN RAISE EXCEPTION 'Lỗi: Bảng đấu của bài tập không khớp thí sinh (BR_BT_01).'; END IF;
    IF NEW.lan_nop > b.so_lan_nop_bai_toi_da THEN RAISE EXCEPTION 'Lỗi: Vượt số lần nộp tối đa của bài tập.'; END IF;
    IF NEW.lan_nop > 1 AND NOT EXISTS (SELECT 1 FROM bainop x WHERE x.bai_tap_id = NEW.bai_tap_id
         AND x.thi_sinh_id = NEW.thi_sinh_id AND x.lan_nop = NEW.lan_nop - 1) THEN
      RAISE EXCEPTION 'Lỗi: LAN_NOP phải tăng dần liên tục (BR_BT_07).'; END IF;
    IF NEW.thoi_gian_bat_dau > b.ngay_het_han THEN RAISE EXCEPTION 'Lỗi: Bài tập đã hết hạn, hệ thống khóa nộp bài (BR_BT_03).'; END IF;
  END IF;
  IF NEW.thoi_gian_nop IS NOT NULL AND NEW.thoi_gian_nop > b.ngay_het_han THEN NEW.trang_thai := 'QUA_HAN_NOP'; END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER trg_bainop_rules BEFORE INSERT OR UPDATE ON bainop FOR EACH ROW EXECUTE FUNCTION trg_bainop_rules();

/* ========== CHI_TIET_DAP_AN_NOP: kiểm tra + tổng điểm = SUM(chi tiết) ========== */
CREATE OR REPLACE FUNCTION trg_ctdan_rules() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE v_bn varchar; v_max numeric;
BEGIN
  IF TG_OP <> 'DELETE' THEN
    IF EXISTS (SELECT 1 FROM bainop n JOIN cauhoi q ON q.cau_hoi_id = NEW.cau_hoi_id
               WHERE n.bai_nop_id = NEW.bai_nop_id AND q.bai_tap_id <> n.bai_tap_id) THEN
      RAISE EXCEPTION 'Lỗi: Câu hỏi không thuộc bài tập của bài nộp.'; END IF;
    SELECT diem_toi_da INTO v_max FROM cauhoi WHERE cau_hoi_id = NEW.cau_hoi_id;
    IF NEW.diem_dat_duoc > v_max THEN RAISE EXCEPTION 'Lỗi: Điểm đạt được vượt điểm tối đa của câu hỏi.'; END IF;
    v_bn := NEW.bai_nop_id;
  ELSE v_bn := OLD.bai_nop_id; END IF;
  UPDATE bainop SET tong_diem = (SELECT sum(diem_dat_duoc) FROM chi_tiet_dap_an_nop WHERE bai_nop_id = v_bn)
  WHERE bai_nop_id = v_bn;
  RETURN NULL;
END $$;
CREATE TRIGGER trg_ctdan_rules AFTER INSERT OR UPDATE OR DELETE ON chi_tiet_dap_an_nop FOR EACH ROW EXECUTE FUNCTION trg_ctdan_rules();

/* ========== QNA: nhân viên hỗ trợ đúng phòng ban ========== */
CREATE OR REPLACE FUNCTION trg_qna_check_nhanvien() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF EXISTS (SELECT 1 FROM nhanvien nv WHERE nv.nhan_vien_id = NEW.nhan_vien_id_ho_tro
             AND nv.phong_ban NOT IN ('CUSTOMER_SUPPORT','BAN_TO_CHUC','ACADEMIC')) THEN
    RAISE EXCEPTION 'Lỗi: Nhân viên hỗ trợ phải thuộc CUSTOMER_SUPPORT / BAN_TO_CHUC / ACADEMIC (BR_QA_02).'; END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER trg_qna_check_nhanvien BEFORE INSERT OR UPDATE ON qna FOR EACH ROW EXECUTE FUNCTION trg_qna_check_nhanvien();

/* ========== Chống mất Admin cuối cùng ========== */
CREATE OR REPLACE FUNCTION trg_prevent_disable_last_admin() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF OLD.trang_thai = 'ACTIVE' AND NEW.trang_thai <> 'ACTIVE'
     AND EXISTS (SELECT 1 FROM nhanvien_vaitro_ct WHERE nhan_vien_id = NEW.nhan_vien_id AND role_id = 'ADMIN')
     AND NOT EXISTS (SELECT 1 FROM nhanvien nv JOIN nhanvien_vaitro_ct ct ON ct.nhan_vien_id = nv.nhan_vien_id
                     WHERE ct.role_id = 'ADMIN' AND nv.trang_thai = 'ACTIVE') THEN
    RAISE EXCEPTION 'Lỗi: Không thể vô hiệu hóa tài khoản Admin duy nhất đang hoạt động!'; END IF;
  RETURN NULL;
END $$;
CREATE TRIGGER trg_prevent_disable_last_admin AFTER UPDATE ON nhanvien FOR EACH ROW EXECUTE FUNCTION trg_prevent_disable_last_admin();

CREATE OR REPLACE FUNCTION trg_prevent_delete_last_admin() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF OLD.role_id = 'ADMIN'
     AND EXISTS (SELECT 1 FROM nhanvien WHERE nhan_vien_id = OLD.nhan_vien_id AND trang_thai = 'ACTIVE')
     AND NOT EXISTS (SELECT 1 FROM nhanvien nv JOIN nhanvien_vaitro_ct ct ON ct.nhan_vien_id = nv.nhan_vien_id
                     WHERE ct.role_id = 'ADMIN' AND nv.trang_thai = 'ACTIVE') THEN
    RAISE EXCEPTION 'Lỗi: Không thể xóa vai trò Admin của tài khoản Admin duy nhất đang hoạt động!'; END IF;
  RETURN NULL;
END $$;
CREATE TRIGGER trg_prevent_delete_last_admin AFTER DELETE ON nhanvien_vaitro_ct FOR EACH ROW EXECUTE FUNCTION trg_prevent_delete_last_admin();

/* ========== AUDIT: 1 hàm dùng chung cho mọi bảng ==========
   Tham số trigger: (khóa 1, khóa 2 hoặc '', hành động khi INSERT hoặc '') */
CREATE OR REPLACE FUNCTION fn_audit() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE
  v_k1 text := TG_ARGV[0]; v_k2 text := NULLIF(TG_ARGV[1], '');
  v_act text; v_old jsonb; v_new jsonb; v_row jsonb; v_id text; v_note text;
  v_strip text[] := ARRAY['embedding']; v_ign text[] := ARRAY['updated_at'];
  v_uid text := fn_ctx('user_id'); v_uname text := fn_ctx('user_name'); v_ip text := fn_ctx('client_ip');
BEGIN
  IF TG_TABLE_NAME = 'tailieu_doan' THEN v_strip := v_strip || 'noi_dung_doan'; END IF;
  IF TG_TABLE_NAME = 'faq_canonical' THEN v_ign := v_ign || 'luot_xem'; END IF;
 
  IF TG_OP = 'INSERT' THEN
    v_act := COALESCE(NULLIF(TG_ARGV[2], ''), 'THEM'); v_new := to_jsonb(NEW) - v_strip; v_row := v_new;
  ELSIF TG_OP = 'UPDATE' THEN
    v_act := 'SUA';
    IF (to_jsonb(OLD) - v_ign) = (to_jsonb(NEW) - v_ign) THEN RETURN NULL; END IF;   -- không có thay đổi thực sự
    v_old := to_jsonb(OLD) - v_strip; v_new := to_jsonb(NEW) - v_strip; v_row := v_new;
  ELSE
    v_act := 'XOA'; v_old := to_jsonb(OLD) - v_strip; v_row := v_old;
  END IF;
  v_id := v_row ->> v_k1;
  IF v_k2 IS NOT NULL THEN v_id := v_id || '|' || (v_row ->> v_k2); END IF;
 
  IF TG_TABLE_NAME = 'dangky' THEN
    v_note := CASE TG_OP
      WHEN 'INSERT' THEN 'Thí sinh ' || (v_row ->> 'thi_sinh_id') || ' đăng ký cuộc thi ' || (v_row ->> 'cuoc_thi_id')
      WHEN 'UPDATE' THEN CASE WHEN OLD.trang_thai <> NEW.trang_thai THEN 'Đổi trạng thái đăng ký: ' || OLD.trang_thai || ' -> ' || NEW.trang_thai END
      ELSE 'Hủy đăng ký của thí sinh ' || (v_row ->> 'thi_sinh_id') || ' - cuộc thi ' || (v_row ->> 'cuoc_thi_id') END;
  ELSIF TG_TABLE_NAME = 'vaitro_quyen' THEN
    v_note := '[PHÂN QUYỀN] ' || CASE TG_OP WHEN 'INSERT' THEN 'Gán' WHEN 'DELETE' THEN 'Thu hồi' ELSE 'Cập nhật' END
              || ' quyền ' || (v_row ->> 'permission_id') || ' - vai trò ' || (v_row ->> 'role_id');
  ELSIF TG_TABLE_NAME = 'log_dangnhap' AND TG_OP = 'INSERT' THEN
    v_uid := NEW.nhan_vien_id; v_ip := NEW.ip_address;
    SELECT ho_ten INTO v_uname FROM nhanvien WHERE nhan_vien_id = NEW.nhan_vien_id;
    v_note := CASE WHEN NEW.trang_thai = 'THANH_CONG' THEN 'Đăng nhập thành công' ELSE 'Đăng nhập thất bại' END;
  END IF;
 
  INSERT INTO audit_log (nguoi_thuc_hien_id, nguoi_thuc_hien, actor_role_id, vai_tro, dia_chi_ip,
                         ten_bang, id_ban_ghi, hanh_dong, du_lieu_cu, du_lieu_moi, ghi_chu)
  VALUES (v_uid, v_uname, fn_ctx('role_id'), fn_ctx('role_name'), v_ip,
          upper(TG_TABLE_NAME), v_id, v_act, v_old::text, v_new::text, v_note);
  RETURN NULL;
END $$;

DO $$ DECLARE r record; BEGIN
  FOR r IN SELECT * FROM (VALUES
    ('nhanvien','nhan_vien_id','',''), ('thisinh','thi_sinh_id','',''), ('doanhnghiep','doanh_nghiep_id','',''),
    ('cuocthi','cuoc_thi_id','',''), ('thanhtoan','thanh_toan_id','',''), ('baitap','bai_tap_id','',''),
    ('cauhoi','cau_hoi_id','',''), ('lua_chon_dap_an','dap_an_id','',''), ('bainop','bai_nop_id','',''),
    ('chi_tiet_dap_an_nop','chi_tiet_id','',''), ('danhmuc','danh_muc_id','',''), ('tailieu','tai_lieu_id','',''),
    ('tag','tag_id','',''), ('tailieu_doan','doan_id','',''), ('qna','qna_id','',''), ('qna_phanhoi','phan_hoi_id','',''),
    ('bieumau','bieu_mau_log','',''), ('quangcao','quang_cao_log','',''), ('dangkyweb','thanh_toan_id','',''),
    ('vaitro','role_id','',''), ('quyen','permission_id','',''), ('faq_canonical','faq_id','',''),
    ('tailieu_tag','tai_lieu_id','tag_id',''), ('vaitro_quyen','role_id','permission_id',''),
    ('dangky','dang_ky_id','','DANG_KY'), ('log_dangnhap','log_dn_id','','DANG_NHAP')
  ) v(t, k1, k2, act)
  LOOP
    EXECUTE format('CREATE TRIGGER trg_audit_%1$s AFTER INSERT OR UPDATE OR DELETE ON %1$I FOR EACH ROW EXECUTE FUNCTION fn_audit(%2$L, %3$L, %4$L)',
                   r.t, r.k1, r.k2, r.act);
  END LOOP;
END $$;

/* ========== IMPORT: đồng bộ số dòng lỗi ========== */
CREATE OR REPLACE FUNCTION trg_import_chitiet_sync() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE v_id bigint;
BEGIN
  v_id := CASE TG_OP WHEN 'DELETE' THEN OLD.import_id ELSE NEW.import_id END;
  UPDATE audit_log_import SET so_dong_loi =
    (SELECT count(DISTINCT so_dong) FROM audit_log_import_chitiet WHERE import_id = v_id AND ket_qua = 'LOI')
  WHERE import_id = v_id;
  RETURN NULL;
END $$;
CREATE TRIGGER trg_import_chitiet_sync AFTER INSERT OR UPDATE OR DELETE ON audit_log_import_chitiet
FOR EACH ROW EXECUTE FUNCTION trg_import_chitiet_sync();

CREATE OR REPLACE FUNCTION fn_import_bat_dau(p_nguoi varchar, p_ten_file varchar, p_ten_bang varchar,
  p_ip varchar DEFAULT NULL, p_ghi_chu varchar DEFAULT NULL) RETURNS bigint LANGUAGE plpgsql AS $$
DECLARE v_id bigint; v_ten varchar;
BEGIN
  SELECT ho_ten INTO v_ten FROM nhanvien WHERE nhan_vien_id = p_nguoi;
  INSERT INTO audit_log_import (nhan_vien_id, ten_file, ten_bang_dich, dia_chi_ip, ghi_chu)
  VALUES (p_nguoi, p_ten_file, p_ten_bang, p_ip, p_ghi_chu) RETURNING import_id INTO v_id;
  INSERT INTO audit_log (nguoi_thuc_hien_id, nguoi_thuc_hien, dia_chi_ip, ten_bang, id_ban_ghi, hanh_dong, ghi_chu)
  VALUES (p_nguoi, v_ten, p_ip, upper(p_ten_bang), v_id::text, 'IMPORT', 'Bắt đầu import file "' || p_ten_file || '" vào bảng ' || p_ten_bang);
  RETURN v_id;
END $$;

CREATE OR REPLACE FUNCTION fn_import_ghi_loi(p_import_id bigint, p_so_dong int, p_ma_loi varchar, p_noi_dung_loi varchar,
  p_ten_cot varchar DEFAULT NULL, p_vi_tri_cot int DEFAULT NULL, p_gia_tri_loi varchar DEFAULT NULL, p_du_lieu_dong text DEFAULT NULL)
RETURNS void LANGUAGE plpgsql AS $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM audit_log_import WHERE import_id = p_import_id) THEN
    RAISE EXCEPTION 'IMPORT_ID % không tồn tại.', p_import_id; END IF;
  INSERT INTO audit_log_import_chitiet (import_id, so_dong, ket_qua, du_lieu_dong, cot_loi, vi_tri_loi, ma_loi, thong_diep_loi)
  VALUES (p_import_id, p_so_dong, 'LOI', COALESCE(p_du_lieu_dong, p_gia_tri_loi), p_ten_cot,
          CASE WHEN p_vi_tri_cot IS NULL THEN 'Dòng ' || p_so_dong ELSE 'Dòng ' || p_so_dong || ', cột ' || p_vi_tri_cot END,
          p_ma_loi, p_noi_dung_loi);
END $$;

CREATE OR REPLACE FUNCTION fn_import_ket_thuc(p_import_id bigint, p_tong_so_dong int, p_so_dong_thanh_cong int,
  p_trang_thai varchar DEFAULT NULL, p_ghi_chu varchar DEFAULT NULL) RETURNS void LANGUAGE plpgsql AS $$
DECLARE v_loi int; v_file varchar; v_bang varchar; v_final varchar;
BEGIN
  SELECT so_dong_loi, ten_file, ten_bang_dich INTO v_loi, v_file, v_bang FROM audit_log_import WHERE import_id = p_import_id;
  IF v_bang IS NULL THEN RAISE EXCEPTION 'IMPORT_ID % không tồn tại.', p_import_id; END IF;
  v_final := COALESCE(p_trang_thai, CASE WHEN v_loi = 0 AND p_so_dong_thanh_cong = p_tong_so_dong THEN 'THANH_CONG'
                                         WHEN p_so_dong_thanh_cong = 0 THEN 'THAT_BAI' ELSE 'HOAN_TAT_CO_LOI' END);
  UPDATE audit_log_import SET thoi_gian_ket_thuc = now(), tong_so_dong = p_tong_so_dong,
         so_dong_thanh_cong = p_so_dong_thanh_cong, trang_thai = v_final, ghi_chu = COALESCE(p_ghi_chu, ghi_chu)
  WHERE import_id = p_import_id;
  UPDATE audit_log SET
    du_lieu_moi = jsonb_build_object('tong_so_dong', p_tong_so_dong, 'so_dong_thanh_cong', p_so_dong_thanh_cong,
                                     'so_dong_loi', v_loi, 'trang_thai', v_final)::text,
    ghi_chu = 'Kết thúc import file "' || v_file || '" vào bảng ' || v_bang || ': Tổng ' || p_tong_so_dong
              || ', Thành công ' || p_so_dong_thanh_cong || ', Lỗi ' || v_loi
  WHERE hanh_dong = 'IMPORT' AND id_ban_ghi = p_import_id::text AND ten_bang = upper(v_bang);
END $$;

CREATE OR REPLACE VIEW vw_lich_su_import AS
SELECT ali.import_id, ali.nhan_vien_id, nv.ho_ten AS nguoi_thuc_hien, ali.ten_file, ali.ten_bang_dich,
       ali.thoi_gian_bat_dau, ali.thoi_gian_ket_thuc,
       extract(epoch FROM (ali.thoi_gian_ket_thuc - ali.thoi_gian_bat_dau))::int AS thoi_gian_xu_ly_giay,
       ali.tong_so_dong, ali.so_dong_thanh_cong, ali.so_dong_loi,
       CASE WHEN ali.tong_so_dong > 0 THEN round(ali.so_dong_thanh_cong * 100.0 / ali.tong_so_dong, 2) END AS ty_le_thanh_cong_pt,
       ali.trang_thai, ali.dia_chi_ip, ali.ghi_chu
FROM audit_log_import ali LEFT JOIN nhanvien nv ON nv.nhan_vien_id = ali.nhan_vien_id;

CREATE OR REPLACE VIEW vw_chi_tiet_loi_import AS
SELECT c.import_id, ali.ten_file, ali.ten_bang_dich, c.so_dong, c.cot_loi, c.vi_tri_loi, c.ma_loi,
       dm.mo_ta AS mo_ta_ma_loi, c.thong_diep_loi, c.du_lieu_dong, c.thoi_gian_loi
FROM audit_log_import_chitiet c
JOIN audit_log_import ali ON ali.import_id = c.import_id
LEFT JOIN dm_ma_loi_import dm ON dm.ma_loi = c.ma_loi;

/* ================ nhanvien.phan_quyen và nhanvien_vaitro_ct luôn đồng bộ ================ */
CREATE OR REPLACE FUNCTION trg_nhanvien_sync_vaitro() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF TG_OP = 'UPDATE' AND NEW.phan_quyen IS DISTINCT FROM OLD.phan_quyen THEN
    DELETE FROM nhanvien_vaitro_ct WHERE nhan_vien_id = NEW.nhan_vien_id AND role_id = OLD.phan_quyen;  -- trigger chặn nếu là Admin cuối
  END IF;
  INSERT INTO nhanvien_vaitro_ct (nhan_vien_id, role_id, nguoi_gan)
  VALUES (NEW.nhan_vien_id, NEW.phan_quyen, (SELECT nhan_vien_id FROM nhanvien WHERE nhan_vien_id = fn_ctx('user_id')))
  ON CONFLICT DO NOTHING;
  RETURN NULL;
END $$;
DROP TRIGGER IF EXISTS trg_nhanvien_sync_vaitro ON nhanvien;
CREATE TRIGGER trg_nhanvien_sync_vaitro AFTER INSERT OR UPDATE OF phan_quyen ON nhanvien
  FOR EACH ROW EXECUTE FUNCTION trg_nhanvien_sync_vaitro();

