/* ================================================================
   003_crud.sql 
   ================================================================ */

/* ================= 1. NHANVIEN ================= */
CREATE OR REPLACE FUNCTION sp_insert_nhanvien(p_nhan_vien_id varchar, p_ho_ten varchar, p_email varchar,
  p_sdt varchar, p_phong_ban varchar, p_phan_quyen varchar DEFAULT 'SUPPORT_STAFF') RETURNS void LANGUAGE plpgsql AS $$
BEGIN
  IF EXISTS (SELECT 1 FROM nhanvien WHERE nhan_vien_id = p_nhan_vien_id) THEN RAISE EXCEPTION 'Mã nhân viên % đã tồn tại.', p_nhan_vien_id; END IF;
  IF EXISTS (SELECT 1 FROM nhanvien WHERE email = p_email) THEN RAISE EXCEPTION 'Email % đã tồn tại.', p_email; END IF;
  IF p_email !~* '@sotatek\.com$' THEN RAISE EXCEPTION 'Email nội bộ phải có đuôi @sotatek.com (BR_NV_01).'; END IF;
  IF EXISTS (SELECT 1 FROM nhanvien WHERE sdt = p_sdt) THEN RAISE EXCEPTION 'Số điện thoại % đã tồn tại.', p_sdt; END IF;
  INSERT INTO nhanvien (nhan_vien_id, ho_ten, email, sdt, phong_ban, phan_quyen)
  VALUES (p_nhan_vien_id, p_ho_ten, p_email, p_sdt, p_phong_ban, p_phan_quyen);
END $$;

CREATE OR REPLACE FUNCTION sp_update_nhanvien(p_nhan_vien_id varchar, p_ho_ten varchar DEFAULT NULL, p_email varchar DEFAULT NULL,
  p_sdt varchar DEFAULT NULL, p_phong_ban varchar DEFAULT NULL, p_phan_quyen varchar DEFAULT NULL, p_trang_thai varchar DEFAULT NULL)
RETURNS void LANGUAGE plpgsql AS $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM nhanvien WHERE nhan_vien_id = p_nhan_vien_id) THEN RAISE EXCEPTION 'Nhân viên % không tồn tại.', p_nhan_vien_id; END IF;
  IF p_email IS NOT NULL AND EXISTS (SELECT 1 FROM nhanvien WHERE email = p_email AND nhan_vien_id <> p_nhan_vien_id) THEN RAISE EXCEPTION 'Email % đã được sử dụng bởi nhân viên khác.', p_email; END IF;
  IF p_email IS NOT NULL AND p_email !~* '@sotatek\.com$' THEN RAISE EXCEPTION 'Email nội bộ phải có đuôi @sotatek.com (BR_NV_01).'; END IF;
  IF p_sdt IS NOT NULL AND EXISTS (SELECT 1 FROM nhanvien WHERE sdt = p_sdt AND nhan_vien_id <> p_nhan_vien_id) THEN RAISE EXCEPTION 'Số điện thoại % đã được sử dụng bởi nhân viên khác.', p_sdt; END IF;
  UPDATE nhanvien SET ho_ten = COALESCE(p_ho_ten, ho_ten), email = COALESCE(p_email, email), sdt = COALESCE(p_sdt, sdt),
    phong_ban = COALESCE(p_phong_ban, phong_ban), phan_quyen = COALESCE(p_phan_quyen, phan_quyen),
    trang_thai = COALESCE(p_trang_thai, trang_thai) WHERE nhan_vien_id = p_nhan_vien_id;
END $$;

CREATE OR REPLACE FUNCTION sp_delete_nhanvien(p_nhan_vien_id varchar) RETURNS void LANGUAGE plpgsql AS $$
BEGIN  -- xóa mềm
  IF NOT EXISTS (SELECT 1 FROM nhanvien WHERE nhan_vien_id = p_nhan_vien_id) THEN RAISE EXCEPTION 'Nhân viên % không tồn tại.', p_nhan_vien_id; END IF;
  UPDATE nhanvien SET trang_thai = 'INACTIVE' WHERE nhan_vien_id = p_nhan_vien_id;
END $$;

/* ================= 2. DOANHNGHIEP ================= */
CREATE OR REPLACE FUNCTION sp_insert_doanhnghiep(p_doanh_nghiep_id varchar, p_ten_doanh_nghiep varchar, p_ma_so_thue varchar,
  p_dia_chi varchar, p_email_lien_he varchar, p_sdt_lien_he varchar, p_hinh_thuc varchar, p_hop_dong varchar,
  p_nganh_nghe varchar DEFAULT NULL, p_loai_tai_tro varchar DEFAULT 'KHONG_TAI_TRO', p_cap_do_tai_tro varchar DEFAULT 'KHONG')
RETURNS void LANGUAGE plpgsql AS $$
BEGIN
  IF EXISTS (SELECT 1 FROM doanhnghiep WHERE doanh_nghiep_id = p_doanh_nghiep_id) THEN RAISE EXCEPTION 'Mã doanh nghiệp % đã tồn tại.', p_doanh_nghiep_id; END IF;
  IF EXISTS (SELECT 1 FROM doanhnghiep WHERE ma_so_thue = p_ma_so_thue) THEN RAISE EXCEPTION 'Mã số thuế % đã tồn tại.', p_ma_so_thue; END IF;
  IF EXISTS (SELECT 1 FROM doanhnghiep WHERE email_lien_he = p_email_lien_he) THEN RAISE EXCEPTION 'Email liên hệ % đã tồn tại.', p_email_lien_he; END IF;
  IF p_hop_dong IS NULL OR p_hop_dong !~* '\.(pdf|doc|docx)$' THEN RAISE EXCEPTION 'Bắt buộc đính kèm file hợp đồng định dạng PDF/Word (BR_DN_05).'; END IF;
  INSERT INTO doanhnghiep (doanh_nghiep_id, ten_doanh_nghiep, ma_so_thue, dia_chi, email_lien_he, sdt_lien_he, nganh_nghe, hinh_thuc, loai_tai_tro, cap_do_tai_tro, hop_dong)
  VALUES (p_doanh_nghiep_id, p_ten_doanh_nghiep, p_ma_so_thue, p_dia_chi, p_email_lien_he, p_sdt_lien_he, p_nganh_nghe, p_hinh_thuc, p_loai_tai_tro, p_cap_do_tai_tro, p_hop_dong);
END $$;

DROP FUNCTION IF EXISTS sp_update_doanhnghiep(varchar, varchar, varchar, varchar, varchar, varchar, varchar, varchar);
CREATE OR REPLACE FUNCTION sp_update_doanhnghiep(p_doanh_nghiep_id varchar, p_ten_doanh_nghiep varchar DEFAULT NULL, p_dia_chi varchar DEFAULT NULL,
  p_email_lien_he varchar DEFAULT NULL, p_sdt_lien_he varchar DEFAULT NULL, p_nganh_nghe varchar DEFAULT NULL,
  p_hinh_thuc varchar DEFAULT NULL, p_hop_dong varchar DEFAULT NULL,
  p_loai_tai_tro varchar DEFAULT NULL, p_cap_do_tai_tro varchar DEFAULT NULL) RETURNS void LANGUAGE plpgsql AS $$
DECLARE d doanhnghiep%ROWTYPE; v_hinh varchar; v_loai varchar; v_cap varchar;
BEGIN
  SELECT * INTO d FROM doanhnghiep WHERE doanh_nghiep_id = p_doanh_nghiep_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Doanh nghiệp % không tồn tại.', p_doanh_nghiep_id; END IF;
  IF p_email_lien_he IS NOT NULL AND EXISTS (SELECT 1 FROM doanhnghiep WHERE email_lien_he = p_email_lien_he AND doanh_nghiep_id <> p_doanh_nghiep_id) THEN
    RAISE EXCEPTION 'Email % đã được sử dụng bởi doanh nghiệp khác.', p_email_lien_he; END IF;
  IF p_hop_dong IS NOT NULL AND p_hop_dong !~* '\.(pdf|doc|docx)$' THEN
    RAISE EXCEPTION 'File hợp đồng phải là PDF/Word (BR_DN_05).'; END IF;
 
  v_hinh := COALESCE(p_hinh_thuc, d.hinh_thuc);
  IF v_hinh = 'CUNG_CAP_THI_SINH' THEN
    v_loai := 'KHONG_TAI_TRO'; v_cap := 'KHONG';
  ELSE
    v_loai := COALESCE(p_loai_tai_tro, d.loai_tai_tro);
    v_cap  := COALESCE(p_cap_do_tai_tro, d.cap_do_tai_tro);
    IF v_loai = 'KHONG_TAI_TRO' OR v_cap = 'KHONG' THEN
      RAISE EXCEPTION 'Doanh nghiệp tài trợ đồng hành phải có loại tài trợ (HIEN_KIM/HIEN_VAT) và cấp độ tài trợ.'; END IF;
  END IF;
 
  UPDATE doanhnghiep SET ten_doanh_nghiep = COALESCE(p_ten_doanh_nghiep, ten_doanh_nghiep), dia_chi = COALESCE(p_dia_chi, dia_chi),
    email_lien_he = COALESCE(p_email_lien_he, email_lien_he), sdt_lien_he = COALESCE(p_sdt_lien_he, sdt_lien_he),
    nganh_nghe = COALESCE(p_nganh_nghe, nganh_nghe), hinh_thuc = v_hinh, loai_tai_tro = v_loai, cap_do_tai_tro = v_cap,
    hop_dong = COALESCE(p_hop_dong, hop_dong)
  WHERE doanh_nghiep_id = p_doanh_nghiep_id;
END $$;

CREATE OR REPLACE FUNCTION sp_delete_doanhnghiep(p_doanh_nghiep_id varchar) RETURNS void LANGUAGE plpgsql AS $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM doanhnghiep WHERE doanh_nghiep_id = p_doanh_nghiep_id) THEN RAISE EXCEPTION 'Doanh nghiệp % không tồn tại.', p_doanh_nghiep_id; END IF;
  IF EXISTS (SELECT 1 FROM qna WHERE doanh_nghiep_id = p_doanh_nghiep_id) THEN RAISE EXCEPTION 'Không thể xóa: doanh nghiệp % đã có lịch sử tương tác (Q&A).', p_doanh_nghiep_id; END IF;
  IF EXISTS (SELECT 1 FROM qna_phanhoi WHERE doanh_nghiep_id = p_doanh_nghiep_id) THEN RAISE EXCEPTION 'Không thể xóa: doanh nghiệp % đã có phản hồi Q&A.', p_doanh_nghiep_id; END IF;
  IF EXISTS (SELECT 1 FROM dangkyweb WHERE doanh_nghiep_id = p_doanh_nghiep_id) THEN RAISE EXCEPTION 'Không thể xóa: doanh nghiệp % đã gắn với đăng ký web.', p_doanh_nghiep_id; END IF;
  IF EXISTS (SELECT 1 FROM doanhnghiep_pipeline WHERE doanh_nghiep_id = p_doanh_nghiep_id) THEN RAISE EXCEPTION 'Không thể xóa: doanh nghiệp % đã có dữ liệu pipeline.', p_doanh_nghiep_id; END IF;
  IF EXISTS (SELECT 1 FROM truyenthong_taitro WHERE doanh_nghiep_id = p_doanh_nghiep_id) THEN RAISE EXCEPTION 'Không thể xóa: doanh nghiệp % đã có dữ liệu truyền thông.', p_doanh_nghiep_id; END IF;
  DELETE FROM doanhnghiep WHERE doanh_nghiep_id = p_doanh_nghiep_id;
END $$;

/* ================= 3. THISINH ================= */
CREATE OR REPLACE FUNCTION fn_kiem_tra_tuoi_bang(p_ngay_sinh date, p_bang varchar) RETURNS void LANGUAGE plpgsql AS $$
DECLARE v_tuoi int := fn_tinh_tuoi_thi(p_ngay_sinh);
BEGIN
  IF v_tuoi NOT BETWEEN 12 AND 24 THEN RAISE EXCEPTION 'Thí sinh % tuổi, ngoài khoảng tuổi dự thi cho phép (12-24 tuổi).', v_tuoi; END IF;
  IF p_bang = 'BANG_A' AND v_tuoi NOT BETWEEN 12 AND 18 THEN RAISE EXCEPTION 'Thí sinh % tuổi không phù hợp Bảng A (yêu cầu 12-18 tuổi).', v_tuoi; END IF;
  IF p_bang = 'BANG_B' AND v_tuoi NOT BETWEEN 19 AND 24 THEN RAISE EXCEPTION 'Thí sinh % tuổi không phù hợp Bảng B (yêu cầu 19-24 tuổi).', v_tuoi; END IF;
END $$;

CREATE OR REPLACE FUNCTION sp_insert_thisinh(p_thi_sinh_id varchar, p_ho_ten varchar, p_email varchar, p_sdt varchar,
  p_ngay_sinh date, p_cccd varchar, p_dia_chi varchar, p_sale_phu_trach_id varchar DEFAULT NULL,
  p_tinh_thanh varchar DEFAULT NULL, p_truong_hoc varchar DEFAULT NULL, p_bang_dau varchar DEFAULT NULL,
  p_trang_thai_ho_so varchar DEFAULT 'MOI_TAO', p_xac_nhan_trung boolean DEFAULT false) RETURNS void LANGUAGE plpgsql AS $$
BEGIN
  IF EXISTS (SELECT 1 FROM thisinh WHERE thi_sinh_id = p_thi_sinh_id) THEN RAISE EXCEPTION 'Mã thí sinh % đã tồn tại.', p_thi_sinh_id; END IF;
  IF EXISTS (SELECT 1 FROM thisinh WHERE cccd = p_cccd) THEN RAISE EXCEPTION 'Số CCCD % đã được sử dụng.', p_cccd; END IF;
  IF EXISTS (SELECT 1 FROM thisinh WHERE email = p_email) THEN RAISE EXCEPTION 'Email % đã tồn tại (BR_TS_01: email duy nhất).', p_email; END IF;
  IF NOT p_xac_nhan_trung AND EXISTS (SELECT 1 FROM thisinh WHERE sdt = p_sdt) THEN RAISE EXCEPTION 'Cảnh báo: SĐT đã tồn tại. Truyền p_xac_nhan_trung => true nếu vẫn muốn tạo.'; END IF;
  IF p_sale_phu_trach_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM nhanvien WHERE nhan_vien_id = p_sale_phu_trach_id AND phong_ban = 'SALES' AND trang_thai = 'ACTIVE') THEN
    RAISE EXCEPTION 'Nhân viên sale % không tồn tại, sai phòng ban hoặc đã INACTIVE.', p_sale_phu_trach_id; END IF;
  PERFORM fn_kiem_tra_tuoi_bang(p_ngay_sinh, p_bang_dau);
  INSERT INTO thisinh (thi_sinh_id, sale_phu_trach_id, ho_ten, email, sdt, ngay_sinh, cccd, dia_chi, tinh_thanh, truong_hoc, bang_dau, trang_thai_ho_so)
  VALUES (p_thi_sinh_id, p_sale_phu_trach_id, p_ho_ten, p_email, p_sdt, p_ngay_sinh, p_cccd, p_dia_chi, p_tinh_thanh, p_truong_hoc, p_bang_dau, p_trang_thai_ho_so);
END $$;

CREATE OR REPLACE FUNCTION sp_update_thisinh(p_thi_sinh_id varchar, p_sale_phu_trach_id varchar DEFAULT NULL, p_ho_ten varchar DEFAULT NULL,
  p_ngay_sinh date DEFAULT NULL, p_email varchar DEFAULT NULL, p_sdt varchar DEFAULT NULL, p_cccd varchar DEFAULT NULL,
  p_dia_chi varchar DEFAULT NULL, p_tinh_thanh varchar DEFAULT NULL, p_truong_hoc varchar DEFAULT NULL, p_bang_dau varchar DEFAULT NULL,
  p_trang_thai_ho_so varchar DEFAULT NULL, p_xac_nhan_trung boolean DEFAULT false) RETURNS void LANGUAGE plpgsql AS $$
DECLARE v_ns date; v_bang varchar;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM thisinh WHERE thi_sinh_id = p_thi_sinh_id) THEN RAISE EXCEPTION 'Thí sinh % không tồn tại.', p_thi_sinh_id; END IF;
  IF p_cccd IS NOT NULL AND EXISTS (SELECT 1 FROM thisinh WHERE cccd = p_cccd AND thi_sinh_id <> p_thi_sinh_id) THEN RAISE EXCEPTION 'Số CCCD % đã thuộc về thí sinh khác.', p_cccd; END IF;
  IF p_email IS NOT NULL AND EXISTS (SELECT 1 FROM thisinh WHERE email = p_email AND thi_sinh_id <> p_thi_sinh_id) THEN RAISE EXCEPTION 'Email % đã thuộc về thí sinh khác.', p_email; END IF;
  IF NOT p_xac_nhan_trung AND p_sdt IS NOT NULL AND EXISTS (SELECT 1 FROM thisinh WHERE sdt = p_sdt AND thi_sinh_id <> p_thi_sinh_id) THEN
    RAISE EXCEPTION 'Cảnh báo: SĐT trùng với hồ sơ khác. Truyền p_xac_nhan_trung => true nếu muốn lưu.'; END IF;
  IF p_sale_phu_trach_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM nhanvien WHERE nhan_vien_id = p_sale_phu_trach_id AND phong_ban = 'SALES' AND trang_thai = 'ACTIVE') THEN
    RAISE EXCEPTION 'Nhân viên sale % không tồn tại, sai phòng ban hoặc đã INACTIVE.', p_sale_phu_trach_id; END IF;
  SELECT COALESCE(p_ngay_sinh, ngay_sinh), COALESCE(p_bang_dau, bang_dau) INTO v_ns, v_bang FROM thisinh WHERE thi_sinh_id = p_thi_sinh_id;
  IF p_ngay_sinh IS NOT NULL OR p_bang_dau IS NOT NULL THEN PERFORM fn_kiem_tra_tuoi_bang(v_ns, v_bang); END IF;
  UPDATE thisinh SET sale_phu_trach_id = COALESCE(p_sale_phu_trach_id, sale_phu_trach_id), ho_ten = COALESCE(p_ho_ten, ho_ten),
    ngay_sinh = COALESCE(p_ngay_sinh, ngay_sinh), email = COALESCE(p_email, email), sdt = COALESCE(p_sdt, sdt), cccd = COALESCE(p_cccd, cccd),
    dia_chi = COALESCE(p_dia_chi, dia_chi), tinh_thanh = COALESCE(p_tinh_thanh, tinh_thanh), truong_hoc = COALESCE(p_truong_hoc, truong_hoc),
    bang_dau = COALESCE(p_bang_dau, bang_dau), trang_thai_ho_so = COALESCE(p_trang_thai_ho_so, trang_thai_ho_so)
  WHERE thi_sinh_id = p_thi_sinh_id;
END $$;

CREATE OR REPLACE FUNCTION sp_delete_thisinh(p_thi_sinh_id varchar) RETURNS void LANGUAGE plpgsql AS $$
BEGIN  -- khóa hồ sơ, hủy đăng ký, thanh toán chờ => thất bại (cùng 1 transaction)
  IF NOT EXISTS (SELECT 1 FROM thisinh WHERE thi_sinh_id = p_thi_sinh_id) THEN RAISE EXCEPTION 'Thí sinh % không tồn tại.', p_thi_sinh_id; END IF;
  UPDATE thisinh SET trang_thai_ho_so = 'KHOA' WHERE thi_sinh_id = p_thi_sinh_id;
  UPDATE dangky SET trang_thai = 'HUY_DANG_KY' WHERE thi_sinh_id = p_thi_sinh_id;
  UPDATE thanhtoan SET trang_thai_thanh_toan = 'THAT_BAI' WHERE thi_sinh_id = p_thi_sinh_id AND trang_thai_thanh_toan = 'CHO_THANH_TOAN';
END $$;

/* ================= 4. CUOCTHI ================= */
CREATE OR REPLACE FUNCTION sp_insert_cuocthi(p_cuoc_thi_id varchar, p_ten_cuoc_thi varchar, p_han_dang_ky timestamp, p_ngay_bat_dau timestamp,
  p_ngay_ket_thuc timestamp, p_trang_thai varchar, p_bang_dau varchar DEFAULT NULL, p_mo_ta varchar DEFAULT NULL) RETURNS void LANGUAGE plpgsql AS $$
BEGIN
  IF EXISTS (SELECT 1 FROM cuocthi WHERE cuoc_thi_id = p_cuoc_thi_id) THEN RAISE EXCEPTION 'Mã cuộc thi % đã tồn tại.', p_cuoc_thi_id; END IF;
  IF p_han_dang_ky <= now() THEN RAISE EXCEPTION 'Hạn đăng ký phải lớn hơn thời điểm tạo (BR_CT_02).'; END IF;
  INSERT INTO cuocthi (cuoc_thi_id, ten_cuoc_thi, bang_dau, mo_ta, han_dang_ky, ngay_bat_dau, ngay_ket_thuc, trang_thai)
  VALUES (p_cuoc_thi_id, p_ten_cuoc_thi, p_bang_dau, p_mo_ta, p_han_dang_ky, p_ngay_bat_dau, p_ngay_ket_thuc, p_trang_thai);
END $$;

CREATE OR REPLACE FUNCTION sp_update_cuocthi(p_cuoc_thi_id varchar, p_ten_cuoc_thi varchar DEFAULT NULL, p_bang_dau varchar DEFAULT NULL,
  p_mo_ta varchar DEFAULT NULL, p_han_dang_ky timestamp DEFAULT NULL, p_ngay_bat_dau timestamp DEFAULT NULL,
  p_ngay_ket_thuc timestamp DEFAULT NULL, p_trang_thai varchar DEFAULT NULL) RETURNS void LANGUAGE plpgsql AS $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM cuocthi WHERE cuoc_thi_id = p_cuoc_thi_id) THEN RAISE EXCEPTION 'Cuộc thi % không tồn tại.', p_cuoc_thi_id; END IF;
  UPDATE cuocthi SET ten_cuoc_thi = COALESCE(p_ten_cuoc_thi, ten_cuoc_thi), bang_dau = COALESCE(p_bang_dau, bang_dau), mo_ta = COALESCE(p_mo_ta, mo_ta),
    han_dang_ky = COALESCE(p_han_dang_ky, han_dang_ky), ngay_bat_dau = COALESCE(p_ngay_bat_dau, ngay_bat_dau),
    ngay_ket_thuc = COALESCE(p_ngay_ket_thuc, ngay_ket_thuc), trang_thai = COALESCE(p_trang_thai, trang_thai) WHERE cuoc_thi_id = p_cuoc_thi_id;
END $$;

CREATE OR REPLACE FUNCTION sp_delete_cuocthi(p_cuoc_thi_id varchar) RETURNS void LANGUAGE plpgsql AS $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM cuocthi WHERE cuoc_thi_id = p_cuoc_thi_id) THEN RAISE EXCEPTION 'Cuộc thi % không tồn tại.', p_cuoc_thi_id; END IF;
  IF EXISTS (SELECT 1 FROM dangky WHERE cuoc_thi_id = p_cuoc_thi_id) THEN RAISE EXCEPTION 'Không thể xóa: Cuộc thi % đã có thí sinh đăng ký.', p_cuoc_thi_id; END IF;
  DELETE FROM cuocthi WHERE cuoc_thi_id = p_cuoc_thi_id;
END $$;

/* ================= 5. DANGKY ================= */
CREATE OR REPLACE FUNCTION sp_insert_dangky(p_dang_ky_id varchar, p_thi_sinh_id varchar, p_cuoc_thi_id varchar,
  p_trang_thai varchar DEFAULT 'CHO_THANH_TOAN', p_ngay_dang_ky timestamp DEFAULT NULL) RETURNS void LANGUAGE plpgsql AS $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM thisinh WHERE thi_sinh_id = p_thi_sinh_id) THEN RAISE EXCEPTION 'Thí sinh % không tồn tại.', p_thi_sinh_id; END IF;
  IF NOT EXISTS (SELECT 1 FROM cuocthi WHERE cuoc_thi_id = p_cuoc_thi_id) THEN RAISE EXCEPTION 'Cuộc thi % không tồn tại.', p_cuoc_thi_id; END IF;
  IF (SELECT han_dang_ky FROM cuocthi WHERE cuoc_thi_id = p_cuoc_thi_id) < now() THEN RAISE EXCEPTION 'Cuộc thi % đã quá hạn đăng ký.', p_cuoc_thi_id; END IF;
  IF EXISTS (SELECT 1 FROM dangky WHERE thi_sinh_id = p_thi_sinh_id AND cuoc_thi_id = p_cuoc_thi_id) THEN RAISE EXCEPTION 'Thí sinh đã đăng ký cuộc thi này rồi.'; END IF;
  INSERT INTO dangky (dang_ky_id, thi_sinh_id, cuoc_thi_id, ngay_dang_ky, trang_thai)
  VALUES (p_dang_ky_id, p_thi_sinh_id, p_cuoc_thi_id, COALESCE(p_ngay_dang_ky, now()), p_trang_thai);
END $$;

CREATE OR REPLACE FUNCTION sp_update_dangky(p_dang_ky_id varchar, p_trang_thai varchar) RETURNS void LANGUAGE plpgsql AS $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM dangky WHERE dang_ky_id = p_dang_ky_id) THEN RAISE EXCEPTION 'Đăng ký % không tồn tại.', p_dang_ky_id; END IF;
  UPDATE dangky SET trang_thai = p_trang_thai WHERE dang_ky_id = p_dang_ky_id;
END $$;

CREATE OR REPLACE FUNCTION sp_delete_dangky(p_dang_ky_id varchar) RETURNS void LANGUAGE plpgsql AS $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM dangky WHERE dang_ky_id = p_dang_ky_id) THEN RAISE EXCEPTION 'Đăng ký % không tồn tại.', p_dang_ky_id; END IF;
  IF EXISTS (SELECT 1 FROM thanhtoan tt JOIN dangky dk ON dk.thi_sinh_id = tt.thi_sinh_id AND dk.cuoc_thi_id = tt.cuoc_thi_id
             WHERE dk.dang_ky_id = p_dang_ky_id AND tt.trang_thai_thanh_toan = 'THANH_TOAN_THANH_CONG') THEN
    RAISE EXCEPTION 'Không thể xóa: đăng ký % đã thanh toán thành công.', p_dang_ky_id; END IF;
  DELETE FROM dangky WHERE dang_ky_id = p_dang_ky_id;
END $$;

/* ================= 6. THANHTOAN ================= */
CREATE OR REPLACE FUNCTION sp_insert_thanhtoan(p_thanh_toan_id varchar, p_thi_sinh_id varchar, p_cuoc_thi_id varchar, p_giao_dich_id varchar,
  p_bang_dau varchar DEFAULT NULL, p_trang_thai_thanh_toan varchar DEFAULT 'CHO_THANH_TOAN', p_ghi_chu varchar DEFAULT NULL)
RETURNS void LANGUAGE plpgsql AS $$
DECLARE v_bang varchar; v_hs varchar; v_now timestamp := now()::timestamp; v_phi numeric;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM thisinh WHERE thi_sinh_id = p_thi_sinh_id) THEN RAISE EXCEPTION 'Thí sinh % không tồn tại.', p_thi_sinh_id; END IF;
  IF NOT EXISTS (SELECT 1 FROM cuocthi WHERE cuoc_thi_id = p_cuoc_thi_id) THEN RAISE EXCEPTION 'Cuộc thi % không tồn tại.', p_cuoc_thi_id; END IF;
  IF NOT EXISTS (SELECT 1 FROM dangky WHERE thi_sinh_id = p_thi_sinh_id AND cuoc_thi_id = p_cuoc_thi_id AND trang_thai <> 'HUY_DANG_KY') THEN
    RAISE EXCEPTION 'Thí sinh % chưa có đăng ký hợp lệ (còn hiệu lực) cho cuộc thi %.', p_thi_sinh_id, p_cuoc_thi_id; END IF;
  IF EXISTS (SELECT 1 FROM thanhtoan WHERE giao_dich_id = p_giao_dich_id) THEN RAISE EXCEPTION 'Mã giao dịch % đã tồn tại.', p_giao_dich_id; END IF;
  IF p_trang_thai_thanh_toan NOT IN ('CHO_THANH_TOAN','THANH_TOAN_THANH_CONG','THAT_BAI','HOAN_TIEN') THEN RAISE EXCEPTION 'Trạng thái thanh toán không hợp lệ.'; END IF;
  SELECT bang_dau, trang_thai_ho_so INTO v_bang, v_hs FROM thisinh WHERE thi_sinh_id = p_thi_sinh_id;
  IF v_hs <> 'DA_DUYET' OR v_bang IS NULL THEN
    RAISE EXCEPTION 'Không thể tạo thanh toán: Hồ sơ thí sinh % chưa hoàn tất/chưa được phân loại Bảng đấu.', p_thi_sinh_id; END IF;
  IF p_bang_dau IS NOT NULL AND p_bang_dau <> v_bang THEN
    RAISE EXCEPTION 'Bảng đấu thanh toán (%) không khớp với bảng đấu đã duyệt trong hồ sơ (%).', p_bang_dau, v_bang; END IF;
  v_phi := fn_le_phi_tai(v_now);
  INSERT INTO thanhtoan (thanh_toan_id, thi_sinh_id, cuoc_thi_id, thoi_gian_thanh_toan, bang_dau, so_tien, trang_thai_thanh_toan, giao_dich_id, ghi_chu)
  VALUES (p_thanh_toan_id, p_thi_sinh_id, p_cuoc_thi_id, v_now, v_bang, v_phi, p_trang_thai_thanh_toan, p_giao_dich_id, p_ghi_chu);
END $$;

CREATE OR REPLACE FUNCTION sp_update_thanhtoan(p_thanh_toan_id varchar, p_trang_thai_thanh_toan varchar,
  p_giao_dich_id varchar DEFAULT NULL, p_ghi_chu varchar DEFAULT NULL) RETURNS void LANGUAGE plpgsql AS $$
DECLARE v_cur varchar;
BEGIN
  SELECT trang_thai_thanh_toan INTO v_cur FROM thanhtoan WHERE thanh_toan_id = p_thanh_toan_id;
  IF v_cur IS NULL THEN RAISE EXCEPTION 'Giao dịch % không tồn tại.', p_thanh_toan_id; END IF;
  IF p_trang_thai_thanh_toan NOT IN ('CHO_THANH_TOAN','THANH_TOAN_THANH_CONG','THAT_BAI','HOAN_TIEN') THEN RAISE EXCEPTION 'Trạng thái thanh toán không hợp lệ.'; END IF;
  IF v_cur = 'HOAN_TIEN' THEN RAISE EXCEPTION 'Giao dịch % đã hoàn tiền, không thể thay đổi.', p_thanh_toan_id; END IF;
  IF v_cur = 'THANH_TOAN_THANH_CONG' AND p_trang_thai_thanh_toan NOT IN ('THANH_TOAN_THANH_CONG','HOAN_TIEN') THEN
    RAISE EXCEPTION 'Giao dịch % đã thanh toán thành công, chỉ được chuyển sang HOAN_TIEN.', p_thanh_toan_id; END IF;
  IF p_giao_dich_id IS NOT NULL AND EXISTS (SELECT 1 FROM thanhtoan WHERE giao_dich_id = p_giao_dich_id AND thanh_toan_id <> p_thanh_toan_id) THEN
    RAISE EXCEPTION 'Mã giao dịch % đã tồn tại ở giao dịch khác.', p_giao_dich_id; END IF;
  UPDATE thanhtoan SET trang_thai_thanh_toan = p_trang_thai_thanh_toan, giao_dich_id = COALESCE(p_giao_dich_id, giao_dich_id),
    ghi_chu = COALESCE(p_ghi_chu, ghi_chu),
    thoi_gian_thanh_toan = CASE WHEN p_trang_thai_thanh_toan = 'THANH_TOAN_THANH_CONG' AND v_cur <> 'THANH_TOAN_THANH_CONG' THEN now() ELSE thoi_gian_thanh_toan END
  WHERE thanh_toan_id = p_thanh_toan_id;
  IF p_trang_thai_thanh_toan = 'HOAN_TIEN' THEN
    UPDATE dangky dk SET trang_thai = 'HUY_DANG_KY' FROM thanhtoan tt
    WHERE tt.thanh_toan_id = p_thanh_toan_id AND dk.thi_sinh_id = tt.thi_sinh_id AND dk.cuoc_thi_id = tt.cuoc_thi_id;
  END IF;
END $$;

/* ================= 7. BÀI TẬP ================= */
CREATE OR REPLACE FUNCTION sp_insert_baitap(p_bai_tap_id varchar, p_cuoc_thi_id varchar, p_bang_dau varchar, p_ten_bai_tap varchar,
  p_ngay_het_han timestamp, p_mo_ta text DEFAULT NULL, p_thoi_gian_lam_bai int DEFAULT 60, p_so_lan_nop_bai_toi_da int DEFAULT 1,
  p_diem_dat numeric DEFAULT NULL, p_ngay_bat_dau timestamp DEFAULT NULL, p_trang_thai varchar DEFAULT 'MO') RETURNS void LANGUAGE plpgsql AS $$
BEGIN
  IF EXISTS (SELECT 1 FROM baitap WHERE bai_tap_id = p_bai_tap_id) THEN RAISE EXCEPTION 'Mã bài tập % đã tồn tại.', p_bai_tap_id; END IF;
  IF NOT EXISTS (SELECT 1 FROM cuocthi WHERE cuoc_thi_id = p_cuoc_thi_id) THEN RAISE EXCEPTION 'Cuộc thi % không tồn tại.', p_cuoc_thi_id; END IF;
  INSERT INTO baitap (bai_tap_id, cuoc_thi_id, bang_dau, ten_bai_tap, mo_ta, thoi_gian_lam_bai, so_lan_nop_bai_toi_da, diem_dat, ngay_bat_dau, ngay_het_han, trang_thai)
  VALUES (p_bai_tap_id, p_cuoc_thi_id, p_bang_dau, p_ten_bai_tap, p_mo_ta, p_thoi_gian_lam_bai, p_so_lan_nop_bai_toi_da, p_diem_dat, p_ngay_bat_dau, p_ngay_het_han, p_trang_thai);
END $$;

CREATE OR REPLACE FUNCTION sp_update_baitap(p_bai_tap_id varchar, p_ten_bai_tap varchar DEFAULT NULL, p_mo_ta text DEFAULT NULL,
  p_thoi_gian_lam_bai int DEFAULT NULL, p_so_lan_nop_bai_toi_da int DEFAULT NULL, p_diem_dat numeric DEFAULT NULL,
  p_ngay_bat_dau timestamp DEFAULT NULL, p_ngay_het_han timestamp DEFAULT NULL, p_trang_thai varchar DEFAULT NULL) RETURNS void LANGUAGE plpgsql AS $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM baitap WHERE bai_tap_id = p_bai_tap_id) THEN RAISE EXCEPTION 'Bài tập % không tồn tại.', p_bai_tap_id; END IF;
  UPDATE baitap SET ten_bai_tap = COALESCE(p_ten_bai_tap, ten_bai_tap), mo_ta = COALESCE(p_mo_ta, mo_ta),
    thoi_gian_lam_bai = COALESCE(p_thoi_gian_lam_bai, thoi_gian_lam_bai), so_lan_nop_bai_toi_da = COALESCE(p_so_lan_nop_bai_toi_da, so_lan_nop_bai_toi_da),
    diem_dat = COALESCE(p_diem_dat, diem_dat), ngay_bat_dau = COALESCE(p_ngay_bat_dau, ngay_bat_dau),
    ngay_het_han = COALESCE(p_ngay_het_han, ngay_het_han), trang_thai = COALESCE(p_trang_thai, trang_thai) WHERE bai_tap_id = p_bai_tap_id;
END $$;

CREATE OR REPLACE FUNCTION sp_delete_baitap(p_bai_tap_id varchar) RETURNS void LANGUAGE plpgsql AS $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM baitap WHERE bai_tap_id = p_bai_tap_id) THEN RAISE EXCEPTION 'Bài tập % không tồn tại.', p_bai_tap_id; END IF;
  IF EXISTS (SELECT 1 FROM bainop WHERE bai_tap_id = p_bai_tap_id) THEN RAISE EXCEPTION 'Bài tập đã có bài nộp, không thể xóa.'; END IF;
  DELETE FROM baitap WHERE bai_tap_id = p_bai_tap_id;
END $$;

CREATE OR REPLACE FUNCTION sp_insert_cauhoi(p_cau_hoi_id varchar, p_bai_tap_id varchar, p_noi_dung_cau_hoi text, p_loai_cau_hoi varchar, p_thu_tu int,
  p_hinh_anh_url varchar DEFAULT NULL, p_diem_toi_da numeric DEFAULT 1.00, p_dap_an_mau_dien_tu text DEFAULT NULL, p_giai_thich_dap_an text DEFAULT NULL)
RETURNS void LANGUAGE plpgsql AS $$
BEGIN
  IF EXISTS (SELECT 1 FROM cauhoi WHERE cau_hoi_id = p_cau_hoi_id) THEN RAISE EXCEPTION 'Mã câu hỏi % đã tồn tại.', p_cau_hoi_id; END IF;
  IF NOT EXISTS (SELECT 1 FROM baitap WHERE bai_tap_id = p_bai_tap_id) THEN RAISE EXCEPTION 'Bài tập % không tồn tại.', p_bai_tap_id; END IF;
  INSERT INTO cauhoi (cau_hoi_id, bai_tap_id, noi_dung_cau_hoi, hinh_anh_url, loai_cau_hoi, thu_tu, diem_toi_da, dap_an_mau_dien_tu, giai_thich_dap_an)
  VALUES (p_cau_hoi_id, p_bai_tap_id, p_noi_dung_cau_hoi, p_hinh_anh_url, p_loai_cau_hoi, p_thu_tu, p_diem_toi_da, p_dap_an_mau_dien_tu, p_giai_thich_dap_an);
END $$;

CREATE OR REPLACE FUNCTION sp_update_cauhoi(p_cau_hoi_id varchar, p_noi_dung_cau_hoi text DEFAULT NULL, p_hinh_anh_url varchar DEFAULT NULL,
  p_loai_cau_hoi varchar DEFAULT NULL, p_thu_tu int DEFAULT NULL, p_diem_toi_da numeric DEFAULT NULL,
  p_dap_an_mau_dien_tu text DEFAULT NULL, p_giai_thich_dap_an text DEFAULT NULL) RETURNS void LANGUAGE plpgsql AS $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM cauhoi WHERE cau_hoi_id = p_cau_hoi_id) THEN RAISE EXCEPTION 'Câu hỏi % không tồn tại.', p_cau_hoi_id; END IF;
  UPDATE cauhoi SET noi_dung_cau_hoi = COALESCE(p_noi_dung_cau_hoi, noi_dung_cau_hoi), hinh_anh_url = COALESCE(p_hinh_anh_url, hinh_anh_url),
    loai_cau_hoi = COALESCE(p_loai_cau_hoi, loai_cau_hoi), thu_tu = COALESCE(p_thu_tu, thu_tu), diem_toi_da = COALESCE(p_diem_toi_da, diem_toi_da),
    dap_an_mau_dien_tu = COALESCE(p_dap_an_mau_dien_tu, dap_an_mau_dien_tu), giai_thich_dap_an = COALESCE(p_giai_thich_dap_an, giai_thich_dap_an)
  WHERE cau_hoi_id = p_cau_hoi_id;
END $$;

CREATE OR REPLACE FUNCTION sp_delete_cauhoi(p_cau_hoi_id varchar) RETURNS void LANGUAGE plpgsql AS $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM cauhoi WHERE cau_hoi_id = p_cau_hoi_id) THEN RAISE EXCEPTION 'Câu hỏi % không tồn tại.', p_cau_hoi_id; END IF;
  DELETE FROM cauhoi WHERE cau_hoi_id = p_cau_hoi_id;
END $$;

CREATE OR REPLACE FUNCTION sp_insert_luachondapan(p_dap_an_id varchar, p_cau_hoi_id varchar, p_noi_dung_dap_an text, p_thu_tu int,
  p_la_dap_an_dung boolean DEFAULT false) RETURNS void LANGUAGE plpgsql AS $$
BEGIN
  IF EXISTS (SELECT 1 FROM lua_chon_dap_an WHERE dap_an_id = p_dap_an_id) THEN RAISE EXCEPTION 'Mã đáp án % đã tồn tại.', p_dap_an_id; END IF;
  IF NOT EXISTS (SELECT 1 FROM cauhoi WHERE cau_hoi_id = p_cau_hoi_id) THEN RAISE EXCEPTION 'Câu hỏi % không tồn tại.', p_cau_hoi_id; END IF;
  INSERT INTO lua_chon_dap_an (dap_an_id, cau_hoi_id, noi_dung_dap_an, la_dap_an_dung, thu_tu)
  VALUES (p_dap_an_id, p_cau_hoi_id, p_noi_dung_dap_an, p_la_dap_an_dung, p_thu_tu);
END $$;

CREATE OR REPLACE FUNCTION sp_update_luachondapan(p_dap_an_id varchar, p_noi_dung_dap_an text DEFAULT NULL,
  p_la_dap_an_dung boolean DEFAULT NULL, p_thu_tu int DEFAULT NULL) RETURNS void LANGUAGE plpgsql AS $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM lua_chon_dap_an WHERE dap_an_id = p_dap_an_id) THEN RAISE EXCEPTION 'Đáp án % không tồn tại.', p_dap_an_id; END IF;
  UPDATE lua_chon_dap_an SET noi_dung_dap_an = COALESCE(p_noi_dung_dap_an, noi_dung_dap_an),
    la_dap_an_dung = COALESCE(p_la_dap_an_dung, la_dap_an_dung), thu_tu = COALESCE(p_thu_tu, thu_tu) WHERE dap_an_id = p_dap_an_id;
END $$;

CREATE OR REPLACE FUNCTION sp_delete_luachondapan(p_dap_an_id varchar) RETURNS void LANGUAGE plpgsql AS $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM lua_chon_dap_an WHERE dap_an_id = p_dap_an_id) THEN RAISE EXCEPTION 'Đáp án % không tồn tại.', p_dap_an_id; END IF;
  DELETE FROM lua_chon_dap_an WHERE dap_an_id = p_dap_an_id;
END $$;

CREATE OR REPLACE FUNCTION sp_insert_bainop(p_bai_nop_id varchar, p_bai_tap_id varchar, p_thi_sinh_id varchar, p_thoi_gian_bat_dau timestamp,
  p_thoi_gian_nop timestamp DEFAULT NULL, p_thoi_gian_lam_bai_giay int DEFAULT NULL, p_trang_thai varchar DEFAULT 'DANG_LAM')
RETURNS void LANGUAGE plpgsql AS $$
DECLARE b baitap%ROWTYPE; v_bang varchar; v_da int;
BEGIN
  IF EXISTS (SELECT 1 FROM bainop WHERE bai_nop_id = p_bai_nop_id) THEN RAISE EXCEPTION 'Mã bài nộp % đã tồn tại.', p_bai_nop_id; END IF;
  SELECT * INTO b FROM baitap WHERE bai_tap_id = p_bai_tap_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Bài tập % không tồn tại.', p_bai_tap_id; END IF;
  IF NOT EXISTS (SELECT 1 FROM thisinh WHERE thi_sinh_id = p_thi_sinh_id) THEN RAISE EXCEPTION 'Thí sinh % không tồn tại.', p_thi_sinh_id; END IF;
  SELECT bang_dau INTO v_bang FROM thisinh WHERE thi_sinh_id = p_thi_sinh_id;
  IF b.trang_thai <> 'MO' THEN RAISE EXCEPTION 'Bài tập % hiện không ở trạng thái mở (MO), không thể bắt đầu làm bài.', p_bai_tap_id; END IF;
  IF v_bang IS NOT NULL AND v_bang <> b.bang_dau THEN RAISE EXCEPTION 'Bài tập % thuộc %, không khớp bảng đấu của thí sinh (BR_BT_01).', p_bai_tap_id, b.bang_dau; END IF;
  IF b.ngay_bat_dau IS NOT NULL AND now() < b.ngay_bat_dau THEN RAISE EXCEPTION 'Bài tập % chưa đến thời gian mở bài.', p_bai_tap_id; END IF;
  IF now() > b.ngay_het_han THEN RAISE EXCEPTION 'Bài tập % đã hết hạn nộp (hạn: %), không thể bắt đầu làm bài mới.', p_bai_tap_id, to_char(b.ngay_het_han, 'YYYY-MM-DD HH24:MI:SS'); END IF;
  IF NOT EXISTS (SELECT 1 FROM dangky WHERE thi_sinh_id = p_thi_sinh_id AND cuoc_thi_id = b.cuoc_thi_id AND trang_thai = 'THANH_CONG') THEN
    RAISE EXCEPTION 'Thí sinh % chưa đăng ký/thanh toán thành công cuộc thi % nên không thể làm bài tập %.', p_thi_sinh_id, b.cuoc_thi_id, p_bai_tap_id; END IF;
  SELECT count(*) INTO v_da FROM bainop WHERE bai_tap_id = p_bai_tap_id AND thi_sinh_id = p_thi_sinh_id;
  IF v_da >= b.so_lan_nop_bai_toi_da THEN RAISE EXCEPTION 'Thí sinh % đã dùng hết % lần nộp của bài tập %.', p_thi_sinh_id, b.so_lan_nop_bai_toi_da, p_bai_tap_id; END IF;
  INSERT INTO bainop (bai_nop_id, bai_tap_id, thi_sinh_id, lan_nop, thoi_gian_bat_dau, thoi_gian_nop, thoi_gian_lam_bai_giay, trang_thai)
  VALUES (p_bai_nop_id, p_bai_tap_id, p_thi_sinh_id, v_da + 1, p_thoi_gian_bat_dau, p_thoi_gian_nop, p_thoi_gian_lam_bai_giay, p_trang_thai);
END $$;

CREATE OR REPLACE FUNCTION sp_update_bainop(p_bai_nop_id varchar, p_tong_diem numeric DEFAULT NULL, p_nhan_xet_chung text DEFAULT NULL,
  p_thoi_gian_nop timestamp DEFAULT NULL, p_thoi_gian_lam_bai_giay int DEFAULT NULL, p_trang_thai varchar DEFAULT NULL)
RETURNS void LANGUAGE plpgsql AS $$
DECLARE v_het_han timestamp; v_final varchar := p_trang_thai;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM bainop WHERE bai_nop_id = p_bai_nop_id) THEN RAISE EXCEPTION 'Bài nộp % không tồn tại.', p_bai_nop_id; END IF;
  IF EXISTS (SELECT 1 FROM bainop WHERE bai_nop_id = p_bai_nop_id AND trang_thai = 'DA_CHAM_DIEM') AND p_tong_diem IS NULL
     AND (p_thoi_gian_nop IS NOT NULL OR p_trang_thai IN ('DANG_LAM','DA_NOP')) THEN
    RAISE EXCEPTION 'Bài nộp % đã được chấm điểm, không thể nộp lại hoặc thay đổi trạng thái làm bài.', p_bai_nop_id; END IF;
  IF p_thoi_gian_nop IS NOT NULL THEN
    SELECT bt.ngay_het_han INTO v_het_han FROM bainop bn JOIN baitap bt ON bt.bai_tap_id = bn.bai_tap_id WHERE bn.bai_nop_id = p_bai_nop_id;
    IF p_thoi_gian_nop > v_het_han AND (p_trang_thai IS NULL OR p_trang_thai = 'DA_NOP') THEN v_final := 'QUA_HAN_NOP';
    ELSIF v_final IS NULL THEN v_final := 'DA_NOP'; END IF;
  END IF;
  UPDATE bainop SET tong_diem = COALESCE(p_tong_diem, tong_diem), nhan_xet_chung = COALESCE(p_nhan_xet_chung, nhan_xet_chung),
    thoi_gian_nop = COALESCE(p_thoi_gian_nop, thoi_gian_nop), thoi_gian_lam_bai_giay = COALESCE(p_thoi_gian_lam_bai_giay, thoi_gian_lam_bai_giay),
    trang_thai = COALESCE(v_final, trang_thai) WHERE bai_nop_id = p_bai_nop_id;
END $$;

CREATE OR REPLACE FUNCTION sp_delete_bainop(p_bai_nop_id varchar) RETURNS void LANGUAGE plpgsql AS $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM bainop WHERE bai_nop_id = p_bai_nop_id) THEN RAISE EXCEPTION 'Bài nộp % không tồn tại.', p_bai_nop_id; END IF;
  DELETE FROM bainop WHERE bai_nop_id = p_bai_nop_id;
END $$;

CREATE OR REPLACE FUNCTION sp_insert_chitietdapannop(p_bai_nop_id varchar, p_cau_hoi_id varchar, p_dap_an_chon_id varchar DEFAULT NULL,
  p_noi_dung_tra_loi text DEFAULT NULL, p_diem_dat_duoc numeric DEFAULT NULL, p_la_dap_an_dung boolean DEFAULT NULL,
  p_nhan_xet_cau_hoi text DEFAULT NULL) RETURNS void LANGUAGE plpgsql AS $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM bainop WHERE bai_nop_id = p_bai_nop_id) THEN RAISE EXCEPTION 'Bài nộp % không tồn tại.', p_bai_nop_id; END IF;
  IF NOT EXISTS (SELECT 1 FROM cauhoi WHERE cau_hoi_id = p_cau_hoi_id) THEN RAISE EXCEPTION 'Câu hỏi % không tồn tại.', p_cau_hoi_id; END IF;
  IF p_dap_an_chon_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM lua_chon_dap_an WHERE dap_an_id = p_dap_an_chon_id AND cau_hoi_id = p_cau_hoi_id) THEN
    RAISE EXCEPTION 'Đáp án % không thuộc câu hỏi % (BR_BT_05).', p_dap_an_chon_id, p_cau_hoi_id; END IF;
  INSERT INTO chi_tiet_dap_an_nop (bai_nop_id, cau_hoi_id, dap_an_chon_id, noi_dung_tra_loi, diem_dat_duoc, la_dap_an_dung, nhan_xet_cau_hoi)
  VALUES (p_bai_nop_id, p_cau_hoi_id, p_dap_an_chon_id, p_noi_dung_tra_loi, p_diem_dat_duoc, p_la_dap_an_dung, p_nhan_xet_cau_hoi);
END $$;

CREATE OR REPLACE FUNCTION sp_update_chitietdapannop(p_chi_tiet_id bigint, p_dap_an_chon_id varchar DEFAULT NULL, p_noi_dung_tra_loi text DEFAULT NULL,
  p_diem_dat_duoc numeric DEFAULT NULL, p_la_dap_an_dung boolean DEFAULT NULL, p_nhan_xet_cau_hoi text DEFAULT NULL) RETURNS void LANGUAGE plpgsql AS $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM chi_tiet_dap_an_nop WHERE chi_tiet_id = p_chi_tiet_id) THEN RAISE EXCEPTION 'Chi tiết bài nộp % không tồn tại.', p_chi_tiet_id; END IF;
  UPDATE chi_tiet_dap_an_nop SET dap_an_chon_id = COALESCE(p_dap_an_chon_id, dap_an_chon_id), noi_dung_tra_loi = COALESCE(p_noi_dung_tra_loi, noi_dung_tra_loi),
    diem_dat_duoc = COALESCE(p_diem_dat_duoc, diem_dat_duoc), la_dap_an_dung = COALESCE(p_la_dap_an_dung, la_dap_an_dung),
    nhan_xet_cau_hoi = COALESCE(p_nhan_xet_cau_hoi, nhan_xet_cau_hoi) WHERE chi_tiet_id = p_chi_tiet_id;
END $$;

CREATE OR REPLACE FUNCTION sp_delete_chitietdapannop(p_chi_tiet_id bigint) RETURNS void LANGUAGE plpgsql AS $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM chi_tiet_dap_an_nop WHERE chi_tiet_id = p_chi_tiet_id) THEN RAISE EXCEPTION 'Chi tiết bài nộp % không tồn tại.', p_chi_tiet_id; END IF;
  DELETE FROM chi_tiet_dap_an_nop WHERE chi_tiet_id = p_chi_tiet_id;
END $$;

/* ---------- Chấm điểm tự động ---------- */
CREATE OR REPLACE FUNCTION sp_chamdiem_bainop(p_bai_nop_id varchar) RETURNS void LANGUAGE plpgsql AS $$
DECLARE v_co_tu_luan boolean;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM bainop WHERE bai_nop_id = p_bai_nop_id) THEN RAISE EXCEPTION 'Bài nộp % không tồn tại.', p_bai_nop_id; END IF;

  -- Trắc nghiệm 1 đáp án & điền từ
  UPDATE chi_tiet_dap_an_nop ct SET la_dap_an_dung = x.dung,
    diem_dat_duoc = CASE WHEN x.dung THEN x.diem_toi_da ELSE 0 END,
    nhan_xet_cau_hoi = CASE WHEN x.dung THEN 'Chấm tự động: Đúng' ELSE 'Chấm tự động: Sai' END
  FROM (
    SELECT c2.chi_tiet_id, ch.diem_toi_da,
           CASE WHEN ch.loai_cau_hoi = 'TRAC_NGHIEM_1' THEN COALESCE(da.la_dap_an_dung, false)
                ELSE COALESCE(da.la_dap_an_dung, false)
                     OR COALESCE(lower(btrim(c2.noi_dung_tra_loi)) = lower(btrim(ch.dap_an_mau_dien_tu)), false) END AS dung
    FROM chi_tiet_dap_an_nop c2
    JOIN cauhoi ch ON ch.cau_hoi_id = c2.cau_hoi_id
    LEFT JOIN lua_chon_dap_an da ON da.dap_an_id = c2.dap_an_chon_id
    WHERE c2.bai_nop_id = p_bai_nop_id AND ch.loai_cau_hoi IN ('TRAC_NGHIEM_1','DIEN_TU')
  ) x WHERE ct.chi_tiet_id = x.chi_tiet_id;

  -- Trắc nghiệm nhiều đáp án: đúng khi chọn đủ và chỉ chọn đáp án đúng
  UPDATE chi_tiet_dap_an_nop ct SET la_dap_an_dung = c.ok,
    diem_dat_duoc = CASE WHEN c.ok AND ct.chi_tiet_id = c.dai_dien THEN c.diem_toi_da ELSE 0 END,
    nhan_xet_cau_hoi = CASE WHEN c.ok THEN 'Chấm tự động: Đúng hoàn toàn' ELSE 'Chấm tự động: Chưa chính xác' END
  FROM (
    SELECT g.*, (g.tong > 0 AND g.so_chon = g.tong AND g.so_dung = g.tong) AS ok FROM (
      SELECT c2.cau_hoi_id, ch.diem_toi_da,
             count(DISTINCT c2.dap_an_chon_id) AS so_chon,
             count(DISTINCT CASE WHEN da.la_dap_an_dung THEN da.dap_an_id END) AS so_dung,
             (SELECT count(*) FROM lua_chon_dap_an z WHERE z.cau_hoi_id = c2.cau_hoi_id AND z.la_dap_an_dung) AS tong,
             min(c2.chi_tiet_id) AS dai_dien
      FROM chi_tiet_dap_an_nop c2
      JOIN cauhoi ch ON ch.cau_hoi_id = c2.cau_hoi_id
      LEFT JOIN lua_chon_dap_an da ON da.dap_an_id = c2.dap_an_chon_id
      WHERE c2.bai_nop_id = p_bai_nop_id AND ch.loai_cau_hoi = 'TRAC_NGHIEM_NHIEU'
      GROUP BY c2.cau_hoi_id, ch.diem_toi_da
    ) g
  ) c WHERE ct.bai_nop_id = p_bai_nop_id AND ct.cau_hoi_id = c.cau_hoi_id;

  SELECT EXISTS (SELECT 1 FROM chi_tiet_dap_an_nop ct JOIN cauhoi ch ON ch.cau_hoi_id = ct.cau_hoi_id
                 WHERE ct.bai_nop_id = p_bai_nop_id AND ch.loai_cau_hoi = 'TU_LUAN' AND ct.diem_dat_duoc IS NULL) INTO v_co_tu_luan;

  UPDATE bainop SET
    tong_diem = COALESCE((SELECT sum(diem_dat_duoc) FROM chi_tiet_dap_an_nop WHERE bai_nop_id = p_bai_nop_id), 0),
    trang_thai = CASE WHEN trang_thai = 'QUA_HAN_NOP' THEN trang_thai WHEN v_co_tu_luan THEN 'DA_NOP' ELSE 'DA_CHAM_DIEM' END,
    nhan_xet_chung = CASE WHEN v_co_tu_luan THEN 'Đã chấm phần trắc nghiệm. Đang chờ chấm tự luận.' ELSE 'Đã hoàn tất chấm điểm tự động.' END
  WHERE bai_nop_id = p_bai_nop_id;
END $$;

/* ================= 8. TAILIEU ================= */
CREATE OR REPLACE FUNCTION sp_insert_tailieu(p_tai_lieu_id varchar, p_ten_tai_lieu varchar, p_loai_tai_lieu varchar, p_url_luu_tru varchar, p_tao_boi varchar,
  p_ten_file_goc varchar DEFAULT NULL, p_duoi_file varchar DEFAULT NULL, p_loai_luu_tru varchar DEFAULT 'OBJECT_STORAGE',
  p_bucket_container varchar DEFAULT NULL, p_duong_dan_tuong_doi varchar DEFAULT NULL, p_trang_thai varchar DEFAULT 'CONG_KHAI',
  p_mo_ta varchar DEFAULT NULL, p_tu_khoa_ai varchar DEFAULT NULL, p_danh_muc_id varchar DEFAULT NULL, p_mime_type varchar DEFAULT NULL,
  p_dung_luong_byte bigint DEFAULT NULL, p_checksum_sha256 char DEFAULT NULL, p_quyen_truy_cap varchar DEFAULT 'NOI_BO')
RETURNS void LANGUAGE plpgsql AS $$
BEGIN
  IF EXISTS (SELECT 1 FROM tailieu WHERE tai_lieu_id = p_tai_lieu_id) THEN RAISE EXCEPTION 'Tài liệu % đã tồn tại.', p_tai_lieu_id; END IF;
  IF p_url_luu_tru IS NULL OR p_url_luu_tru !~* '^https?://' THEN RAISE EXCEPTION 'URL lưu trữ không hợp lệ (phải bắt đầu bằng http:// hoặc https://).'; END IF;
  IF p_dung_luong_byte IS NOT NULL AND p_dung_luong_byte > 52428800 THEN RAISE EXCEPTION 'Dung lượng file vượt quá 50MB (BR_TL_03).'; END IF;
  IF NOT EXISTS (SELECT 1 FROM nhanvien WHERE nhan_vien_id = p_tao_boi) THEN RAISE EXCEPTION 'Nhân viên tạo tài liệu % không tồn tại.', p_tao_boi; END IF;
  IF p_danh_muc_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM danhmuc WHERE danh_muc_id = p_danh_muc_id) THEN RAISE EXCEPTION 'Danh mục % không tồn tại.', p_danh_muc_id; END IF;
  IF p_checksum_sha256 IS NOT NULL AND EXISTS (SELECT 1 FROM tailieu WHERE checksum_sha256 = p_checksum_sha256) THEN RAISE EXCEPTION 'File này đã tồn tại trong hệ thống (trùng checksum).'; END IF;
  INSERT INTO tailieu (tai_lieu_id, ten_tai_lieu, loai_tai_lieu, danh_muc_id, url_luu_tru, ten_file_goc, duoi_file, loai_luu_tru, bucket_container,
    duong_dan_tuong_doi, tu_khoa_ai, mime_type, dung_luong_byte, checksum_sha256, quyen_truy_cap, trang_thai, mo_ta, tao_boi)
  VALUES (p_tai_lieu_id, p_ten_tai_lieu, p_loai_tai_lieu, p_danh_muc_id, p_url_luu_tru, p_ten_file_goc, p_duoi_file, p_loai_luu_tru, p_bucket_container,
    p_duong_dan_tuong_doi, p_tu_khoa_ai, p_mime_type, p_dung_luong_byte, p_checksum_sha256, p_quyen_truy_cap, p_trang_thai, p_mo_ta, p_tao_boi);
END $$;

CREATE OR REPLACE FUNCTION sp_update_tailieu(p_tai_lieu_id varchar, p_ten_tai_lieu varchar DEFAULT NULL, p_loai_tai_lieu varchar DEFAULT NULL,
  p_url_luu_tru varchar DEFAULT NULL, p_ten_file_goc varchar DEFAULT NULL, p_duoi_file varchar DEFAULT NULL, p_loai_luu_tru varchar DEFAULT NULL,
  p_bucket_container varchar DEFAULT NULL, p_duong_dan_tuong_doi varchar DEFAULT NULL, p_mime_type varchar DEFAULT NULL, p_mo_ta varchar DEFAULT NULL,
  p_tu_khoa_ai varchar DEFAULT NULL, p_trang_thai varchar DEFAULT NULL, p_danh_muc_id varchar DEFAULT NULL, p_quyen_truy_cap varchar DEFAULT NULL)
RETURNS void LANGUAGE plpgsql AS $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM tailieu WHERE tai_lieu_id = p_tai_lieu_id) THEN RAISE EXCEPTION 'Tài liệu % không tồn tại.', p_tai_lieu_id; END IF;
  IF p_danh_muc_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM danhmuc WHERE danh_muc_id = p_danh_muc_id) THEN RAISE EXCEPTION 'Danh mục % không tồn tại.', p_danh_muc_id; END IF;
  UPDATE tailieu SET ten_tai_lieu = COALESCE(p_ten_tai_lieu, ten_tai_lieu), loai_tai_lieu = COALESCE(p_loai_tai_lieu, loai_tai_lieu),
    url_luu_tru = COALESCE(p_url_luu_tru, url_luu_tru), ten_file_goc = COALESCE(p_ten_file_goc, ten_file_goc), duoi_file = COALESCE(p_duoi_file, duoi_file),
    loai_luu_tru = COALESCE(p_loai_luu_tru, loai_luu_tru), bucket_container = COALESCE(p_bucket_container, bucket_container),
    duong_dan_tuong_doi = COALESCE(p_duong_dan_tuong_doi, duong_dan_tuong_doi), mime_type = COALESCE(p_mime_type, mime_type),
    mo_ta = COALESCE(p_mo_ta, mo_ta), tu_khoa_ai = COALESCE(p_tu_khoa_ai, tu_khoa_ai), trang_thai = COALESCE(p_trang_thai, trang_thai),
    danh_muc_id = COALESCE(p_danh_muc_id, danh_muc_id), quyen_truy_cap = COALESCE(p_quyen_truy_cap, quyen_truy_cap)
  WHERE tai_lieu_id = p_tai_lieu_id;
END $$;

CREATE OR REPLACE FUNCTION sp_delete_tailieu(p_tai_lieu_id varchar) RETURNS void LANGUAGE plpgsql AS $$
BEGIN  -- xóa mềm
  IF NOT EXISTS (SELECT 1 FROM tailieu WHERE tai_lieu_id = p_tai_lieu_id) THEN RAISE EXCEPTION 'Tài liệu % không tồn tại.', p_tai_lieu_id; END IF;
  IF EXISTS (SELECT 1 FROM qna WHERE tai_lieu_id = p_tai_lieu_id) THEN RAISE EXCEPTION 'Tài liệu % đang được tham chiếu trong Q&A, không thể xóa.', p_tai_lieu_id; END IF;
  UPDATE tailieu SET trang_thai = 'DA_XOA' WHERE tai_lieu_id = p_tai_lieu_id;
END $$;

/* ================= 9. QNA & FAQ ================= */
CREATE OR REPLACE FUNCTION sp_insert_qna(p_qna_id varchar, p_nhan_vien_id_ho_tro varchar, p_noi_dung_hoi text, p_kenh_tuong_tac varchar,
  p_thi_sinh_id varchar DEFAULT NULL, p_doanh_nghiep_id varchar DEFAULT NULL, p_tai_lieu_id varchar DEFAULT NULL) RETURNS void LANGUAGE plpgsql AS $$
BEGIN
  IF (p_thi_sinh_id IS NULL AND p_doanh_nghiep_id IS NULL) OR (p_thi_sinh_id IS NOT NULL AND p_doanh_nghiep_id IS NOT NULL) THEN RAISE EXCEPTION 'Phải chọn duy nhất một đối tượng: Thí sinh hoặc Doanh nghiệp.'; END IF;
  IF p_thi_sinh_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM thisinh WHERE thi_sinh_id = p_thi_sinh_id) THEN RAISE EXCEPTION 'Thí sinh % không tồn tại.', p_thi_sinh_id; END IF;
  IF p_doanh_nghiep_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM doanhnghiep WHERE doanh_nghiep_id = p_doanh_nghiep_id) THEN RAISE EXCEPTION 'Doanh nghiệp % không tồn tại.', p_doanh_nghiep_id; END IF;
  IF p_tai_lieu_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM tailieu WHERE tai_lieu_id = p_tai_lieu_id) THEN RAISE EXCEPTION 'Tài liệu % không tồn tại.', p_tai_lieu_id; END IF;
  IF NOT EXISTS (SELECT 1 FROM nhanvien WHERE nhan_vien_id = p_nhan_vien_id_ho_tro AND trang_thai = 'ACTIVE' AND phong_ban IN ('CUSTOMER_SUPPORT','BAN_TO_CHUC','ACADEMIC')) THEN
    RAISE EXCEPTION 'Nhân viên % không hợp lệ hoặc không thuộc phòng ban hỗ trợ (CUSTOMER_SUPPORT, BAN_TO_CHUC, ACADEMIC).', p_nhan_vien_id_ho_tro; END IF;
  IF p_noi_dung_hoi IS NULL OR btrim(p_noi_dung_hoi) = '' THEN RAISE EXCEPTION 'Nội dung câu hỏi không được rỗng.'; END IF;
  INSERT INTO qna (qna_id, thi_sinh_id, doanh_nghiep_id, tai_lieu_id, nhan_vien_id_ho_tro, noi_dung_hoi, thoi_gian, kenh_tuong_tac)
  VALUES (p_qna_id, p_thi_sinh_id, p_doanh_nghiep_id, p_tai_lieu_id, p_nhan_vien_id_ho_tro, p_noi_dung_hoi, now(), p_kenh_tuong_tac);
END $$;

DROP FUNCTION IF EXISTS sp_update_qna(varchar, text, varchar, varchar, smallint);
CREATE OR REPLACE FUNCTION sp_update_qna(p_qna_id varchar, p_noi_dung_tra_loi text DEFAULT NULL, p_nhan_vien_id_ho_tro varchar DEFAULT NULL,
  p_trang_thai varchar DEFAULT NULL, p_danh_gia_hai_long int DEFAULT NULL) RETURNS void LANGUAGE plpgsql AS $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM qna WHERE qna_id = p_qna_id) THEN RAISE EXCEPTION 'Tương tác % không tồn tại.', p_qna_id; END IF;
  IF p_nhan_vien_id_ho_tro IS NOT NULL AND NOT EXISTS (SELECT 1 FROM nhanvien WHERE nhan_vien_id = p_nhan_vien_id_ho_tro AND phong_ban IN ('CUSTOMER_SUPPORT','BAN_TO_CHUC','ACADEMIC')) THEN
    RAISE EXCEPTION 'Nhân viên % không thuộc phòng ban hỗ trợ hợp lệ.', p_nhan_vien_id_ho_tro; END IF;
  IF p_danh_gia_hai_long IS NOT NULL THEN
    IF p_danh_gia_hai_long < 1 OR p_danh_gia_hai_long > 5 THEN RAISE EXCEPTION 'Điểm đánh giá hài lòng phải từ 1 đến 5 sao.'; END IF;
    IF NOT EXISTS (SELECT 1 FROM qna WHERE qna_id = p_qna_id AND noi_dung_tra_loi IS NOT NULL) AND p_noi_dung_tra_loi IS NULL THEN
      RAISE EXCEPTION 'Chỉ được đánh giá sau khi đã có câu trả lời.'; END IF;
  END IF;
  UPDATE qna SET noi_dung_tra_loi = COALESCE(p_noi_dung_tra_loi, noi_dung_tra_loi),
    nhan_vien_id_ho_tro = COALESCE(p_nhan_vien_id_ho_tro, nhan_vien_id_ho_tro),
    trang_thai = COALESCE(p_trang_thai, CASE WHEN p_noi_dung_tra_loi IS NOT NULL THEN 'DA_TRA_LOI' ELSE trang_thai END),
    danh_gia_hai_long = COALESCE(p_danh_gia_hai_long::smallint, danh_gia_hai_long) WHERE qna_id = p_qna_id;
END $$;

CREATE OR REPLACE FUNCTION sp_delete_qna(p_qna_id varchar) RETURNS void LANGUAGE plpgsql AS $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM qna WHERE qna_id = p_qna_id) THEN RAISE EXCEPTION 'Tương tác Q&A % không tồn tại.', p_qna_id; END IF;
  RAISE EXCEPTION 'Lịch sử tương tác Q&A % đã phát sinh, không được phép xóa.', p_qna_id;
END $$;

CREATE OR REPLACE FUNCTION sp_promote_qna_to_faq(p_faq_id varchar, p_qna_id varchar, p_cau_hoi_chuan varchar, p_cau_tra_loi_chuan text,
  p_danh_muc varchar, p_duyet_boi varchar) RETURNS void LANGUAGE plpgsql AS $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM qna WHERE qna_id = p_qna_id) THEN RAISE EXCEPTION 'QNA % không tồn tại.', p_qna_id; END IF;
  IF NOT EXISTS (SELECT 1 FROM nhanvien WHERE nhan_vien_id = p_duyet_boi AND trang_thai = 'ACTIVE') THEN RAISE EXCEPTION 'Nhân viên duyệt % không tồn tại hoặc đã INACTIVE.', p_duyet_boi; END IF;
  IF EXISTS (SELECT 1 FROM faq_canonical WHERE faq_id = p_faq_id) THEN RAISE EXCEPTION 'Mã FAQ % đã tồn tại.', p_faq_id; END IF;
  IF p_danh_muc IS NULL OR btrim(p_danh_muc) = '' THEN RAISE EXCEPTION 'Danh mục FAQ (danh_muc) là bắt buộc.'; END IF;
  IF p_cau_hoi_chuan IS NULL OR p_cau_tra_loi_chuan IS NULL OR btrim(p_cau_hoi_chuan) = '' OR btrim(p_cau_tra_loi_chuan) = '' THEN
    RAISE EXCEPTION 'Câu hỏi và câu trả lời chuẩn không được để rỗng (BR_FAQ_01).'; END IF;
  INSERT INTO faq_canonical (faq_id, danh_muc, cau_hoi_chuan, cau_tra_loi_chuan, nguon_qna_id, trang_thai, duyet_boi)
  VALUES (p_faq_id, btrim(p_danh_muc), p_cau_hoi_chuan, p_cau_tra_loi_chuan, p_qna_id, 'DA_DUYET', p_duyet_boi);
END $$;

/* ================= 10. BIEUMAU / QUANGCAO / DANGKYWEB ================= */
CREATE OR REPLACE FUNCTION sp_insert_bieumau(p_bieu_mau_log varchar, p_ho_ten varchar, p_sdt varchar, p_email varchar,
  p_thi_sinh_id varchar DEFAULT NULL, p_ngay_sinh date DEFAULT NULL, p_truong_hoc varchar DEFAULT NULL, p_kenh_biet varchar DEFAULT NULL,
  p_cau_hoi text DEFAULT NULL, p_trang_thai_ghi_danh varchar DEFAULT NULL) RETURNS void LANGUAGE plpgsql AS $$
DECLARE v_ts varchar := p_thi_sinh_id; v_trung boolean;
BEGIN
  IF EXISTS (SELECT 1 FROM bieumau WHERE bieu_mau_log = p_bieu_mau_log) THEN RAISE EXCEPTION 'Bản ghi Form % đã tồn tại.', p_bieu_mau_log; END IF;
  IF v_ts IS NULL THEN SELECT thi_sinh_id INTO v_ts FROM thisinh WHERE (sdt = p_sdt AND p_sdt <> '') OR (email = p_email AND p_email <> '') LIMIT 1; END IF;
  IF v_ts IS NOT NULL AND NOT EXISTS (SELECT 1 FROM thisinh WHERE thi_sinh_id = v_ts) THEN RAISE EXCEPTION 'Thí sinh % không tồn tại trong hệ thống.', v_ts; END IF;
  SELECT EXISTS (SELECT 1 FROM bieumau WHERE (sdt = p_sdt AND p_sdt <> '') OR (email = p_email AND p_email <> '')) INTO v_trung;
  INSERT INTO bieumau (bieu_mau_log, thi_sinh_id, ho_ten, ngay_sinh, sdt, email, truong_hoc, kenh_biet, cau_hoi, trang_thai_ghi_danh)
  VALUES (p_bieu_mau_log, v_ts, p_ho_ten, p_ngay_sinh, p_sdt, p_email, p_truong_hoc, p_kenh_biet, p_cau_hoi,
          COALESCE(p_trang_thai_ghi_danh, CASE WHEN v_trung THEN 'TRUNG_LAP' ELSE 'CHO_XU_LY' END));
END $$;

CREATE OR REPLACE FUNCTION sp_update_bieumau(p_bieu_mau_log varchar, p_thi_sinh_id varchar DEFAULT NULL, p_trang_thai_ghi_danh varchar DEFAULT NULL)
RETURNS void LANGUAGE plpgsql AS $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM bieumau WHERE bieu_mau_log = p_bieu_mau_log) THEN RAISE EXCEPTION 'Bản ghi Form % không tồn tại.', p_bieu_mau_log; END IF;
  IF p_thi_sinh_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM thisinh WHERE thi_sinh_id = p_thi_sinh_id) THEN RAISE EXCEPTION 'Thí sinh % không tồn tại.', p_thi_sinh_id; END IF;
  UPDATE bieumau SET thi_sinh_id = COALESCE(p_thi_sinh_id, thi_sinh_id), trang_thai_ghi_danh = COALESCE(p_trang_thai_ghi_danh, trang_thai_ghi_danh)
  WHERE bieu_mau_log = p_bieu_mau_log;
END $$;

CREATE OR REPLACE FUNCTION sp_insert_quangcao(p_quang_cao_log varchar, p_quang_cao_id varchar, p_ten_quang_cao varchar, p_chien_dich varchar, p_nen_tang varchar,
  p_ho_ten varchar DEFAULT NULL, p_so_dien_thoai varchar DEFAULT NULL, p_thi_sinh_id varchar DEFAULT NULL, p_bieu_mau_log varchar DEFAULT NULL,
  p_hop_thu_url varchar DEFAULT NULL, p_trang_thai_khach_hang varchar DEFAULT 'MOI', p_sdt varchar DEFAULT NULL, p_email varchar DEFAULT NULL,
  p_ngay_sinh varchar DEFAULT NULL, p_dia_chi varchar DEFAULT NULL, p_link_inbox varchar DEFAULT NULL, p_cau_hoi_them varchar DEFAULT NULL,
  p_chi_phi numeric DEFAULT NULL) RETURNS void LANGUAGE plpgsql AS $$
DECLARE v_sdt varchar; v_ten varchar := NULLIF(btrim(p_ho_ten), ''); v_ts varchar := p_thi_sinh_id; v_email varchar := p_email;
        v_tt varchar := p_trang_thai_khach_hang; v_d text; bm bieumau%ROWTYPE;
BEGIN
  IF EXISTS (SELECT 1 FROM quangcao WHERE quang_cao_log = p_quang_cao_log) THEN RAISE EXCEPTION 'Mã Log quảng cáo % đã tồn tại.', p_quang_cao_log; END IF;
  IF p_quang_cao_id IS NULL OR btrim(p_quang_cao_id) = '' THEN RAISE EXCEPTION 'Bắt buộc phải truyền mã quảng cáo nguồn (quang_cao_id).'; END IF;
  v_sdt := COALESCE(NULLIF(btrim(p_so_dien_thoai), ''), NULLIF(btrim(p_sdt), ''));
  IF p_bieu_mau_log IS NOT NULL THEN
    SELECT * INTO bm FROM bieumau WHERE bieu_mau_log = p_bieu_mau_log;
    IF NOT FOUND THEN RAISE EXCEPTION 'Bản ghi Form % không tồn tại trong bảng BIEUMAU.', p_bieu_mau_log; END IF;
    v_ten := COALESCE(v_ten, bm.ho_ten); v_sdt := COALESCE(v_sdt, bm.sdt); v_email := COALESCE(v_email, bm.email); v_ts := COALESCE(v_ts, bm.thi_sinh_id);
  END IF;
  -- Chuẩn hóa SĐT về 10 số VN
  IF v_sdt IS NOT NULL THEN
    v_d := regexp_replace(v_sdt, '[^0-9]', '', 'g');
    IF left(v_d, 2) = '84' AND length(v_d) = 11 THEN v_d := '0' || substr(v_d, 3);
    ELSIF length(v_d) = 9 THEN v_d := '0' || v_d; END IF;
    v_sdt := CASE WHEN v_d ~ '^(03|05|07|08|09)[0-9]{8}$' THEN v_d ELSE NULL END;
  END IF;
  IF v_sdt IS NULL THEN v_tt := 'ERROR_MISSING_INFO'; END IF;
  IF v_ten IS NULL THEN RAISE EXCEPTION 'Bắt buộc có họ tên (BR_FB_01).'; END IF;
  IF v_ts IS NULL AND (v_sdt IS NOT NULL OR v_email IS NOT NULL) THEN
    SELECT thi_sinh_id INTO v_ts FROM thisinh WHERE (sdt = v_sdt AND v_sdt IS NOT NULL) OR (email = v_email AND v_email IS NOT NULL AND v_email <> '') LIMIT 1; END IF;
  IF v_ts IS NOT NULL AND NOT EXISTS (SELECT 1 FROM thisinh WHERE thi_sinh_id = v_ts) THEN RAISE EXCEPTION 'Thí sinh % không tồn tại trong hệ thống.', v_ts; END IF;
  INSERT INTO quangcao (quang_cao_log, thi_sinh_id, ten_quang_cao, quang_cao_id, chien_dich, bieu_mau_log, nen_tang, ho_ten, so_dien_thoai, email, ngay_sinh,
    dia_chi, link_inbox, cau_hoi_them, hop_thu_url, trang_thai_khach_hang, chi_phi)
  VALUES (p_quang_cao_log, v_ts, p_ten_quang_cao, p_quang_cao_id, p_chien_dich, p_bieu_mau_log, p_nen_tang, v_ten, v_sdt, v_email, p_ngay_sinh,
    p_dia_chi, p_link_inbox, p_cau_hoi_them, p_hop_thu_url, v_tt, p_chi_phi);
END $$;

CREATE OR REPLACE FUNCTION sp_update_quangcao(p_quang_cao_log varchar, p_thi_sinh_id varchar DEFAULT NULL, p_trang_thai_khach_hang varchar DEFAULT NULL,
  p_chi_phi numeric DEFAULT NULL) RETURNS void LANGUAGE plpgsql AS $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM quangcao WHERE quang_cao_log = p_quang_cao_log) THEN RAISE EXCEPTION 'Bản ghi quảng cáo % không tồn tại.', p_quang_cao_log; END IF;
  IF p_thi_sinh_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM thisinh WHERE thi_sinh_id = p_thi_sinh_id) THEN RAISE EXCEPTION 'Thí sinh % không tồn tại.', p_thi_sinh_id; END IF;
  UPDATE quangcao SET thi_sinh_id = COALESCE(p_thi_sinh_id, thi_sinh_id), trang_thai_khach_hang = COALESCE(p_trang_thai_khach_hang, trang_thai_khach_hang),
    chi_phi = COALESCE(p_chi_phi, chi_phi) WHERE quang_cao_log = p_quang_cao_log;
END $$;

CREATE OR REPLACE FUNCTION sp_insert_dangkyweb(p_thanh_toan_id varchar, p_ho_ten varchar, p_sdt varchar, p_email varchar, p_so_tien numeric,
  p_thoi_gian_thanh_toan timestamp, p_bang_dau varchar, p_giao_dich_id varchar, p_thi_sinh_id varchar DEFAULT NULL,
  p_tinh_thanh varchar DEFAULT NULL, p_truong_hoc varchar DEFAULT NULL, p_doi_tac varchar DEFAULT NULL, p_doanh_nghiep_id varchar DEFAULT NULL,
  p_trang_thai_thanh_toan varchar DEFAULT 'CHO_THANH_TOAN', p_ghi_chu varchar DEFAULT NULL, p_hoa_hong numeric DEFAULT NULL)
RETURNS void LANGUAGE plpgsql AS $$
DECLARE v_ts varchar := p_thi_sinh_id; v_hh numeric := p_hoa_hong;
BEGIN
  IF EXISTS (SELECT 1 FROM dangkyweb WHERE thanh_toan_id = p_thanh_toan_id) THEN RAISE EXCEPTION 'Mã thanh toán % đã tồn tại.', p_thanh_toan_id; END IF;
  IF p_giao_dich_id IS NOT NULL AND EXISTS (SELECT 1 FROM dangkyweb WHERE giao_dich_id = p_giao_dich_id) THEN RAISE EXCEPTION 'Mã giao dịch % đã tồn tại.', p_giao_dich_id; END IF;
  IF p_trang_thai_thanh_toan = 'THANH_TOAN_THANH_CONG' AND (p_giao_dich_id IS NULL OR btrim(p_giao_dich_id) = '') THEN RAISE EXCEPTION 'Giao dịch thành công bắt buộc phải có mã giao dịch.'; END IF;
  IF v_ts IS NOT NULL AND NOT EXISTS (SELECT 1 FROM thisinh WHERE thi_sinh_id = v_ts) THEN RAISE EXCEPTION 'Thí sinh % không tồn tại.', v_ts; END IF;
  IF p_doanh_nghiep_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM doanhnghiep WHERE doanh_nghiep_id = p_doanh_nghiep_id) THEN RAISE EXCEPTION 'Doanh nghiệp % không tồn tại.', p_doanh_nghiep_id; END IF;
  IF p_doi_tac IS NOT NULL AND p_doanh_nghiep_id IS NOT NULL THEN RAISE EXCEPTION 'Chỉ được chọn một: p_doi_tac HOẶC p_doanh_nghiep_id, không nhập cả hai.'; END IF;
  IF p_so_tien < 0 THEN RAISE EXCEPTION 'Số tiền phải >= 0.'; END IF;
  IF v_ts IS NULL THEN SELECT thi_sinh_id INTO v_ts FROM thisinh WHERE (sdt = p_sdt AND p_sdt <> '') OR (email = p_email AND p_email <> '') LIMIT 1; END IF;
  IF v_hh IS NULL AND p_doanh_nghiep_id IS NOT NULL
     AND EXISTS (SELECT 1 FROM doanhnghiep WHERE doanh_nghiep_id = p_doanh_nghiep_id AND hinh_thuc = 'CUNG_CAP_THI_SINH') THEN
    v_hh := round(p_so_tien * fn_ty_le_hoa_hong(), 2); END IF;
  INSERT INTO dangkyweb (thanh_toan_id, thi_sinh_id, thoi_gian_thanh_toan, bang_dau, ho_ten, sdt, email, tinh_thanh, truong_hoc, so_tien, doi_tac,
    doanh_nghiep_id, trang_thai_thanh_toan, giao_dich_id, ghi_chu, hoa_hong)
  VALUES (p_thanh_toan_id, v_ts, p_thoi_gian_thanh_toan, p_bang_dau, p_ho_ten, p_sdt, p_email, p_tinh_thanh, p_truong_hoc, p_so_tien, p_doi_tac,
    p_doanh_nghiep_id, p_trang_thai_thanh_toan, p_giao_dich_id, p_ghi_chu, v_hh);
END $$;

CREATE OR REPLACE FUNCTION sp_update_dangkyweb(p_thanh_toan_id varchar, p_thi_sinh_id varchar DEFAULT NULL, p_doi_tac varchar DEFAULT NULL,
  p_doanh_nghiep_id varchar DEFAULT NULL, p_trang_thai_thanh_toan varchar DEFAULT NULL, p_giao_dich_id varchar DEFAULT NULL)
RETURNS void LANGUAGE plpgsql AS $$
DECLARE d dangkyweb%ROWTYPE; v_doi_tac varchar; v_dn varchar;
BEGIN
  SELECT * INTO d FROM dangkyweb WHERE thanh_toan_id = p_thanh_toan_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Đăng ký web % không tồn tại.', p_thanh_toan_id; END IF;
  IF d.trang_thai_thanh_toan = 'THANH_TOAN_THANH_CONG' AND (p_trang_thai_thanh_toan IS NOT NULL OR p_giao_dich_id IS NOT NULL OR p_thi_sinh_id IS NOT NULL OR p_doi_tac IS NOT NULL OR p_doanh_nghiep_id IS NOT NULL) THEN
    RAISE EXCEPTION 'Giao dịch đã thanh toán thành công. Không được phép chỉnh sửa'; END IF;
  IF COALESCE(p_trang_thai_thanh_toan, d.trang_thai_thanh_toan) = 'THANH_TOAN_THANH_CONG' AND COALESCE(p_giao_dich_id, d.giao_dich_id) IS NULL THEN
    RAISE EXCEPTION 'Trạng thái đã thanh toán bắt buộc phải có mã giao dịch (giao_dich_id).'; END IF;
  IF p_thi_sinh_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM thisinh WHERE thi_sinh_id = p_thi_sinh_id) THEN RAISE EXCEPTION 'Thí sinh % không tồn tại.', p_thi_sinh_id; END IF;
  IF p_doanh_nghiep_id IS NOT NULL AND p_doanh_nghiep_id <> '' AND NOT EXISTS (SELECT 1 FROM doanhnghiep WHERE doanh_nghiep_id = p_doanh_nghiep_id) THEN RAISE EXCEPTION 'Doanh nghiệp % không tồn tại.', p_doanh_nghiep_id; END IF;
  IF p_giao_dich_id IS NOT NULL AND EXISTS (SELECT 1 FROM dangkyweb WHERE giao_dich_id = p_giao_dich_id AND thanh_toan_id <> p_thanh_toan_id) THEN RAISE EXCEPTION 'Mã giao dịch % đã tồn tại ở bản ghi khác.', p_giao_dich_id; END IF;
  v_doi_tac := CASE WHEN p_doi_tac = '' THEN NULL ELSE COALESCE(p_doi_tac, d.doi_tac) END;
  v_dn := CASE WHEN p_doanh_nghiep_id = '' THEN NULL ELSE COALESCE(p_doanh_nghiep_id, d.doanh_nghiep_id) END;
  IF p_doanh_nghiep_id IS NOT NULL AND p_doanh_nghiep_id <> '' AND p_doi_tac IS NULL THEN v_doi_tac := NULL; END IF;
  IF p_doi_tac IS NOT NULL AND p_doi_tac <> '' AND p_doanh_nghiep_id IS NULL THEN v_dn := NULL; END IF;
  IF v_doi_tac IS NOT NULL AND v_dn IS NOT NULL THEN RAISE EXCEPTION 'Chỉ được chọn một: doi_tac HOẶC doanh_nghiep_id.'; END IF;
  UPDATE dangkyweb SET thi_sinh_id = COALESCE(p_thi_sinh_id, thi_sinh_id), doi_tac = v_doi_tac, doanh_nghiep_id = v_dn,
    trang_thai_thanh_toan = COALESCE(p_trang_thai_thanh_toan, trang_thai_thanh_toan), giao_dich_id = COALESCE(p_giao_dich_id, giao_dich_id)
  WHERE thanh_toan_id = p_thanh_toan_id;
END $$;

-- Chuyển đăng ký web (đã thanh toán) sang thí sinh / đăng ký / thanh toán chính thức
CREATE OR REPLACE FUNCTION fn_sinh_id(p_prefix text, p_bang text, p_cot text) RETURNS text LANGUAGE plpgsql AS $$
DECLARE v text; n int;
BEGIN
  LOOP
    v := p_prefix || to_char(now(), 'YYYYMMDD') || lpad((floor(random() * 10000))::int::text, 4, '0');
    EXECUTE format('SELECT count(*) FROM %I WHERE %I = $1', p_bang, p_cot) INTO n USING v;
    EXIT WHEN n = 0;
  END LOOP;
  RETURN v;
END $$;

CREATE OR REPLACE FUNCTION sp_duyet_dangkyweb_sang_chinh_thuc(p_thanh_toan_id varchar, p_cuoc_thi_id varchar,
  p_ngay_sinh date DEFAULT NULL, p_cccd varchar DEFAULT NULL, p_sale_phu_trach_id varchar DEFAULT NULL) RETURNS text LANGUAGE plpgsql AS $$
DECLARE w dangkyweb%ROWTYPE; v_ts varchar; v_hs varchar; v_tt varchar; v_dk varchar; v_time timestamp;
BEGIN
  SELECT * INTO w FROM dangkyweb WHERE thanh_toan_id = p_thanh_toan_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Lỗi: Không tìm thấy giao dịch web với mã THANH_TOAN_ID: %', p_thanh_toan_id; END IF;
  IF w.trang_thai_thanh_toan <> 'THANH_TOAN_THANH_CONG' THEN
    RAISE EXCEPTION 'Lỗi: Giao dịch % chưa thanh toán thành công (Trạng thái hiện tại: %)!', p_thanh_toan_id, w.trang_thai_thanh_toan; END IF;
  IF NOT EXISTS (SELECT 1 FROM cuocthi WHERE cuoc_thi_id = p_cuoc_thi_id) THEN RAISE EXCEPTION 'Lỗi: Cuộc thi % không tồn tại trên hệ thống.', p_cuoc_thi_id; END IF;
  IF p_sale_phu_trach_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM nhanvien WHERE nhan_vien_id = p_sale_phu_trach_id AND phong_ban = 'SALES' AND trang_thai = 'ACTIVE') THEN
    RAISE EXCEPTION 'Nhân viên sale % không tồn tại, sai phòng ban hoặc đã INACTIVE.', p_sale_phu_trach_id; END IF;
  IF EXISTS (SELECT 1 FROM thanhtoan WHERE giao_dich_id = w.giao_dich_id) THEN
    RAISE EXCEPTION 'Lỗi: Giao dịch % đã được duyệt/đồng bộ trước đó!', p_thanh_toan_id; END IF;
 
  v_time := COALESCE(w.thoi_gian_thanh_toan, now()::timestamp);
 
  v_ts := w.thi_sinh_id;
  IF v_ts IS NULL THEN SELECT thi_sinh_id INTO v_ts FROM thisinh WHERE lower(email) = lower(w.email); END IF;
  IF v_ts IS NULL THEN SELECT min(thi_sinh_id) INTO v_ts FROM thisinh WHERE sdt = w.sdt HAVING count(*) = 1; END IF;
 
  IF v_ts IS NULL THEN
    IF p_cccd IS NULL OR btrim(p_cccd) = '' THEN RAISE EXCEPTION 'Thí sinh mới bắt buộc phải truyền p_cccd (12 số).'; END IF;
    IF p_ngay_sinh IS NULL THEN RAISE EXCEPTION 'Thí sinh mới bắt buộc phải truyền p_ngay_sinh (để kiểm tra độ tuổi/bảng đấu).'; END IF;
    v_ts := fn_sinh_id('TS', 'thisinh', 'thi_sinh_id');
    INSERT INTO thisinh (thi_sinh_id, sale_phu_trach_id, ho_ten, email, sdt, ngay_sinh, cccd, dia_chi, tinh_thanh, truong_hoc, bang_dau, trang_thai_ho_so)
    VALUES (v_ts, p_sale_phu_trach_id, w.ho_ten, w.email, w.sdt, p_ngay_sinh, p_cccd, 'Đăng ký Web', w.tinh_thanh, w.truong_hoc, w.bang_dau, 'DA_DUYET');
  ELSE
    SELECT trang_thai_ho_so INTO v_hs FROM thisinh WHERE thi_sinh_id = v_ts;
    IF v_hs = 'KHOA' THEN RAISE EXCEPTION 'Hồ sơ thí sinh % đang bị khóa, không thể duyệt.', v_ts; END IF;
    UPDATE thisinh SET trang_thai_ho_so = 'DA_DUYET', bang_dau = COALESCE(bang_dau, w.bang_dau),
                       sale_phu_trach_id = COALESCE(sale_phu_trach_id, p_sale_phu_trach_id)
    WHERE thi_sinh_id = v_ts;
  END IF;
 
  IF NOT EXISTS (SELECT 1 FROM dangky WHERE thi_sinh_id = v_ts AND cuoc_thi_id = p_cuoc_thi_id) THEN
    v_dk := fn_sinh_id('DK', 'dangky', 'dang_ky_id');
    INSERT INTO dangky (dang_ky_id, thi_sinh_id, cuoc_thi_id, ngay_dang_ky, trang_thai, created_at, updated_at)
    VALUES (v_dk, v_ts, p_cuoc_thi_id, v_time, 'CHO_THANH_TOAN', v_time, v_time);
  ELSE
    UPDATE dangky SET trang_thai = 'CHO_THANH_TOAN'
    WHERE thi_sinh_id = v_ts AND cuoc_thi_id = p_cuoc_thi_id AND trang_thai = 'HUY_DANG_KY';
  END IF;
 
  IF w.so_tien > 0 THEN
    v_tt := fn_sinh_id('TT', 'thanhtoan', 'thanh_toan_id');
    INSERT INTO thanhtoan (thanh_toan_id, thi_sinh_id, cuoc_thi_id, thoi_gian_thanh_toan, bang_dau, so_tien, trang_thai_thanh_toan, giao_dich_id, ghi_chu, created_at, updated_at)
    VALUES (v_tt, v_ts, p_cuoc_thi_id, v_time, w.bang_dau, w.so_tien, 'THANH_TOAN_THANH_CONG', w.giao_dich_id, 'Đồng bộ từ DANGKYWEB', v_time, v_time);
    -- trigger trg_thanhtoan_rules tự chuyển dangky -> THANH_CONG
  ELSE
    UPDATE dangky SET trang_thai = 'THANH_CONG' WHERE thi_sinh_id = v_ts AND cuoc_thi_id = p_cuoc_thi_id;
  END IF;
 
  UPDATE dangkyweb SET thi_sinh_id = v_ts WHERE thanh_toan_id = p_thanh_toan_id;
  RETURN 'Duyệt thành công giao dịch web ' || p_thanh_toan_id || '. Thí sinh ID: ' || v_ts
         || ', Mã thanh toán chính thức: ' || COALESCE(v_tt, '(không có - số tiền 0đ)');
END $$;

/* ================= 11. RBAC ================= */
CREATE OR REPLACE FUNCTION sp_insert_vaitro(p_role_id varchar, p_ten_vai_tro varchar, p_mo_ta varchar, p_trang_thai varchar DEFAULT 'DANG_AP_DUNG')
RETURNS void LANGUAGE plpgsql AS $$
BEGIN
  IF EXISTS (SELECT 1 FROM vaitro WHERE role_id = p_role_id) THEN RAISE EXCEPTION 'Mã vai trò % đã tồn tại trong hệ thống.', p_role_id; END IF;
  IF p_role_id NOT IN ('ADMIN','MANAGER','SALE_STAFF','SUPPORT_STAFF') THEN RAISE EXCEPTION 'Vai trò phải thuộc: ADMIN, MANAGER, SALE_STAFF, SUPPORT_STAFF (BR_NV_03).'; END IF;
  IF p_trang_thai NOT IN ('DANG_AP_DUNG','TAM_KHOA') THEN RAISE EXCEPTION 'Trạng thái không hợp lệ. Chỉ chấp nhận DANG_AP_DUNG hoặc TAM_KHOA.'; END IF;
  INSERT INTO vaitro (role_id, ten_vai_tro, mo_ta, trang_thai) VALUES (p_role_id, p_ten_vai_tro, p_mo_ta, p_trang_thai);
END $$;

CREATE OR REPLACE FUNCTION sp_update_vaitro(p_role_id varchar, p_ten_vai_tro varchar DEFAULT NULL, p_mo_ta varchar DEFAULT NULL, p_trang_thai varchar DEFAULT NULL)
RETURNS void LANGUAGE plpgsql AS $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM vaitro WHERE role_id = p_role_id) THEN RAISE EXCEPTION 'Vai trò % không tồn tại.', p_role_id; END IF;
  IF p_trang_thai IS NOT NULL AND p_trang_thai NOT IN ('DANG_AP_DUNG','TAM_KHOA') THEN RAISE EXCEPTION 'Trạng thái không hợp lệ.'; END IF;
  UPDATE vaitro SET ten_vai_tro = COALESCE(p_ten_vai_tro, ten_vai_tro), mo_ta = COALESCE(p_mo_ta, mo_ta), trang_thai = COALESCE(p_trang_thai, trang_thai) WHERE role_id = p_role_id;
END $$;

CREATE OR REPLACE FUNCTION sp_delete_vaitro(p_role_id varchar) RETURNS void LANGUAGE plpgsql AS $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM vaitro WHERE role_id = p_role_id) THEN RAISE EXCEPTION 'Vai trò % không tồn tại.', p_role_id; END IF;
  IF EXISTS (SELECT 1 FROM nhanvien_vaitro_ct WHERE role_id = p_role_id) THEN RAISE EXCEPTION 'Không thể xóa vai trò % vì đang có nhân viên sử dụng.', p_role_id; END IF;
  DELETE FROM vaitro WHERE role_id = p_role_id;
END $$;

CREATE OR REPLACE FUNCTION sp_insert_quyen(p_permission_id varchar, p_ten_quyen varchar, p_nhom_chuc_nang varchar, p_mo_ta varchar DEFAULT NULL)
RETURNS void LANGUAGE plpgsql AS $$
BEGIN
  IF EXISTS (SELECT 1 FROM quyen WHERE permission_id = p_permission_id) THEN RAISE EXCEPTION 'Mã quyền % đã tồn tại.', p_permission_id; END IF;
  INSERT INTO quyen (permission_id, ten_quyen, nhom_chuc_nang, mo_ta) VALUES (p_permission_id, p_ten_quyen, p_nhom_chuc_nang, p_mo_ta);
END $$;

CREATE OR REPLACE FUNCTION sp_update_quyen(p_permission_id varchar, p_ten_quyen varchar DEFAULT NULL, p_nhom_chuc_nang varchar DEFAULT NULL, p_mo_ta varchar DEFAULT NULL)
RETURNS void LANGUAGE plpgsql AS $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM quyen WHERE permission_id = p_permission_id) THEN RAISE EXCEPTION 'Mã quyền % không tồn tại.', p_permission_id; END IF;
  UPDATE quyen SET ten_quyen = COALESCE(p_ten_quyen, ten_quyen), nhom_chuc_nang = COALESCE(p_nhom_chuc_nang, nhom_chuc_nang), mo_ta = COALESCE(p_mo_ta, mo_ta)
  WHERE permission_id = p_permission_id;
END $$;

CREATE OR REPLACE FUNCTION sp_delete_quyen(p_permission_id varchar) RETURNS void LANGUAGE plpgsql AS $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM quyen WHERE permission_id = p_permission_id) THEN RAISE EXCEPTION 'Mã quyền % không tồn tại.', p_permission_id; END IF;
  DELETE FROM quyen WHERE permission_id = p_permission_id;
END $$;

CREATE OR REPLACE FUNCTION sp_assign_role_permission(p_role_id varchar, p_permission_id varchar, p_action varchar DEFAULT 'GRANT')
RETURNS void LANGUAGE plpgsql AS $$
BEGIN
  IF upper(p_action) NOT IN ('GRANT','REVOKE') THEN RAISE EXCEPTION 'Hành động % không hợp lệ. Vui lòng chọn GRANT hoặc REVOKE.', p_action; END IF;
  IF NOT EXISTS (SELECT 1 FROM vaitro WHERE role_id = p_role_id) THEN RAISE EXCEPTION 'Vai trò % không tồn tại.', p_role_id; END IF;
  IF NOT EXISTS (SELECT 1 FROM quyen WHERE permission_id = p_permission_id) THEN RAISE EXCEPTION 'Quyền % không tồn tại.', p_permission_id; END IF;
  IF upper(p_action) = 'GRANT' THEN
    INSERT INTO vaitro_quyen (role_id, permission_id) VALUES (p_role_id, p_permission_id) ON CONFLICT DO NOTHING;
  ELSE DELETE FROM vaitro_quyen WHERE role_id = p_role_id AND permission_id = p_permission_id; END IF;
END $$;

CREATE OR REPLACE FUNCTION sp_assign_user_role(p_nhan_vien_id varchar, p_role_id varchar, p_action varchar DEFAULT 'GRANT', p_nguoi_gan varchar DEFAULT NULL)
RETURNS void LANGUAGE plpgsql AS $$
BEGIN
  IF upper(p_action) NOT IN ('GRANT','REVOKE') THEN RAISE EXCEPTION 'Hành động % không hợp lệ. Vui lòng chọn GRANT hoặc REVOKE.', p_action; END IF;
  IF upper(p_action) = 'GRANT' THEN
    IF NOT EXISTS (SELECT 1 FROM nhanvien WHERE nhan_vien_id = p_nhan_vien_id) THEN RAISE EXCEPTION 'Nhân viên % không tồn tại.', p_nhan_vien_id; END IF;
    IF NOT EXISTS (SELECT 1 FROM vaitro WHERE role_id = p_role_id AND trang_thai = 'DANG_AP_DUNG') THEN RAISE EXCEPTION 'Vai trò % không tồn tại hoặc đang bị tạm khóa.', p_role_id; END IF;
    IF p_nguoi_gan IS NOT NULL AND NOT EXISTS (SELECT 1 FROM nhanvien WHERE nhan_vien_id = p_nguoi_gan) THEN RAISE EXCEPTION 'Người thực hiện gán (%) không tồn tại.', p_nguoi_gan; END IF;
    IF EXISTS (SELECT 1 FROM nhanvien_vaitro_ct WHERE nhan_vien_id = p_nhan_vien_id AND role_id = p_role_id) THEN RAISE EXCEPTION 'Nhân viên % đã được gán vai trò % từ trước.', p_nhan_vien_id, p_role_id; END IF;
    INSERT INTO nhanvien_vaitro_ct (nhan_vien_id, role_id, nguoi_gan) VALUES (p_nhan_vien_id, p_role_id, p_nguoi_gan);
  ELSE
    IF NOT EXISTS (SELECT 1 FROM nhanvien_vaitro_ct WHERE nhan_vien_id = p_nhan_vien_id AND role_id = p_role_id) THEN RAISE EXCEPTION 'Nhân viên % hiện không nắm giữ vai trò %.', p_nhan_vien_id, p_role_id; END IF;
    DELETE FROM nhanvien_vaitro_ct WHERE nhan_vien_id = p_nhan_vien_id AND role_id = p_role_id;  -- trigger chặn nếu là Admin cuối
  END IF;
END $$;

CREATE OR REPLACE FUNCTION sp_insert_log_dangnhap(p_nhan_vien_id varchar, p_trang_thai varchar, p_ip_address varchar DEFAULT NULL,
  p_user_agent varchar DEFAULT NULL, p_ghi_chu varchar DEFAULT NULL) RETURNS void LANGUAGE plpgsql AS $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM nhanvien WHERE nhan_vien_id = p_nhan_vien_id) THEN RAISE EXCEPTION 'Nhân viên % không tồn tại.', p_nhan_vien_id; END IF;
  IF p_trang_thai NOT IN ('THANH_CONG','THAT_BAI') THEN RAISE EXCEPTION 'Trạng thái không hợp lệ. Chỉ chấp nhận THANH_CONG hoặc THAT_BAI.'; END IF;
  INSERT INTO log_dangnhap (nhan_vien_id, ip_address, user_agent, trang_thai, ghi_chu) VALUES (p_nhan_vien_id, p_ip_address, p_user_agent, p_trang_thai, p_ghi_chu);
END $$;

/* ---------- Kiểm tra / truy vấn quyền ---------- */
CREATE OR REPLACE FUNCTION fn_check_user_permission(p_nhan_vien_id varchar, p_permission_id varchar) RETURNS boolean LANGUAGE sql STABLE AS $$
  SELECT EXISTS (
    SELECT 1 FROM nhanvien_vaitro_ct nvt
    JOIN vaitro vt ON vt.role_id = nvt.role_id
    JOIN vaitro_quyen vtq ON vtq.role_id = vt.role_id
    JOIN nhanvien nv ON nv.nhan_vien_id = nvt.nhan_vien_id
    WHERE nvt.nhan_vien_id = p_nhan_vien_id AND nv.trang_thai = 'ACTIVE' AND vt.trang_thai = 'DANG_AP_DUNG' AND vtq.permission_id = p_permission_id) $$;

CREATE OR REPLACE FUNCTION fn_get_user_permissions(p_nhan_vien_id varchar)
RETURNS TABLE (permission_id varchar, ten_quyen varchar, nhom_chuc_nang varchar, mo_ta varchar) LANGUAGE sql STABLE AS $$
  SELECT DISTINCT q.permission_id, q.ten_quyen, q.nhom_chuc_nang, q.mo_ta
  FROM nhanvien_vaitro_ct nvt JOIN vaitro vt ON vt.role_id = nvt.role_id
  JOIN vaitro_quyen vtq ON vtq.role_id = vt.role_id JOIN quyen q ON q.permission_id = vtq.permission_id
  JOIN nhanvien nv ON nv.nhan_vien_id = nvt.nhan_vien_id
  WHERE nvt.nhan_vien_id = p_nhan_vien_id AND nv.trang_thai = 'ACTIVE' AND vt.trang_thai = 'DANG_AP_DUNG'
  ORDER BY q.nhom_chuc_nang, q.permission_id $$;

CREATE OR REPLACE FUNCTION fn_get_user_roles(p_nhan_vien_id varchar)
RETURNS TABLE (nhan_vien_id varchar, ho_ten varchar, role_id varchar, ten_vai_tro varchar, mo_ta varchar, trang_thai_vai_tro varchar, ngay_gan timestamp, nguoi_gan varchar)
LANGUAGE sql STABLE AS $$
  SELECT nv.nhan_vien_id, nv.ho_ten, vt.role_id, vt.ten_vai_tro, vt.mo_ta, vt.trang_thai, nvt.ngay_gan, nvt.nguoi_gan
  FROM nhanvien nv JOIN nhanvien_vaitro_ct nvt ON nvt.nhan_vien_id = nv.nhan_vien_id JOIN vaitro vt ON vt.role_id = nvt.role_id
  WHERE nv.nhan_vien_id = p_nhan_vien_id ORDER BY vt.role_id $$;

CREATE OR REPLACE FUNCTION fn_get_role_permissions(p_role_id varchar)
RETURNS TABLE (role_id varchar, ten_vai_tro varchar, permission_id varchar, ten_quyen varchar, nhom_chuc_nang varchar, mo_ta varchar, ngay_gan timestamp)
LANGUAGE sql STABLE AS $$
  SELECT vt.role_id, vt.ten_vai_tro, q.permission_id, q.ten_quyen, q.nhom_chuc_nang, q.mo_ta, vtq.ngay_gan
  FROM vaitro vt JOIN vaitro_quyen vtq ON vtq.role_id = vt.role_id JOIN quyen q ON q.permission_id = vtq.permission_id
  WHERE vt.role_id = p_role_id ORDER BY q.nhom_chuc_nang, q.permission_id $$;