-- Run once after creating alice@example.com and bob@example.com in Supabase Auth.
begin;
do $$
declare alice uuid; bob uuid; private_id bigint;
begin
  select id into strict alice from auth.users where email = 'alice@example.com';
  select id into strict bob from auth.users where email = 'bob@example.com';
  insert into public.users (id, username) values (alice, 'Alice'), (bob, 'Bob');
  -- The imported frontend routes to channel 1 after login.
  insert into public.channels (id, slug, created_by) values (1, 'general', alice);
  perform setval(pg_get_serial_sequence('public.channels', 'id'), 1, true);
  insert into public.channels (slug, created_by, is_private)
    values ('support-private', alice, true) returning id into private_id;
  insert into public.channel_members values (private_id, alice);
  insert into public.messages (message, user_id, channel_id) values
    ('Hello from Alice!', alice, 1),
    ('Private message for support', alice, private_id);
end $$;
commit;
