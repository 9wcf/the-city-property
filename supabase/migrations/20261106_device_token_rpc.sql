-- Device token registration must work when a different account signs in on the
-- same phone: a plain RLS upsert cannot take over a token owned by the previous user.

create or replace function public.register_device_token(
  p_token text,
  p_platform text default 'android'
) returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'يجب تسجيل الدخول أولاً';
  end if;
  if coalesce(p_token, '') = '' then
    return;
  end if;

  insert into public.device_tokens (user_id, token, platform, updated_at)
  values (auth.uid(), p_token, coalesce(nullif(p_platform, ''), 'android'), now())
  on conflict (token) do update
    set user_id = excluded.user_id,
        platform = excluded.platform,
        updated_at = now();
end;
$$;

revoke all on function public.register_device_token(text, text) from public, anon;
grant execute on function public.register_device_token(text, text) to authenticated;

create or replace function public.unregister_device_token(p_token text)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    return;
  end if;
  delete from public.device_tokens
   where token = p_token and user_id = auth.uid();
end;
$$;

revoke all on function public.unregister_device_token(text) from public, anon;
grant execute on function public.unregister_device_token(text) to authenticated;
