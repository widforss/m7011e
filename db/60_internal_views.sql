CREATE OR REPLACE VIEW interface.Account AS
SELECT DISTINCT ON
    (Account._id) Account._id,
                  Account._id_public,
                  Properties.email,
                  ARRAY [ postgis.ST_X(Settings.geom),
                      postgis.ST_Y(Settings.geom)]::INT[2] AS coordinates,
                  Account.logDate                          AS creationDate,
                  Manager.manager,
                  CASE
                      WHEN Properties.blocked > NOW()
                          THEN EXTRACT(EPOCH FROM Properties.blocked - NOW())
                      ELSE 0
                      END                                  AS blocked,
                  Properties.active,
                  Properties.gdpr,
                  Data.consumption,
                  Data.production,
                  Data.buffer,
                  Data.blackout,
                  Data.logDate                             AS dataDate,
                  Settings.toBuffer,
                  Settings.fromBuffer,
                  '/api/avatar/' || Avatar._id_public      AS avatarUrl
FROM account.Account
         INNER JOIN account.Manager
                    ON Account._id = Manager._accountId
         INNER JOIN account.Properties
                    ON Account._id = Properties._accountId
         INNER JOIN account.Settings
                    ON Account._id = Settings._accountId
         INNER JOIN account.Data
                    ON Account._id = Data._accountId
         LEFT JOIN account.Avatar
                   ON Account._id = Avatar._accountId
ORDER BY Account._id,
         Manager.logDate DESC,
         Properties.logDate DESC,
         Settings.logDate DESC,
         Data.logDate DESC,
         Avatar.logDate DESC;

CREATE OR REPLACE VIEW interface.AccountSession AS
SELECT DISTINCT ON (Session._id_public) Session._id,
                                        Session._id_public,
                                        Session._accountId,
                                        SessionProperties.active AND
                                        Account.active AND
                                        Account.gdpr              AS active,
                                        Session.logdate           AS creationDate,
                                        SessionProperties.logdate AS lastEditDate
FROM Account.Session
         INNER JOIN Account.SessionProperties
                    ON Session._id = SessionProperties._sessionId
         INNER JOIN interface.Account
                    ON Account._id = Session._accountId
ORDER BY Session._id_public,
         SessionProperties.logDate DESC;

CREATE OR REPLACE VIEW interface.AccountCode AS
SELECT CodeCall._id,
       CodeCall._id_public,
       Code._id                            AS _codeId,
       Code._id_public                     AS _codeId_public,
       Code.email,
       Code.code,
       CodeCall.logDate                    AS creationDate,
       Code.logDate                        AS validFromDate,
       Code.logDate + INTERVAL '10' MINUTE AS deprecateDate,
       Code.logDate + INTERVAL '15' MINUTE AS expireDate
FROM account.Code
         INNER JOIN account.CodeCall
                    ON Code._id = CodeCall._codeId;

CREATE OR REPLACE VIEW interface.AccountCodeCheck AS
SELECT *
FROM account.CodeCheck;

CREATE OR REPLACE VIEW interface.Price AS
SELECT Price.price,
       Price.byUser,
       Price.logDate AS lastEditDate
FROM price.Price
ORDER BY logDate DESC
LIMIT 1;

CREATE OR REPLACE VIEW interface.Coal AS
SELECT Settings.start,
       Settings.produce,
       Settings.toBuffer,
       Settings.fromBuffer,
       Data.status,
       Data.buffer
FROM coal.Settings
         LEFT JOIN coal.Data ON TRUE
ORDER BY Settings.logDate DESC,
         Data.logDate DESC
LIMIT 1;