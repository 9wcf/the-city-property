-- Restructure the owner portfolio (owner@thecity.com) into four independent
-- properties, each with a single building:
--   عمارة شارع 42      -> 13 apartments (4/3/3/3)
--   عمارة الكرادة خارج -> 13 apartments (4/3/3/3)
--   عمارة الكرادة داخل -> 8  apartments (3/3/2)
--   عمارة الوردة       -> 11 apartments (3/3/3/2)
--
-- The two existing compounds are renamed in place instead of deleted so the
-- active leases (علاوي الزاجل - 101, علي حسون هاشم - 203) stay intact.
-- Safe to re-run: compounds/buildings/floors/units are matched before insert.

do $$
declare
  v_owner uuid := 'b46f5598-92b4-42e7-87b0-40a17fbb8298';
  v_specs jsonb := '[
    {"name":"عمارة شارع 42","location":"بغداد - الكرادة - شارع 42","counts":[4,3,3,3],
     "compound":"65127c0a-cf3c-43a1-b59f-fafd4e1b427c","building":"be5f07f0-fbe1-4d44-b791-9b6246ad3da4"},
    {"name":"عمارة الكرادة خارج","location":"بغداد - الكرادة - خارج","counts":[4,3,3,3],
     "compound":"d0063e59-7c3c-4cf1-bf77-e7ddee4ea9bf","building":"70ebd100-2024-4c22-997a-2eb43c4d5204"},
    {"name":"عمارة الكرادة داخل","location":"بغداد - الكرادة - داخل","counts":[3,3,2]},
    {"name":"عمارة الوردة","location":"بغداد - الكرادة - الوردة","counts":[3,3,3,2]}
  ]'::jsonb;
  v_spec jsonb;
  v_name text;
  v_location text;
  v_compound uuid;
  v_building uuid;
  v_floor uuid;
  v_floor_number integer;
  v_units integer;
  v_unit text;
  f integer;
  u integer;
begin
  for v_spec in select * from jsonb_array_elements(v_specs) loop
    v_name := v_spec->>'name';
    v_location := v_spec->>'location';
    v_compound := null;
    v_building := null;

    if v_spec->>'compound' is not null then
      update public.compounds
         set name = v_name,
             location = v_location,
             is_active = true,
             updated_at = now()
       where id = (v_spec->>'compound')::uuid
         and owner_id = v_owner
      returning id into v_compound;
    end if;

    if v_compound is null then
      select id into v_compound
        from public.compounds
       where owner_id = v_owner and name = v_name
       limit 1;
    end if;

    if v_compound is null then
      insert into public.compounds (name, location, owner_id, is_active)
      values (v_name, v_location, v_owner, true)
      returning id into v_compound;
    end if;

    if v_spec->>'building' is not null then
      select id into v_building
        from public.buildings
       where id = (v_spec->>'building')::uuid
         and compound_id = v_compound;
    end if;

    if v_building is null then
      select id into v_building
        from public.buildings
       where compound_id = v_compound
       order by created_at
       limit 1;
    end if;

    if v_building is null then
      insert into public.buildings (compound_id, name, address, total_floors, is_active)
      values (v_compound, v_name, v_location, jsonb_array_length(v_spec->'counts'), true)
      returning id into v_building;
    end if;

    update public.buildings
       set name = v_name,
           address = v_location,
           total_floors = jsonb_array_length(v_spec->'counts'),
           is_active = true,
           updated_at = now()
     where id = v_building;

    for f in 0 .. jsonb_array_length(v_spec->'counts') - 1 loop
      v_floor_number := f + 1;
      select id into v_floor
        from public.floors
       where building_id = v_building and floor_number = v_floor_number;

      if v_floor is null then
        insert into public.floors (building_id, floor_number)
        values (v_building, v_floor_number)
        returning id into v_floor;
      end if;

      v_units := (v_spec->'counts'->f)::int;
      for u in 1 .. v_units loop
        v_unit := (v_floor_number * 100 + u)::text;
        if not exists (
          select 1 from public.apartments
           where floor_id = v_floor and unit_number = v_unit
        ) then
          insert into public.apartments
            (floor_id, unit_number, room_count, area_sqm, rent_amount, status)
          values
            (v_floor, v_unit, 2, null, 0, 'vacant');
        end if;
      end loop;
    end loop;
  end loop;
end;
$$;
