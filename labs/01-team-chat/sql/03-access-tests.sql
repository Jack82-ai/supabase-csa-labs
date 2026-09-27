-- SQL Editor as administrator. Requires the two Auth users and seed channels.
-- All test data and membership changes roll back. Identity sequence gaps can remain.
begin;
do $$
declare a uuid; b uuid; c bigint; g bigint; m bigint;
begin
  select id into strict a from auth.users where email = 'alice@example.com';
  select id into strict b from auth.users where email = 'bob@example.com';
  select id into strict c from public.channels where slug = 'support-private';
  select id into strict g from public.channels where slug = 'general';
  insert into public.channel_members values (c, a) on conflict do nothing;
  delete from public.channel_members where channel_id = c and user_id = b;
  insert into public.messages(message,user_id,channel_id) values ('Access test',a,c) returning id into m;
  perform set_config('lab.alice',a::text,true);
  perform set_config('lab.bob',b::text,true);
  perform set_config('lab.private',c::text,true);
  perform set_config('lab.general',g::text,true);
  perform set_config('lab.message',m::text,true);
  perform set_config('request.jwt.claims',json_build_object('sub',b,'role','authenticated')::text,true);
end $$;
set local role authenticated;
do $$
declare c bigint := current_setting('lab.private')::bigint;
begin
  if auth.uid() is distinct from current_setting('lab.bob')::uuid then raise exception 'FAIL: Bob identity'; end if;
  if exists(select 1 from public.channels where id=c) or exists(select 1 from public.messages where channel_id=c) then
    raise exception 'FAIL: nonmember can read private content';
  end if;
  begin
    insert into public.messages(message,user_id,channel_id) values ('Denied',auth.uid(),c);
    raise exception 'FAIL: nonmember insert allowed';
  exception when insufficient_privilege then null;
  end;
  begin
    insert into public.messages(message,user_id,channel_id)
    values ('Impersonation',current_setting('lab.alice')::uuid,current_setting('lab.general')::bigint);
    raise exception 'FAIL: impersonation allowed';
  exception when insufficient_privilege then null;
  end;
end $$;
reset role;
insert into public.channel_members values (current_setting('lab.private')::bigint,current_setting('lab.bob')::uuid);
set local role authenticated;
do $$
declare c bigint := current_setting('lab.private')::bigint; n integer; own_id bigint;
begin
  if not exists(select 1 from public.channels where id=c) or
     not exists(select 1 from public.messages where id=current_setting('lab.message')::bigint) then
    raise exception 'FAIL: member cannot read';
  end if;
  insert into public.messages(message,user_id,channel_id) values ('Member post',auth.uid(),c) returning id into own_id;
  update public.messages set message='Own edit' where id=own_id;
  get diagnostics n = row_count;
  if n <> 1 then raise exception 'FAIL: own edit'; end if;
  update public.messages set message='Unauthorized edit' where id=current_setting('lab.message')::bigint;
  get diagnostics n = row_count;
  if n <> 0 then raise exception 'FAIL: edited another author'; end if;
end $$;
reset role;
delete from public.channel_members where channel_id=current_setting('lab.private')::bigint and user_id=current_setting('lab.bob')::uuid;
set local role authenticated;
do $$
begin
  if exists(select 1 from public.messages where channel_id=current_setting('lab.private')::bigint) then
    raise exception 'FAIL: revoked member can read';
  end if;
end $$;
reset role;
select 'PASS: read isolation, impersonation, membership grant/revoke, insert and edit ownership' as result;
rollback;
