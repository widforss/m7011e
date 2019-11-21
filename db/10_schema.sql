DROP SCHEMA IF EXISTS account CASCADE;
DROP SCHEMA IF EXISTS interface CASCADE;

CREATE SCHEMA IF NOT EXISTS account;
CREATE SCHEMA IF NOT EXISTS interface;
CREATE SCHEMA IF NOT EXISTS uuid;
CREATE SCHEMA IF NOT EXISTS trigram;

CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA uuid;
CREATE EXTENSION IF NOT EXISTS pg_trgm WITH SCHEMA trigram;
