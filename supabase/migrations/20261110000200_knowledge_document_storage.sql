INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'knowledge-documents',
  'knowledge-documents',
  false,
  52428800,
  ARRAY[
    'application/pdf',
    'application/msword',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'text/plain',
    'text/csv',
    'application/vnd.ms-excel',
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'application/octet-stream'
  ]
)
ON CONFLICT (id) DO UPDATE
SET public = false,
    file_size_limit = EXCLUDED.file_size_limit,
    allowed_mime_types = EXCLUDED.allowed_mime_types;

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
