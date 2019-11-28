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
    END IF;

    INSERT INTO Account.properties (_accountid, email, active, gdpr)
    VALUES (account_iface_._id, assertAccount.email, TRUE, TRUE);

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