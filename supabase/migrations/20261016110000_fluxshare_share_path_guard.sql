drop policy if exists "owners can create 24 hour shares" on public.share_links;

create policy "owners can create 24 hour shares"
  on public.share_links for insert to authenticated
  with check (
    owner_id = (select auth.uid())
    and storage_path = owner_id::text || '/' || id::text
    and revoked_at is null
    and expires_at > now()
    and expires_at <= now() + interval '24 hours'
  );
