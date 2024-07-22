-- This SQL code should be executed last
CREATE index IF NOT EXISTS poi_polygon_name_trgm_idx ON osm_poi_polygon
  USING gin (name gin_trgm_ops);

 CREATE index IF NOT EXISTS poi_polygon_ref_trgm_idx ON osm_poi_polygon
  USING gin (ref gin_trgm_ops);

CREATE index IF NOT EXISTS poi_point_name_trgm_idx ON osm_poi_point
  USING gin (name gin_trgm_ops);

CREATE index IF NOT EXISTS indoor_polygon_name_trgm_idx ON osm_indoor_polygon
  USING gin (name gin_trgm_ops);

CREATE index IF NOT EXISTS indoor_polygon_ref_trgm_idx ON osm_indoor_polygon
  USING gin (ref gin_trgm_ops);

CREATE OR REPLACE FUNCTION public.fuzzy_search(query_name text)
    RETURNS json
    LANGUAGE sql
    immutable
    strict
    parallel safe
AS
$function$
SELECT json_agg(st_asgeojson(feature.*)::json)
FROM (SELECT global_id_from_imposm(osm_id) AS id,
             ST_Transform(geometry, 4326)  AS geometry,
             NULLIF(name, '')              AS name,
             tags,
             nullif(ref, '')               as ref,
             level,
             similarity
      FROM (SELECT osm_id,
                   geometry,
                   name,
                   ref,
                   tags,
                   level,
                   similarity(name, query_name) as similarity
            FROM osm_poi_point
            WHERE similarity(name, query_name) > 0.1

            UNION ALL

            SELECT osm_id,
                   geometry,
                   name,
                   ref,
                   tags,
                   level,
                   GREATEST(similarity(name, query_name), similarity(ref, query_name)) as similarity
            FROM osm_indoor_polygon
            WHERE similarity(name, query_name) > 0.1
               or similarity(ref, query_name) > 0.1) AS poi_union
      ORDER BY similarity DESC) AS feature;
$function$;

CREATE OR REPLACE FUNCTION public.search_tag(query_name text)
    RETURNS json
    LANGUAGE sql
    immutable
    strict
    parallel safe
AS
$function$
SELECT json_agg(st_asgeojson(feature.*)::json)
FROM (SELECT global_id_from_imposm(osm_id) AS id,
             ST_Transform(geometry, 4326)  AS geometry,
             NULLIF(name, '')              AS name,
             tags,
             nullif(ref, '')               as ref,
             level
      FROM (SELECT osm_id, geometry, name, ref, tags, level
            FROM osm_poi_point
            WHERE subclass = query_name

            UNION ALL

            SELECT osm_id, geometry, name, ref, tags, level
            FROM osm_indoor_polygon
            WHERE tags -> 'amenity' = query_name) AS poi_union) AS feature;
$function$;

CREATE OR REPLACE FUNCTION public.get_amenity()
    RETURNS json
    LANGUAGE sql
    immutable
    strict
    parallel safe
AS
$function$
SELECT json_agg(amenity)
FROM (SELECT DISTINCT subclass as amenity
      FROM osm_poi_point

      UNION ALL

      SELECT DISTINCT tags -> 'amenity' as amenity
      FROM osm_indoor_polygon) as _
$function$;

CREATE OR REPLACE FUNCTION get_indoor(query_id integer)
    RETURNS JSON AS
$$
SELECT ST_AsGeoJSON(feature.*)::json
FROM (SELECT osm_id                       AS id,
             ST_Transform(geometry, 4326) AS geometry,
             NULLIF(name, '')             AS name,
             tags
      FROM osm_indoor_polygon
      WHERE osm_id = query_id

      UNION ALL

      SELECT osm_id                       AS id,
             ST_Transform(geometry, 4326) AS geometry,
             NULLIF(name, '')             AS name,
             tags
      FROM osm_poi_point
      WHERE osm_id = query_id
     ) AS feature;
$$ LANGUAGE SQL IMMUTABLE;

DO
$$
    BEGIN
        IF NOT EXISTS (SELECT 1
                       FROM pg_roles
                       WHERE rolname = 'web_anon') THEN
            CREATE ROLE web_anon nologin;
            GRANT USAGE ON SCHEMA public TO web_anon;
            GRANT SELECT ON osm_indoor_polygon, osm_poi_point TO web_anon;
        END IF;
    END
$$;

DROP FUNCTION IF EXISTS getmvt(zoom integer, x integer, y integer);
CREATE FUNCTION getmvt(zoom integer, x integer, y integer)
    RETURNS TABLE(mvt bytea, key text) AS $$
BEGIN
    RETURN QUERY SELECT
                     decode('00', 'hex')::bytea AS mvt,
                     '0' AS key;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION gettile(zoom INT, x INT, y INT) RETURNS bytea AS
$$
DECLARE
    headers      TEXT;
    DECLARE blob bytea;
begin
    select '[{"Content-Type": "application/x-protobuf"},'
               '{"Content-Encoding": "gzip"}]'
    into headers;
    perform set_config('response.headers', headers, true);
    select mvt from getmvt(zoom, x, y) into blob;
    if FOUND -- special var, see https://www.postgresql.org/docs/current/plpgsql-statements.html#PLPGSQL-STATEMENTS-DIAGNOSTICS
    then
        return (blob);
    else
        raise sqlstate 'PT404' using
            message = 'NOT FOUND',
            detail = 'Tile not found',
            hint = format('%s / %s / %s seems to be an invalid tile', zoom, x, y);
    end if;
end
$$ language plpgsql;
