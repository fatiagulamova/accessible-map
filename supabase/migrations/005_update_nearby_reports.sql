-- ============================================================
-- 005_update_nearby_reports.sql
-- nearby_reports fonksiyonuna photo_url alanını ekler
-- ============================================================

-- Return type değiştiği için CREATE OR REPLACE tek başına yeterli
-- değildir; fonksiyonun önce kaldırılması gerekir.
drop function if exists public.nearby_reports(decimal, decimal, integer);

create or replace function public.nearby_reports(
    p_lat        decimal,
    p_lng        decimal,
    p_radius_m   integer default 1000
)
returns table (
    report_id    uuid,
    title        varchar,
    description  text,
    photo_url    text,
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
        r.photo_url,
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
