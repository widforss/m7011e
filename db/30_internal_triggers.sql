CREATE OR REPLACE FUNCTION interface.trg_account_properties_check()
    RETURNS trigger
AS
$$
DECLARE
    nameExists_ BOOL;
BEGIN
    SELECT EXISTS(
                   SELECT 1
                   FROM interface.Account
                   WHERE Account.email = NEW.email
                     AND Account._id <> NEW._accountId
               )
    INTO nameExists_;

    IF nameExists_ THEN
        RAISE EXCEPTION 'Email already in use!';
    END IF;
    RETURN NEW;
END;
$$ language plpgsql STABLE;