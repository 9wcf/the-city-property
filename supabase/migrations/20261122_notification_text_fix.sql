-- ============================================================================
-- 2026-11-22 — إصلاح نصوص إشعارات الصيانة والإيجار والدفع
-- دوال التريغر كانت مخزّنة بنصوص عربية مشوّشة (UTF-8 قُرئ كـ WIN1256)،
-- فظهرت عناوين مثل «ط¨ظ„ط§ط؛ طµظٹط§ظ†ط© ط¬ط¯ظٹط¯» في شاشة الإشعارات.
-- يعيد هذا الملف كتابة الدوال بنصوص صحيحة ويصلح الإشعارات القديمة.
-- ============================================================================

create or replace function public.notify_maintenance_change()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_compound uuid;
  v_owner    uuid;
  v_managers uuid[];
begin
  select b.compound_id, c.owner_id
    into v_compound, v_owner
    from public.apartments a
    join public.floors f on f.id = a.floor_id
    join public.buildings b on b.id = f.building_id
    join public.compounds c on c.id = b.compound_id
   where a.id = new.apartment_id;

  v_managers := public.managers_for_apartment(new.apartment_id);

  if tg_op = 'INSERT' then
    perform public.push_notification(
      v_managers, 'بلاغ صيانة جديد', new.title, 'maintenance',
      jsonb_build_object('request_id', new.id, 'apartment_id', new.apartment_id));
    perform public.push_notification(
      array[v_owner], 'بلاغ صيانة جديد', new.title, 'maintenance',
      jsonb_build_object('request_id', new.id, 'apartment_id', new.apartment_id));
  elsif tg_op = 'UPDATE' and new.status is distinct from old.status then
    perform public.push_notification(
      array[new.tenant_id], 'تحديث بلاغ الصيانة',
      new.title || ' — ' || case new.status
        when 'submitted' then 'تم الاستلام'
        when 'under_review' then 'قيد المراجعة'
        when 'awaiting_owner' then 'بانتظار موافقة المالك'
        when 'approved' then 'تمت الموافقة'
        when 'in_progress' then 'قيد التنفيذ'
        when 'completed' then 'مكتمل'
        when 'confirmed' then 'تم التأكيد'
        when 'rejected' then 'مرفوض'
        when 'cancelled' then 'ملغى'
        else 'تم التحديث' end,
      'maintenance',
      jsonb_build_object('request_id', new.id, 'status', new.status));
  end if;

  return new;
end;
$function$;

create or replace function public.notify_lease_change()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_compound uuid;
  v_owner    uuid;
begin
  select b.compound_id, c.owner_id
    into v_compound, v_owner
    from public.apartments a
    join public.floors f on f.id = a.floor_id
    join public.buildings b on b.id = f.building_id
    join public.compounds c on c.id = b.compound_id
   where a.id = new.apartment_id;

  if tg_op = 'INSERT' then
    if new.status = 'pending' then
      perform public.push_notification(
        public.managers_for_apartment(new.apartment_id),
        'طلب ربط شقة جديد', 'يوجد طلب سكن بانتظار قرارك', 'lease',
        jsonb_build_object('lease_id', new.id, 'apartment_id', new.apartment_id));
      perform public.push_notification(
        array[v_owner], 'طلب ربط شقة جديد', 'يوجد طلب سكن بانتظار قرار المدير', 'lease',
        jsonb_build_object('lease_id', new.id, 'apartment_id', new.apartment_id));
    end if;
  elsif tg_op = 'UPDATE' and new.status is distinct from old.status then
    perform public.push_notification(
      array[new.tenant_id],
      case new.status when 'active' then 'تمت الموافقة على طلبك' else 'تحديث طلب ربط الشقة' end,
      case new.status
        when 'active' then 'تمت الموافقة على طلب السكن، أهلاً بك.'
        when 'rejected' then 'تم رفض طلب ربط الشقة.'
        else 'الحالة الجديدة: ' || new.status end,
      'lease',
      jsonb_build_object('lease_id', new.id, 'status', new.status));
  end if;

  return new;
end;
$function$;

create or replace function public.notify_payment()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_owner     uuid;
  v_apartment uuid;
  v_country   text;
  v_currency  text;
begin
  select i.apartment_id
    into v_apartment
    from public.invoices i
   where i.id = new.invoice_id;

  select c.owner_id, c.country
    into v_owner, v_country
    from public.apartments a
    join public.floors f on f.id = a.floor_id
    join public.buildings b on b.id = f.building_id
    join public.compounds c on c.id = b.compound_id
   where a.id = v_apartment;

  v_currency := case coalesce(v_country, 'IQ')
    when 'AE' then 'د.إ'
    when 'US' then '$'
    else 'د.ع' end;

  perform public.push_notification(
    array[new.tenant_id], 'تم تسجيل دفعة',
    'تم استلام دفعة بمبلغ ' || new.amount::text || ' ' || v_currency,
    'payment', jsonb_build_object('payment_id', new.id));

  if v_owner is not null then
    perform public.push_notification(
      array[v_owner], 'دفعة جديدة',
      'تم تسجيل دفعة بمبلغ ' || new.amount::text || ' ' || v_currency,
      'payment', jsonb_build_object('payment_id', new.id));
  end if;

  return new;
end;
$function$;

-- ------------------------------------------------ إصلاح إشعارات الصيانة القديمة
with fixed as (
  select n.id,
         (n.data ? 'status') as is_update,
         n.data->>'status' as status_value,
         case
           when r.title is not null then r.title
           when position(' â€” ' in n.body) > 0 then split_part(n.body, ' â€” ', 1)
           when position(' — ' in n.body) > 0 then split_part(n.body, ' — ', 1)
           else n.body
         end as prefix
    from public.notifications n
    left join public.maintenance_requests r
      on r.id::text = n.data->>'request_id'
   where n.notification_type = 'maintenance'
)
update public.notifications n
   set title = case f.is_update
                 when true then 'تحديث بلاغ الصيانة'
                 else 'بلاغ صيانة جديد' end,
       body = case
         when f.is_update then f.prefix || ' — ' || (case f.status_value
           when 'submitted' then 'تم الاستلام'
           when 'under_review' then 'قيد المراجعة'
           when 'awaiting_owner' then 'بانتظار موافقة المالك'
           when 'approved' then 'تمت الموافقة'
           when 'in_progress' then 'قيد التنفيذ'
           when 'completed' then 'مكتمل'
           when 'confirmed' then 'تم التأكيد'
           when 'rejected' then 'مرفوض'
           when 'cancelled' then 'ملغى'
           else 'تم التحديث' end)
         else f.prefix end
  from fixed f
 where n.id = f.id;

-- ------------------------------------------------ إصلاح إشعارات الإيجار القديمة
with fixed as (
  select n.id,
         n.user_id,
         n.data->>'status' as status_value,
         exists (
           select 1
             from public.leases l
             join public.apartments a on a.id = l.apartment_id
             join public.floors f on f.id = a.floor_id
             join public.buildings b on b.id = f.building_id
             join public.compounds c on c.id = b.compound_id
            where l.id::text = n.data->>'lease_id'
              and c.owner_id = n.user_id
         ) as is_owner
    from public.notifications n
   where n.notification_type = 'lease'
)
update public.notifications n
   set title = case
         when f.status_value is null then 'طلب ربط شقة جديد'
         when f.status_value = 'active' then 'تمت الموافقة على طلبك'
         else 'تحديث طلب ربط الشقة' end,
       body = case
         when f.status_value is null then case
           when f.is_owner then 'يوجد طلب سكن بانتظار قرار المدير'
           else 'يوجد طلب سكن بانتظار قرارك' end
         when f.status_value = 'active' then 'تمت الموافقة على طلب السكن، أهلاً بك.'
         when f.status_value = 'rejected' then 'تم رفض طلب ربط الشقة.'
         else 'الحالة الجديدة: ' || f.status_value end
  from fixed f
 where n.id = f.id;

-- ------------------------------------------------ إصلاح إشعارات الدفع القديمة
with fixed as (
  select n.id,
         n.user_id,
         p.tenant_id,
         p.amount,
         c.country
    from public.notifications n
    join public.payments p on p.id::text = n.data->>'payment_id'
    join public.invoices i on i.id = p.invoice_id
    join public.apartments a on a.id = i.apartment_id
    join public.floors f on f.id = a.floor_id
    join public.buildings b on b.id = f.building_id
    join public.compounds c on c.id = b.compound_id
   where n.notification_type = 'payment'
)
update public.notifications n
   set title = case when f.tenant_id = f.user_id then 'تم تسجيل دفعة' else 'دفعة جديدة' end,
       body = case when f.tenant_id = f.user_id
                 then 'تم استلام دفعة بمبلغ ' else 'تم تسجيل دفعة بمبلغ ' end
              || f.amount::text || ' ' ||
              case coalesce(f.country, 'IQ')
                when 'AE' then 'د.إ'
                when 'US' then '$'
                else 'د.ع' end
  from fixed f
 where n.id = f.id;

-- إشعارات دفع قديمة تعذّر ربطها بدفعة/فاتورة قائمة: استخراج المبلغ من النص المخزّن.
update public.notifications n
   set title = 'تم تسجيل دفعة',
       body = 'تم استلام دفعة بمبلغ ' || coalesce(
                (select p.amount::text from public.payments p
                  where p.id::text = n.data->>'payment_id'),
                (regexp_match(n.body, '([0-9]+(?:\.[0-9]+)?)'))[1]
              ) || ' د.ع'
 where n.notification_type = 'payment'
   and n.body ~ '[0-9]'
   and not exists (
     select 1
       from public.payments p
       join public.invoices i on i.id = p.invoice_id
       join public.apartments a on a.id = i.apartment_id
       join public.floors f on f.id = a.floor_id
       join public.buildings b on b.id = f.building_id
       join public.compounds c on c.id = b.compound_id
      where p.id::text = n.data->>'payment_id'
   );

notify pgrst, 'reload schema';
