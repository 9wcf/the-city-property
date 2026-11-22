-- Tenant documents + lease contract images.
-- Private storage bucket, metadata table, and access policies scoped through
-- the lease -> apartment -> building -> compound chain.

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'tenant-documents',
  'tenant-documents',
  false,
  10485760,
  array['image/jpeg', 'image/png', 'image/webp', 'image/heic', 'application/pdf']
)
on conflict (id) do update
  set public = false,
      file_size_limit = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

-- ------------------------------------------------------------------ helpers

create or replace function public.lease_is_accessible(p_lease uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
      from public.leases l
      join public.apartments a on a.id = l.apartment_id
      join public.floors f on f.id = a.floor_id
      join public.buildings b on b.id = f.building_id
      join public.compounds c on c.id = b.compound_id
     where l.id = p_lease
       and (
         l.tenant_id = auth.uid()
         or c.owner_id = auth.uid()
         or exists (
           select 1
             from public.manager_assignments ma
            where ma.manager_id = auth.uid()
              and ma.compound_id = c.id
              and coalesce(ma.is_active, true)
         )
       )
  );
$$;

create or replace function public.lease_is_manageable(p_lease uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
      from public.leases l
      join public.apartments a on a.id = l.apartment_id
      join public.floors f on f.id = a.floor_id
      join public.buildings b on b.id = f.building_id
      join public.compounds c on c.id = b.compound_id
     where l.id = p_lease
       and (
         c.owner_id = auth.uid()
         or exists (
           select 1
             from public.manager_assignments ma
            where ma.manager_id = auth.uid()
              and ma.compound_id = c.id
              and coalesce(ma.is_active, true)
         )
       )
  );
$$;

-- Safe path-based variants used by storage policies. They never raise on
-- malformed object names; they simply deny access.
create or replace function public.lease_path_is_accessible(p_name text)
returns boolean
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_lease uuid;
begin
  begin
    v_lease := (storage.foldername(p_name))[1]::uuid;
  exception when others then
    return false;
  end;
  return public.lease_is_accessible(v_lease);
end;
$$;

create or replace function public.lease_path_is_manageable(p_name text)
returns boolean
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_lease uuid;
begin
  begin
    v_lease := (storage.foldername(p_name))[1]::uuid;
  exception when others then
    return false;
  end;
  return public.lease_is_manageable(v_lease);
end;
$$;

revoke all on function public.lease_is_accessible(uuid) from public, anon;
revoke all on function public.lease_is_manageable(uuid) from public, anon;
revoke all on function public.lease_path_is_accessible(text) from public, anon;
revoke all on function public.lease_path_is_manageable(text) from public, anon;
grant execute on function public.lease_is_accessible(uuid) to authenticated;
grant execute on function public.lease_is_manageable(uuid) to authenticated;
grant execute on function public.lease_path_is_accessible(text) to authenticated;
grant execute on function public.lease_path_is_manageable(text) to authenticated;

-- ------------------------------------------------------------- metadata table

create table if not exists public.lease_documents (
  id            uuid primary key default gen_random_uuid(),
  lease_id      uuid not null references public.leases(id) on delete cascade,
  tenant_id     uuid not null references public.profiles(id) on delete cascade,
  apartment_id  uuid references public.apartments(id) on delete set null,
  kind          text not null default 'tenant'
                check (kind in ('tenant', 'contract', 'other')),
  storage_path  text not null unique,
  file_name     text,
  mime_type     text,
  size_bytes    bigint not null default 0,
  uploaded_by   uuid references public.profiles(id) on delete set null,
  created_at    timestamptz not null default now()
);

create index if not exists lease_documents_lease_idx
  on public.lease_documents (lease_id, kind, created_at);

alter table public.lease_documents enable row level security;

drop policy if exists lease_documents_select on public.lease_documents;
create policy lease_documents_select on public.lease_documents
  for select to authenticated
  using (public.lease_is_accessible(lease_id));

drop policy if exists lease_documents_insert on public.lease_documents;
create policy lease_documents_insert on public.lease_documents
  for insert to authenticated
  with check (public.lease_is_manageable(lease_id));

drop policy if exists lease_documents_delete on public.lease_documents;
create policy lease_documents_delete on public.lease_documents
  for delete to authenticated
  using (public.lease_is_manageable(lease_id));

revoke all on public.lease_documents from public, anon;
grant select, insert, delete on public.lease_documents to authenticated;

-- ----------------------------------------------------------- storage policies

drop policy if exists "tenant_documents_read" on storage.objects;
create policy "tenant_documents_read"
on storage.objects
for select
to authenticated
using (
  bucket_id = 'tenant-documents'
  and public.lease_path_is_accessible(name)
);

drop policy if exists "tenant_documents_upload" on storage.objects;
create policy "tenant_documents_upload"
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'tenant-documents'
  and public.lease_path_is_manageable(name)
);

drop policy if exists "tenant_documents_delete" on storage.objects;
create policy "tenant_documents_delete"
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'tenant-documents'
  and public.lease_path_is_manageable(name)
);
