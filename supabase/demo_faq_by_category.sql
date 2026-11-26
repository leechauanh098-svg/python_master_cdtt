-- Demo FAQ content for the eight categories shown with no approved questions.
-- Answers direct users to current official information; do not treat these as competition policy.
DO $$
DECLARE
  v_reviewer varchar(20);
BEGIN
  SELECT nhan_vien_id
  INTO v_reviewer
  FROM public.nhanvien
  WHERE trang_thai = 'ACTIVE'
  ORDER BY
    CASE
      WHEN phan_quyen = 'SUPPORT_STAFF' THEN 0
      WHEN phan_quyen IN ('ADMIN', 'MANAGER') THEN 1
      ELSE 2
    END,
    nhan_vien_id
  LIMIT 1;

  IF v_reviewer IS NULL THEN
    RAISE EXCEPTION 'Không tìm thấy nhân viên ACTIVE để gán người duyệt FAQ demo.';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM (VALUES
      ('Quy chế cuộc thi'),
      ('Đăng ký và lệ phí'),
      ('Lịch thi và hình thức thi'),
      ('Ôn tập và đề thi mẫu'),
      ('Hỗ trợ kỹ thuật'),
      ('Tài trợ và đối tác'),
      ('Chứng chỉ và bảng xếp hạng'),
      ('Sự kiện và talkshow')
    ) AS target_categories(category)
    WHERE NOT EXISTS (
      SELECT 1
      FROM public.danhmuc d
      WHERE d.ten_danh_muc = target_categories.category
    )
  ) THEN
    RAISE EXCEPTION 'Thiếu một hoặc nhiều danh mục FAQ mục tiêu; kiểm tra tên danh mục trước khi import.';
  END IF;

  INSERT INTO public.faq_canonical (
    faq_id,
    danh_muc,
    cau_hoi_chuan,
    cau_tra_loi_chuan,
    trang_thai,
    duyet_boi
  )
  SELECT
    qa.faq_id,
    qa.category,
    qa.question,
    qa.answer,
    'DA_DUYET',
    v_reviewer
  FROM (VALUES
    (
      'DEMOFAQ001',
      'Quy chế cuộc thi',
      'Có thể xem thể lệ và quy chế cuộc thi ở đâu?',
      'Thể lệ, điều kiện tham gia, cách tính điểm và quy định của mùa thi được đăng trong mục thông báo chính thức của Ban tổ chức. Vui lòng xem phiên bản mới nhất trên website; nếu cần giải thích thêm, hãy liên hệ kênh hỗ trợ chính thức.'
    ),
    (
      'DEMOFAQ002',
      'Đăng ký và lệ phí',
      'Đăng ký dự thi như thế nào?',
      'Bạn điền biểu mẫu đăng ký trên website và làm theo hướng dẫn hiển thị để hoàn tất hồ sơ. Hạn đăng ký, điều kiện dự thi và các bước tiếp theo có thể thay đổi theo mùa thi, vì vậy hãy kiểm tra thông báo chính thức và lưu lại mã đăng ký.'
    ),
    (
      'DEMOFAQ003',
      'Lịch thi và hình thức thi',
      'Làm sao để biết lịch thi và hình thức thi của từng vòng?',
      'Lịch, hình thức và hướng dẫn tham gia từng vòng được Ban tổ chức công bố qua website và kênh liên hệ đã đăng ký. Hãy kiểm tra thông báo mới nhất trước ngày thi; nếu chưa nhận được thông tin, liên hệ bộ phận hỗ trợ với mã đăng ký của bạn.'
    ),
    (
      'DEMOFAQ004',
      'Ôn tập và đề thi mẫu',
      'Tài liệu ôn tập và đề thi mẫu được đăng ở đâu?',
      'Tài liệu ôn tập và đề mẫu (nếu có) được đăng trong mục tài liệu chính thức của cuộc thi. Hãy đối chiếu với nội dung áp dụng cho mùa thi hiện tại; đề mẫu chỉ giúp làm quen định dạng và không đảm bảo câu hỏi thi thật sẽ giống đề mẫu.'
    ),
    (
      'DEMOFAQ005',
      'Hỗ trợ kỹ thuật',
      'Tôi cần làm gì khi gặp lỗi kỹ thuật trong lúc dự thi?',
      'Hãy ghi lại thời điểm xảy ra lỗi, chụp ảnh màn hình nếu có thể và liên hệ kênh hỗ trợ chính thức ngay khi thuận tiện. Cung cấp mã thí sinh cùng thông tin thiết bị/trình duyệt; không gửi mật khẩu hoặc mã xác thực cho bất kỳ ai.'
    ),
    (
      'DEMOFAQ006',
      'Tài trợ và đối tác',
      'Doanh nghiệp muốn đồng hành hoặc tài trợ cuộc thi thì liên hệ thế nào?',
      'Doanh nghiệp vui lòng liên hệ Ban tổ chức qua kênh đối tác được công bố chính thức để trao đổi về hình thức đồng hành, quyền lợi và hồ sơ liên quan. Các điều khoản chỉ được xác nhận theo văn bản/thỏa thuận chính thức của hai bên.'
    ),
    (
      'DEMOFAQ007',
      'Chứng chỉ và bảng xếp hạng',
      'Khi nào có chứng chỉ và bảng xếp hạng?',
      'Điều kiện cấp chứng chỉ, cách xác nhận kết quả và thời điểm công bố bảng xếp hạng được quy định trong thông báo chính thức của từng mùa thi. Hãy theo dõi website hoặc tài khoản dự thi để xem kết quả đã được Ban tổ chức xác nhận.'
    ),
    (
      'DEMOFAQ008',
      'Sự kiện và talkshow',
      'Đăng ký tham gia sự kiện hoặc talkshow của cuộc thi ở đâu?',
      'Thông tin chương trình, điều kiện tham gia và đường dẫn đăng ký (nếu cần) được đăng trong thông báo sự kiện chính thức. Hãy kiểm tra thời hạn đăng ký và làm theo hướng dẫn của từng chương trình.'
    )
  ) AS qa(faq_id, category, question, answer)
  WHERE NOT EXISTS (
    SELECT 1
    FROM public.faq_canonical f
    WHERE f.danh_muc = qa.category
      AND f.trang_thai = 'DA_DUYET'
  )
  ON CONFLICT (faq_id) DO NOTHING;
END;
$$;

SELECT
  d.ten_danh_muc,
  count(f.faq_id) FILTER (WHERE f.trang_thai = 'DA_DUYET') AS so_cau_hoi_da_duyet
FROM public.danhmuc d
LEFT JOIN public.faq_canonical f ON f.danh_muc = d.ten_danh_muc
WHERE d.ten_danh_muc IN (
  'Quy chế cuộc thi',
  'Đăng ký và lệ phí',
  'Lịch thi và hình thức thi',
  'Ôn tập và đề thi mẫu',
  'Hỗ trợ kỹ thuật',
  'Tài trợ và đối tác',
  'Chứng chỉ và bảng xếp hạng',
  'Sự kiện và talkshow'
)
GROUP BY d.ten_danh_muc
ORDER BY d.ten_danh_muc;
