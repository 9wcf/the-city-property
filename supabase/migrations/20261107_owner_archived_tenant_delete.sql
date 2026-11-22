-- Owner-only permanent removal of an archived tenant.
--
-- An archived tenant is a tenant_apartments row with is_current = false and a
-- move_out_date inside the caller's portfolio. The function refuses to touch
-- anyone who still rents a unit or has an active/pending lease anywhere, and
-- refuses when part of the tenant's history belongs to another owner, so a
-- delete can never reach outside the caller's portfolio.

-- The dashboard reads archived tenants through this function instead of the
-- tables directly: the owner has no select policy on tenant_apartments and
-- payments, so a direct query comes back empty for the owner.
create or replace function public.owner_archived_tenants()
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_result jsonb;
begin
  perform public.owner_assert_owner();

  select coalesce(
           jsonb_agg(latest.rec order by latest.rec->>'move_out_date' desc),
           '[]'::jsonb
         )
    into v_result
    from (
      select distinct on (ta.tenant_id)
             jsonb_build_object(
               'tenant_id', p.id,
               'profile', jsonb_build_object(
                 'id', p.id,
                 'full_name', p.full_name,
                 'phone_number', p.phone_number,
                 'email', p.email,
                 'avatar_url', p.avatar_url,
                 'notes', p.notes,
                 'role', p.role,
                 'is_active', p.is_active
               ),
               'apartment_id', ta.apartment_id,
               'move_out_date', ta.move_out_date,
               'payments_count',
                 (select count(*) from public.payments pay
                   where pay.tenant_id = p.id),
               'paid_total',
                 (select coalesce(sum(pay.amount), 0) from public.payments pay
                   where pay.tenant_id = p.id)
             ) as rec
        from public.tenant_apartments ta
        join public.profiles p on p.id = ta.tenant_id
       where coalesce(ta.is_current, false) = false
         and ta.move_out_date is not null
         and p.role = 'tenant'
         and public.owner_owns_apartment(ta.apartment_id)
       order by ta.tenant_id, ta.move_out_date desc
    ) latest;

  return v_result;
end;
$$;

revoke all on function public.owner_archived_tenants() from public, anon;
grant execute on function public.owner_archived_tenants() to authenticated;

create or replace function public.owner_delete_archived_tenant(p_tenant_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_role text;
begin
  perform public.owner_assert_owner();

  select p.role::text into v_role
    from public.profiles p
   where p.id = p_tenant_id;

  if v_role is null then
    raise exception 'المستأجر غير موجود';
  end if;
  if v_role <> 'tenant' then
    raise exception 'يمكن حذف حسابات المستأجرين فقط';
  end if;

  if not exists (
    select 1
      from public.tenant_apartments ta
     where ta.tenant_id = p_tenant_id
       and coalesce(ta.is_current, false) = false
       and ta.move_out_date is not null
       and public.owner_owns_apartment(ta.apartment_id)
  ) then
    raise exception 'هذا المستأجر غير مؤرشف ضمن محفظتك';
  end if;

  if exists (
    select 1
      from public.tenant_apartments
     where tenant_id = p_tenant_id
       and coalesce(is_current, false) = true
  ) then
    raise exception 'لا يمكن حذف مستأجر مرتبط بشقة حالياً';
  end if;

  if exists (
    select 1
      from public.leases
     where tenant_id = p_tenant_id
       and status in ('active', 'pending')
  ) then
    raise exception 'لا يمكن حذف مستأجر لديه عقد نشط أو طلب ربط معلّق';
  end if;

  if exists (
    select 1
      from public.tenant_apartments ta
     where ta.tenant_id = p_tenant_id
       and not public.owner_owns_apartment(ta.apartment_id)
  ) then
    raise exception 'سجل هذا المستأجر مرتبط بعقارات خارج محفظتك';
  end if;

  update public.expenses set created_by = null where created_by = p_tenant_id;
  update public.apartment_managers set assigned_by = null
   where assigned_by = p_tenant_id;
  update public.payments set created_by = null where created_by = p_tenant_id;
  update public.manager_assignments set assigned_by = null
   where assigned_by = p_tenant_id;
  update public.maintenance_requests set approved_by = null
   where approved_by = p_tenant_id;
  update public.maintenance_requests set assigned_employee_id = null
   where assigned_employee_id = p_tenant_id;
  update public.maintenance_images set uploaded_by = null
   where uploaded_by = p_tenant_id;
  update public.tenant_documents set verified_by = null
   where verified_by = p_tenant_id;
  update public.audit_log set user_id = null where user_id = p_tenant_id;
  delete from public.announcements where created_by = p_tenant_id;

  delete from public.chat_messages where sender_id = p_tenant_id;
  delete from public.chat_room_members where user_id = p_tenant_id;
  delete from public.tenant_documents where tenant_id = p_tenant_id;
  delete from public.maintenance_messages where sender_id = p_tenant_id;
  delete from public.maintenance_requests where tenant_id = p_tenant_id;
  delete from public.lease_documents where tenant_id = p_tenant_id;
  delete from public.payments where tenant_id = p_tenant_id;
  delete from public.invoices where tenant_id = p_tenant_id;
  delete from public.notifications where user_id = p_tenant_id;
  delete from public.device_tokens where user_id = p_tenant_id;
  delete from public.tenant_apartments where tenant_id = p_tenant_id;
  delete from public.leases where tenant_id = p_tenant_id;
  delete from public.profiles where id = p_tenant_id;
  delete from auth.users where id = p_tenant_id;
end;
$$;

revoke all on function public.owner_delete_archived_tenant(uuid) from public, anon;
grant execute on function public.owner_delete_archived_tenant(uuid) to authenticated;

-- Owners must be able to read the rent payments of tenants in their portfolio
-- so the archived-tenant panel can show the full history before deletion.
drop policy if exists payments_select_owner on public.payments;
create policy payments_select_owner on public.payments
  for select to authenticated
  using (
    exists (
      select 1
        from public.tenant_apartments ta
        join public.apartments a on a.id = ta.apartment_id
        join public.floors f on f.id = a.floor_id
        join public.buildings b on b.id = f.building_id
        join public.compounds c on c.id = b.compound_id
       where ta.tenant_id = payments.tenant_id
         and c.owner_id = auth.uid()
    )
  );

notify pgrst, 'reload schema';
