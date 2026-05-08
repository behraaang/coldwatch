# Threat Model

This document is honest about what `coldwatch` defends against and — more importantly — what it does not. If you are about to paste a real mainnet xpub into a `coldwatch` instance, **read this first.**

## The single most important fact

> A leaked xpub **cannot** spend any of your Bitcoin. It **can** reveal every address and transaction you have ever made or will ever make, forever.

Public keys verify signatures; they do not produce them. Without your seed phrase (which `coldwatch` never sees, never asks for, and cannot derive), nothing here can sign a spend.

## What `coldwatch` defends against

| Threat | Defense | Effectiveness |
|---|---|---|
| **Theft of funds** | Watch-only architecture; no private keys touch the system | Absolute — by design |
| **Slow theft discovery** | Sub-second push alarm on any outgoing tx | High; opens the RBF fight-back window |
| **Phone-notification leak** | E2E-encrypted ntfy payload + HMAC | High; ntfy.sh sees ciphertext only |
| **Database snapshot leak** | Rails 7 `encrypts :xpub`, AES-256-GCM | High against casual access; ineffective if attacker also has the master key |
| **Repo-leaked xpub** | CI guard greps every commit for xpub-shaped strings | High against accidents |
| **Log-leaked xpub** | Rails parameter filter + custom log redactor middleware | High |
| **Network MITM** | Caddy + Let's Encrypt, HTTPS-only, HSTS | High |
| **Drive-by access to dashboard** | Caddy IP allowlist + Rails session login | High |
| **ntfy outage masking the alarm** | Heartbeat job pings ntfy every 15 min; on N consecutive failures, fall back to email + dashboard banner | High against silent failure |
| **Reorg confusion** | Two-tier balance accounting (unsettled vs settled, 6-conf threshold) | High; matches Bitcoin Core's own conservatism |

## What `coldwatch` does NOT defend against

This list is the senior signal. Every one of these is a real limitation; we surface them honestly because hiding them would mislead you.

### 1. Sophisticated attacker who already has your seed

If your seed is compromised, the attacker has the same private keys you do. They can:

- See your mempool replacement and re-broadcast at a higher fee (fee war)
- Fee-bump faster than you can with a hardware wallet button-press
- Win the race ~50% of the time against a prepared user, much higher against an unprepared one

`coldwatch` opens the window; it does not guarantee victory in it. See `docs/runbook.md` for the realistic playbook.

### 2. Attacker with hypervisor access on the Hetzner host

A Hetzner employee, or anyone who breaches Hetzner's infrastructure at the hypervisor layer, can read RAM. The xpub is decrypted in memory while `coldwatch` is running. Mitigations:

- Hetzner is reputable; attack is improbable for a non-targeted individual
- Encrypted-at-rest column makes a casual snapshot attacker capture ciphertext only
- The *real* fix is running on hardware you physically control. Out of scope for v1.

### 3. Compromised Hetzner Cloud account

If your Hetzner login is phished or your password reused-and-leaked, the attacker downloads a snapshot of the volume. They get:

- Ciphertext for the xpub column (useful if they also breach the master key)
- Plaintext for everything else (transactions, USD snapshots, derived addresses — privacy disaster but not a theft vector)

Mitigations: strong unique password, hardware-backed 2FA on Hetzner, separate the master key from the snapshot (env var on the running container, not in any backup).

### 4. mempool.space correlation

In v1 we use mempool.space as the chain data source. Every address `coldwatch` queries is visible to mempool.space and to any network observer between you and them. They can correlate all your wallet's addresses as belonging to one entity.

- Acceptable for most users; mempool.space is well-run, has a privacy policy, and isn't selling data
- The v2 fix is running your own Bitcoin Core node on the same Hetzner box. The `ChainProvider` interface is built to accommodate this swap with no callsite changes.

### 5. Phone compromise

If your phone is jailbroken, malware-infected, or simply unlocked-and-stolen, an attacker:

- Can read incoming ntfy notifications (defeats the E2E encryption; the phone has the key)
- Cannot retroactively read messages received before compromise (ntfy doesn't store them server-side after delivery)
- Can subscribe to your topic going forward (we mitigate by topic-name secrecy + HMAC verification on the phone side, but a compromised phone has both)

If you suspect your phone, immediately rotate the ntfy topic and the E2E key in `coldwatch`'s settings.

### 6. Hardware wallet compromise (the original threat)

The whole reason `coldwatch` exists is that hardware wallets *can* be compromised:

- Phished firmware ("Ledger Live update" social engineering)
- Evil maid (brief physical access)
- Supply-chain swap (used / Amazon-marketplace devices)

`coldwatch` does **not** prevent these. It detects the *consequences* by alerting on outgoing transactions. Your defenses against hardware-wallet compromise are upstream of `coldwatch`:

- Buy directly from the manufacturer
- Verify the seed-generation entropy yourself when you can
- Keep firmware updated *only* via the official app
- Physical security on the device

### 7. The $5 wrench attack

Anyone who knows you have significant Bitcoin can target you physically. `coldwatch` cannot help with this; in fact, accidentally exposing your xpub *increases* this risk because attackers can size your stack precisely.

Mitigation: keep your wallet activity private, don't post about your holdings, treat your xpub like the highly sensitive document it is.

### 8. Bugs in `coldwatch` itself

This is a single-developer project. There will be bugs. We mitigate with:

- Watch-only architecture (the worst-case bug cannot drain funds, only leak metadata)
- Test suite including integration tests against Bitcoin testnet
- Pre-commit / CI guard for xpub-shaped strings
- Conventional commits + changelog so users can audit changes

But you are accepting the risk of a privacy bug, not a financial bug, when you run `coldwatch`.

## Defense-in-depth summary

For your **personal instance** on Hetzner, the layered defenses are:

1. **DNS** — only published, not secret, but precise subdomain naming
2. **Caddy IP allowlist** — only your home / known IPs reach the Rails app
3. **TLS** — everything in transit
4. **Rails session login** — even past Caddy, you authenticate
5. **Rails parameter filter + log redactor** — xpub never reaches logs
6. **Encrypted column in Postgres** — at-rest defense
7. **Strong Hetzner Cloud account password + 2FA** — protects the snapshot vector
8. **CI guard + .gitignore discipline** — protects against repo leaks
9. **ntfy E2E encryption** — protects the push channel
10. **Heartbeat fallback** — protects against silent alarm failure

Removing any one of these is a real downgrade. Adding more (Tailscale-only access, your own node, a hardware-attested key for the master key) is v2 territory.

## What the public demo accepts that the personal instance does not

The public `demo.{domain}` subdomain accepts pasted xpubs from strangers. Its threat model is fundamentally different:

- Visitors may paste **real mainnet xpubs into a service they do not trust**. This is a privacy disaster waiting to happen for those visitors.
- We mitigate by: **massive red warning** on the form, **1-hour session TTL** with auto-purge, **no persistence** beyond the session, **public ntfy topic** (testnet only), and a **prominent link to this document**.
- We do not mitigate against: a malicious operator (us) saving xpubs out-of-band. Visitors who don't trust us should run the personal instance themselves.

If you are running this as a public demo for a portfolio, **do not save visitor xpubs anywhere**. The session-purge worker is part of the trust contract.

## Disclosure

Found a security issue? Email me@behrangmirzamani.com. Please do not open a public GitHub issue for vulnerabilities.
