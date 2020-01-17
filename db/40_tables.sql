CREATE TABLE account.Account
(
    _id        UUID        NOT NULL DEFAULT uuid.uuid_generate_v4(),
    _id_public UUID        NOT NULL DEFAULT uuid.uuid_generate_v4(),

    logDate    TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    PRIMARY KEY (_id),
    UNIQUE (_id_public)
);
CREATE INDEX ON account.Account (logDate);

CREATE TABLE account.Manager
(
    _id        UUID        NOT NULL DEFAULT uuid.uuid_generate_v4(),
    _id_public UUID        NOT NULL DEFAULT uuid.uuid_generate_v4(),
    _accountId UUID        NOT NULL,
    manager    BOOL        NOT NULL,

    logDate    TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    PRIMARY KEY (_id),
    FOREIGN KEY (_accountId) REFERENCES account.Account (_id),
    UNIQUE (_id_public)
);
CREATE INDEX ON account.Manager (_accountId);
CREATE INDEX ON account.Manager (manager);
CREATE INDEX ON account.Manager (logDate);

CREATE TABLE account.Properties
(
    _id        UUID         NOT NULL DEFAULT uuid.uuid_generate_v4(),
    _id_public UUID         NOT NULL DEFAULT uuid.uuid_generate_v4(),
    _accountId UUID         NOT NULL,
    email      VARCHAR(255) NOT NULL,
    blocked    TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    active     BOOL         NOT NULL,
    gdpr       BOOL         NOT NULL,

    logDate    TIMESTAMPTZ  NOT NULL DEFAULT NOW(),

    PRIMARY KEY (_id),
    FOREIGN KEY (_accountId) REFERENCES account.Account (_id),
    UNIQUE (_id_public),
    CHECK (EXTRACT(EPOCH FROM blocked - NOW()) >= 10 OR blocked = NOW()),
    CHECK (EXTRACT(EPOCH FROM blocked - NOW()) <= 100)
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
    toBuffer   REAL                          NOT NULL DEFAULT 1,
    fromBuffer REAL                          NOT NULL DEFAULT 0,

    logDate    TIMESTAMPTZ                   NOT NULL DEFAULT NOW(),

    PRIMARY KEY (_id),
    FOREIGN KEY (_accountId) REFERENCES account.Account (_id),
    UNIQUE (_id_public),
    CHECK (512758 < postgis.ST_X(geom) AND postgis.ST_X(geom) < 864415),
    CHECK (7213073 < postgis.ST_Y(geom) AND postgis.ST_Y(geom) < 7689477),
    CHECK (0 <= toBuffer AND toBuffer <= 1),
    CHECK (0 <= fromBuffer AND fromBuffer <= 1)
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
    buffer      REAL        NOT NULL DEFAULT 0,
    blackout    BOOL        NOT NULL DEFAULT FALSE,

    logDate     TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    PRIMARY KEY (_id),
    FOREIGN KEY (_accountId) REFERENCES account.Account (_id),
    UNIQUE (_id_public),
    UNIQUE (_accountId),
    CHECK (consumption >= 0 AND production >= 0),
    CHECK (0 <= buffer AND buffer <= 70)
);
CREATE INDEX ON account.Properties (logDate);

CREATE TABLE account.Avatar
(
    _id        UUID         NOT NULL DEFAULT uuid.uuid_generate_v4(),
    _id_public UUID         NOT NULL DEFAULT uuid.uuid_generate_v4(),
    _accountId UUID         NOT NULL,
    image      BYTEA        NOT NULL,
    format     VARCHAR(255) NOT NULL,

    logDate    TIMESTAMPTZ  NOT NULL DEFAULT NOW(),

    PRIMARY KEY (_id),
    FOREIGN KEY (_accountId) REFERENCES account.Account (_id),
    UNIQUE (_id_public),
    CHECK (format LIKE 'JPEG' OR format LIKE 'PNG')
);
CREATE INDEX ON account.Avatar (_accountId);
CREATE INDEX ON account.Avatar (logDate);

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

CREATE TABLE price.Price
(
    _id        UUID        NOT NULL DEFAULT uuid.uuid_generate_v4(),
    _id_public UUID        NOT NULL DEFAULT uuid.uuid_generate_v4(),
    price      REAL        NOT NULL,
    byUser     UUID,

    logDate    TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    PRIMARY KEY (_id),
    UNIQUE (_id_public)
);
CREATE INDEX ON price.Price (logDate);
INSERT INTO price.Price (price)
VALUES (1.5);

CREATE TABLE coal.Settings
(
    _id        UUID        NOT NULL DEFAULT uuid.uuid_generate_v4(),
    _id_public UUID        NOT NULL DEFAULT uuid.uuid_generate_v4(),
    start      BOOL        NOT NULL DEFAULT FALSE,
    produce    REAL        NOT NULL DEFAULT 5000,
    toBuffer   REAL        NOT NULL DEFAULT 1,
    fromBuffer REAL        NOT NULL DEFAULT 0,
    byUser     UUID,

    logDate    TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    PRIMARY KEY (_id),
    UNIQUE (_id_public),
    CHECK (0 <= produce AND produce <= 5000),
    CHECK (0 <= toBuffer AND toBuffer <= 1),
    CHECK (0 <= fromBuffer AND fromBuffer <= 1)
);
CREATE INDEX ON coal.Settings (byUser);
CREATE INDEX ON coal.Settings (logDate);
INSERT INTO coal.Settings DEFAULT
VALUES;

CREATE TABLE coal.Data
(
    singleton  BOOL        NOT NULL DEFAULT TRUE,
    status     TIMESTAMPTZ,
    buffer     REAL        NOT NULL DEFAULT 0,

    logDate    TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    PRIMARY KEY (singleton),
    CHECK (singleton),
    CHECK (0 <= buffer AND buffer <= 70000)
);
CREATE INDEX ON coal.Data (logDate);
INSERT INTO coal.Data DEFAULT
VALUES;
