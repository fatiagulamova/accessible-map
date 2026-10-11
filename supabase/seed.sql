-- ============================================================
-- Seed Data - Test için örnek veriler
-- ============================================================

insert into public.locations (address, latitude, longitude, description)
values
    ('Bartın Üniversitesi Ağdacı Kampüsü', 41.6234, 32.3456, 'Kampüs ana giriş'),
    ('Bartın Şehir Merkezi',              41.6378, 32.3374, 'Cumhuriyet Meydanı'),
    ('Bartın Otogar',                     41.6412, 32.3512, 'Şehirlerarası otobüs terminali');

insert into public.accessibility_features
    (location_id, feature_type, has_ramp, has_elevator, has_stairs, pavement_status, slope_degree, sidewalk_width)
select id, 'ramp', true, true, false, 'good', 3.0, 2.0
from public.locations where address = 'Bartın Üniversitesi Ağdacı Kampüsü';

insert into public.accessibility_features
    (location_id, feature_type, has_ramp, has_elevator, has_stairs, pavement_status, slope_degree, sidewalk_width)
select id, 'stairs', false, false, true, 'bad', 8.5, 1.2
from public.locations where address = 'Bartın Şehir Merkezi';