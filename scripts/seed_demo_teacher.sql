-- Seed demo teacher for Flutter Web dashboard (pilot / lokal only).
-- Run via Supabase SQL editor or MCP execute_sql (postgres / service role).
-- DO NOT use these credentials in production — change or disable before go-live.
--
-- Email:    guru@cellforensic.demo
-- Password: CellForensicDemo1!
-- Name:     Guru Demo

do $$
declare
  v_user_id uuid := gen_random_uuid();
  v_email text := 'guru@cellforensic.demo';
  v_password text := 'CellForensicDemo1!';
begin
  if exists (select 1 from auth.users where lower(email) = lower(v_email)) then
    raise notice 'demo teacher % already exists — skipping auth insert', v_email;
    return;
  end if;

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
    jsonb_build_object('provider', 'email', 'providers', jsonb_build_array('email')),
    jsonb_build_object('full_name', 'Guru Demo'),
    now(),
    now(),
    '',
    '',
    '',
    '',
    false
  );

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
end $$;

select public.promote_user_to_teacher('guru@cellforensic.demo', 'Guru Demo');
