-- Push notifications: forward each new in-app notification to the send-push Edge Function.
-- The shared secret lives in app_config (key = push_secret) and must match the function's
-- PUSH_SECRET secret. Missing secret/key simply skips the push.

create extension if not exists pg_net with schema extensions;

create or replace function public.notifications_send_push()
returns trigger
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_secret text;
begin
  select value into v_secret from public.app_config where key = 'push_secret';
  if coalesce(v_secret, '') = '' then
    return new;
  end if;

  perform net.http_post(
    url := 'https://ukbfvtbrqdccnchkhhxk.supabase.co/functions/v1/send-push',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-push-secret', v_secret
    ),
    body := jsonb_build_object(
      'user_id', new.user_id,
      'title', new.title,
      'body', coalesce(new.body, ''),
      'data', coalesce(new.data, '{}'::jsonb)
    ),
    timeout_milliseconds := 5000
  );

  return new;
exception when others then
  -- A push failure must never block the notification itself.
  return new;
end;
$$;

revoke all on function public.notifications_send_push() from public, anon, authenticated;

drop trigger if exists notifications_push on public.notifications;
create trigger notifications_push
after insert on public.notifications
for each row execute function public.notifications_send_push();
