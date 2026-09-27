# Team chat: access control, Realtime, and message history

A team messaging application with public-to-signed-in-users and private channels. Based on the [official Supabase Next.js Slack clone](https://github.com/supabase/supabase/tree/master/examples/slack-clone/nextjs-slack-clone). Upstream attribution is retained in [LICENSE](LICENSE) and the imported revision in [UPSTREAM_COMMIT.txt](UPSTREAM_COMMIT.txt).

## Scope and evidence

Manual workshop checks on September 26–27, 2026 demonstrated:

- Alice and Bob signed in in separate browser sessions and exchanged messages live after `messages` was added to the Realtime publication.
- SQL role simulations rejected sender impersonation and restricted message edits to their author.
- Nonmember Bob could not read a private channel or its messages, and his attempted insert raised SQLSTATE 42501.
- Adding membership granted access and posting; removing it hid the channel after refresh. Already downloaded messages cannot be retracted by RLS.
- A temporary 100,000-row benchmark returned 50 rows in 8.271 ms without an index and 0.117 ms with one. This is a single illustrative run, not an app-wide speedup or controlled load test.
- Cursor pagination returned IDs 6/5, then 4/3, then 1. After message 10 arrived, the original cursor still returned 4/3 while OFFSET returned 5/4.

These are recorded workshop observations, not a fresh hosted-database audit. The SQL below reconstructs the exercised final schema; it is not a database dump. Fresh setup explicitly restricts grants rather than depending on project defaults.

## Packaging validation

On September 27, 2026, all five SQL files executed in a temporary PGlite Postgres environment with synthetic Auth users and a minimal `auth.uid()` stand-in. Access assertions passed, the benchmark switched from Sort to Index Scan, and only the two seed messages remained after test rollback. The hosted Realtime publication statement was excluded because this environment does not model Supabase Realtime. This validates SQL behavior locally, not the hosted Auth/API/Realtime integration. No hosted database changes were made during packaging.

## Run on a fresh isolated Supabase project

Do not rerun setup against the existing workshop database.

1. In Supabase SQL Editor, run all of [sql/01-schema.sql](sql/01-schema.sql).
2. In Authentication → Users, create `alice@example.com` and `bob@example.com` with your own saved passwords and confirmed email status. These are synthetic accounts. No passwords are stored here.
3. Run [sql/02-seed.sql](sql/02-seed.sql) once. It creates profiles, `general` with ID 1 (required by the frontend), and `support-private` with Alice as its only member.
4. In a terminal at this directory, run:

```bash
npm ci
cp .env.example .env.local
```

5. Edit `.env.local`: set `NEXT_PUBLIC_SUPABASE_URL` and `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY` to this project's URL and publishable key. Never put a secret/service-role key in browser configuration. Keep the file untracked.
6. Start the application:

```bash
npm run dev -- --port 3001
```

7. Open http://localhost:3001 and sign in as Alice. Use an Incognito window for Bob.

Use the scripts under `sql/` for this version. The imported `full-schema.sql`, `supabase/migrations/`, `supabase/seed.sql`, and `supabase/config.toml` belong to a different upstream setup with additional roles/hooks. Do not run the upstream quickstart, `supabase db push`, or `config push` for this lab.

## Checks and exercises

- [03-access-tests.sql](sql/03-access-tests.sql): run the whole file as administrator in SQL Editor. It uses authenticated-role simulations, raises an exception on failed assertions, and rolls back test changes. Successful output contains `PASS`. Sequence gaps may remain after rollback. This script passed the local packaging check described above; it has not been rerun against the hosted project.
- [04-query-exercises.sql](sql/04-query-exercises.sql): run individual sections for EXPLAIN, cursor pagination, and OFFSET. The recorded cursor must be replaced on a fresh dataset.
- [05-index-benchmark.sql](sql/05-index-benchmark.sql): run the whole file to compare a temporary dataset before/after indexing. Temporary tables are dropped at commit. Index creation warms data caches; timings are illustrative. No app network or RLS overhead is measured.

For browser verification, send a message in `general` from each account and observe the other window without refreshing. Alice should see `support-private`; Bob should not initially. Membership changes are managed in SQL Editor, not the app. Refresh after changing membership.

## Design decisions and limits

- Foreign keys enforce existing user/channel references; RLS enforces access. Deleting a channel cascades to its messages, so this schema is not an archival retention design.
- `channel_members` has a composite primary key to prevent duplicate memberships. Users can read their own memberships but cannot grant themselves access.
- Message policies query channels through channel RLS. Ownership and channel access are both required for writes.
- The index `(channel_id, inserted_at DESC, id DESC)` supports filtering and stable history ordering.
- Pagination is demonstrated in SQL only. The app still loads history with its original query; no Load Older button was added.
- The imported New Channel/delete/signup controls are not supported by this reduced setup. There are no channel-write/delete policies or automatic profile-creation trigger. Do not treat their presence as a verified feature.
- Only message changes are published. User/channel live updates, instant clearing after revocation, robust error display, and production deployment were not validated.
- Local compatibility fixes include the Supabase auth subscription return shape, Realtime listener cleanup and unique topics, modern Next.js Link markup, and the Sass dependency.

## Cleanup

Stop the dev server with Ctrl-C. Benchmark tables and regression-test changes clean themselves up as described above. Keep the isolated project if continuing exercises; no destructive project cleanup is automated.
