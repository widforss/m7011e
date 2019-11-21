CREATE FUNCTION interface.is_whitespace(string TEXT) RETURNS BOOLEAN as
$$
BEGIN
    RETURN string ~ ('^[ \s\t\v\b\r\n\f\u00A0\u1680\u2000\u2001' ||
                     '\u2002\u2003\u2004\u2005\u2006\u2007\u2008' ||
                     '\u2009\u200A\u202f\u205f\u3000]*$');
END;
$$ language plpgsql STABLE;
CREATE DOMAIN interface.name_t AS VARCHAR(255)
    CHECK ( NOT interface.is_whitespace(value) );