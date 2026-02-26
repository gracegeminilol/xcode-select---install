-- Phase 1 schema for UIUC hyper-local short-term subleasing app
-- Intended for Supabase Postgres

create extension if not exists "pgcrypto";
create extension if not exists "citext";

-- ---------- ENUMS ----------
create type public.user_type as enum ('student', 'resident');
create type public.verification_status as enum ('pending', 'verified', 'rejected');
create type public.break_category as enum (
  'thanksgiving_break',
  'winter_break',
  'spring_break',
  'summer_holiday',
  'custom'
);
create type public.listing_status as enum ('draft', 'active', 'booked', 'completed', 'cancelled');
create type public.transaction_status as enum (
  'initiated',
  'funds_held',
  'release_pending',
  'released',
  'refunded',
  'failed'
);

-- ---------- PROFILES ----------
create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email citext not null unique,
  full_name text,
  phone_number text,
  user_type public.user_type not null,
  is_uiuc_student boolean generated always as (email like '%@illinois.edu') stored,
  id_verification_status public.verification_status not null default 'pending',
  stripe_customer_id text,
  stripe_connect_account_id text,
  stripe_identity_verification_session_id text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint student_email_guard check (
    (user_type = 'student' and email like '%@illinois.edu')
    or user_type = 'resident'
  )
);

create index profiles_user_type_idx on public.profiles(user_type);
create index profiles_verification_idx on public.profiles(id_verification_status);

-- ---------- LISTINGS ----------
create table public.listings (
  id uuid primary key default gen_random_uuid(),
  lessor_id uuid not null references public.profiles(id) on delete cascade,
  title text not null,
  description text,
  address_line_1 text not null,
  address_line_2 text,
  city text not null default 'Urbana-Champaign',
  state text not null default 'IL',
  postal_code text,
  latitude numeric(9,6),
  longitude numeric(9,6),
  monthly_rent_cents integer not null check (monthly_rent_cents > 0),
  utility_cap_cents integer not null default 0 check (utility_cap_cents >= 0),
  roommate_count integer not null default 0 check (roommate_count >= 0),
  lease_start_date date not null,
  lease_end_date date not null,
  break_category public.break_category not null,
  max_stay_days integer not null generated always as ((lease_end_date - lease_start_date) + 1) stored,
  status public.listing_status not null default 'draft',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint lease_dates_valid check (lease_end_date >= lease_start_date),
  constraint lease_max_3_months check ((lease_end_date - lease_start_date) <= 92),
  constraint block_uiuc_housing check (
    lower(address_line_1) not similar to '%(far|par|isr|nugent|allen hall|lincoln avenue residence|ike|bousfield|wassaja|larm|lar|taft|weston|snyder)%'
  )
);

create index listings_lessor_idx on public.listings(lessor_id);
create index listings_break_idx on public.listings(break_category);
create index listings_status_idx on public.listings(status);
create index listings_dates_idx on public.listings(lease_start_date, lease_end_date);

-- ---------- ESCROW TRANSACTIONS ----------
create table public.transactions (
  id uuid primary key default gen_random_uuid(),
  listing_id uuid not null references public.listings(id) on delete restrict,
  lessor_id uuid not null references public.profiles(id) on delete restrict,
  sublessee_id uuid not null references public.profiles(id) on delete restrict,
  stripe_payment_intent_id text unique,
  stripe_transfer_id text,
  stripe_connect_account_id text,
  total_amount_cents integer not null check (total_amount_cents > 0),
  escrow_fee_cents integer not null default 0 check (escrow_fee_cents >= 0),
  platform_fee_cents integer not null default 0 check (platform_fee_cents >= 0),
  currency text not null default 'usd',
  status public.transaction_status not null default 'initiated',
  funds_held_at timestamptz,
  payout_released_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint lessor_sublessee_must_differ check (lessor_id <> sublessee_id)
);

create index transactions_listing_idx on public.transactions(listing_id);
create index transactions_lessor_idx on public.transactions(lessor_id);
create index transactions_sublessee_idx on public.transactions(sublessee_id);
create index transactions_status_idx on public.transactions(status);

-- ---------- CONVERSATIONS & MESSAGES ----------
create table public.conversations (
  id uuid primary key default gen_random_uuid(),
  listing_id uuid not null references public.listings(id) on delete cascade,
  created_by uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  unique(listing_id, created_by)
);

create table public.conversation_participants (
  conversation_id uuid not null references public.conversations(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  joined_at timestamptz not null default now(),
  primary key (conversation_id, user_id)
);

create table public.messages (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.conversations(id) on delete cascade,
  sender_id uuid not null references public.profiles(id) on delete cascade,
  body text not null,
  is_read boolean not null default false,
  created_at timestamptz not null default now()
);

create index messages_conversation_idx on public.messages(conversation_id, created_at);
create index participants_user_idx on public.conversation_participants(user_id);

-- ---------- TIMESTAMP TRIGGER ----------
create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger profiles_updated_at
before update on public.profiles
for each row execute function public.set_updated_at();

create trigger listings_updated_at
before update on public.listings
for each row execute function public.set_updated_at();

create trigger transactions_updated_at
before update on public.transactions
for each row execute function public.set_updated_at();

-- ---------- RLS ----------
alter table public.profiles enable row level security;
alter table public.listings enable row level security;
alter table public.transactions enable row level security;
alter table public.conversations enable row level security;
alter table public.conversation_participants enable row level security;
alter table public.messages enable row level security;

-- Profiles: users can read verified profiles, update only themselves.
create policy "profiles_select_verified"
on public.profiles
for select
using (id_verification_status = 'verified' or auth.uid() = id);

create policy "profiles_update_own"
on public.profiles
for update
using (auth.uid() = id)
with check (auth.uid() = id);

-- Listings: anyone authenticated can read active listings; owners manage their listings.
create policy "listings_select_active"
on public.listings
for select
using (status = 'active' or auth.uid() = lessor_id);

create policy "listings_insert_own"
on public.listings
for insert
with check (auth.uid() = lessor_id);

create policy "listings_update_own"
on public.listings
for update
using (auth.uid() = lessor_id)
with check (auth.uid() = lessor_id);

-- Transactions: involved parties only.
create policy "transactions_select_party"
on public.transactions
for select
using (auth.uid() in (lessor_id, sublessee_id));

create policy "transactions_insert_sublessee"
on public.transactions
for insert
with check (auth.uid() = sublessee_id);

-- Conversations and messages are visible only to participants.
create policy "conversations_select_participants"
on public.conversations
for select
using (
  exists (
    select 1 from public.conversation_participants cp
    where cp.conversation_id = id and cp.user_id = auth.uid()
  )
);

create policy "participants_select_own"
on public.conversation_participants
for select
using (user_id = auth.uid());

create policy "messages_select_participant"
on public.messages
for select
using (
  exists (
    select 1 from public.conversation_participants cp
    where cp.conversation_id = conversation_id and cp.user_id = auth.uid()
  )
);

create policy "messages_insert_sender_participant"
on public.messages
for insert
with check (
  auth.uid() = sender_id and
  exists (
    select 1 from public.conversation_participants cp
    where cp.conversation_id = conversation_id and cp.user_id = auth.uid()
  )
);
