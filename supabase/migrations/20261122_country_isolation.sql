-- ============================================================================
-- 2026-11-22 — Multi-country support (IQ / AE / US)
--   * compounds.country + profiles.country
--   * per-country phone normalization/validation for every staff RPC
--   * country-aware compound create/update
-- Managers stay scoped to their assigned compounds (RLS unchanged) and tenants
-- stay scoped to their leases; the owner sees every compound they own.
-- ============================================================================

-- ---------------------------------------------------------------- columns
alter table public.compounds
  add column if not exists country text not null default 'IQ';

alter table public.profiles
  add column if not exists country text not null default 'IQ';

do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'compounds_country_check'
  ) then
    alter table public.compounds
      add constraint compounds_country_check
      check (country in ('IQ', 'AE', 'US'));
  end if;
  if not exists (
    select 1 from pg_constraint where conname = 'profiles_country_check'
  ) then
    alter table public.profiles
      add constraint profiles_country_check
      check (country in ('IQ', 'AE', 'US'));
  end if;
end;
$$;

create index if not exists compounds_owner_country_idx
  on public.compounds (owner_id, country);

-- ---------------------------------------------------------------- phones
create or replace function public.country_from_phone(p_phone text)
returns text
language plpgsql
immutable
set search_path = public
as $$
declare
  v text := regexp_replace(coalesce(p_phone, ''), '\D', '', 'g');
begin
  if v like '971%' then return 'AE'; end if;
  if v like '964%' then return 'IQ'; end if;
  if length(v) = 11 and v like '1%' then return 'US'; end if;
  if length(v) = 10 and v like '05%' then return 'AE'; end if;
  if length(v) = 10 and v like '5%' then return 'AE'; end if;
  if length(v) = 10 and v like '07%' then return 'IQ'; end if;
  if length(v) = 10 and v like '7%' then return 'IQ'; end if;
  return 'IQ';
end;
$$;

create or replace function public.normalize_phone(
  p_phone text,
  p_country text default 'IQ'
) returns text
language plpgsql
immutable
set search_path = public
as $$
declare
  v text := regexp_replace(coalesce(p_phone, ''), '\D', '', 'g');
  c text := upper(coalesce(nullif(p_country, ''), 'IQ'));
begin
  if c = 'IQ' then
    if v like '964%' then
      v := '0' || substr(v, 4);
    elsif length(v) = 10 and v like '7%' then
      v := '0' || v;
    end if;
  elsif c = 'AE' then
    if v like '971%' then
      v := '0' || substr(v, 4);
    elsif length(v) = 9 and v like '5%' then
      v := '0' || v;
    end if;
  elsif c = 'US' then
    if length(v) = 11 and v like '1%' then
      v := substr(v, 2);
    end if;
  end if;
  return v;
end;
$$;

create or replace function public.is_valid_phone(
  p_phone text,
  p_country text default 'IQ'
) returns boolean
language sql
immutable
set search_path = public
as $$
  select case upper(coalesce(nullif(p_country, ''), 'IQ'))
    when 'IQ' then p_phone ~ '^07[0-9]{9}$'
    when 'AE' then p_phone ~ '^05[0-9]{8}$'
    when 'US' then p_phone ~ '^[2-9][0-9]{9}$'
    else false
  end;
$$;

-- GoTrue stores international numbers without the leading plus.
create or replace function public.phone_gotrue(
  p_local text,
  p_country text default 'IQ'
) returns text
language sql
immutable
set search_path = public
as $$
  select case upper(coalesce(nullif(p_country, ''), 'IQ'))
    when 'IQ' then '964' || substr(p_local, 2)
    when 'AE' then '971' || substr(p_local, 2)
    when 'US' then '1' || p_local
  end;
$$;

revoke all on function public.country_from_phone(text) from public, anon;
revoke all on function public.normalize_phone(text, text) from public, anon;
revoke all on function public.is_valid_phone(text, text) from public, anon;
revoke all on function public.phone_gotrue(text, text) from public, anon;
grant execute on function public.country_from_phone(text) to authenticated;
grant execute on function public.normalize_phone(text, text) to authenticated;
grant execute on function public.is_valid_phone(text, text) to authenticated;
grant execute on function public.phone_gotrue(text, text) to authenticated;

-- ---------------------------------------------------------------- new users
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_phone_raw text;
  v_phone     text;
  v_country   text;
  v_name      text;
begin
  v_phone_raw := coalesce(
    nullif(NEW.raw_user_meta_data->>'phone', ''),
    nullif(NEW.raw_user_meta_data->>'phone_number', ''),
    NEW.phone
  );
  v_country := upper(coalesce(NEW.raw_user_meta_data->>'country', ''));
  if v_country not in ('IQ', 'AE', 'US') then
    v_country := public.country_from_phone(v_phone_raw);
  end if;
  v_phone := public.normalize_phone(v_phone_raw, v_country);
  if v_phone = '' then
    v_phone := 'u' || substr(replace(NEW.id::text, '-', ''), 1, 12);
  end if;

  v_name := coalesce(
    nullif(trim(NEW.raw_user_meta_data->>'full_name'), ''),
    'مستخدم جديد'
  );

  insert into public.profiles (id, phone_number, full_name, role, is_active, email, country)
  values (NEW.id, v_phone, v_name, 'tenant', true, NEW.email, v_country)
  on conflict (id) do update
    set phone_number = case when excluded.phone_number <> '' then excluded.phone_number else public.profiles.phone_number end,
        full_name    = case when excluded.full_name <> '' then excluded.full_name else public.profiles.full_name end,
        email        = coalesce(public.profiles.email, excluded.email);
  return NEW;
end;
$$;

create or replace function public.ensure_profile(p_full_name text default null)
returns public.profiles
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid     uuid := auth.uid();
  v_phone   text;
  v_country text;
  v_meta    jsonb;
  v_row     public.profiles%rowtype;
begin
  if v_uid is null then
    raise exception 'يجب تسجيل الدخول أولاً';
  end if;

  select coalesce(u.phone, u.raw_user_meta_data->>'phone', u.raw_user_meta_data->>'phone_number'),
         coalesce(u.raw_user_meta_data, '{}'::jsonb)
    into v_phone, v_meta
    from auth.users u
   where u.id = v_uid;

  v_country := upper(coalesce(v_meta->>'country', ''));
  if v_country not in ('IQ', 'AE', 'US') then
    v_country := public.country_from_phone(v_phone);
  end if;
  v_phone := public.normalize_phone(v_phone, v_country);
  if v_phone = '' then
    v_phone := 'u' || substr(replace(v_uid::text, '-', ''), 1, 12);
  end if;

  insert into public.profiles (id, phone_number, full_name, role, is_active, country)
  values (
    v_uid,
    v_phone,
    coalesce(nullif(trim(p_full_name), ''), 'مستخدم جديد'),
    'tenant',
    true,
    v_country
  )
  on conflict (id) do update
    set full_name = coalesce(nullif(trim(p_full_name), ''), public.profiles.full_name),
        updated_at = now();

  select * into v_row from public.profiles where id = v_uid;
  return v_row;
end;
$$;

-- ---------------------------------------------------------------- compounds
drop function if exists public.owner_create_compound(text, text, text);
drop function if exists public.owner_create_compound(text, text, text, text);

create or replace function public.owner_create_compound(
  p_name text,
  p_location text default null,
  p_description text default null,
  p_country text default 'IQ'
) returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid     uuid;
  v_id      uuid;
  v_country text := upper(coalesce(nullif(p_country, ''), 'IQ'));
begin
  v_uid := public.owner_assert_owner();
  if coalesce(trim(p_name), '') = '' then
    raise exception 'اسم المجمع مطلوب';
  end if;
  if v_country not in ('IQ', 'AE', 'US') then
    raise exception 'الدولة غير مدعومة';
  end if;

  insert into public.compounds (name, location, description, owner_id, is_active, country)
  values (trim(p_name), nullif(trim(coalesce(p_location, '')), ''),
          nullif(trim(coalesce(p_description, '')), ''), v_uid, true, v_country)
  returning id into v_id;

  return v_id;
end;
$$;

drop function if exists public.owner_update_compound(uuid, text, text, text);
drop function if exists public.owner_update_compound(uuid, text, text, text, text);

create or replace function public.owner_update_compound(
  p_compound uuid,
  p_name text,
  p_location text default null,
  p_description text default null,
  p_country text default null
) returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_country text := upper(nullif(p_country, ''));
begin
  perform public.owner_assert_owner();
  if not public.owner_owns_compound(p_compound) then
    raise exception 'هذا المجمع ليس ضمن محفظتك';
  end if;
  if v_country is not null and v_country not in ('IQ', 'AE', 'US') then
    raise exception 'الدولة غير مدعومة';
  end if;

  update public.compounds
     set name = trim(p_name),
         location = nullif(trim(coalesce(p_location, '')), ''),
         description = nullif(trim(coalesce(p_description, '')), ''),
         country = coalesce(v_country, country),
         updated_at = now()
   where id = p_compound;
end;
$$;

revoke all on function public.owner_create_compound(text, text, text, text) from public, anon;
revoke all on function public.owner_update_compound(uuid, text, text, text, text) from public, anon;
grant execute on function public.owner_create_compound(text, text, text, text) to authenticated;
grant execute on function public.owner_update_compound(uuid, text, text, text, text) to authenticated;

-- ---------------------------------------------------------------- managers
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
  v_country text;
  v_local   text;
  v_manager public.profiles%rowtype;
begin
  if v_caller is null then
    raise exception 'يجب تسجيل الدخول أولاً';
  end if;
  if not public.owns_compound(p_compound_id) then
    raise exception 'يمكن للمالك فقط تعيين مديري مجمعاته';
  end if;

  select country into v_country from public.compounds where id = p_compound_id;
  v_local := public.normalize_phone(p_phone, v_country);

  select * into v_manager
    from public.profiles
   where regexp_replace(coalesce(phone_number, ''), '\D', '', 'g') in (v_local, public.phone_gotrue(v_local, v_country))
     and role = 'manager'
     and coalesce(is_active, true)
   limit 1;

  if not found then
    raise exception 'لا يوجد حساب مدير بهذا الرقم. تأكد أن المدير أنشأ حسابه أولاً';
  end if;
  if v_manager.country not in ('IQ', 'AE', 'US') then
    update public.profiles set country = v_country where id = v_manager.id;
  elsif v_manager.country <> v_country then
    raise exception 'هذا المدير مسجل في دولة أخرى';
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

create or replace function public.assign_apartment_manager(
  p_apartment_id uuid,
  p_phone text
) returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_country text;
  v_local   text;
  v_manager public.profiles%rowtype;
begin
  if auth.uid() is null then
    raise exception 'يجب تسجيل الدخول أولاً';
  end if;
  if not public.owns_apartment(p_apartment_id) then
    raise exception 'يمكن للمالك فقط تعيين مديري شققه';
  end if;

  select c.country into v_country
    from public.apartments a
    join public.floors f on f.id = a.floor_id
    join public.buildings b on b.id = f.building_id
    join public.compounds c on c.id = b.compound_id
   where a.id = p_apartment_id;

  v_local := public.normalize_phone(p_phone, v_country);

  select * into v_manager
    from public.profiles
   where regexp_replace(coalesce(phone_number, ''), '\D', '', 'g') in (v_local, public.phone_gotrue(v_local, v_country))
     and role = 'manager'
     and coalesce(is_active, true)
   limit 1;

  if not found then
    raise exception 'لا يوجد حساب مدير بهذا الرقم. تأكد أن المدير أنشأ حسابه أولاً';
  end if;
  if v_manager.country not in ('IQ', 'AE', 'US') then
    update public.profiles set country = v_country where id = v_manager.id;
  elsif v_manager.country <> v_country then
    raise exception 'هذا المدير مسجل في دولة أخرى';
  end if;

  insert into public.apartment_managers (apartment_id, manager_id, assigned_by, is_active)
  values (p_apartment_id, v_manager.id, auth.uid(), true)
  on conflict (apartment_id, manager_id)
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

revoke all on function public.assign_apartment_manager(uuid, text) from public, anon;
grant execute on function public.assign_apartment_manager(uuid, text) to authenticated;

drop function if exists public.owner_create_manager(text, text, text);
drop function if exists public.owner_create_manager(text, text, text, text);

create or replace function public.owner_create_manager(
  p_full_name text,
  p_phone text,
  p_password text,
  p_country text default 'IQ'
) returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_caller  public.profiles%rowtype;
  v_country text := upper(coalesce(nullif(p_country, ''), 'IQ'));
  v_local   text;
  v_gotrue  text;
  v_user_id uuid := gen_random_uuid();
begin
  select * into v_caller from public.profiles where id = auth.uid();
  if not found or v_caller.role <> 'owner' then
    raise exception 'يمكن للمالك فقط إضافة مديرين';
  end if;
  if v_country not in ('IQ', 'AE', 'US') then
    raise exception 'الدولة غير مدعومة';
  end if;

  if length(coalesce(trim(p_full_name), '')) < 3 then
    raise exception 'اسم المدير قصير جداً';
  end if;
  if length(coalesce(p_password, '')) < 8 then
    raise exception 'كلمة المرور يجب أن تكون 8 أحرف على الأقل';
  end if;

  v_local := public.normalize_phone(p_phone, v_country);
  if not public.is_valid_phone(v_local, v_country) then
    raise exception 'رقم الهاتف غير صالح';
  end if;
  v_gotrue := public.phone_gotrue(v_local, v_country);

  if exists (
       select 1 from auth.users u
        where regexp_replace(coalesce(u.phone, ''), '\D', '', 'g') = v_gotrue
     )
     or exists (
       select 1 from public.profiles p
        where regexp_replace(coalesce(p.phone_number, ''), '\D', '', 'g') in (v_local, v_gotrue)
     ) then
    raise exception 'هذا الرقم مسجل مسبقاً';
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
    v_gotrue,
    now(),
    extensions.crypt(p_password, extensions.gen_salt('bf', 10)),
    jsonb_build_object('provider', 'phone', 'providers', jsonb_build_array('phone')),
    jsonb_build_object('full_name', trim(p_full_name), 'role', 'manager', 'phone', v_local, 'country', v_country),
    '', '', '', '', '', '', '', '', 0, false,
    now(), now(), false, false
  );

  insert into auth.identities (
    user_id, identity_data, provider, provider_id,
    last_sign_in_at, created_at, updated_at
  ) values (
    v_user_id,
    jsonb_build_object('sub', v_user_id::text, 'phone', v_gotrue),
    'phone',
    v_gotrue,
    now(), now(), now()
  );

  insert into public.profiles (id, full_name, phone_number, role, is_active, country)
  values (v_user_id, trim(p_full_name), v_local, 'manager', true, v_country)
  on conflict (id) do update
    set full_name = excluded.full_name,
        phone_number = excluded.phone_number,
        role = 'manager',
        is_active = true,
        country = excluded.country;

  insert into public.owner_created_members (owner_id, member_id)
  values (auth.uid(), v_user_id)
  on conflict (owner_id, member_id) do nothing;

  return jsonb_build_object(
    'manager_id', v_user_id,
    'full_name', trim(p_full_name),
    'phone_number', v_local
  );
end;
$$;

revoke all on function public.owner_create_manager(text, text, text, text) from public, anon;
grant execute on function public.owner_create_manager(text, text, text, text) to authenticated;

-- ---------------------------------------------------------------- tenants
drop function if exists public.manager_add_tenant(uuid, text, text, uuid, numeric, numeric, date, date, text, text);

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
  v_country           text;
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

  select c.id, c.owner_id, c.country
    into v_compound_id, v_owner_id, v_country
    from public.apartments a
    join public.floors f    on f.id = a.floor_id
    join public.buildings b on b.id = f.building_id
    join public.compounds c on c.id = b.compound_id
   where a.id = p_apartment_id;

  if v_compound_id is null then
    raise exception 'الشقة غير موجودة';
  end if;

  v_local := public.normalize_phone(p_phone, v_country);
  if not public.is_valid_phone(v_local, v_country) then
    raise exception 'رقم الهاتف غير صالح لهذه الدولة';
  end if;
  -- GoTrue v2.197 stores international numbers without the leading plus.
  v_gotrue_phone := public.phone_gotrue(v_local, v_country);

  if p_password is not null and length(p_password) < 8 then
    raise exception 'كلمة المرور يجب أن تكون 8 أحرف على الأقل';
  end if;

  if p_rent is null or p_rent <= 0 then
    raise exception 'مبلغ الإيجار غير صالح';
  end if;
  if p_start_date is null or p_end_date is null or p_end_date <= p_start_date then
    raise exception 'تاريخ العقد غير صالح';
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
   where regexp_replace(coalesce(phone_number, ''), '\D', '', 'g') in (v_local, v_gotrue_phone)
     and (country is null or country = v_country)
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
     where regexp_replace(coalesce(phone, ''), '\D', '', 'g') in (v_gotrue_phone, v_local)
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
      'phone', v_local,
      'country', v_country
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

  insert into public.profiles (id, full_name, phone_number, role, is_active, country)
  values (v_user_id, trim(p_full_name), v_local, 'tenant', true, v_country)
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

-- ---------------------------------------------------------------- manager scope
-- Managers reach compounds only through active assignments (app already filters,
-- this makes it true even for direct API calls).
create or replace function public.manager_can_view_compound(p_compound uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.owns_compound(p_compound)
      or exists (
        select 1 from public.manager_assignments ma
         where ma.compound_id = p_compound
           and ma.manager_id = auth.uid()
           and coalesce(ma.is_active, true)
      );
$$;

revoke all on function public.manager_can_view_compound(uuid) from public, anon;
grant execute on function public.manager_can_view_compound(uuid) to authenticated;
