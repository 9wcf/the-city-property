-- ----------------------------------------------------------------------------
-- 2026-11-06 — Manager ↔ compound assignments controlled by the owner.
-- One manager may serve many compounds (one row per compound).
-- Only the compound owner can assign/remove; the client never edits
-- manager_assignments directly.
-- ----------------------------------------------------------------------------

-- Assign (or re-activate) a manager on a compound using the manager's phone.
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

-- Deactivate an assignment; the row is kept so the history survives.
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
