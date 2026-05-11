# Claude Code instructions for `coldwatch`

This file is auto-loaded by any Claude Code session opened in this repo. It captures the context, conventions, and gotchas that don't live anywhere else in the codebase. Read first; the deep docs in `docs/*.md` are referenced below.

## What this project is

A self-hosted, watch-only Bitcoin cold-storage sentinel. Watches a wallet's xpub, fires a sub-second alarm via ntfy when any outgoing tx is detected, also tracks fees / UTXOs / USD value. Watch-only forever — **no private keys, no signing, ever**. Production target: a Hetzner VPS hosting both a private personal instance and a public demo subdomain.

Built primarily as a portfolio piece for digital-assets engineering roles. Code quality and operational thinking matter more than feature breadth.

**Owner:** behraaang (Behrang Mirzamani). Repo: `github.com/behraaang/coldwatch`. Local: `~/work/coldwatch`.

## Current state (2026-05-09)

Build days completed:

| Day | What | Status |
|---|---|---|
| 1 | Rails 7.2 skeleton + Docker dev stack | ✅ |
| 2 | Wallet model + encryption + BIP84 derivation | ✅ |
| 2.5/2.6 | Initial design + Tailwind pipeline wired | ✅ (dark version, then rejected) |
| 3 | Address persistence + REST sync | ✅ |
| 4a | Async sync via Sidekiq + Turbo Streams live UI | ✅ |
| 4b | Long-lived WebSocket subscriber to mempool.space | ✅ |
| UI pivot | Light editorial design (paper + Bitcoin-orange + serif) | ✅ |
| 5 | Outgoing-tx alarm + ntfy push | ✅ |
| 6 | UTXO map + fee monitor + USD snapshots | ✅ |
| Fee UI | Fee monitor card on show page | ✅ |
| **7 next** | Spouse view + CSV export + Hetzner deploy + public demo | — |
| 8 | Alarm hardening: ntfy E2E encryption, HMAC, heartbeat fallback | — |

**The product currently does what the README promises end-to-end on `localhost:3000`. It has not been deployed to Hetzner yet.**

The architectural decisions log is in `docs/build-plan.md`. Always update that file when a Day completes or a decision changes.

## Non-obvious rules (these are HARD, not preferences)

1. **No `Co-Authored-By: Claude` trailers in commits.** Portfolio framing depends on solo authorship. Commit messages should be substantive but never mention AI authorship.

2. **Light theme only.** A dark version was shipped and rejected. Do not reintroduce dark mode. Color tokens are spec'd in `docs/frontend-stack.md` — paper / cream / ink / stone / sage / rust / petrol / orange-brand. Never use Tailwind defaults like `bg-zinc-*` or `bg-blue-*`.

3. **Three typefaces, no others.** Instrument Serif (display + h1 italic), Inter (body), JetBrains Mono (numerics + addresses + txids). All three are imported via Google Fonts in `app/assets/tailwind/application.css`.

4. **Watch-only forever.** Never accept private keys. Never include signing libraries beyond `bitcoinrb` (which has them but we use only the public-key derivation paths). The xpub is the sensitive value; it's encrypted at rest via Rails 7 `encrypts`.

5. **BIP84 only in v1.** Native SegWit (zpub mainnet, vpub testnet) only. Other extended-key formats are rejected at the form level. Don't add Taproot (BIP86) / wrapped SegWit (BIP49) / legacy (BIP44) without an explicit user request.

6. **Watch out for the wrong remote.** `~/work/career-ops` (the user's separate project) has its `origin` pointing at `santifer/career-ops` upstream OSS. **Never push from career-ops.** Only push from `~/work/coldwatch` which is `behraaang/coldwatch`. Verify with `git remote -v` if uncertain.

7. **Never log or display the xpub.** A Rails parameter filter is in place, plus a CI guard that fails the build if any base58 string matching the xpub regex lands in tracked files. Don't disable either.

## Operational gotchas (lessons learned the hard way)

- **`rails new --skip-bundle --css=tailwind` does NOT run `tailwindcss:install`.** Pages render unstyled until you run `bin/rails tailwindcss:install` separately. This was a real bug we hit. See the `feedback_rails_tailwind_install.md` memory in the career-ops project memory dir if curious about the trace.

- **Long-running Ruby scripts (`lib/mempool_subscriber.rb`) need `ActiveRecord::Base.connection_handler.clear_active_connections!` between iterations.** Otherwise AR's connection cache + Postgres transaction isolation make the script keep returning stale empty query results even after another process commits.

- **`docker-compose.yml` env_file must be marked optional.** Use `env_file: { path: .env, required: false }`. CI runs `docker compose config` without `.env` files; without `required: false` the lint job fails.

- **bash precedence:** `cmd1 && cmd2 && watcher & exec server` puts the WHOLE chain in the background. Group with `( watcher & ) &&` for proper foreground/background separation.

- **`mempool_subscriber` container needs `BOOTSTRAP_RECURRING_JOBS=true`** to enqueue FeeMonitorJob + UsdSnapshotJob on startup. Set in `docker-compose.override.yml` for the sidekiq service. Initializer uses Redis SETNX so only one process actually does the bootstrap.

- **Tailwind v4 writes its build output to `app/assets/builds/tailwind.css`** (NOT `application.css`). Layout's stylesheet_link_tag must reference `tailwind`, not `application`. The install generator handles this.

- **Test data:** for local testing, use the **BIP84 spec test vector zpub** — it's the well-known one derived from the mnemonic `"abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about"`. The zpub is in `test/fixtures/files/test_xpubs.yml` (the xpub-guard excludes `test/fixtures/`). Never paste the user's real mainnet zpub into runner scripts that get logged.

- **Production uses nginx, not Caddy.** The Hetzner box already runs nginx + certbot for behdev.com / behrangmirzamani.com on :80/:443, so the repo's `caddy/` stack is dev-only. On prod, the personal stack uses `docker-compose.production.yml` to bind web to `127.0.0.1:3001` and the existing nginx proxies `coldwatch.behdev.com` to it. See `docs/deploy.md` for the full runbook.

- **`coldwatch_web` external network needs to exist on prod**, even though we don't run Caddy. `docker-compose.yml` declares `coldwatch_web: external: true` for the dev-time Caddy bridge. On the box you have to `docker network create coldwatch_web` once or compose refuses to start the personal stack.

- **`connection_pool ~> 2.4` pin is load-bearing.** 3.x changed `Pool#pop`'s arity and crashes Sidekiq 7.3's scheduled-job poller silently — self-rescheduling jobs (FeeMonitorJob, UsdSnapshotJob) queue forever. Don't unpin until Sidekiq cuts a 7.3-compatible release.

- **AR encryption keys must be in OS env before Rails boots.** `bin/rails test` loads `config/application.rb` before `test/test_helper.rb` runs, so `||=` defaults in test_helper are too late. Local docker injects them via `.env.development`; CI sets them in `.github/workflows/ci.yml`; prod has them in `personal/.env`.

- **CI parallel workers fail on a fresh postgres.** Rails minitest `parallelize(workers: :number_of_processors)` creates per-worker DBs like `..._test-0`, `..._test-1`. They exist locally because prior runs created them, but a fresh CI postgres has only the base DB. CI sets `PARALLEL_WORKERS=1` to run sequentially.

- **Tailscale subnet route for phone access.** Phone on cellular hits `coldwatch.behdev.com` → public DNS → public IP → nginx sees the cellular IP → 403 from the allowlist. Fix: box advertises its own public IP (`tailscale set --advertise-routes=$PUBLIC_IP/32` + `sysctl net.ipv4.ip_forward=1` + approve in admin console), and nginx allowlist gets `100.64.0.0/10` added alongside the home IP. Phone with Tailscale on now routes the public IP through the tunnel and arrives with a tailnet source IP. Runbook in `docs/deploy.md` Step 8.

## How to run / develop

```bash
# All commands from personal/

# First time only:
docker compose up -d --build
docker compose exec -T web bin/rails db:prepare
docker compose exec -T web bin/rails tailwindcss:install   # if pages render unstyled

# Day-to-day:
docker compose ps                                # what's running
docker compose logs -f web                       # tail web logs
docker compose logs -f sidekiq                   # tail sidekiq jobs
docker compose logs -f mempool_subscriber        # tail WS subscriber
docker compose exec -T web bin/rails console     # rails console
docker compose exec -T web bin/rails runner FILE # run a script
docker compose exec -T web bin/rails test        # run unit tests

# Visit http://localhost:3000
```

## Architecture quick map

```
docker-compose stacks (one Hetzner box, two stacks):
├── personal/  (private instance, IP-allowlisted via Caddy)
└── demo/      (public, paste-your-own-xpub, 1-hour TTL)  [not yet deployed]

Each stack contains 5 containers:
├── web                 Rails server, exposes :3000 (Caddy reverse-proxies)
├── sidekiq             ActiveJob worker (WalletSyncJob, AlarmDetectionJob, FeeMonitorJob, UsdSnapshotJob)
├── mempool_subscriber  long-lived WS connection to mempool.space, holds open per-network
├── db                  Postgres 16
└── redis               for Sidekiq queue + ActionCable Pub/Sub

Backend:
├── Wallet                   has many addresses, alert_events, utxos (through addresses)
├── Address                  has many utxos
├── Utxo                     belongs_to address; (txid, vout) unique
├── AlertEvent               outgoing-tx alarm log; (wallet_id, txid) unique
├── UsdSnapshot              one row per date; (date) unique

Services:
├── AddressDerivation        BIP84 derivation via bitcoinrb
├── MempoolFetcher           fetch (address summary), fetch_txs, fetch_utxos
├── UtxoSyncer               idempotent UTXO upsert + orphan deletion
├── OutgoingTxDetector       classify direction, persist alert events
├── NtfyPusher               POST to ntfy.sh with title/priority/tags/click headers
├── FeeFetcher               GET /api/v1/fees/recommended
└── UsdFetcher               GET coingecko /simple/price

Jobs (all ActiveJob via Sidekiq adapter):
├── WalletSyncJob            materialize addresses + sync balances + sync UTXOs
├── AlarmDetectionJob        wraps OutgoingTxDetector
├── FeeMonitorJob            self-rescheduling every 5 min
└── UsdSnapshotJob           self-rescheduling daily
```

## Conventions

- **Services in `app/services/`** — class methods or instances, autoloaded
- **No new gems without explicit user OK.** When in doubt, inline SVG / Net::HTTP / write it yourself.
- **Inline SVG icons only.** No `lucide-rails`, no Heroicons gem. 1.5px stroke, 24×24 viewBox, rounded line caps. Match the phosphor-ish style.
- **Hotwire (Turbo + Stimulus) only.** No React, no Vue, no SPA.
- **Numeric values use `font-mono tabular-nums`.** Always.
- **Mobile-first.** Test class strings at 375px wide.
- **Don't write planning docs / decision docs / analysis docs** unless the user asks. Keep architecture in `docs/build-plan.md` when it shifts.

## Pointers to all docs

Read these in order if you're new to the project:

| Doc | What |
|---|---|
| `README.md` | Product overview, public-facing |
| `docs/build-plan.md` | Architecture record + decisions log + week-by-week milestones |
| `docs/frontend-stack.md` | Design system: colors, typography, layout posture, what NOT to do |
| `docs/architecture.md` | Sequence diagrams (alarm path, reorg, v2 sovereign mode) |
| `docs/threat-model.md` | What coldwatch defends against and what it doesn't |
| `docs/runbook.md` | "Your phone just buzzed" decision tree (RBF flow, panic destination prereqs) |
| `docs/migration-emergency.md` | Pre-emptive seed-compromise migration playbook |
| `docs/sparrow-setup.md` | Sparrow Wallet first-run + private Electrum upgrade path |
| `docs/ledger-setup.md` | Finding zpub on Ledger Live |
| `BOOTSTRAP.md` | Day-1 setup commands |

## Test discipline (current vs target)

Currently: **7 tests** in `test/services/outgoing_tx_detector_test.rb`. CI does NOT run them yet (only lints compose + greps for leaked xpubs).

Target: ~30 tests covering AddressDerivation, NtfyPusher, AlertEvent uniqueness, Wallet validations, MempoolFetcher response parsing, WalletSyncJob, AlarmDetectionJob, controllers. **The user has explicitly chosen to defer this backfill** in favor of feature progress; don't sneak it in.

When you DO add tests later, the priority is in `docs/build-plan.md` notes (TODO: add a section there). For now: any *new* service / model lands with its tests in the same commit, but old code doesn't get backfilled mid-feature.

## Sensitive paths (never commit, often gitignored)

- `personal/config/master.key` — Rails master key
- `personal/.env.development` — RAILS_ENCRYPTION_*_KEY values for dev
- `personal/.env` — production secrets (if it ever exists; not yet)
- `personal/log/*` — may contain xpub fragments (Rails parameter filter is in place but defense-in-depth)
- `personal/tmp/*` — same
- `personal/db/*.sqlite3` — not used (we're on Postgres) but caught by gitignore

The xpub-shaped-string CI guard at `scripts/grep-xpub-guard.sh` runs on every push and fails the build if any tracked file contains a string matching `\b[xyzZ]pub[A-HJ-NP-Za-km-z1-9]{100,}\b` outside `docs/` and test fixtures.

## When in doubt

- The user wants action over planning. Avoid asking too many clarifying questions; pick the senior-engineer default and proceed.
- When making a real architectural decision, update `docs/build-plan.md` Decisions Log so it survives.
- When a bug bites that future-Claude would hit too, add a line to the "Operational gotchas" section above.
- When introducing a new convention, add it to the "Conventions" section above.
