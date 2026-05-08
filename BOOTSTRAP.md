# Bootstrap — Day 1

This repo currently contains infrastructure, docs, and CI guardrails. The Rails applications themselves are not in this repo yet — you will create them on Day 1 of the build, inside `personal/` and `demo/`.

## Prerequisites

- A Hetzner Cloud server (CX22 or larger, Ubuntu 22.04 or 24.04)
- A domain pointing at the Hetzner box (two A records: `coldwatch.{your-domain}` and `demo.{your-domain}`)
- Docker + Docker Compose v2 installed on the box (`docker compose`, not `docker-compose`)
- Your home IP address for the Caddy allowlist (find with `curl -4 ifconfig.io`)
- A second hardware wallet ordered or in hand — see `docs/runbook.md` for why this is a prerequisite, not an optional extra

## Step 1 — Customize Caddy

```bash
cd caddy
cp .env.example .env
# Edit .env: set DOMAIN=your-domain.tld and HOME_IP=1.2.3.4/32
```

## Step 2 — Bootstrap the personal Rails app

From the repo root, on the Hetzner box (or locally if you'd rather develop and rsync):

```bash
docker run --rm -v "$(pwd)/personal:/app" -w /app ruby:3.3-slim bash -c \
  "apt-get update -qq && apt-get install -y --no-install-recommends build-essential libpq-dev nodejs npm && \
   gem install rails -v '~> 7.2' && \
   rails new . --database=postgresql --skip-git --skip-bundle --css=tailwind --javascript=importmap"
```

Then in `personal/Gemfile` add:

```ruby
gem "sidekiq"
gem "redis"
gem "bitcoin-ruby", require: "bitcoin"
gem "faye-websocket"  # mempool.space WebSocket client
gem "rqrcode"         # for receive-address QR codes (later)
```

Add `personal/Dockerfile` and update `personal/docker-compose.yml` to point at it.

## Step 3 — Bootstrap the demo Rails app

Same as Step 2, substituting `demo` for `personal`. The demo will eventually share most code via a shared engine, but for v0 keep them as two independent apps.

## Step 4 — Bring it all up

```bash
(cd personal && cp .env.example .env && docker compose up -d)
(cd demo && cp .env.example .env && docker compose up -d)
(cd caddy && docker compose up -d)
```

## Step 5 — DNS and TLS

- Point `coldwatch.{your-domain}` and `demo.{your-domain}` A records at the Hetzner IP
- Caddy will fetch Let's Encrypt certificates automatically on first request
- Test: `curl -I https://coldwatch.{your-domain}` should return 200 (from your allowlisted IP) or 403 (from anywhere else)

## Step 6 — Verify the xpub guard

Before you ever paste an xpub into the form, make sure the CI guard is wired up:

```bash
chmod +x scripts/grep-xpub-guard.sh
./scripts/grep-xpub-guard.sh
```

It should exit 0 (no xpub-shaped strings found). If anyone ever commits one accidentally, this script and the GitHub Action will fail the build.

## You're ready

Day 1 of the build per `interview-prep/artifact-coldwatch.md` (in the parent `career-ops` repo) is now complete. Move to Day 2 of the spec.
