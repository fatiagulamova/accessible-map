-- ============================================================
-- Migration: 006_seed_more_bartin_data
-- Description: Bartın merkez için ek konum, erişilebilirlik ve rapor verileri
-- ============================================================

-- NOT: Bu dosya yalnızca Supabase SQL Editor'de manuel olarak çalıştırılmalıdır.
-- reports.user_id alanı NOT NULL ve profiles(id) foreign key'ine sahiptir.
-- Bu nedenle raporlar, mevcut profillerden en eski kayda bağlanır.
-- Profil yoksa raporlar atlanır; bir kullanıcı kaydı oluşturup dosyayı
-- tekrar çalıştırabilirsiniz. Konum ve özellik kayıtları yine de eklenir.

-- ============================================================
-- 1. YENİ KONUMLAR (Bartın merkez çevresi)
-- ============================================================
with new_locations (address, latitude, longitude, description) as (
    values
        ('Cumhuriyet Meydanı Kuzey Geçişi', 41.6382, 32.3370, 'Meydanın kuzey yaya geçişi'),
        ('Bartın Belediyesi Önü', 41.6372, 32.3362, 'Belediye hizmet binası girişi'),
        ('Uzun Çarşı Girişi', 41.6368, 32.3382, 'Tarihi çarşının ana giriş aksı'),
        ('Bartın Devlet Hastanesi Yolu', 41.6359, 32.3395, 'Hastane yaya erişim güzergahı'),
        ('Kültür Merkezi Yanı', 41.6388, 32.3351, 'Kültür merkezi yan yaya yolu'),
        ('Atatürk Parkı', 41.6374, 32.3357, 'Park ana giriş ve yürüyüş yolu'),
        ('Bartın Üniversitesi Şehir Yerleşkesi', 41.6362, 32.3410, 'Şehir yerleşkesi girişi'),
        ('PTT Caddesi', 41.6379, 32.3388, 'PTT binası çevresi'),
        ('Hükümet Caddesi', 41.6365, 32.3369, 'Hükümet konağı yaya aksı'),
        ('Yalı Mahallesi Sahil Yolu', 41.6391, 32.3338, 'Sahil yürüyüş yolu'),
        ('İnkum Yolu Kavşağı', 41.6402, 32.3401, 'İnkum yolu yaya geçişi'),
        ('Kemerköprü Mahallesi', 41.6348, 32.3342, 'Mahalle merkezi kaldırımları')
)
insert into public.locations (address, latitude, longitude, description)
select
    nl.address,
    nl.latitude::decimal(10, 8),
    nl.longitude::decimal(11, 8),
    nl.description
from new_locations nl
where not exists (
    select 1
    from public.locations l
    where l.address = nl.address
);

-- ============================================================
-- 2. HER KONUM İÇİN ERİŞİLEBİLİRLİK ÖZELLİĞİ
-- ============================================================
with feature_data (
    address,
    feature_type,
    has_ramp,
    has_elevator,
    has_stairs,
    pavement_status,
    slope_degree,
    sidewalk_width,
    notes
) as (
    values
        ('Cumhuriyet Meydanı Kuzey Geçişi', 'ramp', true, false, false, 'good', 2.0, 2.20, 'Meydan girişinde geniş rampa mevcut.'),
        ('Bartın Belediyesi Önü', 'stairs', false, false, true, 'moderate', 5.0, 1.20, 'Belediye girişinde yüksek basamaklar var; rampa bulunmuyor.'),
        ('Uzun Çarşı Girişi', 'sidewalk', true, false, false, 'moderate', 3.0, 1.60, 'Çarşı girişinde kaldırım daralıyor.'),
        ('Bartın Devlet Hastanesi Yolu', 'stairs', false, false, true, 'moderate', 6.0, 1.30, 'Hastane yaya girişinde basamaklar bulunuyor; rampa yok.'),
        ('Kültür Merkezi Yanı', 'elevator', true, true, false, 'good', 1.0, 1.90, 'Kültür merkezinde engelli asansörü mevcut.'),
        ('Atatürk Parkı', 'sidewalk', false, false, false, 'bad', 5.5, 0.90, 'Park girişinde kaldırım çökük ve dar.'),
        ('Bartın Üniversitesi Şehir Yerleşkesi', 'elevator', true, true, true, 'moderate', 4.0, 1.70, 'Yerleşke girişinde asansör ve merdiven birlikte.'),
        ('PTT Caddesi', 'sidewalk', false, false, false, 'bad', 7.0, 1.10, 'Cadde üzerinde park eden araçlar geçişi zorlaştırıyor.'),
        ('Hükümet Caddesi', 'ramp', true, false, false, 'good', 2.0, 2.30, 'Hükümet konağı önünde rampa mevcut.'),
        ('Yalı Mahallesi Sahil Yolu', 'sidewalk', false, false, false, 'moderate', 3.5, 1.30, 'Sahil yolunda kaldırım yüzeyi dalgalı.'),
        ('İnkum Yolu Kavşağı', 'ramp', true, false, false, 'moderate', 4.5, 1.50, 'Kavşakta rampa var ancak eğim yüksek.'),
        ('Kemerköprü Mahallesi', 'stairs', false, false, true, 'bad', 9.0, 0.85, 'Mahalle merkezinde merdivenli geçiş; rampa yok.')
)
insert into public.accessibility_features (
    location_id,
    feature_type,
    has_ramp,
    has_elevator,
    has_stairs,
    pavement_status,
    slope_degree,
    sidewalk_width,
    notes
)
select
    l.id,
    fd.feature_type::public.feature_type,
    fd.has_ramp,
    fd.has_elevator,
    fd.has_stairs,
    fd.pavement_status::public.pavement_status,
    fd.slope_degree,
    fd.sidewalk_width,
    fd.notes
from feature_data fd
join public.locations l on l.address = fd.address
where not exists (
    select 1
    from public.accessibility_features f
    where f.location_id = l.id
);

-- Raporlar için kullanılabilir profil kontrolü
do $$
begin
    if not exists (select 1 from public.profiles) then
        raise notice '006_seed_more_bartin_data: profiles tablosu boş. Raporlar oluşturulmadı; bir kullanıcı kaydı oluşturup dosyayı tekrar çalıştırın.';
    end if;
end;
$$;

-- ============================================================
-- 3. MOCK RAPORLAR
-- ============================================================
with report_data (address, title, description, status, days_ago) as (
    values
        (
            'Uzun Çarşı Girişi',
            'Bozuk Kaldırım',
            'Kaldırım taşları yerinden oynamış; tekerlekli sandalye ve bebek arabası ile geçerken takılma riski oluşturuyor.',
            'validated',
            1
        ),
        (
            'Bartın Belediyesi Önü',
            'Rampa Eksikliği',
            'Belediye binası girişinde rampa bulunmuyor; yüksek basamaklar nedeniyle tekerlekli sandalye erişimi mümkün değil.',
            'pending',
            2
        ),
        (
            'Uzun Çarşı Girişi',
            'Dar Geçiş',
            'Çarşı girişinde seyyar tezgahlar kaldırımı daraltmış; iki kişinin yan yana geçmesi zor.',
            'validated',
            3
        ),
        (
            'Kültür Merkezi Yanı',
            'Asansör Arızası',
            'Kültür merkezindeki engelli asansörü birkaç gündür çalışmıyor; üst katlara erişim sadece merdivenle sağlanıyor.',
            'validated',
            4
        ),
        (
            'Atatürk Parkı',
            'Bozuk Kaldırım',
            'Park girişindeki kaldırımda çökme var; yağış sonrası su birikintisi oluşuyor.',
            'pending',
            5
        ),
        (
            'Bartın Devlet Hastanesi Yolu',
            'Rampa Eksikliği',
            'Hastane yaya girişine giden güzergahta rampa yok; kaldırım ile yol arasında yükseklik farkı bulunuyor.',
            'pending',
            6
        ),
        (
            'PTT Caddesi',
            'Dar Geçiş',
            'PTT Caddesi üzerinde kaldırıma park eden araçlar yüzünden geçiş alanı çok daralıyor.',
            'validated',
            7
        ),
        (
            'Bartın Üniversitesi Şehir Yerleşkesi',
            'Asansör Arızası',
            'Şehir yerleşkesindeki asansörün kapıları zor kapanıyor ve sesli uyarı çalışmıyor.',
            'pending',
            8
        ),
        (
            'Yalı Mahallesi Sahil Yolu',
            'Bozuk Kaldırım',
            'Sahil yürüyüş yolunda kırık beton parçaları ve düzensiz zemin var.',
            'pending',
            9
        ),
        (
            'Kemerköprü Mahallesi',
            'Rampa Eksikliği',
            'Mahalle merkezindeki kaldırım ile cadde arasında rampa bulunmuyor; geçiş için yüksek basamaklar kullanılıyor.',
            'validated',
            10
        )
),
seed_user as (
    select id as user_id
    from public.profiles
    order by created_at asc
    limit 1
)
insert into public.reports (
    user_id,
    location_id,
    title,
    description,
    status,
    created_at
)
select
    u.user_id,
    l.id,
    rd.title,
    rd.description,
    rd.status::public.report_status,
    now() - make_interval(days => rd.days_ago)
from report_data rd
join public.locations l on l.address = rd.address
cross join seed_user u
where not exists (
    select 1
    from public.reports r
    where r.location_id = l.id
      and r.title = rd.title
);
