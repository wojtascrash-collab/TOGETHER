BEGIN;
SET LOCAL lock_timeout = '5s';
SET LOCAL statement_timeout = '60s';

-- Canvas produces a single baseline JPEG frame. Check its container, byte
-- budget and dimensions before letting a browser decode the image.
CREATE FUNCTION together_profile_private.is_thumbnail_jpeg(image bytea)
RETURNS boolean
LANGUAGE plpgsql IMMUTABLE STRICT SECURITY INVOKER SET search_path = ''
AS $validator$
DECLARE
  byte_count integer := pg_catalog.octet_length(image);
  offset_bytes integer := 2;
  marker integer;
  segment_length integer;
  components integer := 0;
  width_px integer;
  height_px integer;
BEGIN
  IF byte_count NOT BETWEEN 32 AND 24576
      OR substring(image FROM 1 FOR 2) <> '\xFFD8'::bytea
      OR substring(image FROM byte_count - 1 FOR 2) <> '\xFFD9'::bytea THEN
    RETURN false;
  END IF;

  WHILE offset_bytes + 4 < byte_count LOOP
    IF pg_catalog.get_byte(image, offset_bytes) <> 255 THEN RETURN false; END IF;
    marker := pg_catalog.get_byte(image, offset_bytes + 1);
    offset_bytes := offset_bytes + 2;
    segment_length := (pg_catalog.get_byte(image, offset_bytes) << 8)
      + pg_catalog.get_byte(image, offset_bytes + 1);
    IF segment_length < 2 OR offset_bytes + segment_length > byte_count - 2 THEN
      RETURN false;
    END IF;

    IF marker = 192 THEN -- Baseline frame
      IF components <> 0 OR segment_length < 11
          OR pg_catalog.get_byte(image, offset_bytes + 2) <> 8 THEN RETURN false; END IF;
      height_px := (pg_catalog.get_byte(image, offset_bytes + 3) << 8)
        + pg_catalog.get_byte(image, offset_bytes + 4);
      width_px := (pg_catalog.get_byte(image, offset_bytes + 5) << 8)
        + pg_catalog.get_byte(image, offset_bytes + 6);
      components := pg_catalog.get_byte(image, offset_bytes + 7);
      IF width_px <> 160 OR height_px <> 160 OR components NOT IN (1, 3)
          OR segment_length <> 8 + 3 * components THEN RETURN false; END IF;
    ELSIF marker = 218 THEN -- Start of the single scan
      IF components = 0 OR segment_length <> 6 + 2 * components
          OR pg_catalog.get_byte(image, offset_bytes + 2) <> components THEN RETURN false; END IF;
      offset_bytes := offset_bytes + segment_length;
      IF offset_bytes >= byte_count - 2 THEN RETURN false; END IF;
      WHILE offset_bytes < byte_count - 2 LOOP
        IF pg_catalog.get_byte(image, offset_bytes) = 255 THEN
          offset_bytes := offset_bytes + 1;
          marker := pg_catalog.get_byte(image, offset_bytes);
          IF marker <> 0 AND marker NOT BETWEEN 208 AND 215 THEN RETURN false; END IF;
        END IF;
        offset_bytes := offset_bytes + 1;
      END LOOP;
      RETURN true;
    ELSIF marker NOT IN (196, 219, 221) AND marker NOT BETWEEN 224 AND 239 THEN
      RETURN false;
    END IF;
    offset_bytes := offset_bytes + segment_length;
  END LOOP;
  RETURN false;
END
$validator$;
REVOKE ALL ON FUNCTION together_profile_private.is_thumbnail_jpeg(bytea) FROM PUBLIC, anon, authenticated, authenticator;
GRANT EXECUTE ON FUNCTION together_profile_private.is_thumbnail_jpeg(bytea) TO authenticated, service_role;

ALTER TABLE public.profiles
  DROP CONSTRAINT profiles_avatar_webp_check,
  ADD CONSTRAINT profiles_avatar_webp_check CHECK (
    avatar_webp IS NULL
      OR together_profile_private.is_thumbnail_webp(avatar_webp)
      OR together_profile_private.is_thumbnail_jpeg(avatar_webp)
  );
COMMIT;
