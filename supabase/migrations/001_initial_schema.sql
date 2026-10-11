-- ============================================================
-- Migration: 001_initial_schema
-- Description: Çekirdek tablolar
-- Author: Fatima Gulamova
-- Date: 2026
-- ============================================================

create extension if not exists "uuid-ossp";

-- ENUM TÜRLERİ
create type public.user_role as enum ('user', 'volunteer', 'admin');
create type public.report_status as enum ('pending', 'validated', 'rejected', 'resolved');
create type public.feature_type as enum ('ramp', 'stairs', 'elevator', 'sidewalk', 'toilet', 'entrance', 'other');
create type public.pavement_status as enum ('good', 'moderate', 'bad');
create type public.algorithm_type as enum ('dijkstra', 'astar');

-- TABLO: profiles
create table public.profiles (
    id            uuid primary key references auth.users(id) on delete cascade,
    full_name     varchar(100) not null,
    email         varchar(255) not null unique,
    phone         varchar(20),
    role          public.user_role not null default 'user',
    is_active     boolean not null default true,
    created_at    timestamptz not null default now(),
    updated_at    timestamptz not null default now()
);

create index idx_profiles_role on public.profiles(role);
create index idx_profiles_active on public.profiles(is_active);

-- TABLO: locations
create table public.locations (
    id            uuid primary key default uuid_generate_v4(),
    address       varchar(255),
    latitude      decimal(10, 8) not null,
    longitude     decimal(11, 8) not null,
    geom          geography(Point, 4326),
    description   text,
    created_at    timestamptz not null default now(),
    updated_at    timestamptz not null default now()
);

create index idx_locations_geom on public.locations using gist(geom);

-- TABLO: accessibility_features
create table public.accessibility_features (
    id                uuid primary key default uuid_generate_v4(),
    location_id       uuid not null references public.locations(id) on delete cascade,
    feature_type      public.feature_type not null,
    has_ramp          boolean default false,
    has_elevator      boolean default false,
    has_stairs        boolean default false,
    has_toilet        boolean default false,
    pavement_status   public.pavement_status default 'moderate',
    slope_degree      decimal(4, 1) default 0.0,
    sidewalk_width    decimal(4, 2) default 1.5,
    notes             text,
    created_at        timestamptz not null default now(),
    updated_at        timestamptz not null default now()
);

create index idx_features_location on public.accessibility_features(location_id);
create index idx_features_type on public.accessibility_features(feature_type);

-- TABLO: reports
create table public.reports (
    id            uuid primary key default uuid_generate_v4(),
    user_id       uuid not null references public.profiles(id) on delete cascade,
    location_id   uuid not null references public.locations(id) on delete cascade,
    title         varchar(150) not null,
    description   text,
    photo_url     text,
    status        public.report_status not null default 'pending',
    created_at    timestamptz not null default now(),
    updated_at    timestamptz not null default now()
);

create index idx_reports_user on public.reports(user_id);
create index idx_reports_location on public.reports(location_id);
create index idx_reports_status on public.reports(status);

-- TABLO: validations
create table public.validations (
    id             uuid primary key default uuid_generate_v4(),
    report_id      uuid not null references public.reports(id) on delete cascade,
    user_id        uuid not null references public.profiles(id) on delete cascade,
    is_valid       boolean not null,
    notes          text,
    validated_at   timestamptz not null default now(),
    created_at     timestamptz not null default now(),
    unique (report_id, user_id)
);

create index idx_validations_report on public.validations(report_id);
create index idx_validations_user on public.validations(user_id);

-- TABLO: routes
create table public.routes (
    id                  uuid primary key default uuid_generate_v4(),
    user_id             uuid references public.profiles(id) on delete set null,
    name                varchar(150),
    start_location_id   uuid references public.locations(id) on delete set null,
    end_location_id     uuid references public.locations(id) on delete set null,
    distance_km         decimal(6, 2),
    accessibility_score decimal(5, 2),
    algorithm           public.algorithm_type default 'astar',
    path_data           jsonb,
    created_at          timestamptz not null default now(),
    updated_at          timestamptz not null default now()
);

create index idx_routes_user on public.routes(user_id);