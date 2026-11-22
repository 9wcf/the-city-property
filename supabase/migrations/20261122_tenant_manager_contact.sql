-- ============================================================================
-- 2026-11-22 — Tenant ↔ manager contact
--   * المستأجر يرى مدير شقته فقط (تعيين على مستوى العقار أو الشقة).
--   * مدير الشقة يستطيع متابعة محادثة طلب الصيانة مثل مدير المجمع.
-- ============================================================================

-- المستأجر يقرأ تعيين المدير الخاص بشقته (الحالية أو قيد الربط) فقط.
drop policy if exists apartment_managers_select on public.apartment_managers;
drop policy if exists apartment_managers_select_scoped on public.apartment_managers;
create policy apartment_managers_select_scoped on public.apartment_managers
  for select to authenticated
  using (
    manager_id = auth.uid()
    or public.owns_apartment(apartment_id)
    or public.manages_apartment(apartment_id)
    or exists (
      select 1
        from public.tenant_apartments ta
       where ta.tenant_id = auth.uid()
         and ta.apartment_id = apartment_managers.apartment_id
         and coalesce(ta.is_current, true)
    )
    or exists (
      select 1
        from public.leases l
       where l.tenant_id = auth.uid()
         and l.apartment_id = apartment_managers.apartment_id
         and l.status::text in ('pending', 'active')
    )
  );

grant select on public.apartment_managers to authenticated;

-- المستأجر يرى ملف مدير شقته حتى قبل تثبيت الربط (عقد قيد الموافقة).
create or replace function public.can_view_profile(p_target uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select
    p_target = auth.uid()
    or exists (
      select 1 from public.tenant_apartments ta
       where ta.tenant_id = p_target
         and (public.owns_apartment(ta.apartment_id) or public.manages_apartment(ta.apartment_id))
    )
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
           or exists (
             select 1 from public.apartment_managers am
              where am.apartment_id = a.id
                and am.manager_id = p_target
                and coalesce(am.is_active, true)
           )
         )
    )
    or exists (
      select 1
        from public.leases l
        join public.apartments a on a.id = l.apartment_id
        join public.floors f on f.id = a.floor_id
        join public.buildings b on b.id = f.building_id
        join public.compounds c on c.id = b.compound_id
       where l.tenant_id = auth.uid()
         and l.status::text in ('pending', 'active')
         and (
           c.owner_id = p_target
           or exists (
             select 1 from public.manager_assignments ma
              where ma.compound_id = c.id
                and ma.manager_id = p_target
                and coalesce(ma.is_active, true)
           )
           or exists (
             select 1 from public.apartment_managers am
              where am.apartment_id = a.id
                and am.manager_id = p_target
                and coalesce(am.is_active, true)
           )
         )
    )
    or exists (
      select 1 from public.leases l
       where l.tenant_id = p_target
         and l.status::text in ('pending', 'active')
         and (public.owns_apartment(l.apartment_id) or public.manages_apartment(l.apartment_id))
    )
    or exists (
      select 1 from public.maintenance_requests r
       where r.tenant_id = p_target
         and (public.owns_apartment(r.apartment_id) or public.manages_apartment(r.apartment_id))
    )
    or exists (
      select 1 from public.manager_assignments ma
       where ma.manager_id = p_target
         and coalesce(ma.is_active, true)
         and public.owns_compound(ma.compound_id)
    )
    or exists (
      select 1 from public.apartment_managers am
       where am.manager_id = p_target
         and coalesce(am.is_active, true)
         and public.owns_apartment(am.apartment_id)
    )
    or exists (
      select 1
        from public.compounds c
        join public.manager_assignments ma on ma.compound_id = c.id
       where c.owner_id = p_target
         and ma.manager_id = auth.uid()
         and coalesce(ma.is_active, true)
    )
    or exists (
      select 1
        from public.apartments a
        join public.floors f on f.id = a.floor_id
        join public.buildings b on b.id = f.building_id
        join public.compounds c on c.id = b.compound_id
        join public.apartment_managers am on am.apartment_id = a.id
       where c.owner_id = p_target
         and am.manager_id = auth.uid()
         and coalesce(am.is_active, true)
    );
$$;

revoke all on function public.can_view_profile(uuid) from public, anon;
grant execute on function public.can_view_profile(uuid) to authenticated;

-- محادثة الطلب: المالك والمستأجر ومدير الشقة/المجمع.
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
         or public.owns_apartment(r.apartment_id)
         or public.manages_apartment(r.apartment_id)
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
         or public.owns_apartment(r.apartment_id)
         or public.manages_apartment(r.apartment_id)
       )
  )
);

notify pgrst, 'reload schema';
