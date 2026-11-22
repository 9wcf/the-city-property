-- ============================================================================
-- 2026-11-06 — Owner web dashboard
--   * owner member management (list / activate / create manager / reset password)
--   * apartment-level manager assignments
--   * expenses, invoice generation, invoice payments
--   * notifications + announcements + device tokens
-- ============================================================================

-- ---------------------------------------------------------------- expenses
create table if not exists public.expenses (
  id           uuid primary key default uuid_generate_v4(),
  compound_id  uuid not null references public.compounds(id) on delete cascade,
  category     text not null default 'general',
  title        text not null,
  amount       numeric not null check (amount >= 0),
  expense_date date not null default current_date,
  notes        text,
  created_by   uuid references public.profiles(id),
  created_at   timestamptz default now()
);

alter table public.expenses enable row level security;
drop policy if exists expenses_select on public.expenses;
drop policy if exists expenses_owner_write on public.expenses;

create policy expenses_select on public.expenses
  for select to authenticated
  using (public.owns_compound(compound_id) or public.manages_compound(compound_id));

create policy expenses_owner_write on public.expenses
  for all to authenticated
  using (public.owns_compound(compound_id))
  with check (public.owns_compound(compound_id));

grant select, insert, update, delete on public.expenses to authenticated;

-- ------------------------------------------------- apartment-level managers
create table if not exists public.apartment_managers (
  id          uuid primary key default uuid_generate_v4(),
  apartment_id uuid not null references public.apartments(id) on delete cascade,
  manager_id  uuid not null references public.profiles(id) on delete cascade,
  assigned_by uuid references public.profiles(id),
  assigned_at timestamptz default now(),
  is_active   boolean default true,
  unique (apartment_id, manager_id)
);

alter table public.apartment_managers enable row level security;
drop policy if exists apartment_managers_select on public.apartment_managers;

create policy apartment_managers_select on public.apartment_managers
  for select to authenticated
  using (
    manager_id = auth.uid()
    or public.owns_apartment(apartment_id)
    or public.manages_apartment(apartment_id)
  );

grant select on public.apartment_managers to authenticated;

-- Apartment managers see apartments assigned to them directly.
create or replace function public.manages_apartment(p_apartment_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
           select 1
             from public.apartments a
             join public.floors f on f.id = a.floor_id
             join public.buildings b on b.id = f.building_id
            where a.id = p_apartment_id
              and public.manages_compound(b.compound_id)
         )
      or exists (
           select 1
             from public.apartment_managers am
            where am.apartment_id = p_apartment_id
              and am.manager_id = auth.uid()
              and coalesce(am.is_active, true)
         );
$$;

grant execute on function public.manages_apartment(uuid) to authenticated;

-- ------------------------------------------------------- assignment RPCs
create or replace function public.assign_apartment_manager(
  p_apartment_id uuid,
  p_phone text
) returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_local   text;
  v_manager public.profiles%rowtype;
begin
  if auth.uid() is null then
    raise exception 'يجب تسجيل الدخول أولاً';
  end if;
  if not public.owns_apartment(p_apartment_id) then
    raise exception 'يمكن للمالك فقط تعيين مديري شققه';
  end if;

  v_local := regexp_replace(coalesce(p_phone, ''), '\D', '', 'g');
  if v_local like '964%' then
    v_local := '0' || substr(v_local, 4);
  elsif v_local not like '0%' then
    v_local := '0' || v_local;
  end if;

  select * into v_manager
    from public.profiles
   where regexp_replace(coalesce(phone_number, ''), '\D', '', 'g') = v_local
     and role = 'manager'
     and coalesce(is_active, true)
   limit 1;

  if not found then
    raise exception 'لا يوجد حساب مدير بهذا الرقم. تأكد أن المدير أنشأ حسابه أولاً';
  end if;

  insert into public.apartment_managers (apartment_id, manager_id, assigned_by, is_active)
  values (p_apartment_id, v_manager.id, auth.uid(), true)
  on conflict (apartment_id, manager_id)
  do update set is_active = true,
                assigned_by = excluded.assigned_by,
                assigned_at = now();

  return jsonb_build_object(
    'manager_id', v_manager.id,
    'full_name', coalesce(v_manager.full_name, 'مدير'),
    'phone_number', v_manager.phone_number
  );
end;
$$;

revoke all on function public.assign_apartment_manager(uuid, text) from public, anon;
grant execute on function public.assign_apartment_manager(uuid, text) to authenticated;

create or replace function public.remove_apartment_manager(
  p_apartment_id uuid,
  p_manager_id uuid
) returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'يجب تسجيل الدخول أولاً';
  end if;
  if not public.owns_apartment(p_apartment_id) then
    raise exception 'يمكن للمالك فقط تعديل مديري شققه';
  end if;

  update public.apartment_managers
     set is_active = false
   where apartment_id = p_apartment_id
     and manager_id = p_manager_id
     and coalesce(is_active, true);
end;
$$;

revoke all on function public.remove_apartment_manager(uuid, uuid) from public, anon;
grant execute on function public.remove_apartment_manager(uuid, uuid) to authenticated;

-- managers responsible for a given apartment (compound + apartment level)
create or replace function public.managers_for_apartment(p_apartment_id uuid)
returns uuid[]
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(array_agg(distinct uid), '{}'::uuid[])
    from (
      select ma.manager_id as uid
        from public.manager_assignments ma
        join public.apartments a on a.id = p_apartment_id
        join public.floors f on f.id = a.floor_id
        join public.buildings b on b.id = f.building_id
       where ma.compound_id = b.compound_id
         and coalesce(ma.is_active, true)
      union
      select am.manager_id
        from public.apartment_managers am
       where am.apartment_id = p_apartment_id
         and coalesce(am.is_active, true)
    ) t;
$$;

revoke all on function public.managers_for_apartment(uuid) from public, anon, authenticated;

-- managers created from the owner dashboard (kept in scope before assignment)
create table if not exists public.owner_created_members (
  owner_id   uuid not null references public.profiles(id) on delete cascade,
  member_id  uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz default now(),
  primary key (owner_id, member_id)
);

alter table public.owner_created_members enable row level security;
drop policy if exists owner_created_members_select on public.owner_created_members;

create policy owner_created_members_select on public.owner_created_members
  for select to authenticated
  using (owner_id = auth.uid());

grant select on public.owner_created_members to authenticated;

-- ------------------------------------------------------------ member RPCs
create or replace function public.owner_members()
returns table (
  id           uuid,
  full_name    text,
  phone_number text,
  email        text,
  role         user_role,
  is_active    boolean,
  scope        text,
  created_at   timestamptz
)
language sql
stable
security definer
set search_path = public
as $$
  with related as (
    select ta.tenant_id as uid, c.name as scope
      from public.tenant_apartments ta
      join public.apartments a on a.id = ta.apartment_id
      join public.floors f on f.id = a.floor_id
      join public.buildings b on b.id = f.building_id
      join public.compounds c on c.id = b.compound_id
     where coalesce(ta.is_current, false)
       and c.owner_id = auth.uid()
    union
    select l.tenant_id, c.name
      from public.leases l
      join public.apartments a on a.id = l.apartment_id
      join public.floors f on f.id = a.floor_id
      join public.buildings b on b.id = f.building_id
      join public.compounds c on c.id = b.compound_id
     where l.status = 'pending'
       and c.owner_id = auth.uid()
    union
    select ma.manager_id, c.name
      from public.manager_assignments ma
      join public.compounds c on c.id = ma.compound_id
     where coalesce(ma.is_active, true)
       and c.owner_id = auth.uid()
    union
    select am.manager_id, 'شقة ' || a.unit_number || ' — ' || c.name
      from public.apartment_managers am
      join public.apartments a on a.id = am.apartment_id
      join public.floors f on f.id = a.floor_id
      join public.buildings b on b.id = f.building_id
      join public.compounds c on c.id = b.compound_id
     where coalesce(am.is_active, true)
       and c.owner_id = auth.uid()
    union
    select ocm.member_id, null
      from public.owner_created_members ocm
     where ocm.owner_id = auth.uid()
  )
  select p.id,
         p.full_name,
         p.phone_number,
         p.email,
         p.role,
         coalesce(p.is_active, true),
         coalesce(string_agg(distinct r.scope, ' · ') filter (where r.scope is not null), 'بدون تعيين'),
         p.created_at
    from related r
    join public.profiles p on p.id = r.uid
   group by p.id, p.full_name, p.phone_number, p.email, p.role, p.is_active, p.created_at
   order by p.role, p.full_name;
$$;

revoke all on function public.owner_members() from public, anon;
grant execute on function public.owner_members() to authenticated;

create or replace function public.set_member_active(
  p_user_id uuid,
  p_active boolean
) returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'يجب تسجيل الدخول أولاً';
  end if;
  if p_user_id = auth.uid() then
    raise exception 'لا يمكنك تعطيل حسابك';
  end if;
  if not exists (select 1 from public.owner_members() m where m.id = p_user_id) then
    raise exception 'هذا العضو ليس ضمن نطاقك';
  end if;

  update public.profiles set is_active = p_active where id = p_user_id;
  update auth.users
     set banned_until = case when p_active then null else 'infinity'::timestamptz end,
         updated_at = now()
   where id = p_user_id;
end;
$$;

revoke all on function public.set_member_active(uuid, boolean) from public, anon;
grant execute on function public.set_member_active(uuid, boolean) to authenticated;

create or replace function public.owner_create_manager(
  p_full_name text,
  p_phone text,
  p_password text
) returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_caller      public.profiles%rowtype;
  v_local       text;
  v_gotrue      text;
  v_user_id     uuid := gen_random_uuid();
begin
  select * into v_caller from public.profiles where id = auth.uid();
  if not found or v_caller.role <> 'owner' then
    raise exception 'يمكن للمالك فقط إضافة مديرين';
  end if;

  if length(coalesce(trim(p_full_name), '')) < 3 then
    raise exception 'اسم المدير قصير جداً';
  end if;
  if length(coalesce(p_password, '')) < 8 then
    raise exception 'كلمة المرور يجب أن تكون 8 أحرف على الأقل';
  end if;

  v_local := regexp_replace(coalesce(p_phone, ''), '\D', '', 'g');
  if v_local like '964%' then
    v_local := '0' || substr(v_local, 4);
  elsif v_local not like '0%' then
    v_local := '0' || v_local;
  end if;
  if length(v_local) < 10 then
    raise exception 'رقم الهاتف غير صالح';
  end if;
  v_gotrue := '964' || substr(v_local, 2);

  if exists (select 1 from auth.users u where u.phone = v_gotrue)
     or exists (select 1 from public.profiles p where p.phone_number = v_local) then
    raise exception 'هذا الرقم مسجل مسبقاً';
  end if;

  insert into auth.users (
    instance_id, id, aud, role, phone, phone_confirmed_at,
    encrypted_password, raw_app_meta_data, raw_user_meta_data,
    confirmation_token, recovery_token, email_change_token_new, email_change,
    email_change_token_current, phone_change, phone_change_token, reauthentication_token,
    email_change_confirm_status, is_super_admin,
    created_at, updated_at, is_sso_user, is_anonymous
  ) values (
    '00000000-0000-0000-0000-000000000000',
    v_user_id,
    'authenticated',
    'authenticated',
    v_gotrue,
    now(),
    extensions.crypt(p_password, extensions.gen_salt('bf', 10)),
    jsonb_build_object('provider', 'phone', 'providers', jsonb_build_array('phone')),
    jsonb_build_object('full_name', trim(p_full_name), 'role', 'manager', 'phone', v_local),
    '', '', '', '', '', '', '', '', 0, false,
    now(), now(), false, false
  );

  insert into auth.identities (
    user_id, identity_data, provider, provider_id,
    last_sign_in_at, created_at, updated_at
  ) values (
    v_user_id,
    jsonb_build_object('sub', v_user_id::text, 'phone', v_gotrue),
    'phone',
    v_gotrue,
    now(), now(), now()
  );

  insert into public.profiles (id, full_name, phone_number, role, is_active)
  values (v_user_id, trim(p_full_name), v_local, 'manager', true)
  on conflict (id) do update
    set full_name = excluded.full_name,
        phone_number = excluded.phone_number,
        role = 'manager',
        is_active = true;

  insert into public.owner_created_members (owner_id, member_id)
  values (auth.uid(), v_user_id)
  on conflict (owner_id, member_id) do nothing;

  return jsonb_build_object(
    'manager_id', v_user_id,
    'full_name', trim(p_full_name),
    'phone_number', v_local
  );
end;
$$;

revoke all on function public.owner_create_manager(text, text, text) from public, anon;
grant execute on function public.owner_create_manager(text, text, text) to authenticated;

create or replace function public.owner_reset_password(
  p_user_id uuid,
  p_password text
) returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'يجب تسجيل الدخول أولاً';
  end if;
  if length(coalesce(p_password, '')) < 8 then
    raise exception 'كلمة المرور يجب أن تكون 8 أحرف على الأقل';
  end if;
  if not exists (select 1 from public.owner_members() m where m.id = p_user_id) then
    raise exception 'هذا العضو ليس ضمن نطاقك';
  end if;

  update auth.users
     set encrypted_password = extensions.crypt(p_password, extensions.gen_salt('bf', 10)),
         updated_at = now()
   where id = p_user_id;
end;
$$;

revoke all on function public.owner_reset_password(uuid, text) from public, anon;
grant execute on function public.owner_reset_password(uuid, text) to authenticated;

-- ------------------------------------------------------------ notifications
create or replace function public.push_notification(
  p_user_ids uuid[],
  p_title text,
  p_body text,
  p_type text,
  p_data jsonb default '{}'::jsonb
) returns void
language sql
security definer
set search_path = public
as $$
  insert into public.notifications (user_id, title, body, notification_type, data)
  select distinct uid, p_title, p_body, p_type, coalesce(p_data, '{}'::jsonb)
    from unnest(p_user_ids) uid
   where uid is not null;
$$;

revoke all on function public.push_notification(uuid[], text, text, text, jsonb) from public, anon, authenticated;

create or replace function public.notify_maintenance_change()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
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
        when 'cancelled' then 'ملغي'
        else 'تم التحديث' end,
      'maintenance',
      jsonb_build_object('request_id', new.id, 'status', new.status));
  end if;

  return new;
end;
$$;

drop trigger if exists trg_notify_maintenance on public.maintenance_requests;
create trigger trg_notify_maintenance
  after insert or update on public.maintenance_requests
  for each row execute function public.notify_maintenance_change();

create or replace function public.notify_lease_change()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
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
$$;

drop trigger if exists trg_notify_lease on public.leases;
create trigger trg_notify_lease
  after insert or update on public.leases
  for each row execute function public.notify_lease_change();

create or replace function public.notify_payment()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_owner uuid;
  v_apartment uuid;
begin
  select i.apartment_id
    into v_apartment
    from public.invoices i
   where i.id = new.invoice_id;

  select c.owner_id into v_owner
    from public.apartments a
    join public.floors f on f.id = a.floor_id
    join public.buildings b on b.id = f.building_id
    join public.compounds c on c.id = b.compound_id
   where a.id = v_apartment;

  perform public.push_notification(
    array[new.tenant_id], 'تم تسجيل دفعة',
    'تم استلام دفعة بمبلغ ' || new.amount::text || ' د.ع',
    'payment', jsonb_build_object('payment_id', new.id));

  if v_owner is not null then
    perform public.push_notification(
      array[v_owner], 'دفعة جديدة', 'تم تسجيل دفعة بمبلغ ' || new.amount::text || ' د.ع',
      'payment', jsonb_build_object('payment_id', new.id));
  end if;

  return new;
end;
$$;

drop trigger if exists trg_notify_payment on public.payments;
create trigger trg_notify_payment
  after insert on public.payments
  for each row execute function public.notify_payment();

create or replace function public.notify_invoice()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public.push_notification(
    array[new.tenant_id], 'فاتورة جديدة',
    'صدرت فاتورة بمبلغ ' || new.total_amount::text || ' د.ع',
    'invoice', jsonb_build_object('invoice_id', new.id));
  return new;
end;
$$;

drop trigger if exists trg_notify_invoice on public.invoices;
create trigger trg_notify_invoice
  after insert on public.invoices
  for each row execute function public.notify_invoice();

-- Owner broadcast to tenants/managers of a compound.
create or replace function public.owner_broadcast(
  p_compound_id uuid,
  p_audience text,
  p_title text,
  p_body text
) returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_ids uuid[];
  v_all uuid[] := '{}'::uuid[];
begin
  if auth.uid() is null then
    raise exception 'يجب تسجيل الدخول أولاً';
  end if;
  if not public.owns_compound(p_compound_id) then
    raise exception 'يمكن للمالك فقط إرسال إشعارات مجمعاته';
  end if;
  if length(trim(coalesce(p_title, ''))) = 0 or length(trim(coalesce(p_body, ''))) = 0 then
    raise exception 'العنوان والنص مطلوبان';
  end if;
  if p_audience not in ('tenants', 'managers', 'all') then
    raise exception 'نوع الجمهور غير صالح';
  end if;

  if p_audience in ('tenants', 'all') then
    select array_agg(distinct ta.tenant_id) into v_ids
      from public.tenant_apartments ta
      join public.apartments a on a.id = ta.apartment_id
      join public.floors f on f.id = a.floor_id
      join public.buildings b on b.id = f.building_id
     where coalesce(ta.is_current, false)
       and b.compound_id = p_compound_id;
    v_all := v_all || coalesce(v_ids, '{}'::uuid[]);
  end if;

  if p_audience in ('managers', 'all') then
    select array_agg(distinct uid) into v_ids
      from (
        select ma.manager_id as uid
          from public.manager_assignments ma
         where ma.compound_id = p_compound_id and coalesce(ma.is_active, true)
        union
        select am.manager_id
          from public.apartment_managers am
          join public.apartments a on a.id = am.apartment_id
          join public.floors f on f.id = a.floor_id
          join public.buildings b on b.id = f.building_id
         where b.compound_id = p_compound_id and coalesce(am.is_active, true)
      ) t;
    v_all := v_all || coalesce(v_ids, '{}'::uuid[]);
  end if;

  perform public.push_notification(v_all, p_title, p_body, 'announcement',
    jsonb_build_object('compound_id', p_compound_id));

  insert into public.announcements
    (title, content, announcement_type, compound_id, created_by, is_active, published_at)
  values
    (trim(p_title), trim(p_body), 'general', p_compound_id, auth.uid(), true, now());

  return coalesce(array_length(v_all, 1), 0);
end;
$$;

revoke all on function public.owner_broadcast(uuid, text, text, text) from public, anon;
grant execute on function public.owner_broadcast(uuid, text, text, text) to authenticated;

-- --------------------------------------------------------------- accounting
create or replace function public.generate_monthly_invoices(
  p_compound_id uuid default null,
  p_month date default null
) returns integer
language plpgsql
security definer
set search_path = public
as $$
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
$$;

revoke all on function public.generate_monthly_invoices(uuid, date) from public, anon;
grant execute on function public.generate_monthly_invoices(uuid, date) to authenticated;

create or replace function public.record_invoice_payment(
  p_invoice_id uuid,
  p_amount numeric,
  p_method text default 'cash',
  p_date date default current_date,
  p_notes text default null
) returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_invoice public.invoices%rowtype;
  v_paid    numeric;
begin
  if auth.uid() is null then
    raise exception 'يجب تسجيل الدخول أولاً';
  end if;
  if coalesce(p_amount, 0) <= 0 then
    raise exception 'المبلغ يجب أن يكون أكبر من صفر';
  end if;

  select * into v_invoice from public.invoices where id = p_invoice_id;
  if not found then
    raise exception 'الفاتورة غير موجودة';
  end if;
  if not (public.owns_apartment(v_invoice.apartment_id)
          or public.manages_apartment(v_invoice.apartment_id)) then
    raise exception 'ليس لديك صلاحية على هذه الفاتورة';
  end if;

  insert into public.payments (
    invoice_id, tenant_id, payment_date, amount, payment_method, notes, created_by
  ) values (
    p_invoice_id, v_invoice.tenant_id, coalesce(p_date, current_date), p_amount,
    coalesce(nullif(trim(p_method), ''), 'cash'),
    nullif(trim(coalesce(p_notes, '')), ''), auth.uid()
  );

  v_paid := coalesce(v_invoice.paid_amount, 0) + p_amount;

  update public.invoices
     set paid_amount = v_paid,
         status = case
           when v_paid >= v_invoice.total_amount then 'paid'::payment_status
           else 'partial'::payment_status
         end,
         updated_at = now()
   where id = p_invoice_id;

  return jsonb_build_object(
    'invoice_id', p_invoice_id,
    'paid_amount', v_paid,
    'total_amount', v_invoice.total_amount,
    'status', case when v_paid >= v_invoice.total_amount then 'paid' else 'partial' end
  );
end;
$$;

revoke all on function public.record_invoice_payment(uuid, numeric, text, date, text) from public, anon;
grant execute on function public.record_invoice_payment(uuid, numeric, text, date, text) to authenticated;

-- ----------------------------------------------------------------- RLS: bills
drop policy if exists invoices_select on public.invoices;

create policy invoices_select on public.invoices
  for select to authenticated
  using (
    tenant_id = auth.uid()
    or public.owns_apartment(apartment_id)
    or public.manages_apartment(apartment_id)
  );

grant select on public.invoices to authenticated;

drop policy if exists announcements_select on public.announcements;
drop policy if exists announcements_owner_insert on public.announcements;

create policy announcements_select on public.announcements
  for select to authenticated
  using (
    created_by = auth.uid()
    or (compound_id is not null and (public.owns_compound(compound_id) or public.manages_compound(compound_id)))
    or exists (
      select 1
        from public.tenant_apartments ta
        join public.apartments a on a.id = ta.apartment_id
        join public.floors f on f.id = a.floor_id
        join public.buildings b on b.id = f.building_id
       where ta.tenant_id = auth.uid()
         and coalesce(ta.is_current, false)
         and b.compound_id = announcements.compound_id
    )
  );

create policy announcements_owner_insert on public.announcements
  for insert to authenticated
  with check (
    created_by = auth.uid()
    and compound_id is not null
    and public.owns_compound(compound_id)
  );

grant select, insert on public.announcements to authenticated;

-- apartment-level managers must read their leases and be visible to owners
drop policy if exists leases_select_policy on public.leases;

create policy leases_select_policy on public.leases
  for select to authenticated
  using (
    tenant_id = auth.uid()
    or public.owns_apartment(apartment_id)
    or public.manages_apartment(apartment_id)
  );

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
             select 1
               from public.apartment_managers am
              where am.apartment_id = ta.apartment_id
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
      select 1
        from public.compounds c
        join public.manager_assignments ma on ma.compound_id = c.id
       where c.owner_id = p_target
         and ma.manager_id = auth.uid()
         and coalesce(ma.is_active, true)
    )
    or exists (
      select 1
        from public.apartment_managers am
        join public.apartments a on a.id = am.apartment_id
        join public.floors f on f.id = a.floor_id
        join public.buildings b on b.id = f.building_id
        join public.compounds c on c.id = b.compound_id
       where am.manager_id = p_target
         and coalesce(am.is_active, true)
         and c.owner_id = auth.uid()
    )
    or exists (
      select 1
        from public.apartment_managers am
        join public.apartments a on a.id = am.apartment_id
        join public.floors f on f.id = a.floor_id
        join public.buildings b on b.id = f.building_id
        join public.compounds c on c.id = b.compound_id
       where am.manager_id = auth.uid()
         and coalesce(am.is_active, true)
         and c.owner_id = p_target
    );
$$;

-- ------------------------------------------------------------- device tokens
create table if not exists public.device_tokens (
  id         uuid primary key default uuid_generate_v4(),
  user_id    uuid not null references public.profiles(id) on delete cascade,
  token      text not null unique,
  platform   text not null default 'android',
  updated_at timestamptz default now()
);

alter table public.device_tokens enable row level security;
drop policy if exists device_tokens_own on public.device_tokens;

create policy device_tokens_own on public.device_tokens
  for all to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

grant select, insert, update, delete on public.device_tokens to authenticated;
