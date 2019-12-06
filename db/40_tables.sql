CREATE TABLE account.Account
(
    _id        UUID        NOT NULL DEFAULT uuid.uuid_generate_v4(),
    _id_public UUID        NOT NULL DEFAULT uuid.uuid_generate_v4(),

    logDate    TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    PRIMARY KEY (_id),
    UNIQUE (_id_public)
);
CREATE INDEX ON account.Account (logDate);

CREATE TABLE account.Properties
(
    _id        UUID         NOT NULL DEFAULT uuid.uuid_generate_v4(),
    _id_public UUID         NOT NULL DEFAULT uuid.uuid_generate_v4(),
    _accountId UUID         NOT NULL,
    email      VARCHAR(255) NOT NULL,
    active     BOOL         NOT NULL,
    gdpr       BOOL         NOT NULL,

    logDate    TIMESTAMPTZ  NOT NULL DEFAULT NOW(),

    PRIMARY KEY (_id),
    FOREIGN KEY (_accountId) REFERENCES account.Account (_id),
    UNIQUE (_id_public)
);
CREATE INDEX ON account.Properties (_accountId);
CREATE INDEX ON account.Properties USING gin (email trigram.gin_trgm_ops);
CREATE INDEX ON account.Properties (active);
CREATE INDEX ON account.Properties (logDate);
CREATE TRIGGER trg_account_properties_check
    BEFORE INSERT OR UPDATE OF email
    ON account.Properties
    FOR EACH ROW
EXECUTE PROCEDURE interface.trg_account_properties_check();

CREATE TABLE account.Settings
(
    _id        UUID                          NOT NULL DEFAULT uuid.uuid_generate_v4(),
    _id_public UUID                          NOT NULL DEFAULT uuid.uuid_generate_v4(),
    _accountId UUID                          NOT NULL,
    geom       postgis.geometry(Point, 3006) NOT NULL DEFAULT postgis.ST_SetSRID(
            postgis.ST_Point(
                    828018,
                    7295937
                ), 3006),

    logDate    TIMESTAMPTZ                   NOT NULL DEFAULT NOW(),

    PRIMARY KEY (_id),
    FOREIGN KEY (_accountId) REFERENCES account.Account (_id),
    UNIQUE (_id_public),
    CHECK (512758 < postgis.ST_X(geom) AND postgis.ST_X(geom) < 864415),
    CHECK (7213073 < postgis.ST_Y(geom) AND postgis.ST_Y(geom) < 7689477)
);
CREATE INDEX ON account.Settings (_accountId);
CREATE INDEX ON account.Settings (logDate);
CREATE INDEX ON account.Settings USING GIST (geom);

CREATE TABLE account.Data
(
    _id         UUID        NOT NULL DEFAULT uuid.uuid_generate_v4(),
    _id_public  UUID        NOT NULL DEFAULT uuid.uuid_generate_v4(),
    _accountId  UUID        NOT NULL,
    consumption REAL        NOT NULL DEFAULT 0,
    production  REAL        NOT NULL DEFAULT 0,

    logDate     TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    PRIMARY KEY (_id),
    FOREIGN KEY (_accountId) REFERENCES account.Account (_id),
    UNIQUE (_id_public),
    CHECK (consumption >= 0 AND production >= 0)
);
CREATE INDEX ON account.Properties (_accountId);
CREATE INDEX ON account.Properties (logDate);

CREATE TABLE account.Session
(
    _id        UUID        NOT NULL DEFAULT uuid.uuid_generate_v4(),
    _id_public UUID        NOT NULL DEFAULT uuid.uuid_generate_v4(),
    _accountId UUID        NOT NULL,

    logDate    TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    PRIMARY KEY (_id),
    FOREIGN KEY (_accountId) REFERENCES account.Account (_id),
    UNIQUE (_id_public)
);
CREATE INDEX ON account.Session (logDate);
CREATE INDEX ON account.Session (_accountId);

CREATE TABLE account.SessionProperties
(
    _id        UUID        NOT NULL DEFAULT uuid.uuid_generate_v4(),
    _id_public UUID        NOT NULL DEFAULT uuid.uuid_generate_v4(),
    _sessionId UUID        NOT NULL,
    active     BOOL        NOT NULL,

    logDate    TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    PRIMARY KEY (_id),
    UNIQUE (_id_public)
);
CREATE INDEX ON account.SessionProperties (logDate);
CREATE INDEX ON account.SessionProperties (active);

CREATE TABLE account.Code
(
    _id        UUID         NOT NULL DEFAULT uuid.uuid_generate_v4(),
    _id_public UUID         NOT NULL DEFAULT uuid.uuid_generate_v4(),
    code       TEXT         NOT NULL DEFAULT LPAD(
            floor(random() * power(10, 6))::TEXT, 6, '0'),
    email      VARCHAR(255) NOT NULL,

    logDate    TIMESTAMPTZ  NOT NULL DEFAULT NOW(),

    PRIMARY KEY (_id),
    UNIQUE (_id_public)
);
CREATE INDEX ON account.Code (code);
CREATE INDEX ON account.Code USING gin (email trigram.gin_trgm_ops);
CREATE INDEX ON account.Code (logDate);

CREATE TABLE account.CodeCall
(
    _id        UUID        NOT NULL DEFAULT uuid.uuid_generate_v4(),
    _id_public UUID        NOT NULL DEFAULT uuid.uuid_generate_v4(),
    _codeId    UUID        NOT NULL,

    logDate    TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    PRIMARY KEY (_id),
    FOREIGN KEY (_codeId) REFERENCES account.Code (_id),
    UNIQUE (_id_public)
);
CREATE INDEX ON account.CodeCall (_codeId);
CREATE INDEX ON account.CodeCall (logDate);

CREATE TABLE account.CodeCheck
(
    _id        UUID         NOT NULL DEFAULT uuid.uuid_generate_v4(),
    _id_public UUID         NOT NULL DEFAULT uuid.uuid_generate_v4(),
    code       TEXT         NOT NULL,
    email      VARCHAR(255) NOT NULL,

    logDate    TIMESTAMPTZ  NOT NULL DEFAULT NOW(),

    PRIMARY KEY (_id),
    UNIQUE (_id_public)
);
CREATE INDEX ON account.CodeCheck (logDate);
CREATE INDEX ON account.CodeCheck (code);
CREATE INDEX ON account.CodeCheck USING gin (email trigram.gin_trgm_ops);