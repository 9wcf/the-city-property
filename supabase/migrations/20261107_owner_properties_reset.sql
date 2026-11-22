-- Hard reset of the property data requested by the owner: remove every old
-- compound/building/floor/apartment together with leases, tenant links,
-- invoices, maintenance requests, announcements and manager assignments
-- (all removed by ON DELETE CASCADE), then seed a clean portfolio for
-- owner@thecity.com with the four independent properties:
--   عمارة شارع 42      -> 13 apartments (4/3/3/3)
--   عمارة الكرادة خارج -> 13 apartments (4/3/3/3)
--   عمارة الكرادة داخل -> 8  apartments (3/3/2)
--   عمارة الوردة       -> 11 apartments (3/3/3/2)

-- chat_rooms has no ON DELETE CASCADE, so detach old rooms first.
delete from public.chat_rooms
 where related_apartment_id is not null;

delete from public.compounds;

do $$
declare
  v_owner uuid := 'b46f5598-92b4-42e7-87b0-40a17fbb8298';
  v_specs jsonb := '[
    {"name":"عمارة شارع 42","location":"بغداد - الكرادة - شارع 42","counts":[4,3,3,3]},
    {"name":"عمارة الكرادة خارج","location":"بغداد - الكرادة - خارج","counts":[4,3,3,3]},
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
  f integer;
  u integer;
begin
  for v_spec in select * from jsonb_array_elements(v_specs) loop
    v_name := v_spec->>'name';
    v_location := v_spec->>'location';

    insert into public.compounds (name, location, owner_id, is_active)
    values (v_name, v_location, v_owner, true)
    returning id into v_compound;

    insert into public.buildings (compound_id, name, address, total_floors, is_active)
    values (v_compound, v_name, v_location, jsonb_array_length(v_spec->'counts'), true)
    returning id into v_building;

    for f in 0 .. jsonb_array_length(v_spec->'counts') - 1 loop
      v_floor_number := f + 1;
      insert into public.floors (building_id, floor_number)
      values (v_building, v_floor_number)
      returning id into v_floor;

      v_units := (v_spec->'counts'->f)::int;
      for u in 1 .. v_units loop
        insert into public.apartments
          (floor_id, unit_number, room_count, area_sqm, rent_amount, status)
        values
          (v_floor, (v_floor_number * 100 + u)::text, 2, null, 0, 'vacant');
      end loop;
    end loop;
  end loop;
end;
$$;
