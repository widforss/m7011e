CREATE OR REPLACE FUNCTION public.getAccountCode(email TEXT)
    RETURNS TEXT
AS
$$
DECLARE
    totalCodes_  INT;
    activeCodes_ INT;
    activeAll_   INT;
    activeDay_   INT;
    newCodes_    INT;
    oldCode_     interface.AccountCode%ROWTYPE;
    account_     interface.Account%ROWTYPE;
BEGIN
    SELECT *
    INTO account_
    FROM interface.Account
    WHERE getAccountCode.email = Account.email
    LIMIT 1;

    SELECT COUNT(*)
    INTO totalCodes_
    FROM interface.AccountCode
    WHERE getAccountCode.email = AccountCode.email;

    SELECT COUNT(*)
    INTO activeCodes_
    FROM interface.AccountCode
    WHERE getAccountCode.email = AccountCode.email
      AND AccountCode.expiredate > NOW();

    SELECT COUNT(*)
    INTO activeAll_
    FROM interface.AccountCode
    WHERE AccountCode.expiredate > NOW();

    SELECT COUNT(*)
    INTO activeDay_
    FROM interface.AccountCode
    WHERE AccountCode.creationDate + INTERVAL '1' DAY > NOW();

    SELECT COUNT(*)
    INTO newCodes_
    FROM interface.AccountCode
    WHERE getAccountCode.email = AccountCode.email
      AND AccountCode.deprecateDate > NOW();

    IF activeCodes_ >= 15 OR activeAll_ >= 150 OR activeDay_ >= 300 THEN
        RETURN NULL;
    END IF;

    IF (account_._id IS NULL AND totalCodes_ > 2) OR newCodes_ > 0 THEN
        RETURN NULL;
    END IF;

    IF account_._id IS NULL AND activeCodes_ > 0 THEN
        RETURN NULL;
    END IF;

    IF NOT account_.active OR NOT account_.gdpr THEN
        RETURN NULL;
    END IF;

    SELECT *
    INTO oldCode_
    FROM interface.AccountCode
    WHERE getAccountCode.email = AccountCode.email
      AND deprecateDate > NOW()
    ORDER BY creationDate DESC
    LIMIT 1;

    IF oldCode_._codeId IS NULL THEN
        INSERT INTO account.Code (email)
        VALUES (email) RETURNING _id, code INTO oldCode_._codeId, oldCode_.code;
    END IF;

    INSERT INTO account.CodeCall (_codeId)
    VALUES (oldCode_._codeId);

    RETURN oldCode_.code;
END ;
$$ language plpgsql VOLATILE
                    SECURITY DEFINER;

CREATE OR REPLACE FUNCTION public.checkAccountCode(email TEXT, code TEXT)
    RETURNS BOOL
AS
$$
DECLARE
    checksDay_  INT;
    checksUser_ INT;
    checksAll_  INT;
    result_     BOOL;
BEGIN
    SELECT COUNT(*)
    INTO checksDay_
    FROM interface.AccountCodeCheck
    WHERE AccountCodeCheck.logdate + INTERVAL '1' DAY > NOW();

    SELECT COUNT(*)
    INTO checksUser_
    FROM interface.AccountCodeCheck
    WHERE checkAccountCode.email = AccountCodeCheck.email
      AND AccountCodeCheck.logdate + INTERVAL '15' MINUTE > NOW();

    SELECT COUNT(*)
    INTO checksAll_
    FROM interface.AccountCodeCheck
    WHERE AccountCodeCheck.logdate + INTERVAL '15' MINUTE > NOW();

    IF checksUser_ >= 15 OR checksAll_ >= 150 OR checksDay_ >= 300 THEN
        RETURN NULL;
    END IF;

    INSERT INTO account.CodeCheck (email, code)
    VALUES (email, code);

    SELECT EXISTS(
                   SELECT 1
                   FROM interface.AccountCode
                   WHERE checkAccountCode.email = AccountCode.email
                     AND checkAccountCode.code = AccountCode.code
                     AND AccountCode.expiredate > NOW()
                   LIMIT 1
               )
    INTO result_;

    RETURN result_;
END ;
$$ language plpgsql VOLATILE
                    SECURITY DEFINER;

CREATE OR REPLACE FUNCTION public.assertAccount(email TEXT)
    RETURNS BOOL
AS
$$
DECLARE
    account_iface_ interface.Account%ROWTYPE;
BEGIN
    SELECT *
    INTO account_iface_
    FROM interface.Account
    WHERE assertAccount.email = Account.email;

    IF account_iface_._id IS NOT NULL AND NOT account_iface_.active THEN
        RETURN FALSE;
    END IF;

    IF account_iface_._id IS NULL THEN
        INSERT INTO Account.Account
            DEFAULT
        VALUES RETURNING _id INTO account_iface_._id;

        INSERT INTO Account.Manager (_accountid, manager)
        VALUES (account_iface_._id, FALSE);

        INSERT INTO Account.Properties (_accountid, email, active, gdpr)
        VALUES (account_iface_._id, assertAccount.email, TRUE, TRUE);

        INSERT INTO Account.Settings (_accountId) VALUES (account_iface_._id);
        INSERT INTO Account.Data (_accountId) VALUES (account_iface_._id);
    END IF;

    RETURN TRUE;
END ;
$$ language plpgsql VOLATILE
                    SECURITY DEFINER;

CREATE OR REPLACE FUNCTION public.createAccountSession(email TEXT)
    RETURNS UUID
AS
$$
DECLARE
    account_iface_ interface.Account%ROWTYPE;
    session_       interface.AccountSession%ROWTYPE;
BEGIN
    SELECT *
    INTO account_iface_
    FROM interface.Account
    WHERE createAccountSession.email = Account.email
      AND Account.active
      AND Account.gdpr;

    IF account_iface_._id IS NULL THEN
        RETURN NULL;
    END IF;

    INSERT INTO Account.Session (_accountid)
    VALUES (account_iface_._id) RETURNING _id, _id_public
                                INTO session_._id, session_._id_public;

    INSERT INTO Account.SessionProperties (_sessionid, active)
    VALUES (session_._id, TRUE);

    RETURN session_._id_public;
END ;
$$ language plpgsql VOLATILE
                    SECURITY DEFINER;

CREATE OR REPLACE FUNCTION public.checkAccountSession(session UUID)
    RETURNS BOOL
AS
$$
DECLARE
    return_ BOOL;
BEGIN
    SELECT EXISTS(
                   SELECT 1
                   FROM interface.AccountSession
                   WHERE checkAccountSession.session = AccountSession._id_public
                     AND AccountSession.active
               )
    INTO return_;

    RETURN return_;
END ;
$$ language plpgsql VOLATILE
                    SECURITY DEFINER;

CREATE OR REPLACE FUNCTION public.revokeAccountSession(session UUID)
    RETURNS BOOL
AS
$$
DECLARE
    session_iface_ interface.AccountSession%ROWTYPE;
BEGIN
    SELECT *
    INTO session_iface_
    FROM interface.AccountSession
    WHERE revokeAccountSession.session = AccountSession._id_public
      AND AccountSession.active
    LIMIT 1;

    IF session_iface_._id IS NULL THEN
        RETURN FALSE;
    END IF;

    INSERT INTO Account.SessionProperties (_sessionId, active)
    VALUES (session_iface_._id, FALSE);

    RETURN TRUE;
END ;
$$ language plpgsql VOLATILE
                    SECURITY DEFINER;

CREATE OR REPLACE FUNCTION public.setSettings(session UUID, settings JSONB)
    RETURNS SETOF public.Account
AS
$$
DECLARE
    session_iface_ interface.AccountSession%ROWTYPE;
    geom_          postgis.geometry(Point, 3006);
    coordinates_   REAL[2];
    fromBuffer_    REAL;
    toBuffer_      REAL;
BEGIN
    SELECT *
    INTO session_iface_
    FROM interface.AccountSession
    WHERE setSettings.session = AccountSession._id_public
      AND AccountSession.active
    LIMIT 1;

    IF session_iface_._id IS NULL THEN
        RAISE EXCEPTION 'Invalid session token!';
    END IF;

    SELECT ARRAY [ settings -> 'coordinates' -> 0,
               settings -> 'coordinates' -> 1] AS coordinates
    INTO coordinates_;
    SELECT postgis.ST_SetSRID(postgis.ST_Point(coordinates_[1],
                                               coordinates_[2]), 3006)
    INTO geom_;

    SELECT settings -> 'fromBuffer',
           settings -> 'toBuffer'
    INTO fromBuffer_, toBuffer_;

    INSERT INTO account.Settings (_accountId, geom, toBuffer, fromBuffer)
    VALUES (session_iface_._accountId, geom_, toBuffer_, fromBuffer_);

    RETURN QUERY
        SELECT public.Account.*
        FROM public.Account
                 LEFT JOIN interface.Account
                           ON public.Account._id_public =
                              interface.Account._id_public
        WHERE interface.Account._id = session_iface_._accountId;
END ;
$$ language plpgsql VOLATILE
                    SECURITY DEFINER;

CREATE OR REPLACE FUNCTION public.getAccount(session UUID)
    RETURNS SETOF public.Account
AS
$$
DECLARE
    session_iface_ interface.AccountSession%ROWTYPE;
BEGIN
    SELECT *
    INTO session_iface_
    FROM interface.AccountSession
    WHERE getAccount.session = AccountSession._id_public
      AND AccountSession.active
    LIMIT 1;

    IF session_iface_._id IS NULL THEN
        RAISE EXCEPTION 'Invalid session token!';
    END IF;

    RETURN QUERY
        SELECT public.Account.*
        FROM public.Account
                 LEFT JOIN interface.Account
                           ON public.Account._id_public =
                              interface.Account._id_public
        WHERE interface.Account._id = session_iface_._accountId;
END
$$ language plpgsql VOLATILE
                    SECURITY DEFINER;

CREATE OR REPLACE FUNCTION public.updateAccountProperties(_id_public UUID,
                                                          email TEXT,
                                                          active BOOL) RETURNS SETOF public.Account
AS
$$
DECLARE
    account_ interface.account%ROWTYPE;
BEGIN
    SELECT *
    INTO account_
    FROM interface.Account
    WHERE updateAccountProperties._id_public = Account._id_public
    LIMIT 1;

    IF account_._id IS NULL THEN
        RAISE EXCEPTION 'Invalid account ID!';
    END IF;

    INSERT INTO Account.Properties (_accountid, email, active, gdpr, blocked)
    VALUES (account_._id, email, active, account_.active, account_.blocked);

    RETURN QUERY
        SELECT *
        FROM public.Account
        WHERE Account._id_public = account_._id_public;
END
$$ language plpgsql VOLATILE
                    SECURITY DEFINER;

CREATE OR REPLACE FUNCTION public.updateAccountData(data JSONB)
    RETURNS void
AS
$$
DECLARE
    data_    public.AccountData_t;
    account_ interface.account%ROWTYPE;
BEGIN
    FOR data_ IN
        SELECT value ->> '_id_public' AS _id_public,
               value -> 'consumption' AS consumption,
               value -> 'production'  AS production,
               value -> 'buffer'      AS buffer,
               value -> 'blackout'    AS blackout
        FROM jsonb_array_elements(data)
        LOOP
            SELECT *
            INTO account_
            FROM interface.Account
            WHERE data_._id_public = Account._id_public
            LIMIT 1;

            IF account_._id IS NULL THEN
                RAISE EXCEPTION 'Invalid account ID!';
            END IF;

            IF data_.buffer > 70 THEN
                SELECT 70 INTO data_.buffer;
            ELSE
                IF data_.buffer < 0 THEN
                    SELECT 0 INTO data_.buffer;
                END IF;
            END IF;

            INSERT INTO Account.Data (_accountid, consumption, production,
                                      buffer, blackout)
            VALUES (account_._id, data_.consumption, data_.production,
                    data_.buffer, data_.blackout)
            ON CONFLICT (_accountId) DO UPDATE
                SET (consumption, production, buffer, blackout) =
                        (data_.consumption, data_.production, data_.buffer,
                         data_.blackout);
        END LOOP;
    RETURN;
END
$$ language plpgsql VOLATILE
                    SECURITY DEFINER;

CREATE OR REPLACE FUNCTION public.getAccountData(session UUID)
    RETURNS SETOF public.AccountData_t
AS
$$
DECLARE
    session_iface_ interface.AccountSession%ROWTYPE;
BEGIN
    SELECT *
    INTO session_iface_
    FROM interface.AccountSession
    WHERE getAccountData.session = AccountSession._id_public
      AND AccountSession.active
    LIMIT 1;

    IF session_iface_._id IS NULL THEN
        RAISE EXCEPTION 'Invalid session token!';
    END IF;

    RETURN QUERY
        SELECT _id_public,
               consumption,
               production,
               buffer,
               blackout
        FROM interface.Account
        WHERE _id = session_iface_._accountId;
END
$$ language plpgsql VOLATILE
                    SECURITY DEFINER;

CREATE OR REPLACE FUNCTION public.upsertAccountAvatar(session UUID,
                                                      format TEXT,
                                                      image BYTEA) RETURNS void
AS
$$
DECLARE
    session_iface_ interface.AccountSession%ROWTYPE;
BEGIN
    SELECT *
    INTO session_iface_
    FROM interface.AccountSession
    WHERE upsertAccountAvatar.session = AccountSession._id_public
      AND AccountSession.active
    LIMIT 1;

    IF session_iface_._id IS NULL THEN
        RAISE EXCEPTION 'Invalid session token!';
    END IF;

    INSERT INTO account.Avatar (_accountId, image, format)
    VALUES (session_iface_._accountId, image, format);

    RETURN;
END
$$ language plpgsql VOLATILE
                    SECURITY DEFINER;

CREATE OR REPLACE FUNCTION public.selectAccountAvatar(session UUID,
                                                      id UUID) RETURNS SETOF public.AccountAvatar_t
AS
$$
DECLARE
    session_iface_ interface.AccountSession%ROWTYPE;
BEGIN
    SELECT *
    INTO session_iface_
    FROM interface.AccountSession
    WHERE selectAccountAvatar.session = AccountSession._id_public
      AND AccountSession.active
    LIMIT 1;

    IF session_iface_._id IS NULL THEN
        RAISE EXCEPTION 'Invalid session token!';
    END IF;

    RETURN QUERY
        SELECT image, format
        FROM account.Avatar
        WHERE session_iface_._accountId = Avatar._accountId
          AND id = Avatar._id_public;
END
$$ language plpgsql VOLATILE
                    SECURITY DEFINER;

CREATE OR REPLACE FUNCTION public.blockAccount(_id_public UUID,
                                               seconds INTERVAL SECOND) RETURNS SETOF public.Account
AS
$$
DECLARE
    account_ interface.account%ROWTYPE;
BEGIN
    SELECT *
    INTO account_
    FROM interface.Account
    WHERE blockAccount._id_public = Account._id_public
    LIMIT 1;

    IF account_._id IS NULL THEN
        RAISE EXCEPTION 'Invalid account ID!';
    END IF;

    INSERT INTO Account.Properties (_accountid, email, active, gdpr, blocked)
    VALUES (account_._id,
            account_.email,
            account_.active,
            account_.active,
            NOW() + seconds);

    RETURN QUERY
        SELECT *
        FROM public.Account
        WHERE Account._id_public = account_._id_public;
END
$$ language plpgsql VOLATILE
                    SECURITY DEFINER;

CREATE OR REPLACE FUNCTION public.setPrice(session UUID,
                                           price REAL) RETURNS SETOF public.Price
AS
$$
DECLARE
    session_iface_ interface.AccountSession%ROWTYPE;
BEGIN
    SELECT *
    INTO session_iface_
    FROM interface.AccountSession
    WHERE setPrice.session = AccountSession._id_public
      AND AccountSession.active
    LIMIT 1;

    IF session_iface_._id IS NULL THEN
        RAISE EXCEPTION 'Invalid session token!';
    END IF;

    INSERT INTO price.Price (price, byuser)
    VALUES (price, session_iface_._accountId);

    RETURN QUERY
        SELECT *
        FROM public.Price;
END
$$ language plpgsql VOLATILE
                    SECURITY DEFINER;

CREATE OR REPLACE FUNCTION public.setCoalSettings(session UUID, settings JSONB)
    RETURNS SETOF public.Coal
AS
$$
DECLARE
    session_iface_ interface.AccountSession%ROWTYPE;
    produce_       REAL;
    fromBuffer_    REAL;
    toBuffer_      REAL;
    start_         BOOL;
BEGIN
    SELECT *
    INTO session_iface_
    FROM interface.AccountSession
    WHERE setCoalSettings.session = AccountSession._id_public
      AND AccountSession.active
    LIMIT 1;

    IF session_iface_._id IS NULL THEN
        RAISE EXCEPTION 'Invalid session token!';
    END IF;

    SELECT settings -> 'fromBuffer',
           settings -> 'toBuffer',
           settings -> 'produce',
           settings -> 'start'
    INTO fromBuffer_, toBuffer_, produce_, start_;

    INSERT INTO coal.Settings (byUser, produce, toBuffer, fromBuffer, start)
    VALUES (session_iface_._accountId, produce_, toBuffer_, fromBuffer_,
            start_);

    RETURN QUERY
        SELECT *
        FROM public.Coal;
END ;
$$ language plpgsql VOLATILE
                    SECURITY DEFINER;

CREATE OR REPLACE FUNCTION public.updateCoalData(data JSONB)
    RETURNS void
AS
$$
DECLARE
    status_bool_ BOOL;
    status_      TIMESTAMPTZ;
    production_  REAL;
    buffer_      REAL;
    coal_        interface.Coal%ROWTYPE;
BEGIN
    SELECT data -> 'production' AS production,
           data -> 'buffer'     AS buffer,
           data -> 'status'     AS status_bool
    INTO production_, buffer_, status_bool_;

    IF buffer_ > 70000 THEN
        SELECT 70000 INTO buffer_;
    ELSE
        IF buffer_ < 0 THEN
            SELECT 0 INTO buffer_;
        END IF;
    END IF;

    SELECT * FROM interface.Coal INTO coal_;

    SELECT CASE
               WHEN status_bool_ AND coal_.status IS NULL
                   THEN NOW() + INTERVAL '10 SECOND'
               WHEN status_bool_ THEN coal_.status
               ELSE NULL
               END
    INTO status_;

    UPDATE Coal.Data
    SET (buffer, status, logdate)
            = (buffer_, status_, NOW())
    WHERE singleton = TRUE;
    RETURN;
END
$$ language plpgsql VOLATILE
                    SECURITY DEFINER;
