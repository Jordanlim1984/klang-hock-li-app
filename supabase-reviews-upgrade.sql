-- Review enhancement migration: run once in Supabase SQL Editor.
alter table public.customer_reviews add column if not exists author_name text;
create or replace function public.set_review_author_name() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  select coalesce(nullif(left(trim(p.display_name),80),''),'Customer') into new.author_name
  from public.profiles p where p.id = new.user_id;
  new.author_name := coalesce(new.author_name,'Customer');
  return new;
end; $$;
drop trigger if exists review_author_name_on_insert on public.customer_reviews;
create trigger review_author_name_on_insert before insert on public.customer_reviews
for each row execute function public.set_review_author_name();
update public.customer_reviews r
set author_name = coalesce(nullif(left(trim(p.display_name),80),''),'Customer')
from public.profiles p where r.user_id=p.id and r.author_name is null;
update public.customer_reviews set author_name='Customer' where author_name is null;
drop policy if exists "Admin deletes reviews" on public.customer_reviews;
create policy "Admin deletes reviews" on public.customer_reviews for delete to authenticated using (public.is_review_admin());
grant delete on public.customer_reviews to authenticated;
