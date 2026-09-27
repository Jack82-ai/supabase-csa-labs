-- Run each numbered section separately in SQL Editor.
-- 1. Query plan for newest 50 messages.
explain (analyze, buffers)
select id, message, user_id, inserted_at from public.messages
where channel_id = 1 order by inserted_at desc, id desc limit 50;

-- 2. First page. Save the LAST row's exact timestamp and ID.
select id, inserted_at, message from public.messages
where channel_id = 1 order by inserted_at desc, id desc limit 2;

-- 3. Historical cursor from the recorded lab. Replace BOTH values for a fresh setup.
select id, inserted_at, message from public.messages
where channel_id = 1
  and (inserted_at, id) < (timestamptz '2026-09-27 00:12:20.823828+00', 5)
order by inserted_at desc, id desc limit 2;

-- 4. Offset comparison: insert a newer message through the app between pages.
-- The cursor stays anchored; skipping two current rows can repeat an earlier row.
select id, inserted_at, message from public.messages
where channel_id = 1 order by inserted_at desc, id desc limit 2 offset 2;
