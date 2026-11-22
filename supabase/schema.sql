-- ============================================================================
-- The City Property — completion migration
-- نفّذ هذا الملف مرة واحدة في Supabase → SQL Editor.
-- الملف idempotent: يمكن تنفيذه أكثر من مرة دون أخطاء.
-- يفترض وجود الجداول الأساسية:
--   profiles, compounds, buildings, floors, apartments,
--   leases, tenant_apartments, payments, manager_assignments
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 0) قيم enum مطلوبة لسير عمل ربط المستأجر
--    (شوهد خطأ: invalid input value for enum lease_status: "pending")
-- ----------------------------------------------------------------------------
alter type public.lease_status add value if not exists 'pending';
alter type public.lease_status add value if not exists 'rejected';

-- ----------------------------------------------------------------------------
-- 1) أعمدة ناقصة في طلبات الصيانة
-- ----------------------------------------------------------------------------
alter table public.maintenance_requests
  add column if not exists image_urls text[] default '{}'::text[],
  add column if not exists manager_notes text,
  add column if not exists rejection_reason text;

-- قيم افتراضية آمنة للطلبات القديمة
update public.maintenance_requests
   set image_urls = '{}'::text[]
 where image_urls is null;

update public.maintenance_requests
   set owner_approval_status = 'pending'
 where owner_approval_status is null;

-- ----------------------------------------------------------------------------
-- 2) محادثة كل طلب صيانة (مستأجر ↔ مدير ↔ مالك)
-- ----------------------------------------------------------------------------
create table if not exists public.maintenance_messages (
  id          uuid primary key default gen_random_uuid(),
  request_id  uuid not null references public.maintenance_requests(id) on delete cascade,
  sender_id   uuid not null references public.profiles(id) on delete cascade,
  body        text not null check (char_length(trim(body)) > 0),
  created_at  timestamptz not null default now()
);

create index if not exists maintenance_messages_request_idx
  on public.maintenance_messages (request_id, created_at);

-- ----------------------------------------------------------------------------
-- 3) فهارس الأداء
-- ----------------------------------------------------------------------------
create index if not exists maintenance_requests_apartment_idx
  on public.maintenance_requests (apartment_id, created_at desc);

create index if not exists maintenance_requests_tenant_idx
  on public.maintenance_requests (tenant_id, created_at desc);

create index if not exists maintenance_requests_status_idx
  on public.maintenance_requests (status);

create index if not exists maintenance_requests_approval_idx
  on public.maintenance_requests (owner_approval_status);

create index if not exists payments_tenant_date_idx
  on public.payments (tenant_id, payment_date desc);

create index if not exists leases_apartment_status_idx
  on public.leases (apartment_id, status);

create index if not exists tenant_apartments_current_idx
  on public.tenant_apartments (apartment_id, is_current);

-- ----------------------------------------------------------------------------
-- 4) RLS لجدول المحادثة
--    القراءة/الكتابة: المستأجر صاحب الطلب، مالك العقار، المدير المسؤول.
-- ----------------------------------------------------------------------------
alter table public.maintenance_messages enable row level security;

drop policy if exists "maintenance_messages_select_participants" on public.maintenance_messages;
create policy "maintenance_messages_select_participants"
on public.maintenance_messages
for select
to authenticated
using (
  exists (
    select 1
      from public.maintenance_requests r
     where r.id = maintenance_messages.request_id
       and (
         r.tenant_id = auth.uid()
         or exists (
           select 1
             from public.apartments a
             join public.floors f    on f.id = a.floor_id
             join public.buildings b on b.id = f.building_id
             join public.compounds c on c.id = b.compound_id
            where a.id = r.apartment_id
              and c.owner_id = auth.uid()
         )
         or exists (
           select 1
             from public.apartments a
             join public.floors f on f.id = a.floor_id
             join public.buildings b on b.id = f.building_id
             join public.manager_assignments ma on ma.compound_id = b.compound_id
            where a.id = r.apartment_id
              and ma.manager_id = auth.uid()
         )
       )
  )
);

drop policy if exists "maintenance_messages_insert_participants" on public.maintenance_messages;
create policy "maintenance_messages_insert_participants"
on public.maintenance_messages
for insert
to authenticated
with check (
  sender_id = auth.uid()
  and exists (
    select 1
      from public.maintenance_requests r
     where r.id = maintenance_messages.request_id
       and (
         r.tenant_id = auth.uid()
         or exists (
           select 1
             from public.apartments a
             join public.floors f    on f.id = a.floor_id
             join public.buildings b on b.id = f.building_id
             join public.compounds c on c.id = b.compound_id
            where a.id = r.apartment_id
              and c.owner_id = auth.uid()
         )
         or exists (
           select 1
             from public.apartments a
             join public.floors f on f.id = a.floor_id
             join public.buildings b on b.id = f.building_id
             join public.manager_assignments ma on ma.compound_id = b.compound_id
            where a.id = r.apartment_id
              and ma.manager_id = auth.uid()
         )
       )
  )
);

-- ----------------------------------------------------------------------------
-- 5) مخزن صور الصيانة (Storage)
--    عام للقراءة كي تعمل image_urls مباشرة، والرفع للمستأجر صاحب الطلب فقط.
-- ----------------------------------------------------------------------------
insert into storage.buckets (id, name, public)
values ('maintenance', 'maintenance', true)
on conflict (id) do nothing;

drop policy if exists "maintenance_upload_tenant" on storage.objects;
create policy "maintenance_upload_tenant"
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'maintenance'
  and exists (
    select 1
      from public.maintenance_requests r
     where r.id::text = (storage.foldername(storage.objects.name))[1]
       and r.tenant_id = auth.uid()
  )
);

drop policy if exists "maintenance_read_authenticated" on storage.objects;
create policy "maintenance_read_authenticated"
on storage.objects
for select
to authenticated
using (bucket_id = 'maintenance');

drop policy if exists "maintenance_delete_owner" on storage.objects;
create policy "maintenance_delete_owner"
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'maintenance'
  and exists (
    select 1
      from public.maintenance_requests r
      join public.apartments a on a.id = r.apartment_id
      join public.floors f on f.id = a.floor_id
      join public.buildings b on b.id = f.building_id
      join public.compounds c on c.id = b.compound_id
     where r.id::text = (storage.foldername(storage.objects.name))[1]
       and c.owner_id = auth.uid()
  )
);

-- ----------------------------------------------------------------------------
-- 5.5) إنشاء البروفايل تلقائياً عند إنشاء مستخدم Auth
--      النسخة القديمة كانت تقرأ الهاتف من raw_user_meta_data فقط، فتفشل
--      دالة manager_add_tenant لأنها تكتب الهاتف في auth.users.phone.
-- ----------------------------------------------------------------------------
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_phone_raw text;
  v_phone     text;
  v_role      text;
begin
  v_phone_raw := coalesce(
    nullif(NEW.raw_user_meta_data->>'phone', ''),
    nullif(NEW.raw_user_meta_data->>'phone_number', ''),
    NEW.phone
  );

  v_phone := regexp_replace(coalesce(v_phone_raw, ''), '[^0-9]', '', 'g');
  if v_phone like '964%' then
    v_phone := '0' || substr(v_phone, 4);
  elsif length(v_phone) = 10 and v_phone like '7%' then
    v_phone := '0' || v_phone;
  end if;

  v_role := case
    when (NEW.raw_user_meta_data->>'role') in ('tenant', 'owner', 'manager')
      then NEW.raw_user_meta_data->>'role'
    else 'tenant'
  end;

  insert into public.profiles (id, phone_number, full_name, role, is_active)
  values (
    NEW.id,
    coalesce(nullif(v_phone, ''), ''),
    coalesce(nullif(trim(NEW.raw_user_meta_data->>'full_name'), ''), 'مستخدم جديد'),
    v_role::public.user_role,
    true
  )
  on conflict (id) do update
    set phone_number = case
          when excluded.phone_number <> '' then excluded.phone_number
          else public.profiles.phone_number end,
        full_name = case
          when excluded.full_name <> '' then excluded.full_name
          else public.profiles.full_name end;

  return NEW;
end;
$$;

-- ----------------------------------------------------------------------------
-- 6) إعدادات الخادم (app_config)
--    تحفظ رموز الدعوة التي تتحقق منها claim_role().
-- ----------------------------------------------------------------------------
create table if not exists public.app_config (
  key   text primary key,
  value text
);

alter table public.app_config enable row level security;
revoke all on public.app_config from anon, authenticated;

-- ----------------------------------------------------------------------------
-- 7) تحقق سريع بعد التنفيذ
-- ----------------------------------------------------------------------------
-- select column_name from information_schema.columns
--  where table_name = 'maintenance_requests' and column_name in
--        ('image_urls','manager_notes','rejection_reason');
-- select * from pg_policies where tablename = 'maintenance_messages';
-- select id, public from storage.buckets where id = 'maintenance';

-- ============================================================================
-- 8) Real phone + password authentication
-- ============================================================================

-- Real phone + password authentication hardening
-- Applied to the live project on 2026-11-05.

-- ---------------------------------------------------------------- profiles
-- New auth users always start as tenants; staff roles are granted only
-- through claim_role() with a server-side invite code.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_phone_raw text;
  v_phone     text;
  v_name      text;
begin
  v_phone_raw := coalesce(
    nullif(NEW.raw_user_meta_data->>'phone', ''),
    nullif(NEW.raw_user_meta_data->>'phone_number', ''),
    NEW.phone
  );
  v_phone := regexp_replace(coalesce(v_phone_raw, ''), '[^0-9]', '', 'g');
  if v_phone like '964%' then
    v_phone := '0' || substr(v_phone, 4);
  elsif length(v_phone) = 10 and v_phone like '7%' then
    v_phone := '0' || v_phone;
  end if;
  if v_phone = '' then
    v_phone := 'u' || substr(replace(NEW.id::text, '-', ''), 1, 12);
  end if;

  v_name := coalesce(
    nullif(trim(NEW.raw_user_meta_data->>'full_name'), ''),
    'مستخدم جديد'
  );

  insert into public.profiles (id, phone_number, full_name, role, is_active, email)
  values (NEW.id, v_phone, v_name, 'tenant', true, NEW.email)
  on conflict (id) do update
    set phone_number = case when excluded.phone_number <> '' then excluded.phone_number else public.profiles.phone_number end,
        full_name    = case when excluded.full_name <> '' then excluded.full_name else public.profiles.full_name end,
        email        = coalesce(public.profiles.email, excluded.email);
  return NEW;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ---------------------------------------------------------------- helpers
create or replace function public.owns_compound(p_compound_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.compounds c
     where c.id = p_compound_id and c.owner_id = auth.uid()
  );
$$;

grant execute on function public.owns_compound(uuid) to authenticated;

create or replace function public.manages_compound(p_compound_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.owns_compound(p_compound_id)
      or exists (
        select 1 from public.manager_assignments ma
         where ma.compound_id = p_compound_id
           and ma.manager_id = auth.uid()
           and coalesce(ma.is_active, true)
      );
$$;

grant execute on function public.manages_compound(uuid) to authenticated;

create or replace function public.manages_apartment(p_apartment_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
      from public.apartments a
      join public.floors f on f.id = a.floor_id
      join public.buildings b on b.id = f.building_id
     where a.id = p_apartment_id
       and public.manages_compound(b.compound_id)
  );
$$;

grant execute on function public.manages_apartment(uuid) to authenticated;

create or replace function public.owns_apartment(p_apartment_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
      from public.apartments a
      join public.floors f    on f.id = a.floor_id
      join public.buildings b on b.id = f.building_id
     where a.id = p_apartment_id
       and public.owns_compound(b.compound_id)
  );
$$;

grant execute on function public.owns_apartment(uuid) to authenticated;

create or replace function public.can_view_profile(p_target uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select
    p_target = auth.uid()
    -- staff -> tenants living in their apartments
    or exists (
      select 1 from public.tenant_apartments ta
       where ta.tenant_id = p_target
         and (public.owns_apartment(ta.apartment_id) or public.manages_apartment(ta.apartment_id))
    )
    -- tenant -> owner / manager of their apartment
    or exists (
      select 1
        from public.tenant_apartments ta
        join public.apartments a on a.id = ta.apartment_id
        join public.floors f on f.id = a.floor_id
        join public.buildings b on b.id = f.building_id
        join public.compounds c on c.id = b.compound_id
       where ta.tenant_id = auth.uid()
         and (
           c.owner_id = p_target
           or exists (
             select 1 from public.manager_assignments ma
              where ma.compound_id = c.id
                and ma.manager_id = p_target
                and coalesce(ma.is_active, true)
           )
         )
    )
    -- staff -> tenant with a pending lease on their apartment
    or exists (
      select 1 from public.leases l
       where l.tenant_id = p_target
         and l.status = 'pending'
         and (public.owns_apartment(l.apartment_id) or public.manages_apartment(l.apartment_id))
    )
    -- staff -> tenant who opened a maintenance request in their apartment
    or exists (
      select 1 from public.maintenance_requests r
       where r.tenant_id = p_target
         and (public.owns_apartment(r.apartment_id) or public.manages_apartment(r.apartment_id))
    )
    -- owner -> managers assigned to their compounds
    or exists (
      select 1 from public.manager_assignments ma
       where ma.manager_id = p_target
         and coalesce(ma.is_active, true)
         and public.owns_compound(ma.compound_id)
    )
    -- manager -> owner of a compound they manage
    or exists (
      select 1
        from public.compounds c
        join public.manager_assignments ma on ma.compound_id = c.id
       where c.owner_id = p_target
         and ma.manager_id = auth.uid()
         and coalesce(ma.is_active, true)
    );
$$;

grant execute on function public.can_view_profile(uuid) to authenticated;

-- ---------------------------------------------------------------- profiles RLS
drop policy if exists "Users can view their own profile" on public.profiles;
drop policy if exists "Managers and owners can view all profiles" on public.profiles;
drop policy if exists "profiles_select_policy" on public.profiles;
drop policy if exists "profiles_update_policy" on public.profiles;
drop policy if exists "Users can update their own profile" on public.profiles;
drop policy if exists profiles_select_related on public.profiles;
drop policy if exists profiles_update_self on public.profiles;

create policy profiles_select_related on public.profiles
  for select to authenticated
  using (public.can_view_profile(id));

create policy profiles_update_self on public.profiles
  for update to authenticated
  using (id = auth.uid())
  with check (id = auth.uid());

-- A user must never be able to change their own role or phone number.
revoke update on public.profiles from anon, authenticated;
grant update (full_name, email, avatar_url, notes) on public.profiles to authenticated;

-- ---------------------------------------------------------------- catalogue RLS
-- Listings are visible to signed-in users only.
drop policy if exists "Everyone can view apartments" on public.apartments;
drop policy if exists apartments_select_policy on public.apartments;
drop policy if exists buildings_select_policy on public.buildings;
drop policy if exists floors_select_policy on public.floors;
drop policy if exists compounds_select_policy on public.compounds;
drop policy if exists "Owners and staff can view compounds" on public.compounds;

-- ---------------------------------------------------------------- leases RLS
drop policy if exists "Only managers can create leases" on public.leases;
drop policy if exists leases_insert_policy on public.leases;
drop policy if exists "Tenants and staff can view leases" on public.leases;

-- ---------------------------------------------------------------- maintenance RLS
drop policy if exists "Relevant users can view maintenance requests" on public.maintenance_requests;
drop policy if exists "Employees can update assigned requests" on public.maintenance_requests;
drop policy if exists "Tenants can create requests" on public.maintenance_requests;
drop policy if exists maintenance_select_policy on public.maintenance_requests;
drop policy if exists maintenance_update_policy on public.maintenance_requests;
drop policy if exists maintenance_select_scoped on public.maintenance_requests;
drop policy if exists maintenance_update_scoped on public.maintenance_requests;

create policy maintenance_select_scoped on public.maintenance_requests
  for select to authenticated
  using (
    tenant_id = auth.uid()
    or assigned_employee_id = auth.uid()
    or public.manages_apartment(apartment_id)
  );

create policy maintenance_update_scoped on public.maintenance_requests
  for update to authenticated
  using (
    tenant_id = auth.uid()
    or assigned_employee_id = auth.uid()
    or public.manages_apartment(apartment_id)
  )
  with check (
    tenant_id = auth.uid()
    or assigned_employee_id = auth.uid()
    or public.manages_apartment(apartment_id)
  );

-- ---------------------------------------------------------------- payments RLS
drop policy if exists payments_select_policy on public.payments;
drop policy if exists payments_insert_policy on public.payments;
drop policy if exists payments_select_scoped on public.payments;
drop policy if exists payments_insert_scoped on public.payments;

create policy payments_select_scoped on public.payments
  for select to authenticated
  using (
    tenant_id = auth.uid()
    or created_by = auth.uid()
    or exists (
      select 1 from public.tenant_apartments ta
       where ta.tenant_id = payments.tenant_id
         and public.manages_apartment(ta.apartment_id)
    )
  );

create policy payments_insert_scoped on public.payments
  for insert to authenticated
  with check (
    created_by = auth.uid()
    and (
      tenant_id = auth.uid()
      or exists (
        select 1 from public.tenant_apartments ta
         where ta.tenant_id = payments.tenant_id
           and public.manages_apartment(ta.apartment_id)
      )
    )
  );

-- Payments may be recorded before an invoice exists.
alter table public.payments alter column invoice_id drop not null;

-- ---------------------------------------------------------------- tenant links
drop policy if exists tenant_apartments_insert on public.tenant_apartments;
create policy tenant_apartments_insert on public.tenant_apartments
  for insert to authenticated
  with check (tenant_id = auth.uid() and coalesce(is_current, false) = false);

-- ---------------------------------------------------------------- staff RPC
drop function if exists public.manager_add_tenant(uuid, text, text, text, uuid, numeric, numeric, date, date, text);
drop function if exists public.manager_add_tenant(uuid, text, text, text, uuid, numeric, numeric, date, date, text, text);

create or replace function public.manager_add_tenant(
  p_manager_id  uuid,
  p_full_name   text,
  p_phone       text,
  p_apartment_id uuid,
  p_rent        numeric,
  p_deposit     numeric,
  p_start_date  date,
  p_end_date    date,
  p_notes       text default null,
  p_password    text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_caller            uuid := auth.uid();
  v_actor             public.profiles%rowtype;
  v_local             text;
  v_gotrue_phone      text;
  v_user_id           uuid;
  v_profile           public.profiles%rowtype;
  v_lease_id          uuid;
  v_compound_id       uuid;
  v_owner_id          uuid;
  v_apartment_status  text;
begin
  if v_caller is null then
    raise exception 'يجب تسجيل الدخول أولاً';
  end if;

  select * into v_actor from public.profiles where id = v_caller;
  if not found or v_actor.role not in ('owner', 'manager') then
    raise exception 'ليس لديك صلاحية لإضافة المستأجرين';
  end if;

  if coalesce(trim(p_full_name), '') = '' then
    raise exception 'اسم المستأجر مطلوب';
  end if;

  v_local := regexp_replace(coalesce(p_phone, ''), '[^0-9]', '', 'g');
  if v_local like '964%' then
    v_local := '0' || substr(v_local, 4);
  elsif length(v_local) = 10 and v_local like '7%' then
    v_local := '0' || v_local;
  end if;
  if v_local !~ '^07[0-9]{9}$' then
    raise exception 'رقم الهاتف غير صالح';
  end if;
  -- GoTrue v2.197 stores international numbers without the leading plus.
  v_gotrue_phone := '964' || substr(v_local, 2);

  if p_password is not null and length(p_password) < 8 then
    raise exception 'كلمة المرور يجب أن تكون 8 أحرف على الأقل';
  end if;

  if p_rent is null or p_rent <= 0 then
    raise exception 'مبلغ الإيجار غير صالح';
  end if;
  if p_start_date is null or p_end_date is null or p_end_date <= p_start_date then
    raise exception 'تاريخ العقد غير صالح';
  end if;

  select c.id, c.owner_id
    into v_compound_id, v_owner_id
    from public.apartments a
    join public.floors f    on f.id = a.floor_id
    join public.buildings b on b.id = f.building_id
    join public.compounds c on c.id = b.compound_id
   where a.id = p_apartment_id;

  if v_compound_id is null then
    raise exception 'الشقة غير موجودة';
  end if;

  if v_actor.role = 'owner' then
    if v_owner_id <> v_actor.id then
      raise exception 'ليس لديك صلاحية على هذه الشقة';
    end if;
  else
    if not exists (
      select 1
        from public.manager_assignments
       where manager_id = v_actor.id
         and compound_id = v_compound_id
         and coalesce(is_active, true)
    ) then
      raise exception 'ليس لديك صلاحية على هذه الشقة';
    end if;
  end if;

  select status::text into v_apartment_status
    from public.apartments
   where id = p_apartment_id
     for update;

  if v_apartment_status is null then
    raise exception 'الشقة غير موجودة';
  end if;
  if v_apartment_status <> 'vacant' then
    raise exception 'الشقة ليست فارغة';
  end if;
  if exists (
    select 1
      from public.leases
     where apartment_id = p_apartment_id
       and status in ('active', 'pending')
  ) then
    raise exception 'يوجد عقد نشط على هذه الشقة';
  end if;

  select * into v_profile
    from public.profiles
   where phone_number in (v_local, '964' || substr(v_local, 2), '+964' || substr(v_local, 2))
   limit 1;

  if found then
    if v_profile.role <> 'tenant' then
      raise exception 'هذا الرقم مسجل كـ% بالفعل',
        case v_profile.role::text
          when 'owner' then 'مالك'
          when 'manager' then 'مدير'
          else v_profile.role::text
        end;
    end if;
    v_user_id := v_profile.id;
  end if;

  if v_user_id is null then
    select id into v_user_id
      from auth.users
     where phone in (v_gotrue_phone, '+' || v_gotrue_phone, v_local)
     limit 1;
  end if;

  if v_user_id is null then
    v_user_id := gen_random_uuid();
  end if;

  insert into auth.users (
    instance_id, id, aud, role, phone, phone_confirmed_at,
    encrypted_password, raw_app_meta_data, raw_user_meta_data,
    confirmation_token, recovery_token, email_change_token_new, email_change,
    email_change_token_current, phone_change, phone_change_token, reauthentication_token,
    email_change_confirm_status, is_super_admin,
    created_at, updated_at, is_sso_user, is_anonymous
  ) values (
    '00000000-0000-0000-0000-000000000000',
    v_user_id,
    'authenticated',
    'authenticated',
    v_gotrue_phone,
    now(),
    case when p_password is null then null
         else extensions.crypt(p_password, extensions.gen_salt('bf', 10)) end,
    jsonb_build_object('provider', 'phone', 'providers', jsonb_build_array('phone')),
    jsonb_build_object(
      'full_name', trim(p_full_name),
      'role', 'tenant',
      'phone', v_local
    ),
    '', '', '', '', '', '', '', '', 0, false,
    now(), now(), false, false
  )
  on conflict (id) do update
    set phone = excluded.phone,
        phone_confirmed_at = coalesce(auth.users.phone_confirmed_at, excluded.phone_confirmed_at),
        encrypted_password = coalesce(excluded.encrypted_password, auth.users.encrypted_password),
        raw_user_meta_data = auth.users.raw_user_meta_data || excluded.raw_user_meta_data,
        updated_at = now();

  insert into auth.identities (
    user_id, identity_data, provider, provider_id,
    last_sign_in_at, created_at, updated_at
  ) values (
    v_user_id,
    jsonb_build_object('sub', v_user_id::text, 'phone', v_gotrue_phone),
    'phone',
    v_gotrue_phone,
    now(), now(), now()
  )
  on conflict (provider_id, provider) do update
    set identity_data = excluded.identity_data,
        updated_at = now();

  if exists (
    select 1
      from public.leases
     where tenant_id = v_user_id
       and status = 'active'
       and apartment_id <> p_apartment_id
  ) then
    raise exception 'هذا المستأجر لديه عقد نشط في شقة أخرى';
  end if;

  insert into public.profiles (id, full_name, phone_number, role, is_active)
  values (v_user_id, trim(p_full_name), v_local, 'tenant', true)
  on conflict (id) do update
    set full_name    = excluded.full_name,
        phone_number = excluded.phone_number,
        is_active    = true;

  insert into public.leases (
    apartment_id, tenant_id, start_date, end_date,
    monthly_rent, deposit_amount, status, notes
  ) values (
    p_apartment_id,
    v_user_id,
    p_start_date,
    p_end_date,
    p_rent,
    greatest(coalesce(p_deposit, 0), 0),
    'active',
    nullif(trim(coalesce(p_notes, '')), '')
  ) returning id into v_lease_id;

  delete from public.tenant_apartments
   where tenant_id = v_user_id and apartment_id = p_apartment_id;

  update public.tenant_apartments
     set is_current = false
   where tenant_id = v_user_id and is_current;

  insert into public.tenant_apartments (
    tenant_id, apartment_id, move_in_date, is_current
  ) values (
    v_user_id, p_apartment_id, p_start_date, true
  );

  update public.apartments
     set status = 'occupied'
   where id = p_apartment_id;

  return jsonb_build_object(
    'tenant_id', v_user_id,
    'lease_id', v_lease_id,
    'full_name', trim(p_full_name),
    'phone_number', v_local,
    'has_password', p_password is not null
  );
end;
$$;

revoke all on function public.manager_add_tenant(uuid, text, text, uuid, numeric, numeric, date, date, text, text) from public, anon;
grant execute on function public.manager_add_tenant(uuid, text, text, uuid, numeric, numeric, date, date, text, text) to authenticated;
drop policy if exists tenant_apartments_delete_own_pending on public.tenant_apartments;
create policy tenant_apartments_delete_own_pending on public.tenant_apartments
  for delete to authenticated
  using (tenant_id = auth.uid() and coalesce(is_current, false) = false);

create or replace function public.ensure_profile(p_full_name text default null)
returns public.profiles
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid   uuid := auth.uid();
  v_phone text;
  v_row   public.profiles%rowtype;
begin
  if v_uid is null then
    raise exception 'يجب تسجيل الدخول أولاً';
  end if;

  select coalesce(
           nullif(u.phone, ''),
           nullif(u.raw_user_meta_data->>'phone', ''),
           nullif(u.raw_user_meta_data->>'phone_number', '')
         )
    into v_phone
    from auth.users u
   where u.id = v_uid;

  v_phone := regexp_replace(coalesce(v_phone, ''), '[^0-9]', '', 'g');
  if v_phone like '964%' then
    v_phone := '0' || substr(v_phone, 4);
  elsif length(v_phone) = 10 and v_phone like '7%' then
    v_phone := '0' || v_phone;
  end if;
  if v_phone = '' then
    v_phone := 'u' || substr(replace(v_uid::text, '-', ''), 1, 12);
  end if;

  insert into public.profiles (id, phone_number, full_name, role, is_active)
  values (
    v_uid,
    v_phone,
    coalesce(nullif(trim(p_full_name), ''), 'مستخدم جديد'),
    'tenant',
    true
  )
  on conflict (id) do update
    set full_name = coalesce(nullif(trim(p_full_name), ''), public.profiles.full_name),
        updated_at = now();

  select * into v_row from public.profiles where id = v_uid;
  return v_row;
end;
$$;

revoke all on function public.ensure_profile(text) from public, anon;
grant execute on function public.ensure_profile(text) to authenticated;

-- ---------------------------------------------------------------- role claims
-- Staff roles are granted only with the matching invite code stored in app_config.
create or replace function public.claim_role(p_role text, p_invite_code text)
returns public.user_role
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid      uuid := auth.uid();
  v_profile  public.profiles%rowtype;
  v_expected text;
begin
  if v_uid is null then
    raise exception 'يجب تسجيل الدخول أولاً';
  end if;
  if p_role not in ('owner', 'manager') then
    raise exception 'الدور المطلوب غير صالح';
  end if;

  select * into v_profile from public.profiles where id = v_uid;
  if not found then
    raise exception 'الملف الشخصي غير موجود';
  end if;
  if v_profile.role <> 'tenant' then
    raise exception 'لا يمكن تغيير الدور بعد تعيينه';
  end if;
  if exists (
    select 1 from public.leases
     where tenant_id = v_uid and status = 'active'
  ) then
    raise exception 'لا يمكن تغيير الدور بعد ارتباطك بعقد إيجار';
  end if;

  select value into v_expected
    from public.app_config
   where key = p_role || '_invite_code';
  if coalesce(trim(v_expected), '') = ''
     or coalesce(p_invite_code, '') <> v_expected then
    raise exception 'رمز الدعوة غير صحيح';
  end if;

  update public.profiles
     set role = p_role::public.user_role,
         updated_at = now()
   where id = v_uid;

  return p_role::public.user_role;
end;
$$;

revoke all on function public.claim_role(text, text) from public, anon;
grant execute on function public.claim_role(text, text) to authenticated;

-- Lets the app reject a wrong invite before creating an account. It only
-- returns a boolean; the code itself never leaves the server.
create or replace function public.check_invite_code(p_role text, p_invite_code text)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select p_role in ('owner', 'manager')
     and exists (
       select 1
         from public.app_config
        where key = p_role || '_invite_code'
          and trim(coalesce(value, '')) <> ''
          and value = p_invite_code
     );
$$;

revoke all on function public.check_invite_code(text, text) from public;
grant execute on function public.check_invite_code(text, text) to anon, authenticated;

-- ============================================================================
-- 9) Manager ↔ compound assignments controlled by the owner (2026-11-06)
--    One manager may serve many compounds; each assignment is one row.
--    Only the compound owner can assign/remove.
-- ============================================================================

create or replace function public.assign_manager_to_compound(
  p_compound_id uuid,
  p_phone text
) returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_caller  uuid := auth.uid();
  v_local   text;
  v_manager public.profiles%rowtype;
begin
  if v_caller is null then
    raise exception 'يجب تسجيل الدخول أولاً';
  end if;

  if not public.owns_compound(p_compound_id) then
    raise exception 'يمكن للمالك فقط تعيين مديري مجمعاته';
  end if;

  -- Accepts 0770…, +964770…, 964770… or a spaced number.
  v_local := regexp_replace(coalesce(p_phone, ''), '\D', '', 'g');
  if v_local like '964%' then
    v_local := '0' || substr(v_local, 4);
  elsif v_local not like '0%' then
    v_local := '0' || v_local;
  end if;

  select * into v_manager
    from public.profiles
   where regexp_replace(coalesce(phone_number, ''), '\D', '', 'g') = v_local
     and role = 'manager'
     and coalesce(is_active, true)
   limit 1;

  if not found then
    raise exception 'لا يوجد حساب مدير بهذا الرقم. تأكد أن المدير أنشأ حسابه أولاً';
  end if;

  insert into public.manager_assignments (manager_id, compound_id, assigned_by, is_active)
  values (v_manager.id, p_compound_id, v_caller, true)
  on conflict (manager_id, compound_id)
  do update set is_active = true,
                assigned_by = excluded.assigned_by,
                assigned_at = now();

  return jsonb_build_object(
    'manager_id', v_manager.id,
    'full_name', coalesce(v_manager.full_name, 'مدير'),
    'phone_number', v_manager.phone_number
  );
end;
$$;

revoke all on function public.assign_manager_to_compound(uuid, text) from public, anon;
grant execute on function public.assign_manager_to_compound(uuid, text) to authenticated;

create or replace function public.remove_manager_assignment(
  p_compound_id uuid,
  p_manager_id uuid
) returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'يجب تسجيل الدخول أولاً';
  end if;

  if not public.owns_compound(p_compound_id) then
    raise exception 'يمكن للمالك فقط تعديل مديري مجمعاته';
  end if;

  update public.manager_assignments
     set is_active = false
   where compound_id = p_compound_id
     and manager_id = p_manager_id
     and coalesce(is_active, true);
end;
$$;

revoke all on function public.remove_manager_assignment(uuid, uuid) from public, anon;
grant execute on function public.remove_manager_assignment(uuid, uuid) to authenticated;
