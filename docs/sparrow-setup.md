# Sparrow Wallet — first setup and operational guide

Sparrow is the desktop wallet you'll use to actually move funds, sign transactions on your hardware wallets, and execute the runbook flows. `coldwatch` is the watcher; Sparrow is the actor. They're complementary tools, not alternatives.

This doc covers:

1. Verifying and installing Sparrow
2. Connecting it to a chain data source — public Electrum + Tor today, your own server later
3. Adding your hardware wallets (Ledger / BitBox / Coldcard each have a different connection style)
4. The minimum-viable testnet practice loop before you trust it with real funds

## Why Sparrow over Ledger Live / BitBoxApp

These vendor-specific apps each work fine for *receiving* on their respective devices. They fall short for the workflows the runbook depends on:

| Capability the runbook needs | Ledger Live | BitBoxApp | Sparrow |
|---|---|---|---|
| Coin control (pick which UTXOs to spend) | ❌ | partial | ✅ |
| RBF first-class | limited | partial | ✅ |
| PSBT round-trip with air-gapped Coldcard | ❌ | partial | ✅ |
| Multiple hardware-wallet vendors in one app | ❌ | ❌ | ✅ |
| Connect to your own Bitcoin Core node | ❌ | ❌ | ✅ |
| Tor support built-in | ❌ | partial | ✅ |
| Custom fee in sat/vB | ❌ | ❌ | ✅ |

For the alarm-fired RBF flow in `runbook.md` and the migration flow in `migration-emergency.md`, you need Sparrow.

## Step 1 — Install Sparrow safely

Download from `sparrowwallet.com`. **Verify the signature** before running. Sparrow's release page documents the verification steps; on macOS:

```bash
# Download the .dmg and the matching .asc signature
gpg --auto-key-locate hkps://keys.openpgp.org --locate-keys craigraw@sparrowwallet.com
gpg --verify sparrow-*.dmg.asc sparrow-*.dmg
# Look for "Good signature from Craig Raw"
```

If the signature is good, install. If not, do not run the binary — you may have a tampered download.

This step matters because Sparrow will hold view of your real wallet and broadcast on your behalf. A trojaned Sparrow is a serious attack vector.

## Step 2 — First-run server config (public Electrum + Tor)

Open Sparrow → **Preferences → Server**. Configure:

```
Server type:        Electrum (Public Servers)
Use Tor:            ✅ ON
URL:                electrum.blockstream.info
Port:               50002
Use SSL:            ✅ ON
```

Click **Test Connection**. You should see "Connected, latest block N" within ~10 seconds (Tor adds a couple seconds to the first connect). Click **Done**.

Why this is sufficient for tonight:

- Sparrow's bundled Tor routes every chain query through a rotating Tor circuit. The Electrum server learns *what* xpubs are queried; it cannot link *who* (your IP) is querying them.
- Public Electrum servers are not actively malicious; they are run by individuals and small teams in the Bitcoin community.
- For most threat models, this is the right balance of privacy and convenience.

You can always upgrade to your own server later. See Step 6.

## Step 3 — Add your hardware wallets

Each device has a different connection model. Sparrow handles all of them, but the workflow differs.

### Ledger (USB-connected, watch-only after migration)

After you've migrated funds *off* the Ledger, the Ledger lives in a drawer as your panic destination. To register it in Sparrow as a watch-only wallet:

1. **File → New Wallet → name it `panic-destination`**
2. Choose **Watch Only Wallet**
3. Connect Ledger, unlock, open the Bitcoin app
4. **Settings → Get extended public key** (or via Sparrow → Connect Hardware Wallet → Import → Ledger)
5. Confirm the xpub on the device screen
6. Save

Now Sparrow shows your Ledger's balance without needing the device plugged in. You only plug it in if you're moving funds *off* the panic destination — which, hopefully, you never do.

### BitBox02 (USB-connected, primary spending)

1. Plug in the BitBox via USB-C, tap to wake, enter device password
2. **File → New Wallet → name it `bitbox-warm`**
3. **Connected Hardware Wallet** → BitBox should appear
4. Confirm derivation path on the BitBoxApp prompt (or Sparrow's prompt) — should be `m/84'/0'/0'` for Native SegWit
5. Sparrow imports the xpub and creates the wallet

For each spend: plug in BitBox, build tx in Sparrow, click Sign, tap to confirm on the device.

### Coldcard (air-gapped via microSD)

Coldcard is **never plugged into your laptop via USB.** It runs on its own batteries (or a power-only USB cable from a wall plug, no data lines). The signing flow is:

1. Initial xpub import — Coldcard exports the xpub to microSD as `coldcard-export.json`
   - On Coldcard: Advanced → MicroSD → Export Wallet → Generic JSON
2. **File → New Wallet → name it `coldcard-deepcold`**
3. **Air-gapped Hardware Wallet** → Coldcard → Import from File → pick the JSON
4. Sparrow now has the watch-only wallet for Coldcard

For each spend (rare — once a year for deep cold):

1. In Sparrow, build the unsigned transaction → **Save → As PSBT**
2. Copy the `.psbt` file to a microSD card
3. Move microSD to Coldcard, plug in (battery still provides power; no laptop)
4. Coldcard reads the PSBT, displays the destination + fee for your visual verification
5. Press to sign; Coldcard writes a `signed.psbt` back to the SD card
6. Move microSD back to your laptop
7. In Sparrow → **File → Import → Signed PSBT** → Broadcast

This loop sounds tedious. It is. That's the point — it makes a USB-based malware attack on your signing key physically impossible.

## Step 4 — The minimum testnet practice loop

Before you migrate any real funds, run this loop *at least* once on testnet:

1. **Sparrow → Preferences → set network to Testnet** (top-right corner switch)
2. Create a fresh testnet wallet via your existing Ledger (`m/84'/1'/0'` for testnet BIP84)
3. Get free testnet BTC from a faucet — `coinfaucet.eu/en/btc-testnet/` or similar
4. Send a test transaction *from* the testnet Ledger wallet *to* a different testnet address you control
5. Build an RBF replacement spending the same UTXOs to a third testnet address with a higher fee
6. Broadcast the replacement
7. Watch the original tx get evicted from the mempool — you've practiced the runbook

Repeat until you can do it without hesitation. Once you can, the mainnet migration is muscle memory.

## Step 5 — Sparrow features to know about

A short tour of features you'll touch routinely.

### Coin Control

**Tools → Coin Control** (or right-click any UTXO). Lets you pick exactly which UTXOs a transaction will spend. Mandatory for the runbook RBF flow because you must spend the *same* UTXOs the attacker is spending. Also useful for:

- Privacy: avoid mixing UTXOs of different provenance in one transaction
- Fee management: spending one large UTXO is cheaper than many small ones

### Address Labels

Right-click any address → Edit Label. Label receive addresses with their purpose ("salary March 2026", "Coinbase buy at $80k") and UTXOs inherit the source label. Hugely useful for tax records and for keeping track of fund provenance years later.

### Transaction Editor

When building a send, Sparrow's transaction view shows inputs, outputs, change, and fee in a clear graph. Verify the fee in sat/vB matches your intent. Verify the destination is what you expect. Don't skim this — verify on the device screen too if hardware-signed.

### Mempool Viewer

**Tools → Mempool Visualizer**. Live view of fee rates and the next few blocks. Use this together with `coldwatch`'s fee monitor — `coldwatch` pings you when fees are quiet, you open Sparrow's mempool view to confirm before broadcasting.

## Step 6 — Upgrade path: your own Electrum server (v2)

Once `coldwatch` v1 is running and your three-wallet migration is complete, the next privacy upgrade is replacing the public Electrum server with your own. **At that point, mempool.space and the public Electrum servers learn nothing about your wallet — ever.**

Two paths, same idea:

### v2-A — On the existing Hetzner box

Add to the Hetzner box (alongside `coldwatch`):

- **Bitcoin Core in pruned mode** (~10 GB disk, 1–2 day initial sync): a full validating node that doesn't keep historical blocks
- **Electrum Personal Server (EPS)**: a tiny daemon that speaks the Electrum protocol and only indexes addresses you tell it about (your xpubs)

Sparrow connects via SSH tunnel:

```bash
# On your laptop, leave a tunnel open
ssh -L 50002:127.0.0.1:50002 you@hetzner-box
```

In Sparrow → Preferences → Server:

```
Server type:        Electrum
URL:                127.0.0.1
Port:               50002
Use SSL:            OFF (tunnel is already encrypted)
Use Tor:            OFF
```

Approximate weekend project. Same Bitcoin Core instance can also feed `coldwatch` once you flip its `CHAIN_PROVIDER=bitcoin_core` config.

### v2-B — On a Raspberry Pi 5 at home

Same software stack, different hardware. Pi 5 (8 GB RAM) + 1 TB external SSD ≈ $200 one-time. Stays at home, never leaves the LAN. Connect via Tailscale (free) so your laptop reaches it from anywhere.

Highest-privacy posture. Recommended once your stack is in three-wallet territory ($15k+).

## Common gotchas

| Symptom | Cause | Fix |
|---|---|---|
| "Server connection failed" on first run | Tor still bootstrapping | Wait ~30s, click Test Connection again |
| BitBox not detected | USB cable is power-only (common with budget cables) | Use the cable that came with the BitBox or a known data-capable USB-C cable |
| Coldcard PSBT signing fails with "wrong wallet" | Sparrow's wallet xpub doesn't match the Coldcard's seed | You imported a different account's xpub. Re-export from Coldcard, re-import in Sparrow. |
| Ledger genuineness check fails in Ledger Live before xpub export | Tampered or used device | Stop. Don't import the xpub. Treat the device as untrusted (see `migration-emergency.md`). |
| Sparrow shows wrong balance | Wallet hasn't fully synced | Tools → Refresh, or check the server connection in the bottom-right status bar |
| RBF replacement won't broadcast | Original tx already confirmed | Race lost; see `runbook.md` Step 5 (loss playbook) |

## What this doc does NOT cover

- **Multisig wallet setup** in Sparrow. Real and powerful, but a different doc. See Sparrow's official multisig guide.
- **CoinJoin / privacy mixing.** Whirlpool / Samourai shut down in 2024. There are alternatives (JoinMarket) but they're advanced and not the right starting place.
- **Lightning channel management.** Sparrow doesn't do Lightning; use Phoenix, Breez, or a node like Umbrel.
- **Exchange withdrawals to Sparrow.** Standard "send to receive address" — no Sparrow-specific guidance needed.

## TL;DR for tonight

1. Download Sparrow from `sparrowwallet.com`, verify the signature, install
2. Open it. Server: Public Electrum + Tor + `electrum.blockstream.info`
3. Switch to testnet, practice the RBF loop until you can do it confidently
4. Switch back to mainnet
5. Add your existing Ledger as a watch-only wallet; you're now ready for the migration sequence in `migration-emergency.md`

The own-server upgrade comes later. Don't block on it.
