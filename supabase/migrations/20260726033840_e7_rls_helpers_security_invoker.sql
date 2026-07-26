-- E7-01 follow-up: helpers as SECURITY INVOKER (no RPC bypass).
-- join_active_session stays SECURITY DEFINER — intentional classroom join RPC.

create or replace function public.session_is_active(target_session_id uuid)
returns boolean
language sql
stable
security invoker
set search_path = public
as $$
  select exists (
    select 1
    from public.learning_sessions s
    where s.id = target_session_id
      and s.status = 'active'
  );
$$;

create or replace function public.group_in_active_session(target_group_id uuid)
returns boolean
language sql
stable
security invoker
set search_path = public
as $$
  select exists (
    select 1
    from public.groups g
    join public.learning_sessions s on s.id = g.session_id
    where g.id = target_group_id
      and s.status = 'active'
  );
$$;

revoke all on function public.session_is_active(uuid) from public;
revoke all on function public.group_in_active_session(uuid) from public;
grant execute on function public.session_is_active(uuid) to anon, authenticated;
grant execute on function public.group_in_active_session(uuid) to anon, authenticated;
