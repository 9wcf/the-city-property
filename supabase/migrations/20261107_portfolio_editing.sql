-- Editable apartment/building details.
-- Apartments: free-text unit name, floor number (0 = ground floor), long description.
-- Buildings: name, address, description and total floors.

alter table public.buildings
  add column if not exists description text;

-- Allow ground floor (0) when creating an apartment.
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
  v_floor_number integer := least(greatest(coalesce(p_floor_number, 1), 0), 200);
begin
  perform public.owner_assert_owner();

  select compound_id into v_compound from public.buildings where id = p_building;
  if v_compound is null or not public.owner_owns_compound(v_compound) then
    raise exception 'هذه العمارة ليست ضمن محفظتك';
  end if;

  select id into v_floor
    from public.floors
   where building_id = p_building and floor_number = v_floor_number;

  if v_floor is null then
    insert into public.floors (building_id, floor_number)
    values (p_building, v_floor_number)
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

drop function if exists public.owner_update_apartment(uuid, numeric, text, integer, numeric, text);

create or replace function public.owner_update_apartment(
  p_apartment uuid,
  p_rent numeric,
  p_status text default null,
  p_rooms integer default null,
  p_area numeric default null,
  p_description text default null,
  p_unit_number text default null,
  p_floor_number integer default null
) returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_building uuid;
  v_floor uuid;
  v_floor_number integer;
begin
  perform public.owner_assert_owner();
  if not public.owner_owns_apartment(p_apartment) then
    raise exception 'هذه الشقة ليست ضمن محفظتك';
  end if;

  select f.building_id, f.id
    into v_building, v_floor
    from public.apartments a
    join public.floors f on f.id = a.floor_id
   where a.id = p_apartment;

  if p_floor_number is not null then
    v_floor_number := least(greatest(p_floor_number, 0), 200);
    select id into v_floor
      from public.floors
     where building_id = v_building and floor_number = v_floor_number;

    if v_floor is null then
      insert into public.floors (building_id, floor_number)
      values (v_building, v_floor_number)
      returning id into v_floor;
    end if;
  end if;

  update public.apartments
     set floor_id = v_floor,
         unit_number = coalesce(
           nullif(btrim(coalesce(p_unit_number, '')), ''),
           unit_number
         ),
         rent_amount = greatest(coalesce(p_rent, rent_amount), 0),
         status = coalesce(nullif(p_status, '')::apartment_status, status),
         room_count = coalesce(p_rooms, room_count),
         area_sqm = case when p_area is null then area_sqm
                         else greatest(p_area, 0) end,
         description = case when p_description is null then description
                            else nullif(btrim(p_description), '') end,
         updated_at = now()
   where id = p_apartment;
end;
$$;

create or replace function public.owner_update_building(
  p_building uuid,
  p_name text,
  p_address text default null,
  p_description text default null,
  p_total_floors integer default null
) returns void
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
  if coalesce(btrim(p_name), '') = '' then
    raise exception 'اسم العمارة مطلوب';
  end if;

  update public.buildings
     set name = btrim(p_name),
         address = nullif(btrim(coalesce(p_address, '')), ''),
         description = case when p_description is null then description
                            else nullif(btrim(p_description), '') end,
         total_floors = least(greatest(coalesce(p_total_floors, total_floors), 1), 60),
         updated_at = now()
   where id = p_building;
end;
$$;

revoke all on function public.owner_update_apartment(uuid, numeric, text, integer, numeric, text, text, integer) from public, anon;
revoke all on function public.owner_update_building(uuid, text, text, text, integer) from public, anon;

grant execute on function public.owner_update_apartment(uuid, numeric, text, integer, numeric, text, text, integer) to authenticated;
grant execute on function public.owner_update_building(uuid, text, text, text, integer) to authenticated;
