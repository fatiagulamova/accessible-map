-- ============================================================
-- Migration: 004_rls_policies
-- Description: Row Level Security politikaları
-- ============================================================

alter table public.profiles              enable row level security;
alter table public.locations             enable row level security;
alter table public.accessibility_features enable row level security;
alter table public.reports               enable row level security;
alter table public.validations           enable row level security;
alter table public.routes                enable row level security;

create or replace function public.current_user_role()
returns public.user_role
as $$
    select role from public.profiles where id = auth.uid();
$$ language sql stable security definer;

-- profiles
create policy "Profiles: herkes okuyabilir"
on public.profiles for select using (true);

create policy "Profiles: kullanıcı kendini güncelleyebilir"
on public.profiles for update using (auth.uid() = id) with check (auth.uid() = id);

create policy "Profiles: admin herkesi güncelleyebilir"
on public.profiles for update using (public.current_user_role() = 'admin');

-- locations
create policy "Locations: herkes okuyabilir"
on public.locations for select using (true);

create policy "Locations: giriş yapan ekleyebilir"
on public.locations for insert with check (auth.uid() is not null);

-- accessibility_features
create policy "Features: herkes okuyabilir"
on public.accessibility_features for select using (true);

create policy "Features: giriş yapan ekleyebilir"
on public.accessibility_features for insert with check (auth.uid() is not null);

-- reports
create policy "Reports: herkes okuyabilir"
on public.reports for select using (true);

create policy "Reports: giriş yapan ekleyebilir"
on public.reports for insert with check (auth.uid() = user_id);

create policy "Reports: sahibi güncelleyebilir"
on public.reports for update using (auth.uid() = user_id);

create policy "Reports: admin silebilir"
on public.reports for delete using (public.current_user_role() = 'admin');

-- validations
create policy "Validations: herkes okuyabilir"
on public.validations for select using (true);

create policy "Validations: giriş yapan ekleyebilir"
on public.validations for insert with check (auth.uid() = user_id);

-- routes
create policy "Routes: sadece sahibi okuyabilir"
on public.routes for select using (auth.uid() = user_id);

create policy "Routes: sahibi ekleyebilir"
on public.routes for insert with check (auth.uid() = user_id);