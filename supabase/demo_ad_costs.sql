-- Demo estimates only: 50,000 VND per Facebook lead and 40,000 VND per Instagram lead.
-- Do not use these estimates as actual campaign spend.
BEGIN;

UPDATE public.quangcao
SET chi_phi = CASE
  WHEN nen_tang ILIKE '%FACEBOOK%' THEN 50000
  WHEN nen_tang ILIKE '%INSTAGRAM%' THEN 40000
END
WHERE COALESCE(chi_phi, 0) = 0
  AND chien_dich IN (
    '1808 Lead | Uni',
    'PM 0808 | SuperAd test DN -> HN',
    'SuperAd test2',
    'PM 1808 | SuperAds test3',
    '2208| SuperAds 4',
    'PM 0808 | SuperAd test DN -> HCM',
    'Ban khong co du quyen',
    'SuperAd test2 - Copy'
  )
  AND (
    nen_tang ILIKE '%FACEBOOK%'
    OR nen_tang ILIKE '%INSTAGRAM%'
  )
RETURNING quang_cao_log, nen_tang, chien_dich, chi_phi;

COMMIT;
