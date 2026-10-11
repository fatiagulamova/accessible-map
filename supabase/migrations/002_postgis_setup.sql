-- ============================================================
-- Migration: 002_postgis_setup
-- Description: PostGIS uzantısı ve mekânsal fonksiyonlar
-- ============================================================

create extension if not exists postgis;

-- TRIGGER: locations.geom otomatik güncelleme
create or replace function public.sync_location_geom()
returns trigger as $$
begin
    new.geom := st_setsrid(
        st_makepoint(new.longitude, new.latitude),
        4326
    )::geography;
    return new;
end;
$$ language plpgsql;

create trigger trg_locations_sync_geom
before insert or update of latitude, longitude
on public.locations
for each row
execute function public.sync_location_geom();

-- FONKSİYON: nearby_reports
create or replace function public.nearby_reports(
    p_lat        decimal,
    p_lng        decimal,
    p_radius_m   integer default 1000
)
returns table (
    report_id    uuid,
    title        varchar,
    description  text,
    status       public.report_status,
    latitude     decimal,
    longitude    decimal,
    distance_m   double precision
)
as $$
begin
    return query
    select
        r.id,
        r.title,
        r.description,
        r.status,
        l.latitude,
        l.longitude,
        st_distance(
            l.geom,
            st_setsrid(st_makepoint(p_lng, p_lat), 4326)::geography
        ) as distance_m
    from public.reports r
    join public.locations l on l.id = r.location_id
    where st_dwithin(
        l.geom,
        st_setsrid(st_makepoint(p_lng, p_lat), 4326)::geography,
        p_radius_m
    )
    order by distance_m asc;
end;
$$ language plpgsql stable;