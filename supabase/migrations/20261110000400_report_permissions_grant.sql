REVOKE ALL ON FUNCTION public.fn_current_user_report_permissions() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_current_user_report_permissions() TO authenticated;

REVOKE ALL ON FUNCTION public.fn_bao_cao_du_lieu(character varying, character varying) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_bao_cao_du_lieu(character varying, character varying) TO authenticated;

REVOKE ALL ON FUNCTION public.fn_report_lead_pipeline(character varying) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_report_lead_pipeline(character varying) TO authenticated;

REVOKE ALL ON FUNCTION public.fn_report_revenue_by_region(character varying) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_report_revenue_by_region(character varying) TO authenticated;

REVOKE ALL ON FUNCTION public.fn_report_practice_top15(character varying) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_report_practice_top15(character varying) TO authenticated;

REVOKE ALL ON FUNCTION public.fn_export_school_reconciliation(character varying) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_export_school_reconciliation(character varying) TO authenticated;
