-- ============================================================================
-- 2026-11-22 — Tenant visibility of the property manager assignment
--   A tenant linked to a unit (current tenant link or pending/active lease)
--   may read the active compound assignments of that compound only, so the
--   app can fall back to the property manager when the unit has no direct
--   apartment manager. No write access is granted.
-- ============================================================================

drop policy if exists manager_assignments_select_tenant on public.manager_assignments;
create policy manager_assignments_select_tenant on public.manager_assignments
  for select to authenticated
  using (
    exists (
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

notify pgrst, 'reload schema';
