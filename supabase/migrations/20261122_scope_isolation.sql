-- ============================================================================
-- 2026-11-22 — Row-level isolation (IQ / AE / US)
--   * المالك: يقرأ كل عقاراته في الدول الثلاث.
--   * مدير البناية: يقرأ فقط المجمع/البناية المسؤول عنها.
--   * مدير شقة: يقرأ فقط شقته وبنايتها ومجمعها.
--   * المستأجر: يقرأ شقته وعقده ومدفوعاته فقط، ويستطيع تصفح
--     الشقق الفارغة في دولته قبل الربط.
--   * فرض القيود في قاعدة البيانات (RLS) بدل الاعتماد على فلترة التطبيق.
-- ============================================================================

-- ---------------------------------------------------------------- helpers
create or replace function public.my_country()
returns text
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
    (select p.country from public.profiles p where p.id = auth.uid()),
    'IQ'
  );
$$;

create or replace function public.is_tenant_user()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
    (select p.role::text from public.profiles p where p.id = auth.uid()),
    'tenant'
  ) = 'tenant';
$$;

-- مستأجر يبحث عن شقة: ليس لديه سكن حالي.
create or replace function public.can_browse_vacancies()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.is_tenant_user()
     and not exists (
       select 1 from public.tenant_apartments ta
        where ta.tenant_id = auth.uid()
          and coalesce(ta.is_current, false)
     );
$$;

create or replace function public.compound_of_building(p_building uuid)
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select b.compound_id from public.buildings b where b.id = p_building;
$$;

create or replace function public.compound_of_floor(p_floor uuid)
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select b.compound_id
    from public.floors f
    join public.buildings b on b.id = f.building_id
   where f.id = p_floor;
$$;

create or replace function public.can_view_compound(p_compound_id uuid)
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
         )
      or exists (
           select 1
             from public.apartment_managers am
             join public.apartments a on a.id = am.apartment_id
             join public.floors f on f.id = a.floor_id
             join public.buildings b on b.id = f.building_id
            where b.compound_id = p_compound_id
              and am.manager_id = auth.uid()
              and coalesce(am.is_active, true)
         )
      or exists (
           select 1
             from public.tenant_apartments ta
             join public.apartments a on a.id = ta.apartment_id
             join public.floors f on f.id = a.floor_id
             join public.buildings b on b.id = f.building_id
            where b.compound_id = p_compound_id
              and ta.tenant_id = auth.uid()
         )
      or exists (
           select 1
             from public.leases l
             join public.apartments a on a.id = l.apartment_id
             join public.floors f on f.id = a.floor_id
             join public.buildings b on b.id = f.building_id
            where b.compound_id = p_compound_id
              and l.tenant_id = auth.uid()
              and l.status::text in ('pending', 'active')
         )
      -- تصفح الشقق الفارغة: دولة المستأجر فقط.
      or (
           public.can_browse_vacancies()
           and exists (
             select 1 from public.compounds c
              where c.id = p_compound_id
                and c.is_active
                and c.country = public.my_country()
           )
         );
$$;

create or replace function public.can_manage_tenant(p_tenant_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.tenant_apartments ta
     where ta.tenant_id = p_tenant_id
       and (
         public.owns_apartment(ta.apartment_id)
         or public.manages_apartment(ta.apartment_id)
       )
  );
$$;

revoke all on function public.my_country() from public, anon;
revoke all on function public.is_tenant_user() from public, anon;
revoke all on function public.can_browse_vacancies() from public, anon;
revoke all on function public.compound_of_building(uuid) from public, anon;
revoke all on function public.compound_of_floor(uuid) from public, anon;
revoke all on function public.can_view_compound(uuid) from public, anon;
revoke all on function public.can_manage_tenant(uuid) from public, anon;
grant execute on function public.my_country() to authenticated;
grant execute on function public.is_tenant_user() to authenticated;
grant execute on function public.can_browse_vacancies() to authenticated;
grant execute on function public.compound_of_building(uuid) to authenticated;
grant execute on function public.compound_of_floor(uuid) to authenticated;
grant execute on function public.can_view_compound(uuid) to authenticated;
grant execute on function public.can_manage_tenant(uuid) to authenticated;

-- owner <-> apartment-level manager visibility
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
      select 1 from public.leases l
       where l.tenant_id = p_target
         and l.status = 'pending'
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

-- ---------------------------------------------------------------- enable RLS
alter table public.compounds           enable row level security;
alter table public.buildings           enable row level security;
alter table public.floors              enable row level security;
alter table public.apartments          enable row level security;
alter table public.leases              enable row level security;
alter table public.invoices            enable row level security;
alter table public.payments            enable row level security;
alter table public.maintenance_requests enable row level security;
alter table public.tenant_apartments   enable row level security;
alter table public.manager_assignments enable row level security;
alter table public.notifications       enable row level security;

-- ---------------------------------------------------------------- catalogue
drop policy if exists compounds_select_policy on public.compounds;
drop policy if exists "Owners and staff can view compounds" on public.compounds;
drop policy if exists compounds_select_scoped on public.compounds;
create policy compounds_select_scoped on public.compounds
  for select to authenticated
  using (public.can_view_compound(id));

drop policy if exists buildings_select_policy on public.buildings;
drop policy if exists buildings_select_scoped on public.buildings;
create policy buildings_select_scoped on public.buildings
  for select to authenticated
  using (public.can_view_compound(compound_id));

drop policy if exists floors_select_policy on public.floors;
drop policy if exists floors_select_scoped on public.floors;
create policy floors_select_scoped on public.floors
  for select to authenticated
  using (public.can_view_compound(public.compound_of_building(building_id)));

drop policy if exists "Everyone can view apartments" on public.apartments;
drop policy if exists apartments_select_policy on public.apartments;
drop policy if exists apartments_select_scoped on public.apartments;
create policy apartments_select_scoped on public.apartments
  for select to authenticated
  using (
    public.owns_apartment(id)
    or public.manages_apartment(id)
    or exists (
      select 1 from public.tenant_apartments ta
       where ta.apartment_id = apartments.id
         and ta.tenant_id = auth.uid()
    )
    or exists (
      select 1 from public.leases l
       where l.apartment_id = apartments.id
         and l.tenant_id = auth.uid()
         and l.status::text in ('pending', 'active')
    )
    or (
      status::text = 'vacant'
      and public.can_view_compound(public.compound_of_floor(floor_id))
    )
  );

drop policy if exists apartments_update_staff on public.apartments;
create policy apartments_update_staff on public.apartments
  for update to authenticated
  using (public.owns_apartment(id) or public.manages_apartment(id))
  with check (public.owns_apartment(id) or public.manages_apartment(id));

grant select on public.compounds, public.buildings, public.floors,
  public.apartments to authenticated;
grant update on public.apartments to authenticated;

-- ---------------------------------------------------------------- leases
drop policy if exists leases_select_policy on public.leases;
drop policy if exists "Tenants and staff can view leases" on public.leases;
drop policy if exists leases_select_scoped on public.leases;
create policy leases_select_scoped on public.leases
  for select to authenticated
  using (
    tenant_id = auth.uid()
    or public.owns_apartment(apartment_id)
    or public.manages_apartment(apartment_id)
  );

drop policy if exists leases_insert_policy on public.leases;
drop policy if exists "Only managers can create leases" on public.leases;
drop policy if exists leases_insert_tenant_pending on public.leases;
create policy leases_insert_tenant_pending on public.leases
  for insert to authenticated
  with check (
    tenant_id = auth.uid()
    and status::text = 'pending'
  );

drop policy if exists leases_update_staff on public.leases;
create policy leases_update_staff on public.leases
  for update to authenticated
  using (
    public.owns_apartment(apartment_id)
    or public.manages_apartment(apartment_id)
  )
  with check (
    public.owns_apartment(apartment_id)
    or public.manages_apartment(apartment_id)
  );

grant select, insert, update on public.leases to authenticated;

-- ---------------------------------------------------------------- tenant links
drop policy if exists tenant_apartments_insert on public.tenant_apartments;
drop policy if exists tenant_apartments_delete_own_pending on public.tenant_apartments;
drop policy if exists tenant_apartments_select_scoped on public.tenant_apartments;
drop policy if exists tenant_apartments_insert_tenant on public.tenant_apartments;
drop policy if exists tenant_apartments_update_staff on public.tenant_apartments;
drop policy if exists tenant_apartments_delete_scoped on public.tenant_apartments;

create policy tenant_apartments_select_scoped on public.tenant_apartments
  for select to authenticated
  using (
    tenant_id = auth.uid()
    or public.owns_apartment(apartment_id)
    or public.manages_apartment(apartment_id)
  );

create policy tenant_apartments_insert_tenant on public.tenant_apartments
  for insert to authenticated
  with check (
    tenant_id = auth.uid()
    and coalesce(is_current, false) = false
    and exists (
      select 1 from public.leases l
       where l.tenant_id = auth.uid()
         and l.apartment_id = tenant_apartments.apartment_id
         and l.status::text in ('pending', 'active')
    )
  );

create policy tenant_apartments_update_staff on public.tenant_apartments
  for update to authenticated
  using (public.owns_apartment(apartment_id) or public.manages_apartment(apartment_id))
  with check (public.owns_apartment(apartment_id) or public.manages_apartment(apartment_id));

create policy tenant_apartments_delete_scoped on public.tenant_apartments
  for delete to authenticated
  using (
    (tenant_id = auth.uid() and coalesce(is_current, false) = false)
    or public.owns_apartment(apartment_id)
    or public.manages_apartment(apartment_id)
  );

grant select, insert, update, delete on public.tenant_apartments to authenticated;

-- ---------------------------------------------------------------- invoices
drop policy if exists invoices_select on public.invoices;
drop policy if exists invoices_select_scoped on public.invoices;
create policy invoices_select_scoped on public.invoices
  for select to authenticated
  using (
    tenant_id = auth.uid()
    or public.owns_apartment(apartment_id)
    or public.manages_apartment(apartment_id)
  );

grant select on public.invoices to authenticated;

-- ---------------------------------------------------------------- payments
drop policy if exists payments_select_policy on public.payments;
drop policy if exists payments_select_scoped on public.payments;
drop policy if exists payments_insert_policy on public.payments;
drop policy if exists payments_insert_scoped on public.payments;
drop policy if exists payments_select_isolated on public.payments;
drop policy if exists payments_insert_isolated on public.payments;

create policy payments_select_isolated on public.payments
  for select to authenticated
  using (
    tenant_id = auth.uid()
    or created_by = auth.uid()
    or public.can_manage_tenant(tenant_id)
  );

create policy payments_insert_isolated on public.payments
  for insert to authenticated
  with check (
    created_by = auth.uid()
    and (
      tenant_id = auth.uid()
      or public.can_manage_tenant(tenant_id)
    )
  );

grant select, insert on public.payments to authenticated;

-- ---------------------------------------------------------------- maintenance
drop policy if exists "Relevant users can view maintenance requests" on public.maintenance_requests;
drop policy if exists "Employees can update assigned requests" on public.maintenance_requests;
drop policy if exists "Tenants can create requests" on public.maintenance_requests;
drop policy if exists maintenance_select_policy on public.maintenance_requests;
drop policy if exists maintenance_update_policy on public.maintenance_requests;
drop policy if exists maintenance_select_scoped on public.maintenance_requests;
drop policy if exists maintenance_update_scoped on public.maintenance_requests;
drop policy if exists maintenance_insert_tenant on public.maintenance_requests;
drop policy if exists maintenance_select_isolated on public.maintenance_requests;
drop policy if exists maintenance_update_isolated on public.maintenance_requests;

create policy maintenance_select_isolated on public.maintenance_requests
  for select to authenticated
  using (
    tenant_id = auth.uid()
    or assigned_employee_id = auth.uid()
    or public.owns_apartment(apartment_id)
    or public.manages_apartment(apartment_id)
  );

create policy maintenance_insert_tenant on public.maintenance_requests
  for insert to authenticated
  with check (
    tenant_id = auth.uid()
    and (
      public.owns_apartment(apartment_id)
      or public.manages_apartment(apartment_id)
      or exists (
        select 1 from public.tenant_apartments ta
         where ta.tenant_id = auth.uid()
           and ta.apartment_id = maintenance_requests.apartment_id
      )
      or exists (
        select 1 from public.leases l
         where l.tenant_id = auth.uid()
           and l.apartment_id = maintenance_requests.apartment_id
           and l.status::text in ('pending', 'active')
      )
    )
  );

create policy maintenance_update_isolated on public.maintenance_requests
  for update to authenticated
  using (
    tenant_id = auth.uid()
    or assigned_employee_id = auth.uid()
    or public.owns_apartment(apartment_id)
    or public.manages_apartment(apartment_id)
  )
  with check (
    tenant_id = auth.uid()
    or assigned_employee_id = auth.uid()
    or public.owns_apartment(apartment_id)
    or public.manages_apartment(apartment_id)
  );

grant select, insert, update on public.maintenance_requests to authenticated;

-- ---------------------------------------------------------------- assignments
drop policy if exists manager_assignments_select on public.manager_assignments;
drop policy if exists manager_assignments_select_scoped on public.manager_assignments;
create policy manager_assignments_select_scoped on public.manager_assignments
  for select to authenticated
  using (
    manager_id = auth.uid()
    or public.owns_compound(compound_id)
    or exists (
      select 1
        from public.tenant_apartments ta
        join public.apartments a on a.id = ta.apartment_id
        join public.floors f on f.id = a.floor_id
        join public.buildings b on b.id = f.building_id
       where b.compound_id = manager_assignments.compound_id
         and ta.tenant_id = auth.uid()
    )
    or exists (
      select 1
        from public.leases l
        join public.apartments a on a.id = l.apartment_id
        join public.floors f on f.id = a.floor_id
        join public.buildings b on b.id = f.building_id
       where b.compound_id = manager_assignments.compound_id
         and l.tenant_id = auth.uid()
         and l.status::text in ('pending', 'active')
    )
  );

grant select on public.manager_assignments to authenticated;

-- ---------------------------------------------------------------- notifications
drop policy if exists notifications_select_own on public.notifications;
drop policy if exists notifications_update_own on public.notifications;
create policy notifications_select_own on public.notifications
  for select to authenticated
  using (user_id = auth.uid());

create policy notifications_update_own on public.notifications
  for update to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

grant select, update on public.notifications to authenticated;

-- ---------------------------------------------------------------- backfill
-- الملفات القديمة أخذت country = 'IQ' افتراضياً؛ نصحّح دولة من لديه سكن حالي
-- من دولة مجمعه الفعلية حتى يعمل تصفح الشقق داخل الدولة الصحيحة.
update public.profiles p
   set country = c.country
  from public.tenant_apartments ta
  join public.apartments a on a.id = ta.apartment_id
  join public.floors f on f.id = a.floor_id
  join public.buildings b on b.id = f.building_id
  join public.compounds c on c.id = b.compound_id
 where p.id = ta.tenant_id
   and coalesce(ta.is_current, false)
   and p.country is distinct from c.country;

notify pgrst, 'reload schema';
