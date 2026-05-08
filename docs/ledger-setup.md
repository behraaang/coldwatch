# Finding your xpub on a Ledger

`coldwatch` v1 supports Native SegWit only (BIP84, addresses starting with `bc1q...`). On Ledger, this is the default "Bitcoin" account. If you've used "Bitcoin Legacy" or "Bitcoin Taproot," v1 won't read it; switch the account in Ledger Live or wait for v2.

## Step 1 — Open Ledger Live, plug in your Ledger, unlock with PIN

## Step 2 — Find the account

- Click **Accounts** in the sidebar
- Click your **Bitcoin** account (not "Bitcoin Legacy" or "Bitcoin Taproot")
- Confirm the addresses you've used start with `bc1q...` — that's BIP84

## Step 3 — Export the xpub

Different Ledger Live versions put this in slightly different places. The most reliable path:

- Click the gear icon next to the account name → **Edit account** → **Advanced logs** → look for `xpubOrAddress`

Or, more reliable:

- Click **Receive** to display a receive address
- Click **Advanced** or look for **Show extended public key**
- Confirm the action on your Ledger device when prompted

The string will look like:

```
zpub6rFR7y4Q2AijBEqTUquhVz398htDFrtymD9xYYfG1m4wAcvPhXNfE3EfH1r1ADqtfSdVCToUG868RvUUkgDKf31mGDtKsAYz2oz2AGutZYs
```

That's your xpub. (The `zpub` prefix is the Native SegWit / BIP84 form. `coldwatch` will accept it directly.)

## Step 4 — Treat this string carefully

This string is a permanent privacy compromise if leaked. Anyone who has it can see every address you'll ever use and every transaction forever. They cannot spend.

- Do not paste it into Discord, Telegram, email, or any chat
- Do not paste it into any public form (including the public `demo.coldwatch` instance) unless you understand the privacy implications
- Do not commit it to any git repo (`coldwatch`'s CI guard will catch this, but don't rely on it)

The right place to paste it is **only** your own `coldwatch` personal instance, behind your Caddy IP allowlist + login.

## Step 5 — Set a low gap-limit address-generation discipline

In Ledger Live, when you generate receive addresses, do not click "fresh address" 50 times in a row in a single session. `coldwatch` defaults to a gap limit of 20; if you exceed it, `coldwatch` will warn you and offer a deeper rescan, but the cleanest practice is one fresh receive address per actual receive event.

## Troubleshooting

**"My xpub starts with `xpub` not `zpub`."** That means you're on Legacy (BIP44). Either switch your Ledger account to "Bitcoin" (Native SegWit) for new funds, or wait for `coldwatch` v2 which adds multi-type support.

**"My xpub starts with `ypub`."** That's wrapped SegWit (BIP49). Same answer — switch to Native SegWit for new funds, or wait for v2.

**"Ledger Live doesn't show me an xpub option."** Update Ledger Live to the latest version. The export option moved around in 2024–2025.

**"I'm worried about an evil-maid attack while doing this on my laptop."** Reasonable. The xpub is shown both on the Ledger Live screen and on the device. Compare them carefully. A compromised host could lie to you about what's being exported.
