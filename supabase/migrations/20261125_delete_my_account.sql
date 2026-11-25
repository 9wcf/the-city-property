-- Self-service account deletion (App Store 5.1.1(v)).
--
-- The caller deletes their own account from the app. Personal content is
-- removed, the login is destroyed (phone/password cleared, user banned,
-- identities and sessions dropped) and the profile is anonymized so the
-- financial records the property owner must keep stay intact.
--
-- Owners who still own compounds cannot delete: they must transfer or remove
-- their properties first (business records must never disappear silently).

create or replace function public.delete_my_account()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid    uuid := auth.uid();
  v_role   text;
  v_status text;
begin
  if v_uid is null then
    raise exception 'يجب تسجيل الدخول أولاً';
  end if;

  select p.role::text into v_role
    from public.profiles p
   where p.id = v_uid;

  if v_role is null then
    raise exception 'الحساب غير موجود';
  end if;

  if exists (select 1 from public.compounds c where c.owner_id = v_uid) then
    raise exception 'لا يمكن حذف حساب مالك مرتبط بعقارات. انقل ملكية العقارات أو احذفها أولاً ثم أعد المحاولة.';
  end if;

  -- 1) Free all current units and close active leases.
  update public.tenant_apartments
     set is_current = false,
         move_out_date = coalesce(move_out_date, current_date)
   where tenant_id = v_uid
     and coalesce(is_current, false) = true;

  update public.apartments a
     set status = 'vacant'
   where a.id in (
           select ta.apartment_id
             from public.tenant_apartments ta
            where ta.tenant_id = v_uid
         )
     and not exists (
           select 1
             from public.tenant_apartments ta2
            where ta2.apartment_id = a.id
              and coalesce(ta2.is_current, false) = true
         );

  select e.enumlabel::text
    into v_status
    from pg_enum e
   where e.enumtypid = 'public.lease_status'::regtype
     and e.enumlabel in ('terminated', 'expired', 'ended', 'cancelled')
   order by array_position(
     array['terminated', 'expired', 'ended', 'cancelled']::text[],
     e.enumlabel::text
   )
   limit 1;

  update public.leases
     set status = coalesce(v_status, status::text)::public.lease_status,
         end_date = coalesce(end_date, current_date),
         updated_at = now()
   where tenant_id = v_uid
     and status in ('active', 'pending');

  -- 2) Remove the user's files from storage (best effort: metadata is
  -- removed; a failed storage cleanup must not block account deletion).
  begin
    delete from storage.objects o
     where o.bucket_id = 'maintenance'
       and (
         o.owner = v_uid
         or exists (
           select 1
             from public.maintenance_requests mr
            where mr.tenant_id = v_uid
              and o.name like mr.id::text || '/%'
         )
       );

    delete from storage.objects o
     where o.bucket_id = 'tenant-documents'
       and (
         o.owner = v_uid
         or o.name in (select d.storage_path from public.tenant_documents d
                        where d.tenant_id = v_uid)
         or o.name in (select l.storage_path from public.lease_documents l
                        where l.tenant_id = v_uid
                          and l.storage_path is not null)
       );
  exception when others then
    null;
  end;

  -- 3) Detach the user from other people's records.
  update public.expenses set created_by = null where created_by = v_uid;
  update public.payments set created_by = null where created_by = v_uid;
  update public.apartment_managers set assigned_by = null where assigned_by = v_uid;
  update public.manager_assignments set assigned_by = null where assigned_by = v_uid;
  update public.maintenance_requests set approved_by = null where approved_by = v_uid;
  update public.maintenance_requests set assigned_employee_id = null where assigned_employee_id = v_uid;
  update public.maintenance_images set uploaded_by = null where uploaded_by = v_uid;
  update public.tenant_documents set verified_by = null where verified_by = v_uid;
  update public.audit_log set user_id = null where user_id = v_uid;

  delete from public.apartment_managers where manager_id = v_uid;
  delete from public.manager_assignments where manager_id = v_uid;
  delete from public.owner_created_members where owner_id = v_uid or member_id = v_uid;
  delete from public.announcements where created_by = v_uid;

  -- 4) Personal content.
  delete from public.chat_messages where sender_id = v_uid;
  delete from public.chat_room_members where user_id = v_uid;
  delete from public.maintenance_messages where sender_id = v_uid;
  delete from public.maintenance_requests where tenant_id = v_uid;
  delete from public.tenant_documents where tenant_id = v_uid;
  delete from public.lease_documents where tenant_id = v_uid;
  delete from public.notifications where user_id = v_uid;
  delete from public.device_tokens where user_id = v_uid;

  -- 5) Destroy the login: no phone, no password, banned, identities and
  -- sessions removed. The same phone can register a fresh account later.
  update auth.users
     set phone = null,
         email = null,
         encrypted_password = null,
         phone_confirmed_at = null,
         email_confirmed_at = null,
         banned_until = 'infinity'::timestamptz,
         raw_user_meta_data = '{}'::jsonb,
         updated_at = now()
   where id = v_uid;

  delete from auth.identities where user_id = v_uid;
  delete from auth.sessions where user_id = v_uid;
  delete from auth.refresh_tokens where user_id::text = v_uid::text;

  -- 6) Anonymize the profile. Financial history (leases, invoices, payments,
  -- tenancy archive) stays under this anonymous profile.
  update public.profiles
     set full_name = 'حساب محذوف',
         phone_number = '0000000000' || substr(replace(v_uid::text, '-', ''), 1, 6),
         email = null,
         avatar_url = null,
         notes = null,
         is_active = false
   where id = v_uid;
end;
$$;

revoke all on function public.delete_my_account() from public, anon;
grant execute on function public.delete_my_account() to authenticated;

notify pgrst, 'reload schema';
