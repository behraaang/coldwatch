# Runbook — your phone just buzzed

This is a decision tree. Do not read it for the first time during an actual emergency. Read it now, set it up now, and only re-read it when the alarm fires.

## Prerequisite — set this up *before* the alarm ever fires

You need a **second hardware wallet** with a **separate seed phrase** stored at a **separate physical location**. Without it, you have nowhere safe to send the funds during the fight-back window — any address derived from your compromised seed is also compromised.

Minimum viable setup:

| Tier | Setup | Cost |
|---|---|---|
| **Acceptable** | A second Ledger or BitBox or Coldcard with a fresh seed, kept at home in a different drawer | ~$80–$150 |
| **Better** | A second hardware wallet from a *different vendor* with a fresh seed, kept at a different physical address (e.g. parents' house, safety deposit box) | Same hardware, different storage |
| **Best** | Above, plus a *third* "deep cold" wallet that holds the bulk while the panic-destination holds nothing routinely | Same plus location |

**Bookmark or print** the receive address from your panic destination wallet. Stick it on the inside of a notebook, on your fridge, in your password manager — somewhere you can find it in 30 seconds at 3 a.m. with shaking hands.

## The alarm

Push reads roughly:

```
⚠ coldwatch: outgoing tx 0.42 BTC detected
txid: abc123...
fee: 8 sat/vB · 0 confs
mempool: https://mempool.space/tx/abc123
```

## Decision tree

### Is this transaction yours?

**You initiated it.** (You're at your desk, you just clicked "send" in Sparrow, this is the confirmation push.)

→ Open the dashboard, mark the alert as "expected." Move on. **End.**

**You did not initiate it.** (You were asleep / at work / on vacation / haven't touched your wallet in months.)

→ Continue below. **You have ~10 minutes before this transaction confirms. Move now.**

### Step 1 — Verify (90 seconds maximum)

1. Open the mempool link from the push. Confirm a real outgoing transaction exists.
2. Verify the inputs are from your addresses (the dashboard will tell you which).
3. Verify the destination is **not** an address you control. (If it is — false alarm. End.)

If steps 1–3 confirm a real theft: continue. The clock is running.

### Step 2 — Get to your hardware wallet (60 seconds)

You need:

- Your *original* hardware wallet (the compromised one — you'll use it to sign the rescue tx, since it has the keys to the UTXOs being stolen)
- A laptop with Sparrow Wallet installed
- The receive address from your *panic destination* wallet (the second one)
- The seed PIN for the original wallet

If you cannot physically reach the original hardware wallet within ~5 minutes, you cannot win the race. **Skip to Step 5 (the loss playbook).**

### Step 3 — Build the replacement transaction (3 minutes)

In Sparrow Wallet, with your original Ledger connected:

1. **File → Import Wallet** (if not already loaded). Use the same xpub `coldwatch` is watching.
2. **Send tab.** Set destination to your panic-destination receive address.
3. **Manually select the same UTXOs** the attacker is spending. (Sparrow shows your UTXOs; the attacker's tx, visible on mempool.space, lists the inputs by txid:vout. Match them.)
4. **Set the fee to 2–3× the attacker's fee.** The push told you their fee in sat/vB. If they used 8, you use 24. Sparrow will show estimated confirm time — aim for "next block."
5. **Enable RBF** if Sparrow doesn't enable it by default (Settings → Advanced → "Enable RBF").
6. **Sign on the Ledger.** The device screen will show the destination address. **Verify it is your panic destination, not anywhere else.** (A compromised host could try to swap. The device screen is the source of truth.)
7. **Broadcast.**

### Step 4 — Watch the race (5–10 minutes)

Open mempool.space. You'll see two transactions spending the same UTXOs. Miners pick the one with the higher fee.

- **Your tx confirms first** → you won. Funds are on the panic destination. Skip to Step 6.
- **Attacker fee-bumps** → they have the same keys, this is possible. Bump again — re-broadcast yours at 1.5× their new fee. You may go through 2–3 rounds. Each round costs you ~15 minutes of stress and a small fee increase.
- **Attacker tx confirms first** → you lost. Go to Step 5.

### Step 5 — The loss playbook

If the attacker won the race, the funds are gone. The alarm still bought you something:

1. **Document everything immediately** — screenshots of the mempool tx, the dashboard, the alarm push, timestamps. You'll need this for police, insurance, and any tax loss reporting.
2. **Notify any exchange where you have related accounts** — same email, same KYC, same patterns. Attackers often try to cash out via accounts they suspect are linked.
3. **Move any other funds you control** that share patterns with the compromised wallet (same email reuse, same physical device, etc.) to a fresh wallet on a fresh device.
4. **File a police report.** US: IC3.gov for the federal record; local PD for the local record.
5. **Contact your insurance** if you have crypto coverage. Most don't, but check.
6. **Tell your CPA.** Theft losses have specific tax treatment (and limitations) in the US. Don't try to figure this out alone.
7. **Identify the attack vector** — phishing email, supply-chain device, malware, physical access. Until you know how, you can't fully recover.

### Step 6 — Aftermath, even if you won

A win means the attacker still has your seed. The current cold wallet is *burned*. You must:

1. **Set up a new wallet on a new device** with a new seed (the device that received the panic transfer is the new wallet *if you're confident it wasn't also compromised*; otherwise a third device).
2. **Move everything from the panic destination to the new wallet** within 24 hours, in case the attacker also discovers the panic destination.
3. **Update `coldwatch`** with the new xpub. Delete the old wallet.
4. **Identify the attack vector before reusing any related infrastructure.** Don't restore a backup, don't reinstall on the same machine, don't use the same email.
5. **Consider professional help** for the forensics. CipherTrace, Chainalysis, and various incident-response firms exist for exactly this.

## What this runbook depends on

- You have a panic-destination wallet ready *before* the alarm. (See top of doc.)
- You can physically reach your original hardware wallet within ~5 minutes.
- You have Sparrow Wallet installed and have used it before. (Practice on testnet at least once. Seriously.)
- Your home network and laptop are not also compromised. (If you're worried they are — use a different device.)

## Practice once on testnet

The single most useful thing you can do with this document is run through it on testnet. Send yourself a testnet outbound, watch the alarm fire, build a replacement, win the race against yourself. The next time the alarm fires for real, you've already done this. Muscle memory matters more than reading.

## What this runbook honestly cannot give you

- Speed against a scripted attacker — they may fee-bump faster than you can sign on a hardware wallet
- Recovery from a deeply compromised network — if your laptop's RPC traffic is being intercepted, your replacement tx may never reach the mempool
- Calm — the first time the alarm fires (real or false), you will panic. The runbook is a substitute for thinking under stress, not a substitute for preparation

The honest expected outcome: **~50% win rate against a smash-and-grab amateur, much lower against a sophisticated targeted attacker, but the alarm always buys you the documentation and notification window even on a loss.** That window has real value.
