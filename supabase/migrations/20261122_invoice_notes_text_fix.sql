-- ============================================================================
-- 2026-11-22 — إصلاح النص العربي في دالة إصدار الفواتير الشهرية
-- كانت الملاحظة تُكتب «ط¥ظٹط¬ط§ط± ط´ظ‡ط± …» بسبب تخزين الدالة بنص مشوّش
-- (UTF-8 قُرئ كـ WIN1256). هذا الملف يعيد كتابة الدالة بنصوص صحيحة.
-- ============================================================================

create or replace function public.generate_monthly_invoices(
  p_compound_id uuid default null,
  p_month date default null
)
returns integer
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_month date := date_trunc('month', coalesce(p_month, current_date))::date;
  v_count integer := 0;
begin
  if auth.uid() is null then
    raise exception 'يجب تسجيل الدخول أولاً';
  end if;
  if p_compound_id is not null and not public.owns_compound(p_compound_id) then
    raise exception 'يمكن للمالك فقط إصدار فواتير مجمعاته';
  end if;

  insert into public.invoices (
    lease_id, apartment_id, tenant_id, invoice_number,
    invoice_date, due_date, rent_amount, total_amount, status, paid_amount, notes
  )
  select l.id,
         l.apartment_id,
         l.tenant_id,
         'INV-' || to_char(v_month, 'YYYYMM') || '-' || substr(replace(l.id::text, '-', ''), 1, 6),
         v_month,
         v_month + 9,
         l.monthly_rent,
         l.monthly_rent,
         'pending',
         0,
         'إيجار شهر ' || to_char(v_month, 'YYYY-MM')
    from public.leases l
    join public.apartments a on a.id = l.apartment_id
    join public.floors f on f.id = a.floor_id
    join public.buildings b on b.id = f.building_id
    join public.compounds c on c.id = b.compound_id
   where l.status = 'active'
     and c.owner_id = auth.uid()
     and (p_compound_id is null or b.compound_id = p_compound_id)
     and not exists (
       select 1 from public.invoices i
        where i.lease_id = l.id
          and date_trunc('month', i.invoice_date) = v_month
     );

  get diagnostics v_count = row_count;
  return v_count;
end;
$function$;

notify pgrst, 'reload schema';
