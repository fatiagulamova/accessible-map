-- ============================================================
-- Migration: 003_functions_triggers
-- Description: updated_at, erişilebilirlik skoru, doğrulama
-- ============================================================

-- updated_at otomatik güncelleme
create or replace function public.set_updated_at()
returns trigger as $$
begin
    new.updated_at := now();
    return new;
end;
$$ language plpgsql;

create trigger trg_profiles_updated before update on public.profiles
for each row execute function public.set_updated_at();

create trigger trg_locations_updated before update on public.locations
for each row execute function public.set_updated_at();

create trigger trg_reports_updated before update on public.reports
for each row execute function public.set_updated_at();

create trigger trg_features_updated before update on public.accessibility_features
for each row execute function public.set_updated_at();

create trigger trg_routes_updated before update on public.routes
for each row execute function public.set_updated_at();

-- Erişilebilirlik skoru hesaplama
create or replace function public.calculate_accessibility_score(
    p_has_ramp        boolean,
    p_has_elevator    boolean,
    p_has_stairs      boolean,
    p_has_toilet      boolean,
    p_pavement_status public.pavement_status,
    p_slope_degree    decimal,
    p_sidewalk_width  decimal
)
returns decimal
as $$
declare
    v_score decimal := 50.0;
begin
    if p_has_ramp then v_score := v_score + 15; end if;
    if p_has_elevator then v_score := v_score + 10; end if;
    if p_has_toilet then v_score := v_score + 5; end if;

    case p_pavement_status
        when 'good' then v_score := v_score + 10;
        when 'moderate' then v_score := v_score + 0;
        when 'bad' then v_score := v_score - 20;
    end case;

    if p_slope_degree > 5 then
        v_score := v_score - (p_slope_degree - 5) * 2;
    end if;

    if p_sidewalk_width < 1.5 then
        v_score := v_score - 15;
    elsif p_sidewalk_width >= 2.0 then
        v_score := v_score + 5;
    end if;

    if p_has_stairs then v_score := v_score - 40; end if;

    if v_score < 0 then v_score := 0; end if;
    if v_score > 100 then v_score := 100; end if;

    return round(v_score, 2);
end;
$$ language plpgsql immutable;

-- Otomatik doğrulama
create or replace function public.auto_validate_report()
returns trigger as $$
declare
    v_total       integer;
    v_positives   integer;
    v_ratio       decimal;
    v_min_votes   constant integer := 5;
    v_threshold   constant decimal := 0.7;
begin
    select count(*), count(*) filter (where is_valid = true)
    into v_total, v_positives
    from public.validations
    where report_id = new.report_id;

    if v_total >= v_min_votes then
        v_ratio := v_positives::decimal / v_total;
        if v_ratio >= v_threshold then
            update public.reports set status = 'validated'
            where id = new.report_id and status = 'pending';
        elsif v_ratio < (1 - v_threshold) then
            update public.reports set status = 'rejected'
            where id = new.report_id and status = 'pending';
        end if;
    end if;
    return new;
end;
$$ language plpgsql;

create trigger trg_auto_validate_report
after insert on public.validations
for each row execute function public.auto_validate_report();

-- Yeni auth.users → profiles
create or replace function public.handle_new_user()
returns trigger as $$
begin
    insert into public.profiles (id, full_name, email, role)
    values (
        new.id,
        coalesce(new.raw_user_meta_data->>'full_name', 'Anonim Kullanıcı'),
        new.email,
        'user'
    );
    return new;
end;
$$ language plpgsql security definer;

create trigger trg_on_auth_user_created
after insert on auth.users
for each row execute function public.handle_new_user();