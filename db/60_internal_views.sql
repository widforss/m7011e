CREATE OR REPLACE VIEW interface.Account AS
SELECT DISTINCT ON
    (Account._id) Account._id,
                  Account._id_public,
                  Properties.email,
                  ARRAY [ postgis.ST_X(Settings.geom),
                      postgis.ST_Y(Settings.geom)]::INT[2] AS coordinates,
                  Account.logDate                          AS creationDate,
                  Properties.active,
                  Properties.gdpr,
                  Data.consumption,
                  Data.production,
                  Data.logDate                             AS dataDate
FROM account.Account
         INNER JOIN account.Properties
                    ON Account._id = Properties._accountId
         INNER JOIN account.Settings
                    ON Account._id = Settings._accountId
         INNER JOIN account.Data
                    ON Account._id = Data._accountId
ORDER BY Account._id,
         Properties.logDate DESC,
         Settings.logDate DESC,
         Data.logDate DESC;

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
