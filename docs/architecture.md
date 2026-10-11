# Mimari

## Katmanlar
1. **Client (Flutter)** → Kullanıcı arayüzü, harita, formlar
2. **Supabase (Backend)** → Auth, PostgreSQL/PostGIS, Storage, Edge Functions
3. **Edge Functions** → Erişilebilirlik skoru, rota algoritması, doğrulama mantığı

## Admin Panel
- Rol tabanlı erişim (RBAC): `user`, `volunteer`, `admin`
- Admin kullanıcıları bildirimleri yönetir, analitik görür
- İlerleyen aşamada ayrı bir Flutter Web modülü olarak geliştirilecek