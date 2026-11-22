-- ============================================================================
-- 2026-11-22 — Catalogue read-scope hardening
--   Replaces the permissive `*_authenticated_read` policies (qual = true) on
--   compounds/buildings/floors/apartments with role-scoped policies:
--     * owner   -> only the compounds they own
--     * manager -> the compound assigned to them (all its units) or, for an
--                  apartment-level manager, that single unit
--     * tenant  -> their own unit/compound; vacant units of their own country
--                  are browsable only while they have no current housing
--   Write policies are unchanged.
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

revoke all on function public.my_country() from public, anon;
revoke all on function public.is_tenant_user() from public, anon;
revoke all on function public.can_browse_vacancies() from public, anon;
revoke all on function public.compound_of_building(uuid) from public, anon;
revoke all on function public.compound_of_floor(uuid) from public, anon;
revoke all on function public.can_view_compound(uuid) from public, anon;
grant execute on function public.my_country() to authenticated;
grant execute on function public.is_tenant_user() to authenticated;
grant execute on function public.can_browse_vacancies() to authenticated;
grant execute on function public.compound_of_building(uuid) to authenticated;
grant execute on function public.compound_of_floor(uuid) to authenticated;
grant execute on function public.can_view_compound(uuid) to authenticated;

-- ---------------------------------------------------------------- compounds
drop policy if exists compounds_authenticated_read on public.compounds;
drop policy if exists compounds_select_policy on public.compounds;
drop policy if exists "Owners and staff can view compounds" on public.compounds;
drop policy if exists compounds_select_scoped on public.compounds;
create policy compounds_select_scoped on public.compounds
  for select to authenticated
  using (public.can_view_compound(id));

-- ---------------------------------------------------------------- buildings
drop policy if exists buildings_authenticated_read on public.buildings;
drop policy if exists buildings_select_policy on public.buildings;
drop policy if exists buildings_select_scoped on public.buildings;
create policy buildings_select_scoped on public.buildings
  for select to authenticated
  using (public.can_view_compound(compound_id));

-- ---------------------------------------------------------------- floors
drop policy if exists floors_authenticated_read on public.floors;
drop policy if exists floors_select_policy on public.floors;
drop policy if exists floors_select_scoped on public.floors;
create policy floors_select_scoped on public.floors
  for select to authenticated
  using (public.can_view_compound(public.compound_of_building(building_id)));

-- ---------------------------------------------------------------- apartments
drop policy if exists apartments_authenticated_read on public.apartments;
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
      apartments.status::text = 'vacant'
      and public.can_browse_vacancies()
      and exists (
        select 1
          from public.floors f
          join public.buildings b on b.id = f.building_id
          join public.compounds c on c.id = b.compound_id
         where f.id = apartments.floor_id
           and c.is_active
           and c.country = public.my_country()
      )
    )
  );

grant select on public.compounds, public.buildings, public.floors,
  public.apartments to authenticated;

notify pgrst, 'reload schema';
