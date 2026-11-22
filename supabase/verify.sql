-- ============================================================================
-- The City Property — لوحة التحقق
-- نفّذ هذا الملف في Supabase → SQL Editor بعد تنفيذ schema.sql.
-- كل الاستعلامات هنا للقراءة فقط، ما عدا "الاختبار الاختياري" في النهاية
-- فهو ينشئ مستأجراً وهمياً ثم يتراجع (ROLLBACK).
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1) لوحة التحقق السريعة (استعلام واحد)
-- ----------------------------------------------------------------------------
with fn as (
  select p.oid,
         p.prosecdef,
         p.proconfig
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public'
     and p.proname = 'manager_add_tenant'
),
storage_policies as (
  select policyname, cmd, roles, qual, with_check
    from pg_policies
   where schemaname = 'storage'
     and tablename = 'objects'
     and policyname like 'maintenance_%'
)
select '01) دالة manager_add_tenant' as "البند",
       case when exists (select 1 from fn)
            then 'موجودة ✓'
            else 'غير موجودة ✗ — نفّذ schema.sql' end as "الحالة"
union all
select '02) SECURITY DEFINER',
       case when exists (select 1 from fn where prosecdef)
            then 'مفعّل ✓' else 'غير مفعّل ✗' end
union all
select '03) search_path',
       case when exists (select 1 from fn where proconfig::text like '%search_path=public%')
            then 'public ✓' else 'غير مضبوط ✗' end
union all
select '04) صلاحية anon',
       case when not exists (select 1 from fn) then 'غير موجودة ✗'
            when has_function_privilege(
              'anon',
              'public.manager_add_tenant(uuid,text,text,uuid,numeric,numeric,date,date,text,text)',
              'EXECUTE'
            ) then 'ممنوحة ✗ — يجب سحبها'
            else 'مسحوبة ✓' end
union all
select '05) صلاحية authenticated',
       case when not exists (select 1 from fn) then 'غير موجودة ✗'
            when has_function_privilege(
              'authenticated',
              'public.manager_add_tenant(uuid,text,text,uuid,numeric,numeric,date,date,text,text)',
              'EXECUTE'
            ) then 'موجودة ✓'
            else 'غير موجودة ✗' end
union all
select '06) Bucket maintenance',
       case when exists (select 1 from storage.buckets b where b.id = 'maintenance' and b."public")
            then 'موجود وعام ✓'
            when exists (select 1 from storage.buckets b where b.id = 'maintenance')
            then 'موجود لكن خاص ⚠'
            else 'غير موجود ✗' end
union all
select '07) سياسة رفع الصور',
       case when exists (
            select 1 from storage_policies
             where policyname = 'maintenance_upload_tenant'
       ) then 'موجودة ✓' else 'ناقصة ✗' end
union all
select '08) سياسة قراءة الصور',
       case when exists (
            select 1 from storage_policies
             where policyname = 'maintenance_read_authenticated'
       ) then 'موجودة ✓' else 'ناقصة ✗' end
union all
select '09) سياسة حذف الصور',
       case when exists (
            select 1 from storage_policies
             where policyname = 'maintenance_delete_owner'
       ) then 'موجودة ✓' else 'ناقصة ✗' end
union all
select '10) إصلاح name الملتبس',
       case when (
            select count(*)
              from storage_policies
             where policyname in (
                     'maintenance_upload_tenant',
                     'maintenance_delete_owner'
                   )
               and coalesce(with_check, qual) like '%storage.objects.name%'
       ) = 2 then 'مضبوط ✓'
       else 'راجع with_check / qual ✗' end
union all
select '11) RLS على storage.objects',
       case when (select relrowsecurity
                    from pg_class
                   where oid = 'storage.objects'::regclass)
            then 'مفعّل ✓' else 'غير مفعّل ✗' end
union all
select '12) جدول app_config',
       case when to_regclass('public.app_config') is not null
            then 'موجود ✓' else 'غير موجود ✗' end
union all
select '13) جدول maintenance_messages',
       case when to_regclass('public.maintenance_messages') is not null
            then 'موجود ✓' else 'غير موجود ✗' end
union all
select '14) أعمدة الصيانة',
       case when (
            select count(*)
              from information_schema.columns
             where table_schema = 'public'
               and table_name = 'maintenance_requests'
               and column_name in ('image_urls', 'manager_notes', 'rejection_reason')
       ) = 3 then 'مكتملة ✓' else 'ناقصة ✗' end
union all
select '15) قيم lease_status',
       case when (
            select count(*)
              from pg_enum e
              join pg_type t on t.oid = e.enumtypid
             where t.typnamespace = 'public'::regnamespace
               and t.typname = 'lease_status'
               and e.enumlabel in ('pending', 'rejected')
       ) = 2 then 'pending + rejected ✓'
       else 'ناقصة ✗' end
union all
select '16) قيد profiles_id_fkey',
       case when exists (
            select 1
              from pg_constraint
             where conrelid = 'public.profiles'::regclass
               and conname = 'profiles_id_fkey'
       ) then 'موجود (متوقع) ✓' else 'غير موجود ⚠' end
union all
select '17) دالة claim_role',
       case when exists (
            select 1 from pg_proc p
             join pg_namespace n on n.oid = p.pronamespace
            where n.nspname = 'public' and p.proname = 'claim_role'
       ) then 'موجودة ✓' else 'غير موجودة ✗' end
union all
select '18) دالة ensure_profile',
       case when exists (
            select 1 from pg_proc p
             join pg_namespace n on n.oid = p.pronamespace
            where n.nspname = 'public' and p.proname = 'ensure_profile'
       ) then 'موجودة ✓' else 'غير موجودة ✗' end
union all
select '19) سياسات profiles المرتبطة',
       case when exists (
            select 1 from pg_policies
             where schemaname = 'public'
               and tablename = 'profiles'
               and policyname = 'profiles_select_related'
       ) then 'موجودة ✓' else 'ناقصة ✗' end
union all
select '20) payments.invoice_id اختياري',
       case when exists (
            select 1 from information_schema.columns
             where table_schema = 'public'
               and table_name = 'payments'
               and column_name = 'invoice_id'
               and is_nullable = 'YES'
       ) then 'يسمح NULL ✓' else 'ما زال إلزامياً ✗' end
union all
select '21) مشغل إنشاء البروفايل',
       case when exists (
            select 1 from pg_trigger t
             join pg_class c on c.oid = t.tgrelid
             join pg_namespace n on n.oid = c.relnamespace
            where n.nspname = 'auth'
              and c.relname = 'users'
              and t.tgname = 'on_auth_user_created'
              and not t.tgisinternal
       ) then 'موجود ✓' else 'ناقص ✗' end
order by 1;

-- ----------------------------------------------------------------------------
-- 2) تفاصيل دالة manager_add_tenant
-- ----------------------------------------------------------------------------
select p.proname                                   as "الدالة",
       pg_get_function_arguments(p.oid)            as "المعاملات",
       pg_get_function_result(p.oid)               as "النتيجة",
       p.prosecdef                                 as "security_definer",
       pg_get_userbyid(p.proowner)                 as "المالك",
       p.proconfig                                 as "الإعدادات",
       has_function_privilege('anon', p.oid, 'EXECUTE')          as "anon_can_execute",
       has_function_privilege('authenticated', p.oid, 'EXECUTE') as "auth_can_execute"
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
 where n.nspname = 'public'
   and p.proname = 'manager_add_tenant';

-- نص الدالة كاملاً (للتأكد من وجود إنشاء auth.users و auth.identities)
select pg_get_functiondef(p.oid) as "التعريف"
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
 where n.nspname = 'public'
   and p.proname = 'manager_add_tenant';

-- ----------------------------------------------------------------------------
-- 3) تفاصيل سياسات Storage
-- ----------------------------------------------------------------------------
select policyname   as "السياسة",
       cmd          as "الأمر",
       roles        as "الأدوار",
       qual         as "USING",
       with_check   as "WITH CHECK"
  from pg_policies
 where schemaname = 'storage'
   and tablename = 'objects'
   and policyname like 'maintenance_%'
 order by policyname;

-- Bucket
select id, name, "public"
  from storage.buckets
 where id = 'maintenance';

-- ----------------------------------------------------------------------------
-- 4) إعداد المصادقة (رموز الدعوة تُخزَّن هنا وتُتحقق منها claim_role)
-- ----------------------------------------------------------------------------
select key, value
  from public.app_config;

-- ----------------------------------------------------------------------------
-- 5) جاهزية المدير والشقق (للتأكد أن لوحة المدير ترى شقة فارغة)
-- ----------------------------------------------------------------------------
select p.full_name,
       p.phone_number,
       c.name as "المجمع",
       count(a.id) filter (where a.status = 'vacant') as "شقق فارغة"
  from public.profiles p
  join public.manager_assignments ma
    on ma.manager_id = p.id
   and coalesce(ma.is_active, true)
  join public.compounds c on c.id = ma.compound_id
  join public.buildings b on b.compound_id = c.id
  join public.floors f on f.building_id = b.id
  join public.apartments a on a.floor_id = f.id
 where p.role = 'manager'
 group by p.id, p.full_name, p.phone_number, c.name
 order by "شقق فارغة" desc;

-- ----------------------------------------------------------------------------
-- 7) مشغلات auth.users وأعمدة profiles
--    إن ظهر خطأ null value in column "phone_number" فهناك احتمالان:
--    أ) نسخة قديمة من manager_add_tenant  → أعد تنفيذ schema.sql
--    ب) Trigger على auth.users يكتب بروفايلاً بدون phone_number
--    هذا الاستعلام يكشف الحالة (ب).
-- ----------------------------------------------------------------------------
select t.tgname                    as "المشغل",
       p.proname                   as "الدالة",
       pg_get_functiondef(p.oid)   as "التعريف"
  from pg_trigger t
  join pg_class c     on c.oid = t.tgrelid
  join pg_namespace n on n.oid = c.relnamespace
  join pg_proc p      on p.oid = t.tgfoid
 where n.nspname = 'auth'
   and c.relname = 'users'
   and not t.tgisinternal;

select column_name    as "العمود",
       is_nullable    as "يقبل NULL",
       column_default as "الافتراضي"
  from information_schema.columns
 where table_schema = 'public'
   and table_name = 'profiles'
 order by ordinal_position;

-- ============================================================================
-- 8) اختبار اختياري: ينشئ مستأجراً وهمياً ثم يتراجع (لا يبقى أي أثر)
--    شغّل الكتلة التالية كاملة في SQL Editor.
--    إذا ظهر خطأ، نفّذ rollback; يدوياً.
-- ============================================================================
/*
begin;

do $$
declare
  v_manager   uuid;
  v_apartment uuid;
  v_result    jsonb;
begin
  select p.id, a.id
    into v_manager, v_apartment
    from public.profiles p
    join public.manager_assignments ma
      on ma.manager_id = p.id
     and coalesce(ma.is_active, true)
    join public.buildings b on b.compound_id = ma.compound_id
    join public.floors f on f.building_id = b.id
    join public.apartments a on a.floor_id = f.id
   where p.role = 'manager'
     and a.status = 'vacant'
     and not exists (
       select 1 from public.leases l
        where l.apartment_id = a.id
          and l.status in ('active', 'pending')
     )
   limit 1;

  if v_manager is null or v_apartment is null then
    raise exception 'لا يوجد مدير مرتبط بشقة فارغة صالحة للاختبار';
  end if;

  v_result := public.manager_add_tenant(
    v_manager,
    'مستأجر اختبار',
    '07700000001',
    v_apartment,
    500000,
    0,
    current_date,
    (current_date + interval '1 year')::date,
    'اختبار تحقق ثم تراجع',
    'TestPass123'
  );

  raise notice 'نجح الاختبار: %', v_result;
end $$;

rollback;
*/

-- ============================================================================
-- 9) تعيين المديرين على المجمعات (2026-11-06)
-- ============================================================================
select p.proname                                  as "الدالة",
       pg_get_function_identity_arguments(p.oid)  as "الوسائط",
       has_function_privilege('anon', p.oid, 'EXECUTE')          as "anon يستطيع",
       has_function_privilege('authenticated', p.oid, 'EXECUTE') as "authenticated يستطيع"
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
 where n.nspname = 'public'
   and p.proname in ('assign_manager_to_compound', 'remove_manager_assignment');

select c.name                                        as "المجمع",
       coalesce(string_agg(p.full_name, ' · '), '—') as "المديرون"
  from public.compounds c
  left join public.manager_assignments ma
    on ma.compound_id = c.id
   and coalesce(ma.is_active, true)
  left join public.profiles p on p.id = ma.manager_id
 group by c.id, c.name, c.owner_id
 order by c.name;
