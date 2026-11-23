-- Run once in Supabase SQL Editor. Review permissions before applying.
create table if not exists public.customer_reviews (
 id uuid primary key default gen_random_uuid(),
 user_id uuid not null references auth.users(id) on delete cascade,
 review_type text not null check (review_type in ('service','product')),
 product_id uuid references public.products(id) on delete set null,
 rating integer not null check (rating between 1 and 5),
 comment text not null check (char_length(trim(comment)) between 5 and 1000),
 status text not null default 'pending' check (status in ('pending','approved','rejected')),
 created_at timestamptz not null default now(),
 constraint product_review_target check (review_type <> 'product' or product_id is not null)
);
create index if not exists customer_reviews_status_created_idx on public.customer_reviews(status,created_at desc);
create index if not exists customer_reviews_product_idx on public.customer_reviews(product_id);
alter table public.customer_reviews enable row level security;
create or replace function public.is_review_admin() returns boolean language sql stable security definer set search_path = '' as $$
 select exists(select 1 from public.profiles where id=auth.uid() and role='admin' and active=true);
$$;
revoke all on function public.is_review_admin() from public;
grant execute on function public.is_review_admin() to authenticated, anon;
drop policy if exists "Anyone reads approved reviews" on public.customer_reviews;
create policy "Anyone reads approved reviews" on public.customer_reviews for select to anon,authenticated using (status='approved');
drop policy if exists "Authors read own reviews" on public.customer_reviews;
create policy "Authors read own reviews" on public.customer_reviews for select to authenticated using (user_id=auth.uid());
drop policy if exists "Admin reads all reviews" on public.customer_reviews;
create policy "Admin reads all reviews" on public.customer_reviews for select to authenticated using (public.is_review_admin());
drop policy if exists "Customers submit pending reviews" on public.customer_reviews;
create policy "Customers submit pending reviews" on public.customer_reviews for insert to authenticated with check (user_id=auth.uid() and status='pending' and exists(select 1 from public.profiles where id=auth.uid() and role='viewer' and active=true));
drop policy if exists "Admin moderates reviews" on public.customer_reviews;
create policy "Admin moderates reviews" on public.customer_reviews for update to authenticated using (public.is_review_admin()) with check (public.is_review_admin());
-- Column grants prevent clients from modifying reviews except admin moderation fields.
revoke all on public.customer_reviews from anon,authenticated;
grant select on public.customer_reviews to anon,authenticated;
grant insert (user_id,review_type,product_id,rating,comment) on public.customer_reviews to authenticated;
grant update (status) on public.customer_reviews to authenticated;
