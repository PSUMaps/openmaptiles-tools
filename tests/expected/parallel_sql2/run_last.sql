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
 RETURNS setof text
 LANGUAGE sql
 immutable
 strict
AS $function$
  SELECT ST_AsGeoJSON(feature.*) FROM (
    SELECT global_id_from_imposm(osm_id) AS id, ST_Transform(geometry, 4326) AS geometry, NULLIF(name, '') AS name,
        tags,
        nullif(ref,'') as ref,
        NULLIF(layer, 0) AS layer,
        level,
        CASE WHEN indoor=TRUE THEN 1 ELSE NULL END as indoor,
        similarity
        FROM (
             SELECT osm_id, geometry, name, ref, name_en, name_de, tags, layer, level, indoor,
             GREATEST(similarity(name, query_name),similarity(ref, query_name)) as similarity
             FROM osm_poi_polygon
             WHERE similarity(name, query_name) > 0.1 or similarity(ref, query_name) > 0.1

             UNION ALL

             SELECT osm_id, geometry, name, ref, name_en, name_de, tags, layer, level, indoor,
             similarity(name, query_name) as similarity
             FROM osm_poi_point
             WHERE similarity(name, query_name) > 0.1

             UNION ALL

             SELECT osm_id, geometry, name, ref, name_en, name_de, tags, null as layer, level, TRUE as indoor,
             GREATEST(similarity(name, query_name),similarity(ref, query_name)) as similarity
             FROM osm_indoor_polygon
             WHERE similarity(name, query_name) > 0.1 or similarity(ref, query_name) > 0.1
        ) AS poi_union
       ORDER BY similarity DESC
  ) AS feature;
$function$;
