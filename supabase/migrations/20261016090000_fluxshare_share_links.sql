create table if not exists public.share_links (
  id uuid primary key,
  owner_id uuid not null references auth.users(id) on delete cascade,
  storage_path text not null unique,
  file_name text not null check (char_length(file_name) between 1 and 255),
  content_type text not null,
  size_bytes bigint not null check (size_bytes between 1 and 52428800),
  created_at timestamptz not null default now(),
  expires_at timestamptz not null,
  revoked_at timestamptz,
  constraint share_links_expiry_window check (
    expires_at > created_at and expires_at <= created_at + interval '24 hours'
  )
);

create index if not exists share_links_active_expiry_idx
  on public.share_links (expires_at)
  where revoked_at is null;
create index if not exists share_links_owner_created_idx
  on public.share_links (owner_id, created_at desc);

alter table public.share_links enable row level security;

create policy "public can read active shares"
  on public.share_links for select to anon
  using (revoked_at is null and expires_at > now());

create policy "authenticated users can read active or owned shares"
  on public.share_links for select to authenticated
  using (
    owner_id = (select auth.uid())
    or (revoked_at is null and expires_at > now())
  );

create policy "owners can create 24 hour shares"
  on public.share_links for insert to authenticated
  with check (
    owner_id = (select auth.uid())
    and revoked_at is null
    and expires_at > now()
    and expires_at <= now() + interval '24 hours'
  );

create policy "owners can delete their shares"
  on public.share_links for delete to authenticated
  using (owner_id = (select auth.uid()));

grant select, insert, delete on public.share_links to authenticated;
grant select on public.share_links to anon;

create table if not exists public.daily_usage (
  user_id uuid not null references auth.users(id) on delete cascade,
  usage_date date not null default (timezone('utc', now()))::date,
  slot smallint not null check (slot between 1 and 3),
  primary key (user_id, usage_date, slot)
);

alter table public.daily_usage enable row level security;

create policy "users can read their daily usage"
  on public.daily_usage for select to authenticated
  using (user_id = (select auth.uid()));

create policy "users can reserve one of three daily slots"
  on public.daily_usage for insert to authenticated
  with check (
    user_id = (select auth.uid())
    and usage_date = (timezone('utc', now()))::date
    and slot between 1 and 3
  );

grant select, insert on public.daily_usage to authenticated;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'shared-files',
  'shared-files',
  false,
  52428800,
  array[
    'image/jpeg', 'image/png', 'image/webp', 'image/gif',
    'application/pdf', 'text/plain', 'text/html', 'audio/mpeg', 'audio/wav',
    'application/octet-stream'
  ]
)
on conflict (id) do update set
  public = false,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

create policy "authenticated owners can upload their shares"
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'shared-files'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

create policy "public can download active shares"
  on storage.objects for select to anon, authenticated
  using (
    bucket_id = 'shared-files'
    and exists (
      select 1
      from public.share_links s
      where s.storage_path = storage.objects.name
        and s.revoked_at is null
        and s.expires_at > now()
    )
  );

create policy "authenticated owners can delete their uploads"
  on storage.objects for delete to authenticated
  using (
    bucket_id = 'shared-files'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );
