-- This SQL code should be executed first

CREATE OR REPLACE FUNCTION slice_language_tags(tags hstore)
RETURNS hstore AS $$
    SELECT delete_empty_keys(slice(tags, ARRAY['name:en', 'name:de', 'name:cs', 'int_name', 'loc_name', 'name', 'wikidata', 'wikipedia']))
$$ LANGUAGE SQL IMMUTABLE;


CREATE OR REPLACE FUNCTION public.fuzzy_search(query_name text)
RETURNS text
LANGUAGE sql
immutable
strict
AS $function$
  SELECT  json_agg(ST_AsGeoJSON(feature.*)) FROM (
    SELECT global_id_from_imposm(osm_id) AS id, ST_Transform(geometry, 4326) AS geometry, NULLIF(name, '') AS name,
        COALESCE(NULLIF(name_en, ''), name) AS name_en,
        COALESCE(NULLIF(name_de, ''), name, name_en) AS name_de,
        tags,
        ref,
        NULLIF(layer, 0) AS layer,
        level,
        CASE WHEN indoor=TRUE THEN 1  END as indoor
        FROM (
             SELECT osm_id, geometry, name, ref, name_en, name_de, tags, layer, level, indoor
             FROM osm_poi_polygon
             WHERE lower(name) LIKE '%' || lower(query_name) || '%' or ref % query_name

             UNION ALL

             SELECT osm_id, geometry, name, ref, name_en, name_de, tags, layer, level, indoor
             FROM osm_poi_point
             WHERE lower(name) LIKE '%' || lower(query_name) || '%'

             UNION ALL

             SELECT osm_id, geometry, name, ref, name_en, name_de, tags, null as layer, level, TRUE as indoor
             FROM osm_indoor_polygon
             WHERE lower(name) LIKE '%' || lower(query_name) || '%' or ref % query_name
        ) AS poi_union
  ) AS feature;
$function$;
