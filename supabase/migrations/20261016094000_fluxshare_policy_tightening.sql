drop policy if exists "public can read active shares" on public.share_links;
drop policy if exists "owners can read their shares" on public.share_links;
drop policy if exists "authenticated users can read active or owned shares" on public.share_links;
drop policy if exists "owners can revoke their shares" on public.share_links;

create policy "public can read active shares"
  on public.share_links for select to anon
  using (revoked_at is null and expires_at > now());

create policy "authenticated users can read active or owned shares"
  on public.share_links for select to authenticated
  using (
    owner_id = (select auth.uid())
    or (revoked_at is null and expires_at > now())
  );

drop policy if exists "owners can revoke their shares" on public.share_links;
revoke update on public.share_links from authenticated;

create index if not exists share_links_owner_created_idx
  on public.share_links (owner_id, created_at desc);

drop function if exists public.consume_conversion();

alter table public.daily_usage drop constraint if exists daily_usage_pkey;
alter table public.daily_usage drop column if exists conversions;
alter table public.daily_usage add column if not exists slot smallint not null default 1;
alter table public.daily_usage alter column slot drop default;
alter table public.daily_usage add constraint daily_usage_slot_check check (slot between 1 and 3);
alter table public.daily_usage add constraint daily_usage_pkey primary key (user_id, usage_date, slot);

drop policy if exists "users can reserve one of three daily slots" on public.daily_usage;
create policy "users can reserve one of three daily slots"
  on public.daily_usage for insert to authenticated
  with check (
    user_id = (select auth.uid())
    and usage_date = (timezone('utc', now()))::date
    and slot between 1 and 3
  );
grant insert on public.daily_usage to authenticated;
