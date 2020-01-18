CREATE OR REPLACE VIEW public.Coal AS
SELECT start,
       produce,
       CASE WHEN buffer >= 70000 AND production > Demand.demand THEN 0
            WHEN buffer <= 0 AND production < Demand.demand THEN 0
            WHEN production > Demand.demand THEN (production - Demand.demand) * tobuffer
            WHEN production < Demand.demand THEN (production - Demand.demand) * fromBuffer
            ELSE 0 END AS bufferUse,
       toBuffer,
       fromBuffer,
       CASE
           WHEN status IS NULL THEN 'stopped'
           WHEN status < NOW() THEN 'started'
           ELSE 'starting' END AS status,
       CASE
           WHEN status < NOW() THEN produce
           ELSE 0 END AS production,
       buffer,
       normalDemand
FROM interface.Coal
JOIN (
    SELECT
        SUM(consumption - production + bufferUse) AS demand
    FROM interface.Account
    WHERE NOT manager
) AS Demand ON TRUE;;
GRANT SELECT ON public.Coal TO PUBLIC;

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
       Account.production,
       Account.buffer,
       CASE WHEN Demand.demand > coal.production - coal.bufferUse THEN
           consumption > Account.production - Account.bufferUse
           ELSE FALSE END AS blackout,
       Account.bufferUse,
       Account.toBuffer,
       Account.fromBuffer,
       dataDate,
       avatarUrl
FROM interface.Account
JOIN (
    SELECT
           SUM(consumption - production + bufferUse) AS demand
    FROM interface.Account
    WHERE NOT manager
    ) AS Demand ON TRUE
JOIN public.coal ON TRUE
WHERE Account.active
  AND Account.gdpr
ORDER BY Account._id_public;
GRANT SELECT ON public.Account TO PUBLIC;

CREATE OR REPLACE VIEW public.Price AS
SELECT price,
       lastEditDate
FROM interface.Price;
GRANT SELECT ON public.Price TO PUBLIC;
