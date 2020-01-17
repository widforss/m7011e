CREATE OR REPLACE VIEW public.Account AS
SELECT _id_public,
       email,
       coordinates,
       creationDate,
       blocked,
       active,
       gdpr,
       manager,
       consumption,
       production,
       buffer,
       blackout,
       toBuffer,
       fromBuffer,
       dataDate,
       avatarUrl
FROM interface.Account
WHERE Account.active
  AND Account.gdpr
ORDER BY Account._id_public;
GRANT SELECT ON public.Account TO PUBLIC;

CREATE OR REPLACE VIEW public.Price AS
SELECT price,
       lastEditDate
FROM interface.Price;
GRANT SELECT ON public.Price TO PUBLIC;

CREATE OR REPLACE VIEW public.Coal AS
SELECT start,
       produce,
       toBuffer,
       fromBuffer,
       CASE
           WHEN status IS NULL THEN 'stopped'
           WHEN status < NOW() THEN 'started'
           ELSE 'starting' END AS status,
       CASE
           WHEN status < NOW() THEN produce
           ELSE 0 END AS production,
       buffer
FROM interface.Coal
GRANT SELECT ON public.Coal TO PUBLIC;
