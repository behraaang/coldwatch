# Build Plan — coldwatch

The architecture record for coldwatch: what we're building, why, in what order, and what we'd cut if we slip. Companion to `architecture.md`, `threat-model.md`, `runbook.md`, `migration-emergency.md`, and `sparrow-setup.md`.

- **Saved:** 2026-05-07
- **Updated:** 2026-05-08
- **Status:** BUILD — Day 1 shipped (Rails 7.2 skeleton, Postgres, Redis, Sidekiq, dev Docker stack)
- **Hardware target (v1):** Ledger primary; migration to BitBox02 + Coldcard Mk4 planned (see `migration-emergency.md`)
- **Visibility:** Public GitHub repo (this one) + public live demo on a Hetzner subdomain (`demo.{domain}`)

## Decisions Log (locked from pair-design 2026-05-07)

| # | Decision | Why |
|---|---|---|
| 1 | **WebSocket from day one** (`wss://mempool.space/api/v1/ws`) — no polling phase | ~1–3s alarm latency vs ~30s; stronger demo story |
| 2 | **BIP84 / Native SegWit (`bc1q...`) only** in v1 | Where the user's real funds live; one path validated end-to-end |
| 3 | **Public demo: paste-your-own-xpub** with red privacy warning + 1-hour session TTL + auto-purge | Most useful demo; mitigated for risk |
| 4 | **Public demo alerts: real public ntfy topic** (testnet only) | Visitors can subscribe and watch alerts fire |
| 5 | **Hosting: both subdomains on the same Hetzner box, separate Docker stacks** | Cheap, simple, hard isolation between personal and demo |
| 6 | **xpub at rest: Rails 7 `encrypts`** (AES-256-GCM, master key in env) | Standard, sufficient; snapshot leak gives ciphertext |
| 7 | **Auth on personal dashboard: IP allowlist via Caddy + Rails session login** | Two layers, minimal moving parts |
| 8 | **README framing: pure project README, no author/job-search bio** | Project stands on its own; threat-model and runbook do the recruiting |
| 9 | **Push: ntfy only in v1** + email heartbeat fallback if ntfy stops responding | Single channel keeps scope tight; heartbeat prevents silent failure |
| 10 | **Alarm payload: full** (amount, txid, source addresses, mempool link) **+ ntfy E2E encryption enabled** | Maximum situational awareness; provider sees ciphertext only |
| 11 | **Spouse view: built in v1** (passphrase-gated, balance-only URL) | Inheritance / continuity story matters |
| 12 | **README opens with architecture diagram + feature list** | Technical-first framing matches digital-asset hiring audience |

## Pitch

A self-hosted, watch-only Rails app that watches a Bitcoin xpub, pushes a sub-second alarm to your phone the moment any outgoing transaction is detected, and gives you a fight-back window to RBF a higher-fee replacement to a fresh address you control before the attacker confirms. Also tracks fee-window alerts, daily USD-value snapshots, UTXO hygiene, and exports a Form-8949-ready CSV.

Watch-only. No private keys. Not now, not ever.

## What the alarm earns you

Attacker broadcasts a theft tx. ~10 minutes until it confirms. `coldwatch` pings your phone in ~1–3s.

- **Manual response (v1):** Sparrow + Ledger + a fresh address on a *separate* hardware wallet, fee 2–3× the attacker's, sign physically, broadcast. Miners take the higher fee.
- **Watchtower mode (v2 flagship):** pre-signed emergency transaction stored in `coldwatch`, broadcast on tap-to-confirm push.
- **Honest caveat:** sophisticated attackers can fee-war back; ~50% lucky-win against amateur attackers. Even on a loss, the alarm buys you minutes to call exchanges, document for police/insurance, protect related wallets.

Hardware prerequisite: a *second* hardware wallet with a *separate seed* at a *separate physical location* (~$80 second device). See `migration-emergency.md` for the full panic-flow setup.

## Stack (decisions baked)

| Layer | Choice | Why |
|---|---|---|
| Backend | Rails 7.2 + Hotwire | 12+ yrs depth; server-rendered matches "trust the box you run" |
| DB | PostgreSQL 16 | One store; xpub column uses Rails 7 `encrypts` |
| Jobs | Sidekiq + Redis | Recurring jobs, fee monitor, snapshot, heartbeat |
| Chain data | mempool.space WebSocket + REST (v1); pluggable to local Bitcoin Core (v2) | Sub-second event delivery; sovereign-mode-ready abstraction |
| Derivation | bitcoinrb, BIP84 only (`m/84'/0'/0'/{0,1}/i`) | One path; Ledger default; cheapest fees |
| Pricing | CoinGecko free tier | Daily USD snapshot only |
| Alerts | ntfy.sh with **E2E encryption** + email heartbeat fallback | Free, push-capable, no signup; provider sees ciphertext |
| TLS | Caddy + Let's Encrypt | One config file; HTTPS by default |
| Auth | Caddy IP allowlist + Rails session login (personal); paste-your-own-xpub form (demo) | Two layers, minimal moving parts |
| Deploy | Two independent Docker Compose stacks on one Hetzner box | Same host, hard blast-radius separation |

## 3-Week Milestones

### Week 1 — Watch + dashboard

Goal: paste a real xpub on a private subdomain and see real balance.

- Day 1 ✅ Rails 7.2 + Docker Compose (personal + demo stacks). Hello-world over HTTPS via Caddy. *Shipped.*
- Day 2 — `Wallet` model with `encrypts :xpub`, prefix-validated form. Single derivation end-to-end via bitcoinrb.
- Day 3 — Derive 20 receive + 20 change addresses, persist them. Initial REST fetch from mempool.space populates known transactions and UTXOs.
- Day 4 — `MempoolSocketWorker`: long-lived WebSocket in Sidekiq, subscribed to all derived addresses. Reconnect with exponential backoff. Idempotent inserts.
- Day 5 — Dashboard: total balance (sats + USD via CoinGecko), recent tx list, per-address breakdown.
- Day 6 — Gap-limit detection + "rescan deeper" button. Sync-time metric.
- Day 7 — Buffer; run against the real xpub.

**Success metric:** end-to-end sync for a 100-address xpub in < 60s.

### Week 2 — Alarm + fee monitor + USD journal

Goal: testnet outbound → phone buzzes in < 3s with E2E-encrypted payload.

- Day 8 — Outgoing-TX detector. Tests for incoming/outgoing/change/mixed. Confirmation thresholds: 0 conf → alarm, 6 conf → settled.
- Day 9 — ntfy with E2E encryption + HMAC. End-to-end testnet test.
- Day 10 — Reorg-aware confirmation tracking. Settled vs unsettled balances on the dashboard.
- Day 11 — Fee monitor: WebSocket fee feed, per-user threshold, alert dispatch.
- Day 12 — Daily USD snapshot + dashboard chart.
- Day 13 — Heartbeat to ntfy every 15 min; email fallback on N consecutive failures. `/metrics` page.
- Day 14 — Buffer.

**Success metric:** alarm latency p95 < 3s on testnet.

### Week 3 — UTXO + hygiene + spouse view + ship

- Day 15 — UTXO list view: amount, age, confirmations, current-spend-cost. Dust flagging.
- Day 16 — Address-reuse + gap-limit warnings on dashboard.
- Day 17 — CSV export (`transactions.csv`).
- Day 18 — Spouse view: `/v/{token}`, passphrase-gated, balance-only.
- Day 19 — README with architecture diagram + feature list. Round-out `threat-model.md`, `runbook.md`, `architecture.md` with anything still in TODOs.
- Day 20 — Public demo subdomain on Hetzner: paste-your-own-xpub form, privacy warning, 1-hour TTL, public ntfy topic. Separate Docker stack.
- Day 21 — 60s Loom demo. Polish. Ship.

Then run the personal instance against the real mainnet xpub for 2+ weeks before claiming "production."

## Scope-cut rules (in order, if we slip)

1. Drop UTXO map. List + balances suffices.
2. Drop CSV export. Tax story is nice-to-have; alarm story is core.
3. Drop spouse view. Single-user MVP.
4. Drop USD chart. Snapshot table is enough.
5. Drop public demo. Personal instance + screencast in README still tells the story.

The alarm and the threat model are irreducible. Everything else is cuttable.

## Why this beats alternatives

| Alternative | Why it loses |
|---|---|
| USDC invoice toy | Generic; no personal stake; everyone builds one |
| Smart-contract risk scanner | Crowded; LLM-heavy; not a backend signal |
| BTC tax tracker only | Too narrow; no real-time / systems story |
| Wallet UI clone | Sparrow / Nunchuk exist; no differentiator |
| Lightning node manager | 3-month project |

## v2 — sovereign mode (planned)

Replace `mempool.space` with own Bitcoin Core (pruned, ~10 GB) + Electrum Personal Server on the same Hetzner box. Single config flag: `CHAIN_PROVIDER=bitcoin_core`. The `ChainProvider` abstraction in v1 keeps callsites the same.
