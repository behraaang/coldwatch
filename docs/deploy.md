# Deploy — Hetzner runbook

Everything required to bring a clean `coldwatch.{domain}` from "fresh VPS" to "wallet UI loading on your phone over Tailscale," in the same order it was first done. Replace `behdev.com` and `coldwatch-hetzner` with your own values throughout.

- **Saved:** 2026-05-10 (after the live deploy)
- **Status:** matches the `personal` stack as deployed. The `demo` stack is not yet wired (see `build-plan.md`).

## What you should already have

- A Hetzner box with SSH access (this runbook assumes `Host hetzner` in `~/.ssh/config`, `User root`).
- A registered domain whose DNS you control.
- A public DNS provider account (Cloudflare / Namecheap / Hetzner DNS — any).
- A laptop with `dig`, `curl`, and `ssh` installed.
- *Recommended:* a [Tailscale](https://tailscale.com/) account (free for personal use) for phone access from cellular.

## Step 1 — Install Docker on the box

Use the official apt repo, not the curl-pipe-bash convenience script (cleaner audit trail, idempotent):

```bash
ssh hetzner '
  apt-get update -qq && \
  apt-get install -y -qq ca-certificates curl gnupg lsb-release && \
  install -m 0755 -d /etc/apt/keyrings && \
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc && \
  chmod a+r /etc/apt/keyrings/docker.asc && \
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo $VERSION_CODENAME) stable" > /etc/apt/sources.list.d/docker.list && \
  apt-get update -qq && \
  DEBIAN_FRONTEND=noninteractive apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
'
ssh hetzner 'docker --version && docker compose version'
```

## Step 2 — Clone the repo

```bash
ssh hetzner 'mkdir -p /opt && cd /opt && git clone https://github.com/behraaang/coldwatch.git'
ssh hetzner 'cd /opt/coldwatch && git rev-parse --short HEAD'
```

To redeploy later, just `cd /opt/coldwatch && git pull` followed by Step 5 build.

## Step 3 — Generate production secrets

The `personal/.env` file holds the postgres password, Rails session secret, and the three ActiveRecord encryption keys. Generate them **on the box** so they never traverse a chat / shell history on your laptop:

```bash
ssh hetzner '
  cd /opt/coldwatch/personal
  if [ ! -f .env ]; then
    PGPW=$(openssl rand -hex 16)
    SKB=$(openssl rand -hex 64)
    EPK=$(openssl rand -hex 16)
    EDK=$(openssl rand -hex 16)
    EKDS=$(openssl rand -hex 16)
    umask 077
    cat > .env <<EOF
POSTGRES_PASSWORD=$PGPW
SECRET_KEY_BASE=$SKB
RAILS_ENCRYPTION_PRIMARY_KEY=$EPK
RAILS_ENCRYPTION_DETERMINISTIC_KEY=$EDK
RAILS_ENCRYPTION_KEY_DERIVATION_SALT=$EKDS
EOF
    chmod 600 .env
  fi
  ls -la .env
'
```

**Back up `personal/.env` somewhere safe** (1Password / Bitwarden). Losing the encryption keys means losing access to every wallet's `xpub` and `ntfy_topic` in the database — the rows stay, the plaintext doesn't.

## Step 4 — Why we skip the `caddy/` stack on production

If your box already runs nginx (this one does — for behdev.com and behrangmirzamani.com), the repo's `caddy/` stack will fight nginx for ports 80/443. On production we leave the `caddy/` stack untouched and let the existing nginx be the public TLS terminator. `personal/docker-compose.production.yml` binds the Rails container to `127.0.0.1:3001` for nginx to proxy_pass into.

## Step 5 — Bring up the personal stack

```bash
ssh hetzner '
  cd /opt/coldwatch/personal
  docker network create coldwatch_web 2>/dev/null || true
  docker compose -f docker-compose.yml -f docker-compose.production.yml up -d --build
'
```

`coldwatch_web` is declared `external: true` in `docker-compose.yml` because the Caddy stack expects it. On prod nothing else attaches; we create it so compose stops complaining.

Verify all five containers are up:

```bash
ssh hetzner 'cd /opt/coldwatch/personal && docker compose -f docker-compose.yml -f docker-compose.production.yml ps'
```

Health check (`/up` returns 200 with HTTPS `X-Forwarded-Proto`, 301 redirect without it because Rails `force_ssl` is on in production):

```bash
ssh hetzner 'curl -s -o /dev/null -w "HTTP %{http_code}\n" -H "X-Forwarded-Proto: https" http://127.0.0.1:3001/up'
```

## Step 6 — DNS record

At your DNS provider, add an A record:

| Type | Name | Value | TTL |
|------|------|-------|-----|
| A | `coldwatch` | your Hetzner public IP | 60 (low for fast retries during setup) |

Verify from the box and from the public internet:

```bash
ssh hetzner 'dig +short coldwatch.behdev.com A'   # should print the IP
dig +short coldwatch.behdev.com A @1.1.1.1        # check from your laptop too
```

## Step 7 — nginx site + Let's Encrypt cert

Write the site file (placeholder IP gets replaced in the next step):

```bash
ssh hetzner 'cat > /etc/nginx/sites-available/coldwatch <<NGINX
upstream coldwatch_personal {
    server 127.0.0.1:3001 fail_timeout=0;
}

server {
    server_name coldwatch.behdev.com;
    client_max_body_size 2M;

    # IP allowlist — fill in your home IPv4 and any tailnet members below.
    allow ALLOWED_IP;
    deny all;

    location / {
        proxy_set_header Host \$http_host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_redirect off;
        proxy_read_timeout 60s;
        proxy_pass http://coldwatch_personal;
    }

    listen 80;
}
NGINX'
```

Replace `ALLOWED_IP` with your home IP (find with `curl -4 ifconfig.io`), enable the site, issue the cert:

```bash
ssh hetzner '
  sed -i "s|allow ALLOWED_IP;|allow 1.2.3.4;|" /etc/nginx/sites-available/coldwatch
  ln -sf /etc/nginx/sites-available/coldwatch /etc/nginx/sites-enabled/coldwatch
  nginx -t && systemctl reload nginx
  certbot --nginx -d coldwatch.behdev.com -n --agree-tos --email you@example.com --redirect
'
```

`certbot --nginx --redirect` rewrites the server block in-place: adds `listen 443 ssl`, `ssl_certificate` lines, and a separate `:80 → :443` redirect block. Renewal is automatic via the systemd timer.

You should now load `https://coldwatch.behdev.com` from your home network and see the wallet UI. Other IPs get a 403.

## Step 8 (optional) — Tailscale for phone-from-anywhere access

The cleanest way to use the same `coldwatch.behdev.com` URL from your phone on cellular without rotating IPs is **Tailscale subnet routing**: the box advertises its own public IP into the tailnet, so any tailnet member (your phone, your laptop with Tailscale on) routes that IP through the tunnel and arrives at nginx with a `100.x.y.z` source — and you put the tailnet CIDR on the allowlist.

```bash
# 1. Install Tailscale on the box via apt
ssh hetzner '
  curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/noble.noarmor.gpg -o /usr/share/keyrings/tailscale-archive-keyring.gpg
  curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/noble.tailscale-keyring.list -o /etc/apt/sources.list.d/tailscale.list
  apt-get update -qq && DEBIAN_FRONTEND=noninteractive apt-get install -y -qq tailscale
'

# 2. Authenticate the box (prints a URL; click it in your browser, approve)
ssh hetzner 'nohup tailscale up --hostname=coldwatch-hetzner > /tmp/tsup.log 2>&1 & disown; sleep 4; cat /tmp/tsup.log'

# 3. Install Tailscale on your phone (App Store / Play Store), sign in to the same account.

# 4. Enable IP forwarding + advertise the box's public IP as a subnet route
ssh hetzner '
  echo "net.ipv4.ip_forward = 1" > /etc/sysctl.d/99-tailscale.conf
  echo "net.ipv6.conf.all.forwarding = 1" >> /etc/sysctl.d/99-tailscale.conf
  sysctl -p /etc/sysctl.d/99-tailscale.conf
  tailscale set --advertise-routes=$(curl -s -4 ifconfig.io)/32
'

# 5. Approve the advertised route in the Tailscale admin console:
#    https://login.tailscale.com/admin/machines → coldwatch-hetzner → Edit route settings → toggle the /32 ON.

# 6. Add the tailnet CIDR to the nginx allowlist (alongside your home IP, so Tailscale-off still works from home)
ssh hetzner '
  sed -i "s|allow 1.2.3.4;|allow 100.64.0.0/10;\n    allow 1.2.3.4;|" /etc/nginx/sites-available/coldwatch
  nginx -t && systemctl reload nginx
'
```

Phone on cellular with Tailscale **on** → `https://coldwatch.behdev.com` now loads. Tailscale **off** → 403.

If you'd rather not run `tailscale serve` is the lighter alternative: it exposes the box on a tailnet-only URL like `https://coldwatch-hetzner.tail<id>.ts.net` without touching nginx or IP forwarding. Trade-off: different URL, only works inside the tailnet.

```bash
# In the Tailscale admin console, enable HTTPS Certificates first:
#   https://login.tailscale.com/admin/dns → HTTPS Certificates → Enable HTTPS.
ssh hetzner 'tailscale serve --bg --https=443 http://127.0.0.1:3001'
```

## Step 9 — Wire ntfy push

In the wallet's edit form, paste an ntfy topic string (8–64 chars, `[A-Za-z0-9_-]`). Install the [ntfy app](https://ntfy.sh/) on your phone and subscribe to the same topic. Test it end-to-end:

```bash
ssh hetzner '
  cd /opt/coldwatch/personal
  docker compose -f docker-compose.yml -f docker-compose.production.yml exec -T web bin/rails runner "
    require %q(net/http); require %q(uri)
    w = Wallet.where.not(ntfy_topic: nil).first
    uri = URI(%(https://ntfy.sh/) + w.ntfy_topic)
    req = Net::HTTP::Post.new(uri)
    req[%q(Title)] = %q(coldwatch test alarm)
    req[%q(Priority)] = %q(urgent)
    req.body = %(Test push. Reply OK from #{w.name}.)
    res = Net::HTTP.start(uri.host, uri.port, use_ssl: true) { |h| h.request(req) }
    puts %(ntfy HTTP) + res.code
  "
'
```

`200` = your phone should buzz within seconds.

## Operations

```bash
# Tail logs
ssh hetzner 'cd /opt/coldwatch/personal && docker compose -f docker-compose.yml -f docker-compose.production.yml logs -f web'
ssh hetzner 'cd /opt/coldwatch/personal && docker compose -f docker-compose.yml -f docker-compose.production.yml logs -f sidekiq'
ssh hetzner 'cd /opt/coldwatch/personal && docker compose -f docker-compose.yml -f docker-compose.production.yml logs -f mempool_subscriber'

# Redeploy after a git push
ssh hetzner 'cd /opt/coldwatch && git pull && cd personal && docker compose -f docker-compose.yml -f docker-compose.production.yml up -d --build'

# Rails console on the box
ssh hetzner 'cd /opt/coldwatch/personal && docker compose -f docker-compose.yml -f docker-compose.production.yml exec web bin/rails console'

# Cert renewal (automatic, but to test)
ssh hetzner 'certbot renew --dry-run'
```

## Known gotchas

- **Force-SSL redirect on `:3001`.** Rails production has `config.force_ssl = true`, so any HTTP request to `127.0.0.1:3001` returns 301. nginx proxies with `X-Forwarded-Proto: $scheme` so the app sees HTTPS — that part works automatically. Don't be alarmed if a bare `curl http://127.0.0.1:3001/up` from the box returns 301; that's healthy.
- **The classifier may block destructive recon.** If you're running this from Claude Code in auto mode, some steps (SSH log reads, removing the IP allowlist, sysctl IP forwarding, curl-pipe-bash installs) will be blocked. Run those commands directly via the `!` shell prefix or grant a permission rule.
- **`connection_pool` pin.** The Gemfile pins `connection_pool ~> 2.4` because 3.x broke Sidekiq 7.3's scheduled-job poller. Don't unpin until Sidekiq cuts a 7.3-compatible release.
- **`coldwatch_web` external network.** `docker-compose.yml` references this network because the Caddy stack expects it. On prod we don't run Caddy, so we create the network as a no-op (`docker network create coldwatch_web`) to satisfy compose.
