-- Klang Hock Li V6: customer registration metadata and admin notifications.
-- This migration does NOT implement password authentication.
-- Run in Supabase SQL Editor after reviewing it.
create table if not exists public.customer_accounts (
  id uuid primary key default gen_random_uuid(),
  phone text not null unique,
  display_name text not null,
  active boolean not null default true,
  registered_at timestamptz not null default now(),
  last_login_at timestamptz,
  login_count integer not null default 0
);
create table if not exists public.admin_notifications (
  id uuid primary key default gen_random_uuid(),
  customer_account_id uuid references public.customer_accounts(id) on delete cascade,
  title text not null,
  created_at timestamptz not null default now(),
  read_at timestamptz
);
alter table public.customer_accounts enable row level security;
alter table public.admin_notifications enable row level security;
-- Only active admins can read these records using the normal authenticated client.
create policy "v6_admin_read_customer_accounts" on public.customer_accounts
for select to authenticated using (
  exists(select 1 from public.profiles p where p.id=auth.uid() and p.role='admin' and p.active=true)
);
create policy "v6_admin_read_notifications" on public.admin_notifications
for select to authenticated using (
  exists(select 1 from public.profiles p where p.id=auth.uid() and p.role='admin' and p.active=true)
);
-- Writes are intentionally not exposed to public clients; secure backend required.
