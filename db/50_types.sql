DROP TYPE IF EXISTS public.Account_t CASCADE;
CREATE TYPE public.Account_t AS (_id_public UUID,
    creationDate TIMESTAMPTZ,
    email VARCHAR(255),
    fromBuffer REAL,
    toBuffer REAL,
    active BOOL,
    gdpr BOOL,
    coordinates INT[2],
    avatarUrl TEXT);

DROP TYPE IF EXISTS public.AccountData_t CASCADE;
CREATE TYPE public.AccountData_t AS (
    _id_public UUID,
    consumption REAL,
    production REAL,
    buffer REAL);

DROP TYPE IF EXISTS public.AccountAvatar_t CASCADE;
CREATE TYPE public.AccountAvatar_t AS (
    image BYTEA,
    format VARCHAR(255));
