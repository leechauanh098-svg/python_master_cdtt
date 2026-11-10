-- =============================================================================
-- Source: supabase/migrations/001_schema.sql
-- =============================================================================

/* ================================================================
   PYTHON MASTER 2026 - POSTGRESQL 
   001_schema.sql 
   ================================================================ */

CREATE EXTENSION IF NOT EXISTS vector;
CREATE EXTENSION IF NOT EXISTS pg_trgm;
CREATE EXTENSION IF NOT EXISTS unaccent;

DO $$ BEGIN
  EXECUTE format('ALTER DATABASE %I SET timezone = %L', current_database(), 'Asia/Ho_Chi_Minh');
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'Không đặt được timezone cấp database (%). Hãy đặt ở role/connection string: options=-c timezone=Asia/Ho_Chi_Minh', SQLERRM;
END $$;
SET timezone = 'Asia/Ho_Chi_Minh';

/* ================ 1. NHÂN VIÊN & CẤU HÌNH ================ */
CREATE TABLE nhanvien (
  nhan_vien_id varchar(20) PRIMARY KEY,
  ho_ten       varchar(100) NOT NULL,
  email        varchar(254) NOT NULL UNIQUE,
  sdt          varchar(10)  NOT NULL,
  phong_ban    varchar(30)  NOT NULL,
  phan_quyen   varchar(30)  NOT NULL,
  trang_thai   varchar(20)  NOT NULL DEFAULT 'ACTIVE',
  created_at   timestamp DEFAULT now(),
  updated_at   timestamp DEFAULT now(),
  CONSTRAINT chk_nv_phongban  CHECK (phong_ban IN ('SALES','MARKETING','BAN_TO_CHUC','ACADEMIC','IT','CUSTOMER_SUPPORT')),
  CONSTRAINT chk_nv_phanquyen CHECK (phan_quyen IN ('ADMIN','MANAGER','SALE_STAFF','SUPPORT_STAFF')),
  CONSTRAINT chk_nv_trangthai CHECK (trang_thai IN ('ACTIVE','INACTIVE')),
  CONSTRAINT chk_nv_email CHECK (email ~ '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]+$' AND email ~* '@sotatek\.com$'),
  CONSTRAINT chk_nv_sdt   CHECK (sdt ~ '^(03|05|07|08|09)[0-9]{8}$')
);
CREATE INDEX idx_nhanvien_hoten ON nhanvien(ho_ten);
CREATE INDEX idx_nhanvien_sdt ON nhanvien(sdt);
CREATE INDEX idx_nhanvien_phongban ON nhanvien(phong_ban);

ALTER TABLE public.nhanvien
ADD COLUMN user_id UUID UNIQUE;

ALTER TABLE public.nhanvien
ADD CONSTRAINT fk_nhanvien_user
FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_nhanvien_user_id ON public.nhanvien(user_id);
CREATE INDEX IF NOT EXISTS idx_nhanvien_phan_quyen ON public.nhanvien(phan_quyen);

CREATE TABLE cauhinh_he_thong (
  khoa_cau_hinh varchar(50) PRIMARY KEY,
  gia_tri       varchar(200) NOT NULL,
  mo_ta         varchar(255),
  updated_at    timestamp DEFAULT now(),
  updated_by    varchar(20) REFERENCES nhanvien(nhan_vien_id)
);
/* ================ 2. THÍ SINH / DOANH NGHIỆP / CUỘC THI ================ */
CREATE TABLE thisinh (
  thi_sinh_id       varchar(20) PRIMARY KEY,
  sale_phu_trach_id varchar(20) REFERENCES nhanvien(nhan_vien_id),
  ho_ten            varchar(100) NOT NULL,
  email             varchar(254) NOT NULL UNIQUE,
  sdt               varchar(10)  NOT NULL,
  ngay_sinh         date NOT NULL,
  dia_chi           varchar(300) NOT NULL,
  cccd              varchar(12)  NOT NULL UNIQUE,
  tinh_thanh        varchar(100),
  truong_hoc        varchar(200),
  bang_dau          varchar(100),
  trang_thai_ho_so  varchar(30) NOT NULL DEFAULT 'MOI_TAO',
  created_at        timestamp DEFAULT now(),
  updated_at        timestamp DEFAULT now(),
  CONSTRAINT chk_ts_bangdau   CHECK (bang_dau IS NULL OR bang_dau IN ('BANG_A','BANG_B')),
  CONSTRAINT chk_ts_trangthai CHECK (trang_thai_ho_so IN ('MOI_TAO','CHO_DUYET','DA_DUYET','KHONG_HOP_LE','KHOA')),
  CONSTRAINT chk_ts_email CHECK (email ~ '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]+$'),
  CONSTRAINT chk_ts_sdt   CHECK (sdt ~ '^(03|05|07|08|09)[0-9]{8}$'),
  CONSTRAINT chk_ts_cccd  CHECK (cccd ~ '^[0-9]{12}$'),
  CONSTRAINT chk_thisinh_daduyet_phai_co_bang_dau CHECK (trang_thai_ho_so <> 'DA_DUYET' OR bang_dau IS NOT NULL)
);  
CREATE INDEX idx_thisinh_sdt ON thisinh(sdt);
CREATE INDEX idx_thisinh_hoten ON thisinh(ho_ten);
CREATE INDEX idx_thisinh_sale ON thisinh(sale_phu_trach_id);
CREATE INDEX idx_thisinh_trangthai ON thisinh(trang_thai_ho_so);
CREATE INDEX idx_thisinh_truonghoc ON thisinh(truong_hoc);

CREATE TABLE doanhnghiep (
  doanh_nghiep_id  varchar(20) PRIMARY KEY,
  ten_doanh_nghiep varchar(200) NOT NULL,
  ma_so_thue       varchar(20)  NOT NULL UNIQUE,
  dia_chi          varchar(300) NOT NULL,
  email_lien_he    varchar(254) NOT NULL UNIQUE,
  sdt_lien_he      varchar(10)  NOT NULL,
  nganh_nghe       varchar(100),
  hinh_thuc        varchar(100) NOT NULL,
  loai_tai_tro     varchar(50)  NOT NULL DEFAULT 'KHONG_TAI_TRO',
  cap_do_tai_tro   varchar(50)  NOT NULL DEFAULT 'KHONG',
  hop_dong         varchar(300) NOT NULL,
  created_at       timestamp DEFAULT now(),
  updated_at       timestamp DEFAULT now(),
  CONSTRAINT chk_dn_hinhthuc CHECK (hinh_thuc IN ('CUNG_CAP_THI_SINH','TAI_TRO_DONG_HANH')),
  CONSTRAINT chk_dn_loaitaitro CHECK (loai_tai_tro IN ('HIEN_KIM','HIEN_VAT','KHONG_TAI_TRO')),
  CONSTRAINT chk_dn_capdo CHECK (cap_do_tai_tro IN ('KIM_CUONG','VANG','BAC','DONG','DONG_HANH','KHONG')),
  CONSTRAINT chk_dn_mst CHECK (ma_so_thue ~ '^[0-9]+$' AND length(ma_so_thue) IN (10,13)),
  CONSTRAINT chk_dn_email CHECK (email_lien_he ~ '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]+$'),
  CONSTRAINT chk_dn_sdt CHECK (sdt_lien_he ~ '^(03|05|07|08|09)[0-9]{8}$'),
  CONSTRAINT chk_dn_hopdong_file CHECK (hop_dong ~* '\.(pdf|doc|docx)$'),
  CONSTRAINT chk_dn_logic_tai_tro CHECK (
    (hinh_thuc = 'CUNG_CAP_THI_SINH' AND loai_tai_tro = 'KHONG_TAI_TRO' AND cap_do_tai_tro = 'KHONG') OR
    (hinh_thuc = 'TAI_TRO_DONG_HANH' AND loai_tai_tro <> 'KHONG_TAI_TRO' AND cap_do_tai_tro <> 'KHONG'))
);
CREATE INDEX idx_doanhnghiep_ten ON doanhnghiep(ten_doanh_nghiep);
CREATE INDEX idx_doanhnghiep_hinhthuc ON doanhnghiep(hinh_thuc);

CREATE TABLE cuocthi (
  cuoc_thi_id   varchar(20) PRIMARY KEY,
  ten_cuoc_thi  varchar(200) NOT NULL,
  bang_dau      varchar(100),
  mo_ta         varchar(1000),
  han_dang_ky   timestamp NOT NULL,
  ngay_bat_dau  timestamp NOT NULL,
  ngay_ket_thuc timestamp NOT NULL,
  trang_thai    varchar(100) NOT NULL,
  created_at    timestamp DEFAULT now(),
  updated_at    timestamp DEFAULT now(),
  CONSTRAINT chk_ct_bangdau CHECK (bang_dau IS NULL OR bang_dau IN ('BANG_A','BANG_B')),
  CONSTRAINT chk_ct_trangthai CHECK (trang_thai IN ('SAP_DIEN_RA','MO_DANG_KY','DONG_DANG_KY','DANG_DIEN_RA','DA_KET_THUC','HUY')),
  CONSTRAINT chk_ct_han_dk CHECK (han_dang_ky <= ngay_bat_dau),
  CONSTRAINT chk_ct_ngay CHECK (ngay_bat_dau <= ngay_ket_thuc)
);
CREATE INDEX idx_cuocthi_ten ON cuocthi(ten_cuoc_thi);
CREATE INDEX idx_cuocthi_trangthai ON cuocthi(trang_thai);

CREATE TABLE dangky (
  dang_ky_id   varchar(20) PRIMARY KEY,
  thi_sinh_id  varchar(20) NOT NULL REFERENCES thisinh(thi_sinh_id),
  cuoc_thi_id  varchar(20) NOT NULL REFERENCES cuocthi(cuoc_thi_id),
  ngay_dang_ky timestamp NOT NULL,
  trang_thai   varchar(30) NOT NULL DEFAULT 'CHO_THANH_TOAN',
  created_at   timestamp DEFAULT now(),
  updated_at   timestamp DEFAULT now(),
  CONSTRAINT chk_dk_trangthai CHECK (trang_thai IN ('CHO_THANH_TOAN','THANH_CONG','HUY_DANG_KY')),
  CONSTRAINT uq_thisinh_cuocthi UNIQUE (thi_sinh_id, cuoc_thi_id)
);
CREATE INDEX idx_dangky_cuocthi ON dangky(cuoc_thi_id);
CREATE INDEX idx_dangky_trangthai ON dangky(trang_thai);
CREATE INDEX idx_dangky_ngay ON dangky(ngay_dang_ky);

CREATE TABLE thanhtoan (
  thanh_toan_id         varchar(30) PRIMARY KEY,
  thi_sinh_id           varchar(20) NOT NULL,
  cuoc_thi_id           varchar(20) NOT NULL,
  thoi_gian_thanh_toan  timestamp NOT NULL,
  bang_dau              varchar(30),
  so_tien               numeric(15,2) NOT NULL,
  trang_thai_thanh_toan varchar(30) NOT NULL DEFAULT 'CHO_THANH_TOAN',
  giao_dich_id          varchar(100) NOT NULL UNIQUE,
  ghi_chu               varchar(500),
  created_at            timestamp DEFAULT now(),
  updated_at            timestamp DEFAULT now(),
  CONSTRAINT chk_tt_bangdau CHECK (bang_dau IS NULL OR bang_dau IN ('BANG_A','BANG_B')),
  CONSTRAINT chk_tt_sotien CHECK (so_tien >= 0),
  CONSTRAINT chk_tt_trangthai CHECK (trang_thai_thanh_toan IN ('CHO_THANH_TOAN','THANH_TOAN_THANH_CONG','THAT_BAI','HOAN_TIEN')),
  CONSTRAINT fk_thanhtoan_dangky FOREIGN KEY (thi_sinh_id, cuoc_thi_id) REFERENCES dangky(thi_sinh_id, cuoc_thi_id)
);
CREATE INDEX idx_thanhtoan_thisinh ON thanhtoan(thi_sinh_id);
CREATE INDEX idx_thanhtoan_cuocthi ON thanhtoan(cuoc_thi_id);
CREATE INDEX idx_thanhtoan_trangthai ON thanhtoan(trang_thai_thanh_toan);

CREATE INDEX IF NOT EXISTS idx_thisinh_hoten_trgm ON thisinh USING gin (ho_ten gin_trgm_ops);
CREATE INDEX IF NOT EXISTS idx_thisinh_email_trgm ON thisinh USING gin (email gin_trgm_ops);
CREATE INDEX IF NOT EXISTS idx_thisinh_truong_trgm ON thisinh USING gin (truong_hoc gin_trgm_ops);
CREATE INDEX IF NOT EXISTS idx_doanhnghiep_ten_trgm ON doanhnghiep USING gin (ten_doanh_nghiep gin_trgm_ops);

SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'thanhtoan';

/* ================ 3. BÀI TẬP ================ */
CREATE TABLE baitap (
  bai_tap_id            varchar(20) PRIMARY KEY,
  cuoc_thi_id           varchar(20) NOT NULL REFERENCES cuocthi(cuoc_thi_id),
  bang_dau              varchar(100) NOT NULL,
  ten_bai_tap           varchar(200) NOT NULL,
  mo_ta                 text,
  thoi_gian_lam_bai     int NOT NULL DEFAULT 60,
  so_lan_nop_bai_toi_da int NOT NULL DEFAULT 1,
  diem_dat              numeric(5,2),
  ngay_bat_dau          timestamp,
  ngay_het_han          timestamp NOT NULL,
  trang_thai            varchar(30) NOT NULL DEFAULT 'MO',
  created_at            timestamp DEFAULT now(),
  updated_at            timestamp DEFAULT now(),
  CONSTRAINT chk_bt_bangdau CHECK (bang_dau IN ('BANG_A','BANG_B')),
  CONSTRAINT chk_bt_thoigianlam CHECK (thoi_gian_lam_bai > 0),
  CONSTRAINT chk_bt_solannop CHECK (so_lan_nop_bai_toi_da >= 1),
  CONSTRAINT chk_bt_diemdat CHECK (diem_dat IS NULL OR diem_dat >= 0),
  CONSTRAINT chk_bt_trangthai CHECK (trang_thai IN ('MO','DONG','HUY')),
  CONSTRAINT chk_baitap_thoigian CHECK (ngay_bat_dau IS NULL OR ngay_bat_dau <= ngay_het_han)
);
CREATE INDEX idx_baitap_cuocthi ON baitap(cuoc_thi_id);
CREATE INDEX idx_baitap_bangdau ON baitap(bang_dau);

CREATE TABLE cauhoi (
  cau_hoi_id         varchar(20) PRIMARY KEY,
  bai_tap_id         varchar(20) NOT NULL REFERENCES baitap(bai_tap_id) ON DELETE CASCADE,
  noi_dung_cau_hoi   text NOT NULL,
  hinh_anh_url       varchar(500),
  loai_cau_hoi       varchar(50) NOT NULL,
  thu_tu             int NOT NULL,
  diem_toi_da        numeric(5,2) NOT NULL DEFAULT 1.00,
  dap_an_mau_dien_tu text,
  giai_thich_dap_an  text,
  created_at         timestamp DEFAULT now(),
  updated_at         timestamp DEFAULT now(),
  CONSTRAINT chk_ch_loai CHECK (loai_cau_hoi IN ('TRAC_NGHIEM_1','TRAC_NGHIEM_NHIEU','DIEN_TU','TU_LUAN')),
  CONSTRAINT chk_ch_thutu CHECK (thu_tu >= 1),
  CONSTRAINT chk_ch_diem CHECK (diem_toi_da > 0),
  CONSTRAINT uq_cauhoi_thutu UNIQUE (bai_tap_id, thu_tu)
);
CREATE INDEX idx_cauhoi_baitap ON cauhoi(bai_tap_id);

CREATE TABLE lua_chon_dap_an (
  dap_an_id       varchar(20) PRIMARY KEY,
  cau_hoi_id      varchar(20) NOT NULL REFERENCES cauhoi(cau_hoi_id) ON DELETE CASCADE,
  noi_dung_dap_an text NOT NULL,
  la_dap_an_dung  boolean NOT NULL DEFAULT false,
  thu_tu          int NOT NULL,
  created_at      timestamp DEFAULT now(),
  CONSTRAINT chk_lc_thutu CHECK (thu_tu >= 1),
  CONSTRAINT uq_lua_chon_thutu UNIQUE (cau_hoi_id, thu_tu),
  CONSTRAINT uq_lua_chon_dapan_cauhoi UNIQUE (dap_an_id, cau_hoi_id)
);
CREATE INDEX idx_luachon_cauhoi ON lua_chon_dap_an(cau_hoi_id);

CREATE TABLE bainop (
  bai_nop_id             varchar(30) PRIMARY KEY,
  bai_tap_id             varchar(20) NOT NULL REFERENCES baitap(bai_tap_id),
  thi_sinh_id            varchar(20) NOT NULL REFERENCES thisinh(thi_sinh_id),
  lan_nop                int NOT NULL DEFAULT 1,
  tong_diem              numeric(5,2),
  nhan_xet_chung         text,
  thoi_gian_bat_dau      timestamp NOT NULL,
  thoi_gian_nop          timestamp,
  thoi_gian_lam_bai_giay int,
  trang_thai             varchar(30) NOT NULL DEFAULT 'DANG_LAM',
  created_at             timestamp NOT NULL DEFAULT now(),
  updated_at             timestamp NOT NULL DEFAULT now(),
  CONSTRAINT chk_bn_lannop CHECK (lan_nop >= 1),
  CONSTRAINT chk_bn_tongdiem CHECK (tong_diem IS NULL OR tong_diem >= 0),
  CONSTRAINT chk_bn_giay CHECK (thoi_gian_lam_bai_giay IS NULL OR thoi_gian_lam_bai_giay >= 0),
  CONSTRAINT chk_bn_trangthai CHECK (trang_thai IN ('DANG_LAM','DA_NOP','DA_CHAM_DIEM','QUA_HAN_NOP')),
  CONSTRAINT uq_bainop_lannop UNIQUE (bai_tap_id, thi_sinh_id, lan_nop),
  CONSTRAINT chk_bainop_thoigian CHECK (thoi_gian_nop IS NULL OR thoi_gian_nop >= thoi_gian_bat_dau)
);
CREATE INDEX idx_bainop_baitap ON bainop(bai_tap_id);
CREATE INDEX idx_bainop_thisinh ON bainop(thi_sinh_id);
CREATE INDEX idx_bainop_trangthai ON bainop(trang_thai);

CREATE TABLE chi_tiet_dap_an_nop (
  chi_tiet_id      bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  bai_nop_id       varchar(30) NOT NULL REFERENCES bainop(bai_nop_id) ON DELETE CASCADE,
  cau_hoi_id       varchar(20) NOT NULL REFERENCES cauhoi(cau_hoi_id),
  dap_an_chon_id   varchar(20),
  noi_dung_tra_loi text,
  diem_dat_duoc    numeric(5,2),
  la_dap_an_dung   boolean,
  nhan_xet_cau_hoi text,
  created_at       timestamp NOT NULL DEFAULT now(),
  updated_at       timestamp NOT NULL DEFAULT now(),
  CONSTRAINT chk_ctda_diem CHECK (diem_dat_duoc IS NULL OR diem_dat_duoc >= 0),
  CONSTRAINT fk_ctda_dapan_cauhoi FOREIGN KEY (dap_an_chon_id, cau_hoi_id) REFERENCES lua_chon_dap_an(dap_an_id, cau_hoi_id),
  CONSTRAINT chk_ctda_noidung_an_toan CHECK (
    noi_dung_tra_loi IS NULL OR NOT (
      noi_dung_tra_loi ~* '<script|<iframe|javascript:|onerror\s*=|onload\s*=|union.*select|drop.*table|'' or ''1''=''1|;.*--'))
);
CREATE INDEX idx_ctda_bainop ON chi_tiet_dap_an_nop(bai_nop_id);
CREATE INDEX idx_ctda_cauhoi ON chi_tiet_dap_an_nop(cau_hoi_id);

/* ================ 4. KNOWLEDGE BASE / RAG ================ */
CREATE TABLE danhmuc (
  danh_muc_id     varchar(20) PRIMARY KEY,
  ten_danh_muc    varchar(200) NOT NULL,
  danh_muc_cha_id varchar(20) REFERENCES danhmuc(danh_muc_id),
  created_at      timestamp NOT NULL DEFAULT now(),
  updated_at      timestamp NOT NULL DEFAULT now()
);
CREATE INDEX idx_danhmuc_cha ON danhmuc(danh_muc_cha_id);

CREATE TABLE tailieu (
  tai_lieu_id         varchar(20) PRIMARY KEY,
  ten_tai_lieu        varchar(200) NOT NULL,
  loai_tai_lieu       varchar(50) NOT NULL,
  danh_muc_id         varchar(20) REFERENCES danhmuc(danh_muc_id),
  url_luu_tru         varchar(500) NOT NULL,
  ten_file_goc        varchar(255),
  duoi_file           varchar(20),
  loai_luu_tru        varchar(30) NOT NULL DEFAULT 'OBJECT_STORAGE',
  bucket_container    varchar(150),
  duong_dan_tuong_doi varchar(500),
  mo_ta               varchar(1000),
  tu_khoa_ai          varchar(500),
  mime_type           varchar(100),
  dung_luong_byte     bigint,
  checksum_sha256     char(64),
  phien_ban           int NOT NULL DEFAULT 1,
  quyen_truy_cap      varchar(20) NOT NULL DEFAULT 'NOI_BO',
  trang_thai          varchar(30) NOT NULL DEFAULT 'NOI_BO',
  tao_boi             varchar(20) NOT NULL REFERENCES nhanvien(nhan_vien_id),
  created_at          timestamp NOT NULL DEFAULT now(),
  updated_at          timestamp NOT NULL DEFAULT now(),
  CONSTRAINT chk_tl_loai CHECK (loai_tai_lieu IN ('QUY_CHE','HO_TRO_KY_THUAT','DE_THI_MAU','TAI_TRO_DOI_TAC','TAI_LIEU_KY_THUAT')),
  CONSTRAINT chk_tl_url CHECK (url_luu_tru ~* '^https?://'),
  CONSTRAINT chk_tl_luutru CHECK (loai_luu_tru IN ('LOCAL','OBJECT_STORAGE','CLOUD','DATABASE')),
  CONSTRAINT chk_tl_dungluong CHECK (dung_luong_byte IS NULL OR (dung_luong_byte >= 0 AND dung_luong_byte <= 52428800)),
  CONSTRAINT chk_tl_phienban CHECK (phien_ban >= 1),
  CONSTRAINT chk_tl_quyen CHECK (quyen_truy_cap IN ('CONG_KHAI','NOI_BO','CHI_ADMIN')),
  CONSTRAINT chk_tl_trangthai CHECK (trang_thai IN ('CONG_KHAI','NOI_BO','AN','DA_XOA'))
);
CREATE INDEX idx_tailieu_loai ON tailieu(loai_tai_lieu);
CREATE INDEX idx_tailieu_trangthai ON tailieu(trang_thai);
CREATE INDEX idx_tailieu_danhmuc ON tailieu(danh_muc_id);
CREATE INDEX idx_tailieu_ten_trgm ON tailieu USING gin (ten_tai_lieu gin_trgm_ops);
CREATE UNIQUE INDEX uq_tailieu_checksum ON tailieu(checksum_sha256) WHERE checksum_sha256 IS NOT NULL;

CREATE TABLE tag (
  tag_id  varchar(20) PRIMARY KEY,
  ten_tag varchar(100) NOT NULL UNIQUE
);
CREATE TABLE tailieu_tag (
  tai_lieu_id varchar(20) NOT NULL REFERENCES tailieu(tai_lieu_id) ON DELETE CASCADE,
  tag_id      varchar(20) NOT NULL REFERENCES tag(tag_id) ON DELETE CASCADE,
  PRIMARY KEY (tai_lieu_id, tag_id)
);
CREATE TABLE tailieu_doan (
  doan_id       bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  tai_lieu_id   varchar(20) NOT NULL REFERENCES tailieu(tai_lieu_id) ON DELETE CASCADE,
  thu_tu_doan   int NOT NULL CHECK (thu_tu_doan >= 1),
  noi_dung_doan text NOT NULL,
  embedding     vector(1536),
  created_at    timestamp DEFAULT now(),
  UNIQUE (tai_lieu_id, thu_tu_doan)
);
CREATE INDEX idx_tailieudoan_tailieu ON tailieu_doan(tai_lieu_id);
-- Tìm kiếm vector (bật khi đã có dữ liệu embedding):
-- CREATE INDEX idx_tailieudoan_emb ON tailieu_doan USING hnsw (embedding vector_cosine_ops);

/* ================ 5. Q&A / FAQ ================ */
CREATE TABLE qna (
  qna_id              varchar(30) PRIMARY KEY,
  thi_sinh_id         varchar(20) REFERENCES thisinh(thi_sinh_id),
  doanh_nghiep_id     varchar(20) REFERENCES doanhnghiep(doanh_nghiep_id),
  tai_lieu_id         varchar(20) REFERENCES tailieu(tai_lieu_id),
  nhan_vien_id_ho_tro varchar(20) NOT NULL REFERENCES nhanvien(nhan_vien_id),
  noi_dung_hoi        text NOT NULL,
  noi_dung_tra_loi    text,
  thoi_gian           timestamp NOT NULL,
  kenh_tuong_tac      varchar(30) NOT NULL,
  trang_thai          varchar(20) NOT NULL DEFAULT 'CHUA_TRA_LOI',
  danh_gia_hai_long   smallint,
  created_at          timestamp DEFAULT now(),
  updated_at          timestamp DEFAULT now(),
  CONSTRAINT chk_qna_kenh CHECK (kenh_tuong_tac IN ('WEBSITE','FACEBOOK','ZALO','EMAIL','HOTLINE')),
  CONSTRAINT chk_qna_trangthai CHECK (trang_thai IN ('CHUA_TRA_LOI','DA_TRA_LOI')),
  CONSTRAINT chk_qna_danhgia CHECK (danh_gia_hai_long IS NULL OR danh_gia_hai_long BETWEEN 1 AND 5),
  CONSTRAINT chk_qna_traloi CHECK (trang_thai <> 'DA_TRA_LOI' OR noi_dung_tra_loi IS NOT NULL),
  CONSTRAINT chk_qna_doituong CHECK ((thi_sinh_id IS NOT NULL AND doanh_nghiep_id IS NULL) OR (thi_sinh_id IS NULL AND doanh_nghiep_id IS NOT NULL))
);
CREATE INDEX idx_qna_thisinh ON qna(thi_sinh_id);
CREATE INDEX idx_qna_nhanvien ON qna(nhan_vien_id_ho_tro);
CREATE INDEX idx_qna_doanhnghiep ON qna(doanh_nghiep_id);
CREATE INDEX idx_qna_thoigian ON qna(thoi_gian);

CREATE TABLE faq_canonical (
  faq_id            varchar(20) PRIMARY KEY,
  danh_muc          varchar(150) NOT NULL,
  cau_hoi_chuan     varchar(500) NOT NULL,
  cau_tra_loi_chuan text NOT NULL,
  nguon_qna_id      varchar(30) REFERENCES qna(qna_id),
  embedding         vector(1536),
  trang_thai        varchar(20) NOT NULL DEFAULT 'NHAP',
  duyet_boi         varchar(20) REFERENCES nhanvien(nhan_vien_id),
  luot_xem          int NOT NULL DEFAULT 0,
  created_at        timestamp DEFAULT now(),
  updated_at        timestamp DEFAULT now(),
  CONSTRAINT chk_faq_trangthai CHECK (trang_thai IN ('NHAP','DA_DUYET','NGUNG_SU_DUNG')),
  CONSTRAINT chk_faq_cauhoi CHECK (length(btrim(cau_hoi_chuan)) > 0),
  CONSTRAINT chk_faq_traloi CHECK (length(btrim(cau_tra_loi_chuan)) > 0),
  CONSTRAINT chk_faq_duyet CHECK (trang_thai <> 'DA_DUYET' OR duyet_boi IS NOT NULL),
  CONSTRAINT chk_faq_luotxem CHECK (luot_xem >= 0)
);
CREATE INDEX idx_faq_trangthai ON faq_canonical(trang_thai);

CREATE TABLE qna_phanhoi (
  phan_hoi_id        bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  qna_id             varchar(30) NOT NULL REFERENCES qna(qna_id) ON DELETE CASCADE,
  thi_sinh_id        varchar(20) REFERENCES thisinh(thi_sinh_id),
  doanh_nghiep_id    varchar(20) REFERENCES doanhnghiep(doanh_nghiep_id),
  diem_danh_gia      smallint,
  noi_dung_phan_hoi  varchar(2000),
  thoi_gian          timestamp NOT NULL DEFAULT now(),
  trang_thai         varchar(30) NOT NULL DEFAULT 'MOI',
  nhan_vien_xu_ly_id varchar(20) REFERENCES nhanvien(nhan_vien_id),
  ghi_chu            varchar(1000),
  created_at         timestamp NOT NULL DEFAULT now(),
  updated_at         timestamp,
  CONSTRAINT ck_qna_phanhoi_diem CHECK (diem_danh_gia IS NULL OR diem_danh_gia BETWEEN 1 AND 5),
  CONSTRAINT ck_qna_phanhoi_trang_thai CHECK (trang_thai IN ('MOI','CHO_DUYET','DA_XU_LY')),
  CONSTRAINT ck_qna_phanhoi_nguoi_gui CHECK ((thi_sinh_id IS NOT NULL AND doanh_nghiep_id IS NULL) OR (thi_sinh_id IS NULL AND doanh_nghiep_id IS NOT NULL))
);
CREATE INDEX ix_qna_phanhoi_qna ON qna_phanhoi(qna_id);

/* ================ 6. MARKETING ================ */
CREATE TABLE bieumau (
  bieu_mau_log        varchar(30) PRIMARY KEY,
  thi_sinh_id         varchar(20) REFERENCES thisinh(thi_sinh_id),
  dau_thoi_gian       timestamp NOT NULL DEFAULT now(),
  ho_ten              varchar(100) NOT NULL,
  ngay_sinh           date,
  sdt                 varchar(10) NOT NULL,
  email               varchar(254) NOT NULL,
  truong_hoc          varchar(200),
  kenh_biet           varchar(100),
  trang_thai_ghi_danh varchar(30) NOT NULL DEFAULT 'CHO_XU_LY',
  cau_hoi             text,
  created_at          timestamp DEFAULT now(),
  updated_at          timestamp DEFAULT now(),
  CONSTRAINT chk_bm_trangthai CHECK (trang_thai_ghi_danh IN ('CHO_XU_LY','DA_DOI_SOAT','DA_TAO_TAI_KHOAN','TRUNG_LAP')),
  CONSTRAINT chk_bm_email CHECK (email ~ '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]+$'),
  CONSTRAINT chk_bm_sdt CHECK (sdt ~ '^(03|05|07|08|09)[0-9]{8}$')
);
CREATE INDEX idx_bieumau_thisinh ON bieumau(thi_sinh_id);
CREATE INDEX idx_bieumau_sdt ON bieumau(sdt);
CREATE INDEX idx_bieumau_email ON bieumau(email);

CREATE TABLE quangcao (
  quang_cao_log         varchar(30) PRIMARY KEY,
  thi_sinh_id           varchar(20) REFERENCES thisinh(thi_sinh_id),
  ten_quang_cao         varchar(200) NOT NULL,
  quang_cao_id          varchar(50) NOT NULL,
  chien_dich            varchar(200) NOT NULL,
  bieu_mau_log          varchar(30) REFERENCES bieumau(bieu_mau_log),
  nen_tang              varchar(100) NOT NULL,
  ho_ten                varchar(100) NOT NULL,
  so_dien_thoai         varchar(50),
  email                 varchar(254),
  ngay_sinh             varchar(50),
  dia_chi               varchar(200),
  link_inbox            varchar(200),
  cau_hoi_them          varchar(500),
  hop_thu_url           varchar(500),
  trang_thai_khach_hang varchar(30) NOT NULL DEFAULT 'MOI',
  chi_phi               numeric(15,2),
  created_at            timestamp DEFAULT now(),
  updated_at            timestamp DEFAULT now(),
  CONSTRAINT chk_qc_trangthai CHECK (trang_thai_khach_hang IN ('MOI','DANG_LIEN_HE','DA_DANG_KY','HUY_DANG_KY','ERROR_MISSING_INFO')),
  CONSTRAINT chk_qc_chiphi CHECK (chi_phi IS NULL OR chi_phi >= 0),
  CONSTRAINT chk_qc_link_inbox CHECK (link_inbox IS NULL OR link_inbox ~* '^https?://'),
  CONSTRAINT chk_qc_email CHECK (email IS NULL OR email ~ '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]+$'),
  CONSTRAINT chk_qc_sdt CHECK (
    (so_dien_thoai IS NOT NULL AND so_dien_thoai ~ '^(03|05|07|08|09)[0-9]{8}$')
    OR (so_dien_thoai IS NULL AND trang_thai_khach_hang = 'ERROR_MISSING_INFO'))
);
CREATE INDEX idx_quangcao_thisinh ON quangcao(thi_sinh_id);
CREATE INDEX idx_quangcao_chiendich ON quangcao(chien_dich);
CREATE INDEX idx_quangcao_bieumau ON quangcao(bieu_mau_log);
CREATE INDEX idx_quangcao_sdt ON quangcao(so_dien_thoai);

CREATE TABLE dangkyweb (
  thanh_toan_id         varchar(30) PRIMARY KEY,
  thi_sinh_id           varchar(20) REFERENCES thisinh(thi_sinh_id),
  thoi_gian_thanh_toan  timestamp NOT NULL,
  bang_dau              varchar(30) NOT NULL,
  ho_ten                varchar(100) NOT NULL,
  sdt                   varchar(10) NOT NULL,
  email                 varchar(254) NOT NULL,
  tinh_thanh            varchar(100),
  truong_hoc            varchar(200),
  so_tien               numeric(15,2) NOT NULL,
  doi_tac               varchar(100),
  doanh_nghiep_id       varchar(20) REFERENCES doanhnghiep(doanh_nghiep_id),
  trang_thai_thanh_toan varchar(30) NOT NULL DEFAULT 'CHO_THANH_TOAN',
  giao_dich_id          varchar(100) NOT NULL UNIQUE,
  ghi_chu               varchar(500),
  hoa_hong              numeric(15,2),
  created_at            timestamp DEFAULT now(),
  updated_at            timestamp DEFAULT now(),
  CONSTRAINT chk_dkw_bangdau CHECK (bang_dau IN ('BANG_A','BANG_B')),
  CONSTRAINT chk_dkw_sotien CHECK (so_tien >= 0),
  CONSTRAINT chk_dkw_hoahong CHECK (hoa_hong IS NULL OR hoa_hong >= 0),
  CONSTRAINT chk_dkw_trangthai CHECK (trang_thai_thanh_toan IN ('CHO_THANH_TOAN','THANH_TOAN_THANH_CONG','THAT_BAI','HUY_GIAO_DICH')),
  CONSTRAINT chk_dangkyweb_doitac CHECK (NOT (doi_tac IS NOT NULL AND doanh_nghiep_id IS NOT NULL)),
  CONSTRAINT chk_dkw_email CHECK (email ~ '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]+$'),
  CONSTRAINT chk_dkw_sdt CHECK (sdt ~ '^(03|05|07|08|09)[0-9]{8}$')
);
CREATE INDEX idx_dangkyweb_thisinh ON dangkyweb(thi_sinh_id);
CREATE INDEX idx_dangkyweb_sdt ON dangkyweb(sdt);
CREATE INDEX idx_dangkyweb_email ON dangkyweb(email);
CREATE INDEX idx_dangkyweb_doanhnghiep ON dangkyweb(doanh_nghiep_id);

/* ================ 7. RBAC ================ */
CREATE TABLE vaitro (
  role_id     varchar(30) PRIMARY KEY,
  ten_vai_tro varchar(100) NOT NULL,
  mo_ta       varchar(255) NOT NULL,
  trang_thai  varchar(20) NOT NULL DEFAULT 'DANG_AP_DUNG',
  ngay_tao    timestamp DEFAULT now(),
  CONSTRAINT chk_vt_trangthai CHECK (trang_thai IN ('DANG_AP_DUNG','TAM_KHOA')),
  CONSTRAINT chk_vt_role CHECK (role_id IN ('ADMIN','MANAGER','SALE_STAFF','SUPPORT_STAFF'))
);
CREATE TABLE quyen (
  permission_id  varchar(50) PRIMARY KEY,
  ten_quyen      varchar(100) NOT NULL,
  nhom_chuc_nang varchar(50) NOT NULL,
  mo_ta          varchar(255)
);
CREATE TABLE vaitro_quyen (
  role_id       varchar(30) NOT NULL REFERENCES vaitro(role_id) ON DELETE CASCADE,
  permission_id varchar(50) NOT NULL REFERENCES quyen(permission_id) ON DELETE CASCADE,
  ngay_gan      timestamp NOT NULL DEFAULT now(),
  PRIMARY KEY (role_id, permission_id)
);
CREATE TABLE nhanvien_vaitro_ct (
  nhan_vien_id varchar(20) NOT NULL REFERENCES nhanvien(nhan_vien_id) ON DELETE CASCADE,
  role_id      varchar(30) NOT NULL REFERENCES vaitro(role_id) ON DELETE CASCADE,
  ngay_gan     timestamp NOT NULL DEFAULT now(),
  nguoi_gan    varchar(20) REFERENCES nhanvien(nhan_vien_id),
  PRIMARY KEY (nhan_vien_id, role_id)
);
CREATE TABLE log_dangnhap (
  log_dn_id    bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  nhan_vien_id varchar(20) NOT NULL REFERENCES nhanvien(nhan_vien_id),
  thoi_gian_dn timestamp NOT NULL DEFAULT now(),
  ip_address   varchar(45),
  user_agent   varchar(255),
  trang_thai   varchar(20) NOT NULL,
  ghi_chu      varchar(255),
  CONSTRAINT chk_ldn_trangthai CHECK (trang_thai IN ('THANH_CONG','THAT_BAI'))
);

/* ================ 8. AUDIT ================ */
CREATE TABLE audit_log (
  audit_log_id       bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  thoi_gian          timestamp(0) NOT NULL DEFAULT now(),
  nguoi_thuc_hien_id varchar(20) REFERENCES nhanvien(nhan_vien_id),
  nguoi_thuc_hien    varchar(100),
  actor_role_id      varchar(30) REFERENCES vaitro(role_id),
  vai_tro            varchar(100),
  dia_chi_ip         varchar(45),
  ten_bang           varchar(100) NOT NULL,
  id_ban_ghi         varchar(100),
  hanh_dong          varchar(20) NOT NULL,
  du_lieu_cu         text,
  du_lieu_moi        text,
  ghi_chu            varchar(500),
  CONSTRAINT ck_audit_log_hanh_dong CHECK (hanh_dong IN ('DANG_KY','DANG_NHAP','DANG_XUAT','THEM','SUA','XOA','IMPORT'))
);
CREATE INDEX ix_audit_log_thoi_gian ON audit_log(thoi_gian);
CREATE INDEX ix_audit_log_nguoi ON audit_log(nguoi_thuc_hien_id);
CREATE INDEX ix_audit_log_hanh_dong ON audit_log(hanh_dong);
CREATE INDEX ix_audit_log_bang ON audit_log(ten_bang, id_ban_ghi);

CREATE TABLE audit_log_archive (
  audit_log_id       bigint PRIMARY KEY,
  thoi_gian          timestamp(0) NOT NULL,
  nguoi_thuc_hien_id varchar(20),
  nguoi_thuc_hien    varchar(100),
  actor_role_id      varchar(30),
  vai_tro            varchar(100),
  dia_chi_ip         varchar(45),
  ten_bang           varchar(100) NOT NULL,
  id_ban_ghi         varchar(100),
  hanh_dong          varchar(20) NOT NULL,
  du_lieu_cu         text,
  du_lieu_moi        text,
  ghi_chu            varchar(500),
  CONSTRAINT ck_audit_archive_hanh_dong CHECK (hanh_dong IN ('DANG_KY','DANG_NHAP','DANG_XUAT','THEM','SUA','XOA','IMPORT'))
);
CREATE INDEX ix_audit_archive_thoigian ON audit_log_archive(thoi_gian);

/* ================ 9. BỔ SUNG: nhật ký, KPI, pipeline ================ */
CREATE TABLE nhatky_hanhdong (
  nhat_ky_id          bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  nhan_vien_id        varchar(20) NOT NULL REFERENCES nhanvien(nhan_vien_id),
  hanh_dong           varchar(255) NOT NULL,
  doi_tuong_anh_huong varchar(100),
  thoi_gian           timestamp NOT NULL DEFAULT now(),
  trang_thai          varchar(20) NOT NULL DEFAULT 'THANH_CONG',
  CONSTRAINT chk_nkhd_trangthai CHECK (trang_thai IN ('THANH_CONG','THAT_BAI','CANH_BAO'))
);
CREATE TABLE kpi_muctieu (
  kpi_id      varchar(20) PRIMARY KEY,
  ky_bao_cao  varchar(20) NOT NULL,
  nhom        varchar(30) NOT NULL,
  ten_kpi     varchar(200) NOT NULL,
  muc_tieu    numeric(18,2) NOT NULL,
  CONSTRAINT chk_kpi_nhom CHECK (nhom IN ('THI_SINH','DOANH_NGHIEP','DOANH_THU')),
  CONSTRAINT chk_kpi_ky CHECK (ky_bao_cao ~ '^[0-9]{4}-Q[1-4]$'),
  CONSTRAINT chk_kpi_muctieu CHECK (muc_tieu >= 0),
  CONSTRAINT uq_kpi UNIQUE (ky_bao_cao, nhom, ten_kpi)
);
CREATE TABLE truyenthong_taitro (
  tt_id           bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  doanh_nghiep_id varchar(20) NOT NULL REFERENCES doanhnghiep(doanh_nghiep_id),
  ngay            date NOT NULL,
  luot_hien_thi   bigint NOT NULL DEFAULT 0 CHECK (luot_hien_thi >= 0),
  luot_tuong_tac  bigint NOT NULL DEFAULT 0 CHECK (luot_tuong_tac >= 0),
  kenh            varchar(100)
);
CREATE TABLE doanhnghiep_pipeline (
  pipeline_id     bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  doanh_nghiep_id varchar(20) NOT NULL REFERENCES doanhnghiep(doanh_nghiep_id),
  giai_doan       varchar(30) NOT NULL CHECK (giai_doan IN ('TIEP_CAN','DAM_PHAN','DE_XUAT_GUI','KY_HOP_DONG','THUC_THU')),
  so_tien         numeric(15,2) NOT NULL DEFAULT 0 CHECK (so_tien >= 0),
  thoi_gian       timestamp NOT NULL DEFAULT now(),
  nhan_vien_id    varchar(20) REFERENCES nhanvien(nhan_vien_id)
);
CREATE INDEX idx_pipeline_dn ON doanhnghiep_pipeline(doanh_nghiep_id, giai_doan);

/* ================ 10. IMPORT DỮ LIỆU ================ */
CREATE TABLE dm_ma_loi_import (
  ma_loi varchar(50) PRIMARY KEY,
  mo_ta  varchar(255) NOT NULL,
  muc_do varchar(20) NOT NULL DEFAULT 'LOI' CHECK (muc_do IN ('LOI','CANH_BAO'))
);
CREATE TABLE audit_log_import (
  import_id          bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  nhan_vien_id       varchar(20) REFERENCES nhanvien(nhan_vien_id),
  ten_bang_dich      varchar(100) NOT NULL,
  ten_file           varchar(255),
  thoi_gian_bat_dau  timestamp NOT NULL DEFAULT now(),
  thoi_gian_ket_thuc timestamp,
  tong_so_dong       int NOT NULL DEFAULT 0,
  so_dong_thanh_cong int NOT NULL DEFAULT 0,
  so_dong_loi        int NOT NULL DEFAULT 0,
  trang_thai         varchar(20) NOT NULL DEFAULT 'DANG_XU_LY',
  dia_chi_ip         varchar(45),
  ghi_chu            varchar(1000),
  CONSTRAINT ck_ali_trangthai CHECK (trang_thai IN ('DANG_XU_LY','THANH_CONG','HOAN_TAT_CO_LOI','THAT_BAI')),
  CONSTRAINT ck_ali_soluong CHECK (tong_so_dong >= 0 AND so_dong_thanh_cong >= 0 AND so_dong_loi >= 0),
  CONSTRAINT ck_ali_tong_hople CHECK (trang_thai = 'DANG_XU_LY' OR so_dong_thanh_cong + so_dong_loi <= tong_so_dong),
  CONSTRAINT ck_ali_thoigian CHECK (thoi_gian_ket_thuc IS NULL OR thoi_gian_ket_thuc >= thoi_gian_bat_dau)
);
CREATE INDEX ix_ali_nguoi ON audit_log_import(nhan_vien_id);
CREATE INDEX ix_ali_bangdich ON audit_log_import(ten_bang_dich);

CREATE TABLE audit_log_import_chitiet (
  chi_tiet_id    bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  import_id      bigint NOT NULL REFERENCES audit_log_import(import_id) ON DELETE CASCADE,
  so_dong        int NOT NULL CHECK (so_dong >= 1),
  ket_qua        varchar(20) NOT NULL DEFAULT 'LOI' CHECK (ket_qua IN ('THANH_CONG','LOI','BO_QUA')),
  du_lieu_dong   text,
  cot_loi        varchar(100),
  vi_tri_loi     varchar(200),
  ma_loi         varchar(50) REFERENCES dm_ma_loi_import(ma_loi),
  thong_diep_loi varchar(1000),
  thoi_gian_loi  timestamp DEFAULT now()
);
CREATE INDEX ix_alic_import ON audit_log_import_chitiet(import_id, so_dong);

