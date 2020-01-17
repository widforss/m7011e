DROP TYPE IF EXISTS public.AccountData_t CASCADE;
CREATE TYPE public.AccountData_t AS (
    _id_public UUID,
    consumption REAL,
    production REAL,
    buffer REAL,
    blackout BOOL);

DROP TYPE IF EXISTS public.AccountAvatar_t CASCADE;
CREATE TYPE public.AccountAvatar_t AS (
    image BYTEA,
    format VARCHAR(255));
