# Bộ SQL cài đặt mới

Các file trong thư mục này gộp nội dung từ `supabase/migrations` thành 7 phần,
để dễ cài đặt theo thứ tự trên một cơ sở dữ liệu Supabase mới:

1. `01_schema.sql` — bảng, kiểu dữ liệu và chỉ mục.
2. `02_triggers_audit.sql` — trigger và nhật ký.
3. `03_crud_reporting.sql` — hàm CRUD và báo cáo.
4. `04_kpi_rbac_dashboard.sql` — KPI, phân quyền và truy cập dashboard.
5. `05_public_access.sql` — các quyền truy cập công khai.
6. `06_partner_access.sql` — phân quyền doanh nghiệp/đối tác và báo cáo.
7. `07_reporting_extensions.sql` — bổ sung báo cáo, lưu trữ tài liệu và cập nhật KPI.

Chạy lần lượt từ `01` đến `07`. Các file gốc trong `supabase/migrations` được giữ
nguyên để bảo toàn lịch sử và đối chiếu nguồn.

Các lệnh `INSERT` nạp dữ liệu ban đầu đã được bỏ khỏi bộ cài này theo yêu cầu
(cấu hình hệ thống, vai trò/quyền, danh mục mã lỗi, backfill vai trò nhân viên,
danh mục tỉnh/thành và cấu hình bucket lưu trữ). Chỉ chạy bộ này khi các dữ liệu
đó đã có trong database. Các lệnh `INSERT` bên trong function/trigger vẫn được
giữ lại vì là thao tác nghiệp vụ của ứng dụng.

`00_reset_database.sql` là tùy chọn và **không nằm trong quy trình cài đặt thông
thường**. Chỉ chạy thủ công trước `01_schema.sql` nếu thực sự muốn xóa các view,
materialized view, bảng và hàm không thuộc extension trong schema `public`.
Lệnh này xóa dữ liệu bảng; `CASCADE` có thể xóa thêm object phụ thuộc. Hãy sao
lưu trước khi chạy. Nó không xóa toàn bộ database (ví dụ: không xóa standalone
sequence, custom type hay schema khác).

**Chỉ dùng bộ này để cài đặt cơ sở dữ liệu mới.** Nếu Supabase đã có dữ liệu hoặc
đã chạy một phần migration, không chạy lại các bundle này; hãy đối chiếu lịch sử
migration và chỉ áp dụng những thay đổi còn thiếu.

Lưu ý: `05_public_access.sql` giữ nguyên các quyền công khai có trong migration
gốc, bao gồm quyền đọc bảng và thực thi hàm cho `anon`. Hãy xem lại phạm vi quyền
này trước khi dùng cho môi trường production.
