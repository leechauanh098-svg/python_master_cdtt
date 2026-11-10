ALTER TABLE public.doanhnghiep
  ADD COLUMN IF NOT EXISTS auth_user_id uuid;

CREATE UNIQUE INDEX IF NOT EXISTS uq_doanhnghiep_auth_user_id
  ON public.doanhnghiep (auth_user_id)
  WHERE auth_user_id IS NOT NULL;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_catalog.pg_constraint
    WHERE conrelid = 'public.doanhnghiep'::regclass
      AND conname = 'fk_doanhnghiep_auth_user'
  ) THEN
    ALTER TABLE public.doanhnghiep
      ADD CONSTRAINT fk_doanhnghiep_auth_user
      FOREIGN KEY (auth_user_id) REFERENCES auth.users(id) ON DELETE SET NULL;
  END IF;
END;
$$;

COMMENT ON COLUMN public.doanhnghiep.auth_user_id IS
  'Supabase Auth UID assigned by an administrator; one Auth account can map to only one company.';

CREATE OR REPLACE FUNCTION public.fn_current_user_is_active_employee()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, public, auth, pg_temp
AS $$
  SELECT auth.uid() IS NOT NULL
    AND EXISTS (
      SELECT 1
      FROM public.nhanvien nv
      WHERE nv.trang_thai = 'ACTIVE'
        AND (
          nv.user_id = auth.uid()
          OR (
            auth.jwt() ->> 'email' IS NOT NULL
            AND lower(nv.email) = lower(auth.jwt() ->> 'email')
          )
        )
    )
$$;

CREATE OR REPLACE FUNCTION public.fn_current_partner_company_id()
RETURNS varchar
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, public, auth, pg_temp
AS $$
  SELECT dn.doanh_nghiep_id
  FROM public.doanhnghiep dn
  WHERE auth.uid() IS NOT NULL
    AND NOT public.fn_current_user_is_active_employee()
    AND dn.auth_user_id = auth.uid()
$$;

CREATE OR REPLACE FUNCTION public.fn_guard_partner_employee_mapping()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, auth, pg_temp
AS $$
BEGIN
  IF NEW.auth_user_id IS NOT NULL AND EXISTS (
    SELECT 1
    FROM public.nhanvien nv
    LEFT JOIN auth.users au ON au.id = NEW.auth_user_id
    WHERE nv.trang_thai = 'ACTIVE'
      AND (
        nv.user_id = NEW.auth_user_id
        OR (au.email IS NOT NULL AND lower(nv.email) = lower(au.email))
      )
  ) THEN
    RAISE EXCEPTION 'Không thể liên kết tài khoản nhân viên với tài khoản đối tác.';
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_guard_partner_employee_mapping ON public.doanhnghiep;
CREATE TRIGGER trg_guard_partner_employee_mapping
  BEFORE INSERT OR UPDATE OF auth_user_id ON public.doanhnghiep
  FOR EACH ROW EXECUTE FUNCTION public.fn_guard_partner_employee_mapping();

REVOKE ALL ON FUNCTION public.fn_current_user_is_active_employee() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_current_user_is_active_employee() TO authenticated;
REVOKE ALL ON FUNCTION public.fn_current_partner_company_id() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_current_partner_company_id() TO authenticated;
REVOKE ALL ON FUNCTION public.fn_guard_partner_employee_mapping() FROM PUBLIC, anon, authenticated;

DO $$
DECLARE
  relation record;
BEGIN
  FOR relation IN
    SELECT c.relname
    FROM pg_catalog.pg_class c
    JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname = 'public'
      AND c.relkind IN ('r', 'p')
  LOOP
    EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY', relation.relname);
    EXECUTE format('DROP POLICY IF EXISTS auth_employee_access ON public.%I', relation.relname);
    EXECUTE format(
      'CREATE POLICY auth_employee_access ON public.%I FOR ALL TO authenticated USING (public.fn_current_user_is_active_employee()) WITH CHECK (public.fn_current_user_is_active_employee())',
      relation.relname
    );
    EXECUTE format('DROP POLICY IF EXISTS anon_existing_read ON public.%I', relation.relname);
    EXECUTE format(
      'CREATE POLICY anon_existing_read ON public.%I FOR SELECT TO anon USING (true)',
      relation.relname
    );
  END LOOP;
END;
$$;

CREATE POLICY partner_company_read ON public.doanhnghiep
  FOR SELECT TO authenticated
  USING (auth_user_id = auth.uid() AND NOT public.fn_current_user_is_active_employee());

CREATE POLICY partner_referrals_read ON public.dangkyweb
  FOR SELECT TO authenticated
  USING (doanh_nghiep_id = public.fn_current_partner_company_id());

CREATE POLICY partner_sponsorship_pipeline_read ON public.doanhnghiep_pipeline
  FOR SELECT TO authenticated
  USING (doanh_nghiep_id = public.fn_current_partner_company_id());

CREATE POLICY partner_sponsorship_reach_read ON public.truyenthong_taitro
  FOR SELECT TO authenticated
  USING (doanh_nghiep_id = public.fn_current_partner_company_id());

CREATE POLICY partner_company_qna_read ON public.qna
  FOR SELECT TO authenticated
  USING (doanh_nghiep_id = public.fn_current_partner_company_id());

CREATE POLICY partner_company_qna_feedback_read ON public.qna_phanhoi
  FOR SELECT TO authenticated
  USING (
    doanh_nghiep_id = public.fn_current_partner_company_id()
    AND EXISTS (
      SELECT 1
      FROM public.qna q
      WHERE q.qna_id = qna_phanhoi.qna_id
        AND q.doanh_nghiep_id = public.fn_current_partner_company_id()
    )
  );

-- Invoker views keep the caller's row-level policies in force.
DO $$
DECLARE
  relation record;
BEGIN
  FOR relation IN
    SELECT c.relname
    FROM pg_catalog.pg_class c
    JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname = 'public'
      AND c.relkind = 'v'
  LOOP
    EXECUTE format('ALTER VIEW public.%I SET (security_invoker = true)', relation.relname);
  END LOOP;
END;
$$;

CREATE OR REPLACE FUNCTION public.fn_partner_portal_overview()
RETURNS TABLE (
  ten_doanh_nghiep varchar,
  ma_so_thue varchar,
  dia_chi varchar,
  email_lien_he varchar,
  sdt_lien_he varchar,
  hinh_thuc varchar,
  loai_tai_tro varchar,
  cap_do_tai_tro varchar,
  so_luong_thi_sinh bigint,
  tong_le_phi_thu_duoc numeric,
  hoa_hong_phai_tra numeric,
  thuc_thu_tai_tro numeric,
  luot_hien_thi bigint,
  luot_tuong_tac bigint
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, public, auth, pg_temp
AS $$
  SELECT dn.ten_doanh_nghiep, dn.ma_so_thue, dn.dia_chi, dn.email_lien_he,
         dn.sdt_lien_he, dn.hinh_thuc, dn.loai_tai_tro, dn.cap_do_tai_tro,
         referrals.so_luong_thi_sinh, referrals.tong_le_phi_thu_duoc,
         referrals.hoa_hong_phai_tra, sponsorship.thuc_thu_tai_tro,
         reach.luot_hien_thi, reach.luot_tuong_tac
  FROM public.doanhnghiep dn
  CROSS JOIN LATERAL (
    SELECT count(dkw.thanh_toan_id)::bigint AS so_luong_thi_sinh,
           COALESCE(sum(dkw.so_tien) FILTER (
             WHERE dkw.trang_thai_thanh_toan = 'THANH_TOAN_THANH_CONG'
           ), 0)::numeric AS tong_le_phi_thu_duoc,
           COALESCE(sum(COALESCE(dkw.hoa_hong, dkw.so_tien * public.fn_ty_le_hoa_hong()))
             FILTER (WHERE dkw.trang_thai_thanh_toan = 'THANH_TOAN_THANH_CONG'), 0)::numeric
             AS hoa_hong_phai_tra
    FROM public.dangkyweb dkw
    WHERE dkw.doanh_nghiep_id = dn.doanh_nghiep_id
  ) referrals
  CROSS JOIN LATERAL (
    SELECT COALESCE(sum(p.so_tien), 0)::numeric AS thuc_thu_tai_tro
    FROM public.doanhnghiep_pipeline p
    WHERE p.doanh_nghiep_id = dn.doanh_nghiep_id
      AND p.giai_doan = 'THUC_THU'
  ) sponsorship
  CROSS JOIN LATERAL (
    SELECT COALESCE(sum(t.luot_hien_thi), 0)::bigint AS luot_hien_thi,
           COALESCE(sum(t.luot_tuong_tac), 0)::bigint AS luot_tuong_tac
    FROM public.truyenthong_taitro t
    WHERE t.doanh_nghiep_id = dn.doanh_nghiep_id
  ) reach
  WHERE auth.uid() IS NOT NULL
    AND NOT public.fn_current_user_is_active_employee()
    AND dn.auth_user_id = auth.uid()
$$;

REVOKE ALL ON FUNCTION public.fn_partner_portal_overview() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.fn_partner_portal_overview() TO authenticated;

NOTIFY pgrst, 'reload schema';
