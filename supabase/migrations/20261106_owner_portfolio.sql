-- Owner portfolio management: create compounds, buildings (with floors/units) and
-- edit or remove apartments. RLS on buildings/floors/apartments has no INSERT policy,
-- so these checks run inside SECURITY DEFINER functions.

create or replace function public.owner_assert_owner()
returns uuid
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception 'يجب تسجيل الدخول أولاً';
  end if;
  if not exists (select 1 from public.profiles where id = v_uid and role = 'owner') then
    raise exception 'هذه العملية للمالك فقط';
  end if;
  return v_uid;
end;
$$;

revoke all on function public.owner_assert_owner() from public, anon;

create or replace function public.owner_owns_compound(p_compound uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.compounds c
     where c.id = p_compound and c.owner_id = auth.uid()
  );
$$;

create or replace function public.owner_create_compound(
  p_name text,
  p_location text default null,
  p_description text default null
) returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid;
  v_id uuid;
begin
  v_uid := public.owner_assert_owner();
  if coalesce(trim(p_name), '') = '' then
    raise exception 'اسم المجمع مطلوب';
  end if;

  insert into public.compounds (name, location, description, owner_id, is_active)
  values (trim(p_name), nullif(trim(coalesce(p_location, '')), ''),
          nullif(trim(coalesce(p_description, '')), ''), v_uid, true)
  returning id into v_id;

  return v_id;
end;
$$;

create or replace function public.owner_update_compound(
  p_compound uuid,
  p_name text,
  p_location text default null,
  p_description text default null
) returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public.owner_assert_owner();
  if not public.owner_owns_compound(p_compound) then
    raise exception 'هذا المجمع ليس ضمن محفظتك';
  end if;

  update public.compounds
     set name = trim(p_name),
         location = nullif(trim(coalesce(p_location, '')), ''),
         description = nullif(trim(coalesce(p_description, '')), ''),
         updated_at = now()
   where id = p_compound;
end;
$$;

create or replace function public.owner_create_building(
  p_compound uuid,
  p_name text,
  p_address text default null,
  p_floors integer default 1,
  p_units_per_floor integer default 1,
  p_rent numeric default 0,
  p_rooms integer default 2,
  p_area numeric default null
) returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_building uuid;
  v_floor uuid;
  f integer;
  u integer;
  v_floors integer := greatest(coalesce(p_floors, 1), 1);
  v_units integer := greatest(coalesce(p_units_per_floor, 1), 0);
begin
  perform public.owner_assert_owner();
  if not public.owner_owns_compound(p_compound) then
    raise exception 'هذا المجمع ليس ضمن محفظتك';
  end if;
  if coalesce(trim(p_name), '') = '' then
    raise exception 'اسم العمارة مطلوب';
  end if;
  if v_floors > 60 or v_units > 50 then
    raise exception 'عدد الطوابق أو الشقق لكل طابق كبير جداً';
  end if;

  insert into public.buildings (compound_id, name, address, total_floors, is_active)
  values (p_compound, trim(p_name), nullif(trim(coalesce(p_address, '')), ''), v_floors, true)
  returning id into v_building;

  for f in 1..v_floors loop
    insert into public.floors (building_id, floor_number)
    values (v_building, f)
    returning id into v_floor;

    for u in 1..v_units loop
      insert into public.apartments
        (floor_id, unit_number, room_count, area_sqm, rent_amount, status)
      values
        (v_floor, (f * 100 + u)::text, greatest(coalesce(p_rooms, 1), 0),
         p_area, greatest(coalesce(p_rent, 0), 0), 'vacant');
    end loop;
  end loop;

  return v_building;
end;
$$;

create or replace function public.owner_create_apartment(
  p_building uuid,
  p_floor_number integer,
  p_unit_number text,
  p_rent numeric default 0,
  p_rooms integer default 2,
  p_area numeric default null,
  p_description text default null
) returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_compound uuid;
  v_floor uuid;
  v_id uuid;
begin
  perform public.owner_assert_owner();

  select compound_id into v_compound from public.buildings where id = p_building;
  if v_compound is null or not public.owner_owns_compound(v_compound) then
    raise exception 'هذه العمارة ليست ضمن محفظتك';
  end if;

  select id into v_floor
    from public.floors
   where building_id = p_building and floor_number = greatest(coalesce(p_floor_number, 1), 1);

  if v_floor is null then
    insert into public.floors (building_id, floor_number)
    values (p_building, greatest(coalesce(p_floor_number, 1), 1))
    returning id into v_floor;
  end if;

  insert into public.apartments
    (floor_id, unit_number, room_count, area_sqm, rent_amount, status, description)
  values
    (v_floor, trim(p_unit_number), greatest(coalesce(p_rooms, 1), 0), p_area,
     greatest(coalesce(p_rent, 0), 0), 'vacant',
     nullif(trim(coalesce(p_description, '')), ''))
  returning id into v_id;

  return v_id;
end;
$$;

create or replace function public.owner_owns_apartment(p_apartment uuid)
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
      join public.compounds c on c.id = b.compound_id
     where a.id = p_apartment and c.owner_id = auth.uid()
  );
$$;

create or replace function public.owner_update_apartment(
  p_apartment uuid,
  p_rent numeric,
  p_status text default null,
  p_rooms integer default null,
  p_area numeric default null,
  p_description text default null
) returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public.owner_assert_owner();
  if not public.owner_owns_apartment(p_apartment) then
    raise exception 'هذه الشقة ليست ضمن محفظتك';
  end if;

  update public.apartments
     set rent_amount = greatest(coalesce(p_rent, rent_amount), 0),
         status = coalesce(nullif(p_status, '')::apartment_status, status),
         room_count = coalesce(p_rooms, room_count),
         area_sqm = coalesce(p_area, area_sqm),
         description = coalesce(nullif(trim(coalesce(p_description, '')), ''), description),
         updated_at = now()
   where id = p_apartment;
end;
$$;

create or replace function public.owner_delete_apartment(p_apartment uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public.owner_assert_owner();
  if not public.owner_owns_apartment(p_apartment) then
    raise exception 'هذه الشقة ليست ضمن محفظتك';
  end if;
  if exists (
    select 1 from public.leases
     where apartment_id = p_apartment and status in ('active', 'pending')
  ) then
    raise exception 'لا يمكن حذف شقة مرتبطة بعقد إيجار';
  end if;

  delete from public.leases where apartment_id = p_apartment;
  delete from public.tenant_apartments where apartment_id = p_apartment;
  delete from public.apartments where id = p_apartment;
end;
$$;

create or replace function public.owner_delete_building(p_building uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_compound uuid;
begin
  perform public.owner_assert_owner();
  select compound_id into v_compound from public.buildings where id = p_building;
  if v_compound is null or not public.owner_owns_compound(v_compound) then
    raise exception 'هذه العمارة ليست ضمن محفظتك';
  end if;
  if exists (
    select 1
      from public.leases l
      join public.apartments a on a.id = l.apartment_id
      join public.floors f on f.id = a.floor_id
     where f.building_id = p_building and l.status in ('active', 'pending')
  ) then
    raise exception 'لا يمكن حذف عمارة تحتوي عقود إيجار نشطة';
  end if;

  delete from public.leases l
   using public.apartments a, public.floors f
   where l.apartment_id = a.id and a.floor_id = f.id and f.building_id = p_building;
  delete from public.tenant_apartments t
   using public.apartments a, public.floors f
   where t.apartment_id = a.id and a.floor_id = f.id and f.building_id = p_building;
  delete from public.apartments a
   using public.floors f
   where a.floor_id = f.id and f.building_id = p_building;
  delete from public.floors where building_id = p_building;
  delete from public.buildings where id = p_building;
end;
$$;

revoke all on function public.owner_create_compound(text, text, text) from public, anon;
revoke all on function public.owner_update_compound(uuid, text, text, text) from public, anon;
revoke all on function public.owner_create_building(uuid, text, text, integer, integer, numeric, integer, numeric) from public, anon;
revoke all on function public.owner_create_apartment(uuid, integer, text, numeric, integer, numeric, text) from public, anon;
revoke all on function public.owner_update_apartment(uuid, numeric, text, integer, numeric, text) from public, anon;
revoke all on function public.owner_delete_apartment(uuid) from public, anon;
revoke all on function public.owner_delete_building(uuid) from public, anon;

grant execute on function public.owner_create_compound(text, text, text) to authenticated;
grant execute on function public.owner_update_compound(uuid, text, text, text) to authenticated;
grant execute on function public.owner_create_building(uuid, text, text, integer, integer, numeric, integer, numeric) to authenticated;
grant execute on function public.owner_create_apartment(uuid, integer, text, numeric, integer, numeric, text) to authenticated;
grant execute on function public.owner_update_apartment(uuid, numeric, text, integer, numeric, text) to authenticated;
grant execute on function public.owner_delete_apartment(uuid) to authenticated;
grant execute on function public.owner_delete_building(uuid) to authenticated;
