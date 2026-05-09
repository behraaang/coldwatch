# Frontend Stack and Design System

What `coldwatch`'s UI is built on, why, and how to keep it consistent. Read before adding views, components, or pages.

> **Posture revision (2026-05-09):** the v1 dark-monochrome aesthetic was rejected as too generic for the Bitcoin-tooling space. This document now describes the v2 direction: **light, paper-warm, Bitcoin-orange-confident, serif-headlined.**

## Posture — what coldwatch's UI should feel like

The brief is **"colorful and modern but surprising."** For a Bitcoin self-custody tool, *surprising* means rejecting the genre's defaults. Almost every Bitcoin tool — Sparrow, mempool.space, Nunchuk, Specter, BlueWallet, Wasabi — defaults to dark, monospace, austere. Going light + serif + confidently colored is the surprise.

Reference notes (not direct copies, but the vibe):
- **The Information / Stratechery / FT Weekend** — bold serif headlines, generous whitespace, confident editorial color
- **Linear / Vercel** — bento layouts, soft shadows, technical-but-warm
- **Cal.com / Posthog** — friendly accent colors used precisely

What this is NOT:
- Not "fintech app" (no neon gradients, no card stacks)
- Not "dark cyberpunk" (no neon-on-black)
- Not "generic SaaS" (no purples, no blues, no bro-pink)
- Not "playful pastel illustration" (no mascots, no doodles)

## Brand

| Token | Value | When |
|---|---|---|
| **Bitcoin Orange** | `#F7931A` (Tailwind: `orange-500`-ish; we'll define `--brand` exactly) | Logo, primary CTA, key numeric accents, status:warning |
| **Ink** | `#1A1612` (warm near-black) | Body text on light bg, headlines |
| **Paper** | `#FAF7F2` (warm off-white) | Page background |
| **Cream** | `#FFFFFF` (pure white, used sparingly) | Card surfaces that need to lift off paper |
| **Stone** | `#A8A29E` (warm gray) | Secondary text, dividers |
| **Sage** | `#52796F` (muted green) | Status:healthy |
| **Rust** | `#A2402F` (deep red-orange) | Status:alarm. Note: not bright red. Quieter, more serious. |
| **Petrol** | `#1B4D5A` (deep teal) | Information, links, hover-darken on Bitcoin Orange |

These are the *only* colors. No rainbow charts, no gradient fields, no purples or blues that aren't Petrol.

## Typography

Three faces — this is core to the surprising-but-modern feel.

| Use | Family | Weight | Notes |
|---|---|---|---|
| **Display & H1** | **Instrument Serif** (variable) | Regular, italic for emphasis | Bold serifs for page titles. This is the editorial signature. Self-host via @fontsource. |
| **Body & H2-H6** | **Inter** (variable) | 400 (body), 500 (headings), 600 (strong) | Workhorse sans. Keep weight modest — 600 is the cap; no 700+. |
| **Numeric / mono** | **JetBrains Mono** (variable) | 400, 500 | All addresses, txids, sats, USD values, derivation paths |

`tabular-nums` on every numeric column. `font-feature-settings: 'ss01'` on Inter for the alternate single-story `a`.

Sizing:

| Use | Size | Weight |
|---|---|---|
| Page title (`<h1>`) | `text-4xl` (~36px) | Instrument Serif Regular, italic for emphasis ranges |
| Section header (`<h2>`) | `text-xl` | Inter 500 |
| Body | `text-sm` (~14px) | Inter 400 |
| Numeric hero (balance) | `text-5xl` | JetBrains Mono 400, `tabular-nums` |
| Caption / metadata | `text-xs` | Inter 400, `text-stone-500` |

Body is intentionally small — `coldwatch` is information-dense by design.

## Layout

- **Bento grid** — heterogeneous card sizes; each card is one concern (balance, status, recent events, actions)
- **Generous whitespace** — `gap-6` minimum between bento cells; `p-8` on hero cards
- **Cards** — `bg-cream` (`#FFFFFF`) with very soft shadow `shadow-[0_1px_3px_rgba(26,22,18,0.04),0_1px_2px_rgba(26,22,18,0.06)]` and 1px border `border-stone-200/60`
- **No cardless lists** — even tables go inside cards
- **Sticky header** — paper bg, ink text, Bitcoin-orange brand mark. Status indicator on the right (sage / orange / rust dot + label)
- **Asymmetric hero** — page titles can be oversized italic; numeric heroes (balance) can be huge serif on cream

## Iconography

Inline SVG only, no gem dependency. Recommended set: hand-coded matching the [Phosphor "duotone-but-thinner" stroke style — 1.5px stroke, 24×24 viewBox, rounded line caps]. Maximum 6 icons per page.

Icons we use:
- **shield-check** (Bitcoin Orange) — security status
- **eye** (Ink) — wallet, watching
- **arrow-down-left** (Sage) — receive
- **arrow-up-right** (Stone) — change branch (subordinate)
- **alert-triangle** (Rust) — alarm, errors
- **clipboard** (Stone) — copy
- **arrow-clockwise** (Bitcoin Orange) — sync action
- **chevron-right** (Stone) — drill-in

## Motion

Subtle, never decorative.

- Status dot: `animate-pulse` only when *transitioning* (syncing, reconnecting), never when steady-state
- Sync icon button: 200ms `transition-transform` rotate on press
- Card hover: `transition-shadow` lifts the soft shadow slightly (~150ms)
- No bounces, no slides, no parallax

## Accessibility

- WCAG AA contrast minimums on all text. Ink on Paper is ~13:1 — fine. Stone-500 on Paper is ~5:1 — also fine, used only for de-emphasized text.
- All icons have `aria-label` or sit next to text labels
- Focus rings: `ring-2 ring-orange-500/40 ring-offset-2 ring-offset-paper`
- All interactive elements are real `<button>` / `<a>` — never click-handlers on `<div>`

## What this means in Tailwind class terms (cheat sheet)

We'll use Tailwind utilities for the most part with a few custom CSS variables for the exact brand colors that don't map to Tailwind defaults (Bitcoin Orange, Paper, Cream, Ink, Petrol, Rust, Sage). Define them in `app/assets/tailwind/application.css` via `@theme` directives.

Sample patterns:

```html
<!-- Page background -->
<body class="bg-paper text-ink">

<!-- Card -->
<div class="bg-cream border border-stone-200 rounded-xl p-8 shadow-soft">

<!-- Page title (the editorial moment) -->
<h1 class="font-serif text-4xl text-ink leading-tight">
  Your wallets, <em>watched.</em>
</h1>

<!-- Numeric hero -->
<div class="font-mono text-5xl tabular-nums text-ink">0.42<span class="text-stone-500"> BTC</span></div>

<!-- Status dot — synced -->
<span class="h-2 w-2 rounded-full bg-sage"></span>

<!-- Primary CTA -->
<a class="bg-orange-brand text-cream rounded-lg px-5 py-2.5 font-medium hover:bg-orange-brand-darker">

<!-- Mono body (txid, address) -->
<span class="font-mono text-xs text-stone-700">bc1q…</span>
```

## What NOT to do

- ❌ Dark mode (it's the v1 we rejected; do not reintroduce)
- ❌ Gradients (any kind — radial, linear, mesh, glow)
- ❌ Drop-shadows that aren't the soft `shadow-soft`
- ❌ Color outside the brand palette
- ❌ Sans-serif headlines (the serif is the signature)
- ❌ Stock illustrations / mascots
- ❌ Bootstrap / DaisyUI / any UI kit
- ❌ Animation longer than 300ms
- ❌ Multiple typefaces beyond the three above

## Reviewing UI work

When a UI change lands, the review checklist:

1. Renders correctly at 375px (iPhone SE) and 1440px (laptop)
2. Keyboard-navigable end-to-end
3. Color contrast meets WCAG AA (Tailwind defaults usually do)
4. Numeric columns use `tabular-nums`
5. Page titles are Instrument Serif italic for emphasis
6. No new custom CSS files introduced (only the `@theme` block in `application.css`)
7. Status colors used semantically (sage = healthy, orange = warning, rust = alarm)
8. Bitcoin Orange used at most twice per viewport (logo + primary CTA, or balance + sync button — not everywhere)

The OMC `web-design-guidelines` skill can run this review automatically when invoked. The OMC `designer` agent does the design pass.
