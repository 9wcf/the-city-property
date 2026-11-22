-- ============================================================================
-- 2026-11-07 — Manager accounting
--   * مصاريف مرتبطة ببناية محددة
--   * صلاحيات مدير البناية: تسجيل الإيجارات ومصاريف بناياته
-- ============================================================================

alter table public.expenses
  add column if not exists building_id uuid references public.buildings(id) on delete set null;

create index if not exists expenses_building_idx
  on public.expenses (building_id);
create index if not exists expenses_compound_date_idx
  on public.expenses (compound_id, expense_date);

-- مدير المجمع أو مدير أي شقة داخل البناية.
create or replace function public.manages_building(p_building_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
           select 1
             from public.buildings b
            where b.id = p_building_id
              and public.manages_compound(b.compound_id)
         )
      or exists (
           select 1
             from public.apartments a
             join public.floors f on f.id = a.floor_id
            where f.building_id = p_building_id
              and public.manages_apartment(a.id)
         );
$$;

grant execute on function public.manages_building(uuid) to authenticated;

-- مدير المجمع أو مدير أي شقة داخل أي بناية من المجمع.
create or replace function public.manages_expense_scope(p_compound_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.manages_compound(p_compound_id)
      or exists (
           select 1
             from public.apartment_managers am
             join public.apartments a on a.id = am.apartment_id
             join public.floors f on f.id = a.floor_id
             join public.buildings b on b.id = f.building_id
            where b.compound_id = p_compound_id
              and am.manager_id = auth.uid()
              and coalesce(am.is_active, true)
         );
$$;

grant execute on function public.manages_expense_scope(uuid) to authenticated;

drop policy if exists expenses_select on public.expenses;
drop policy if exists expenses_manager_insert on public.expenses;
drop policy if exists expenses_manager_update on public.expenses;
drop policy if exists expenses_manager_delete on public.expenses;

create policy expenses_select on public.expenses
  for select to authenticated
  using (public.owns_compound(compound_id) or public.manages_expense_scope(compound_id));

create policy expenses_manager_insert on public.expenses
  for insert to authenticated
  with check (
    public.manages_expense_scope(compound_id)
    and (
      building_id is null
      or exists (
           select 1
             from public.buildings b
            where b.id = expenses.building_id
              and b.compound_id = expenses.compound_id
              and public.manages_building(b.id)
         )
    )
  );

create policy expenses_manager_update on public.expenses
  for update to authenticated
  using (created_by = auth.uid() and public.manages_expense_scope(compound_id))
  with check (
    created_by = auth.uid()
    and public.manages_expense_scope(compound_id)
    and (
      building_id is null
      or exists (
           select 1
             from public.buildings b
            where b.id = expenses.building_id
              and b.compound_id = expenses.compound_id
              and public.manages_building(b.id)
         )
    )
  );

create policy expenses_manager_delete on public.expenses
  for delete to authenticated
  using (created_by = auth.uid() and public.manages_expense_scope(compound_id));

notify pgrst, 'reload schema';
