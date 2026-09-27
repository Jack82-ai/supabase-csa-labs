-- Run the whole block. Temporary data only; no app tables or RLS are measured.
begin;
create temporary table chat_benchmark (
  id bigint, channel_id bigint, inserted_at timestamptz, message text
) on commit drop;
insert into chat_benchmark
select n, (n % 100)+1, now()-n*interval '1 second', 'Sample message '||n
from generate_series(1,100000) n;
analyze chat_benchmark;
create temporary table benchmark_results (step integer, test text, plan jsonb) on commit drop;
do $$
declare p json;
begin
  execute 'explain (analyze,buffers,format json) select id,message,inserted_at from chat_benchmark where channel_id=1 order by inserted_at desc,id desc limit 50' into p;
  insert into benchmark_results values (1,'Without index',p::jsonb);
end $$;
create index chat_benchmark_history_idx on chat_benchmark(channel_id,inserted_at desc,id desc);
do $$
declare p json;
begin
  execute 'explain (analyze,buffers,format json) select id,message,inserted_at from chat_benchmark where channel_id=1 order by inserted_at desc,id desc limit 50' into p;
  insert into benchmark_results values (2,'With index',p::jsonb);
end $$;
select test, plan #>> '{0,Execution Time}' as execution_ms,
  plan #>> '{0,Plan,Plans,0,Node Type}' as operation_below_limit,
  plan #>> '{0,Plan,Actual Rows}' as rows_returned
from benchmark_results order by step;
commit;
