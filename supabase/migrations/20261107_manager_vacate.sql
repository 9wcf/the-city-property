-- ============================================================================
-- 2026-11-07 — إخلاء الشقة وأرشفة المستأجر
--   * يحوّل حالة الشقة إلى «فارغة» ويوقف ربط المستأجر الحالي.
--   * ينهي العقد النشط ويحفظ تاريخ الإخلاء والملاحظات في الأرشيف.
--   * متاح للمالك ومدير المجمع ومدير الشقة.
-- ============================================================================

alter table public.tenant_apartments
  add column if not exists move_out_date date;

create or replace function public.vacate_tenant(
  p_tenant_id uuid,
  p_apartment_id uuid,
  p_move_out_date date default current_date,
  p_notes text default null
) returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_is_current boolean;
  v_lease_id   uuid;
  v_status     text;
  v_date       date := coalesce(p_move_out_date, current_date);
begin
  if auth.uid() is null then
    raise exception 'يجب تسجيل الدخول أولاً';
  end if;

  if not (public.owns_apartment(p_apartment_id)
          or public.manages_apartment(p_apartment_id)) then
    raise exception 'ليس لديك صلاحية على هذه الشقة';
  end if;

  select coalesce(is_current, false)
    into v_is_current
    from public.tenant_apartments
   where tenant_id = p_tenant_id
     and apartment_id = p_apartment_id
   limit 1;

  if not coalesce(v_is_current, false) then
    raise exception 'هذا المستأجر غير مرتبط بالشقة حالياً';
  end if;

  update public.tenant_apartments
     set is_current = false,
         move_out_date = v_date
   where tenant_id = p_tenant_id
     and apartment_id = p_apartment_id;

  select id
    into v_lease_id
    from public.leases
   where tenant_id = p_tenant_id
     and apartment_id = p_apartment_id
     and status = 'active'
   order by start_date desc
   limit 1;

  -- نختار أول حالة نهائية متاحة في نوع lease_status.
  select e.enumlabel::text
    into v_status
    from pg_enum e
   where e.enumtypid = 'public.lease_status'::regtype
     and e.enumlabel in ('terminated', 'expired', 'ended', 'cancelled')
   order by array_position(
     array['terminated', 'expired', 'ended', 'cancelled']::text[],
     e.enumlabel::text
   )
   limit 1;

  if v_lease_id is not null then
    update public.leases
       set end_date = least(end_date, v_date),
           status = coalesce(v_status, status::text)::public.lease_status,
           notes = case
             when nullif(trim(coalesce(p_notes, '')), '') is null then notes
             else concat_ws(E'\n', notes, 'إخلاء: ' || trim(p_notes))
           end,
           updated_at = now()
     where id = v_lease_id;
  end if;

  update public.apartments
     set status = 'vacant'
   where id = p_apartment_id;

  return jsonb_build_object(
    'tenant_id', p_tenant_id,
    'apartment_id', p_apartment_id,
    'lease_id', v_lease_id,
    'lease_status', v_status,
    'move_out_date', v_date
  );
end;
$$;

grant execute on function public.vacate_tenant(uuid, uuid, date, text) to authenticated;

notify pgrst, 'reload schema';
