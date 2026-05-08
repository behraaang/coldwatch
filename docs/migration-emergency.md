# Emergency Migration — "I suspect my seed may be compromised"

This document is for the case most Bitcoin self-custody guides quietly skip: you have funds on a hardware wallet *right now*, and you have reason — concrete or vague — to suspect the seed may be known to someone other than you.

It is **not** for the case where an alarm has already fired and a theft transaction is in the mempool. That case is `docs/runbook.md`.

The two are different problems:

| Situation | Document | What's happening |
|---|---|---|
| You suspect leakage but no alarm has fired yet | **this doc** | Pre-emptive migration to a fresh wallet |
| Alarm has fired, attacker is actively spending | `docs/runbook.md` | Real-time fight-back with RBF |

## Triage

Read these. Place yourself in a tier honestly.

### Red — migrate within hours

Any of:

- You typed your seed phrase into any website (the 2020 Ledger customer-data-leak phishing campaign tricked thousands into doing this)
- You photographed your seed phrase and the photo touched any cloud service (iCloud, Google Photos, Dropbox, WhatsApp, Telegram, email)
- You stored your seed phrase in a password manager (1Password, LastPass, Bitwarden) and that password manager has been breached, or you've ever shared a vault with anyone, or you've ever typed the master password on a public computer
- You showed your seed to someone — anyone — even briefly
- You opened a recent email or DM that asked you to "verify your Ledger" or "claim airdrop" and clicked any link or entered anything

**Action:** Migrate today. Pay whatever fee is required. Treat as a real emergency, not a project.

### Yellow — migrate this week

Any of:

- Vague suspicion, no specific incident, but you can't rule out one of the Red items with full confidence
- You bought the device used or from a third-party marketplace (Amazon, eBay, Facebook Marketplace) — *seed* is probably fine but the device itself may be compromised; either way, migrate
- You used the device on a computer that was later found to have malware
- You moved homes recently and the device was out of sight during the move
- You traveled with the device and it was out of your direct control (hotel safe, checked luggage)

**Action:** Migrate during a low-fee mempool window in the next 7 days. Use `coldwatch`'s fee monitor to find a quiet window.

### Green — migrate when convenient

- Pure precaution, no triggering event
- Routine architecture upgrade as part of moving to Option C (Coldcard + BitBox + Ledger as panic destination)

**Action:** Migrate as part of your normal Option C rollout over 2–3 weeks. No urgency.

## The sequence (do not deviate)

Whether Red, Yellow, or Green, the order is the same:

```
  1. Receive your new wallet(s) — Coldcard, BitBox02, or both. Brand new, direct from manufacturer.
  2. Set up the new wallet(s) in a different room/time from each other. Generate fresh seeds.
  3. Run a small test: send $10–50 worth from CURRENT wallet → new wallet. Wait for 1 confirmation.
  4. Verify in Sparrow: balance arrived on new wallet, source address debit registered.
  5. Send the bulk: CURRENT wallet → new wallet, all funds, single transaction, RBF enabled.
  6. Wait for 6 confirmations (~1 hour). The funds are now permanently on the new wallet.
  7. ONLY NOW: factory-reset the old wallet.
  8. Generate a new seed on the old wallet (or decommission it permanently if you're paranoid about the hardware).
  9. The old wallet, with its new seed, can now serve as your panic destination.
```

## Why move first, reset second

If you reset before moving:

- The funds remain on the blockchain at the old addresses, controlled by the old seed
- To spend them, you must enter the old (suspect) seed back into a wallet — exposing it again
- Any window where the seed is "in your hands" again is another window for compromise
- Worst case: you reset, can't find your seed backup, and the funds are unrecoverable

Move first. Confirm the funds arrived. Then reset. Then forget the old seed exists.

## Genuineness check (before trusting a reset)

If your suspicion is **seed-level only** — you handled the seed badly, but the device itself was bought new and never out of your control — a factory reset gives you a clean wallet on the same hardware.

If your suspicion is **hardware-level** — supply-chain swap, evil-maid, used device — a reset on tampered hardware gives you a *new* compromised seed. The same device leaks the new seed the same way it leaked the old.

Distinguish before trusting a reset:

### Ledger

Plug into Ledger Live. Ledger Live automatically performs a genuineness check on every connection — it cryptographically challenges the device to prove its identity using Ledger's signing keys. If the device responds correctly, the hardware is genuine and a reset is sufficient.

If the genuineness check fails (or has ever failed in the past), the device is untrusted. Decommission it.

### BitBox / Coldcard

Both vendors document their genuineness check procedure on their support pages:

- BitBox: pairing and attestation handled by the BitBoxApp on first connection
- Coldcard: physical attestation card included in the box; the device shows a number you compare against the card

In both cases, do the check on first setup. If it fails, contact the vendor.

## Fee strategy during migration

The migration transaction is **time-sensitive in a way normal transactions are not**, because the attacker (if there is one) may see your tx in the mempool and try to race it.

**Don't be cheap on this transaction.** Specifically:

| Tier | Fee strategy |
|---|---|
| Red (active suspicion) | Top of mempool — aim for next-block confirmation. Sparrow's "next block" target. Pay $20–$80 instead of $5; the difference is rounding error vs. the stack. |
| Yellow | Above-average — `coldwatch` fee monitor's threshold + 50%. Confirms within 1–2 blocks. |
| Green | Wait for a quiet window using the fee monitor. Pay normal rates. |

**Enable RBF.** Sparrow does this by default. If for any reason the tx gets stuck below the new mempool floor, you can fee-bump without rebuilding.

**Run `coldwatch` during the migration.** Even a partial v0 instance pointed at the suspect xpub will fire the alarm if a competing transaction appears in the mempool. Side benefit: real-world alarm test.

## Tor and privacy posture

If you're worried about a *targeted* attacker who's monitoring your network connections, broadcast through Tor:

- Sparrow has a Tor toggle in Preferences → Server. Enable it before the migration tx.
- Connect Sparrow to your own Bitcoin Core node *or* to a public Electrum server over Tor — not to mempool.space directly during this operation, since the connection metadata could be observed.

For most users, this is overkill — but if your reason for suspicion includes "I think I'm being targeted," do it.

## What this document does NOT cover

- **Recovery from a confirmed theft.** That's not a migration; that's a loss. See `docs/runbook.md` Step 5 (the loss playbook).
- **Multisig migration.** Significantly more complex. Out of scope; consult Sparrow / Unchained Capital docs if you're moving from singlesig to multisig.
- **Lightning channel migration.** Not relevant unless you're running an LN node, in which case this whole doc doesn't apply to you.
- **Privacy-preserving consolidation across many addresses.** A migration tx that consumes 30 UTXOs and outputs to 1 destination *correlates* all 30 source addresses as belonging to one entity. If you previously had address-level privacy (received from CoinJoin output, etc.) you'll lose it in the consolidation. For most users this trade-off is fine — privacy is already gone the moment you mistrust the seed.

## Realistic outcome

If you migrate from a non-actively-monitored leaked seed: **success rate ~99%**. The attacker probably hasn't noticed you yet. You'll get a clean migration in 1–6 confirmations and the old seed becomes worthless.

If you migrate from an *actively monitored* seed: **success rate is the same as the runbook's RBF fight-back — closer to 50%**. The attacker may try to race you. Your defense is the high-fee strategy above plus running `coldwatch` to detect a race in real-time.

If the seed wasn't actually compromised at all (you were just being cautious): **100% success, $5–$50 in fees, $300 in new hardware, several hours of your time, and a much better wallet architecture going forward.** This is the best outcome and not a wasted effort.

## Practice once on testnet first

Before you run this for real, run the entire sequence once on Bitcoin testnet with worthless coins:

1. Set up a "compromised" testnet wallet on your existing Ledger
2. Get free testnet BTC from a faucet
3. Set up a fresh testnet wallet on your new device
4. Migrate testnet funds following the sequence above
5. Reset the Ledger to a fresh testnet seed afterward
6. Confirm the old testnet wallet now shows 0 and the new one shows the migrated amount

After one successful testnet run, you can do the mainnet migration with confidence. Without practice, the first time you run this *will* be the first time, and stress will compound mistakes. Always practice first.
