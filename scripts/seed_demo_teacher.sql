-- Idempotent demo teacher seed for the Flutter Web dashboard.
-- Run only from Supabase SQL Editor / postgres after the E9 auth migration.
-- Replaying this file intentionally resets the demo password and repairs the
-- email identity, app metadata, and public profile.
--
-- PILOT / LOCAL ONLY. Disable this account or change its password before a
-- public production launch. Never expose a service_role key to Flutter.
--
-- Email:    guru@cellforensic.demo
-- Password: CellForensicDemo1!
-- Name:     Guru Demo

do $seed_teacher$
declare
  v_user_id uuid;
  v_email constant text := 'guru@cellforensic.demo';
  v_password constant text := 'CellForensicDemo1!';
  v_full_name constant text := 'Guru Demo';
begin
  select u.id
  into v_user_id
  from auth.users u
  where lower(u.email) = lower(v_email)
  limit 1;

  if v_user_id is null then
    v_user_id := gen_random_uuid();

    insert into auth.users (
      instance_id,
      id,
      aud,
      role,
      email,
      encrypted_password,
      email_confirmed_at,
      raw_app_meta_data,
      raw_user_meta_data,
      created_at,
      updated_at,
      confirmation_token,
      recovery_token,
      email_change_token_new,
      email_change,
      is_anonymous
    ) values (
      '00000000-0000-0000-0000-000000000000',
      v_user_id,
      'authenticated',
      'authenticated',
      v_email,
      extensions.crypt(v_password, extensions.gen_salt('bf')),
      now(),
      jsonb_build_object(
        'provider', 'email',
        'providers', jsonb_build_array('email'),
        'role', 'teacher'
      ),
      jsonb_build_object('full_name', v_full_name),
      now(),
      now(),
      '',
      '',
      '',
      '',
      false
    );

    raise notice 'Created demo teacher auth user: %', v_email;
  else
    update auth.users
    set encrypted_password = extensions.crypt(
          v_password,
          extensions.gen_salt('bf')
        ),
        email_confirmed_at = coalesce(email_confirmed_at, now()),
        raw_app_meta_data = coalesce(raw_app_meta_data, '{}'::jsonb)
          || jsonb_build_object(
            'provider', 'email',
            'providers', jsonb_build_array('email'),
            'role', 'teacher'
          ),
        raw_user_meta_data = coalesce(raw_user_meta_data, '{}'::jsonb)
          || jsonb_build_object('full_name', v_full_name),
        updated_at = now()
    where id = v_user_id;

    raise notice 'Repaired existing demo teacher auth user: %', v_email;
  end if;

  -- Supabase password login also requires an email identity. Repair it when a
  -- manually-created auth.users row does not have one yet.
  if not exists (
    select 1
    from auth.identities i
    where i.user_id = v_user_id
      and i.provider = 'email'
  ) then
    insert into auth.identities (
      id,
      provider_id,
      user_id,
      identity_data,
      provider,
      last_sign_in_at,
      created_at,
      updated_at
    ) values (
      gen_random_uuid(),
      v_user_id::text,
      v_user_id,
      jsonb_build_object(
        'sub', v_user_id::text,
        'email', v_email,
        'email_verified', true,
        'phone_verified', false
      ),
      'email',
      now(),
      now(),
      now()
    );

    raise notice 'Created missing email identity for: %', v_email;
  else
    update auth.identities
    set provider_id = v_user_id::text,
        identity_data = coalesce(identity_data, '{}'::jsonb)
          || jsonb_build_object(
            'sub', v_user_id::text,
            'email', v_email,
            'email_verified', true,
            'phone_verified', false
          ),
        updated_at = now()
    where user_id = v_user_id
      and provider = 'email';
  end if;

  -- Keep authorization in public.profiles and app metadata synchronized using
  -- the E9 admin-only helper.
  perform public.promote_user_to_teacher(v_email, v_full_name);

  if not exists (
    select 1
    from public.profiles p
    where p.id = v_user_id
      and p.role = 'teacher'
      and p.full_name = v_full_name
  ) then
    raise exception 'teacher_seed_verification_failed: %', v_email;
  end if;
end
$seed_teacher$;

-- Safe verification output: no password or token is returned.
select
  u.id,
  u.email,
  u.email_confirmed_at is not null as email_confirmed,
  exists (
    select 1
    from auth.identities i
    where i.user_id = u.id
      and i.provider = 'email'
  ) as email_identity_exists,
  p.full_name,
  p.role
from auth.users u
join public.profiles p on p.id = u.id
where lower(u.email) = lower('guru@cellforensic.demo');
