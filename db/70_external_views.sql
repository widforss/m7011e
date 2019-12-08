CREATE OR REPLACE VIEW public.Account AS
SELECT _id_public,
       coordinates,
       toBuffer,
       fromBuffer,
       consumption,
       production,
       buffer,
       dataDate
FROM interface.Account
WHERE Account.active
  AND Account.gdpr
ORDER BY Account._id_public;
GRANT SELECT ON public.Account TO PUBLIC;