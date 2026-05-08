# Frontend Stack and Design System

What `coldwatch`'s UI is built on, why, and how to keep it consistent. Read before adding views, components, or pages.

## Posture — what coldwatch's UI should feel like

A security tool, not a fintech app:

- **Information-dense, not decorative.** UTXOs, balances, addresses, alarms — all need to be scannable at a glance. No splash screens, no marketing copy.
- **Dark by default.** Operators read this at 3 a.m. Dark mode is not a toggle; it's the canonical UI. Light mode comes later.
- **Monochrome with semantic accent.** Greys for chrome and content. Color only signals status:
  - **Green** — settled / healthy / connected
  - **Amber** — unsettled / warning / mempool below threshold
  - **Red** — alarm / outgoing tx detected / connection lost
  - No purples, no gradients, no rainbow charts.
- **Mobile-first.** The dashboard will be checked from your phone. Every page works at 375px wide.
- **Server-rendered, no SPA.** Hotwire + Turbo Frames + Stimulus only. No React, no Vue, no client-side routing.
- **Accessible by default.** Real `<button>` elements, real labels, focus states, keyboard navigation. WCAG AA contrast minimums.

If a design choice violates one of the above, it's wrong. If a design choice doesn't appear above, default to "match Tailwind's conventions and don't invent."

## Stack — what's installed

| Layer | Choice | Why |
|---|---|---|
| HTML rendering | ERB + ViewComponent | ERB for pages; ViewComponent for reusable units (`StatusBadge`, `UtxoRow`, `AddressMonospace`, `AlarmCard`) |
| CSS | Tailwind CSS via `tailwindcss-rails` | Already in Gemfile. Use utility classes; avoid custom CSS files. |
| Interactivity | Hotwire — Turbo + Stimulus | Already in Gemfile. Real-time dashboard updates via Turbo Streams pushed from Sidekiq. |
| Stimulus components | `stimulus-components` (npm or pin via importmap) | For prefab dropdowns, modals, clipboard buttons, tooltips. Don't reinvent. |
| Icons | Lucide via `lucide-rails` gem | Open-source, consistent stroke style, ~1500 icons. Use sparingly. |
| Charts | Chart.js via `chartkick` gem | For the USD-over-time line chart. One line, dark theme, no animation. |
| Fonts | Inter (variable) | Free, modern, optimized for screen reading. Self-hosted via importmap or `@fontsource/inter`. |
| Mono font | JetBrains Mono | For txids, addresses, sat counts. Self-hosted. |

## Gems to add (Day 2/3 when we build the UI)

```ruby
# Component-based views (recommend over plain partials for reusable units)
gem "view_component", "~> 3.20"

# Lucide icon helpers
gem "lucide-rails", "~> 0.5"

# Chart.js wrapper
gem "chartkick", "~> 5.1"

# Optional: live component browser in dev (great for design iteration)
group :development do
  gem "lookbook", "~> 2.3"
end
```

## Component conventions

When building reusable UI:

```
app/components/
├── application_component.rb    # base class
├── status_badge_component.rb
├── status_badge_component.html.erb
├── utxo_row_component.rb
├── utxo_row_component.html.erb
└── ...
```

Rules:

- One component, one concern. `StatusBadgeComponent` shows status. `UtxoRowComponent` shows a single UTXO. Don't combine.
- All Bitcoin-specific formatting goes through helpers (`format_sats`, `format_btc`, `format_usd`, `truncate_address`, `truncate_txid`). Never inline the truncation in markup.
- Components accept primitives or models, not hashes. `UtxoRowComponent.new(utxo: @utxo)`, not `(data: { ... })`.
- Components have visible test coverage (`test/components/`).

## Page layout

```
app/views/layouts/application.html.erb
  ├── <header> — wallet picker + connection status (always visible)
  ├── <nav>    — Dashboard / UTXOs / Transactions / Settings
  ├── <main>   — page content
  └── <footer> — sync status + last block height
```

The header status indicator is the *single* place users learn whether the watcher is alive. It's a small dot + text:

- 🟢 "Watching · synced @ block 879431"
- 🟡 "Reconnecting…"
- 🔴 "DISCONNECTED — alarm offline"

Make this big enough to read across a room.

## Color tokens (Tailwind classes we standardize on)

Use these consistently; don't invent new ones.

| Purpose | Tailwind class |
|---|---|
| Page background | `bg-zinc-950` |
| Card / panel background | `bg-zinc-900` |
| Border | `border-zinc-800` |
| Primary text | `text-zinc-100` |
| Secondary text | `text-zinc-400` |
| Muted / hints | `text-zinc-500` |
| Mono text (addresses, txids) | `font-mono text-zinc-300` |
| Status — healthy | `text-emerald-400` / `bg-emerald-500/10` / `border-emerald-500/30` |
| Status — warning | `text-amber-400` / `bg-amber-500/10` / `border-amber-500/30` |
| Status — alarm | `text-red-400` / `bg-red-500/10` / `border-red-500/30` |
| Interactive primary | `bg-zinc-100 text-zinc-900 hover:bg-white` |
| Interactive secondary | `bg-zinc-800 text-zinc-100 hover:bg-zinc-700` |
| Focus ring | `focus:ring-2 focus:ring-zinc-400 focus:ring-offset-2 focus:ring-offset-zinc-950` |

## Typography scale

| Use | Class |
|---|---|
| Page title | `text-3xl font-semibold tracking-tight` |
| Section header | `text-xl font-semibold` |
| Body | `text-sm` (yes, small — we are dense) |
| Numeric (balance, fee, sats) | `text-4xl font-mono tabular-nums` |
| Caption / metadata | `text-xs text-zinc-500` |

`tabular-nums` for any numeric column (balances, USD values, sats). It keeps digits aligned vertically.

## What NOT to do

- ❌ Don't add a CSS framework component library (no Bootstrap, no Bulma, no DaisyUI on top of Tailwind)
- ❌ Don't add an HTTP client like Axios — use Turbo, fetch, or Stimulus
- ❌ Don't introduce React, Vue, Svelte, or any SPA framework
- ❌ Don't use SVG illustrations or hero graphics
- ❌ Don't animate anything except status transitions (a 200ms color fade on alarm-fired is fine; a 1-second hover bounce is not)
- ❌ Don't add light mode until the dark mode is fully polished

## Reviewing UI work

When a UI change lands, the review checklist:

1. Renders correctly at 375px (iPhone SE) and 1440px (laptop)
2. Keyboard-navigable end-to-end
3. Color contrast meets WCAG AA (Tailwind's defaults usually do)
4. Numeric columns use `tabular-nums`
5. Status colors used semantically (no green for "alarm fired")
6. No new custom CSS files introduced
7. New components have tests in `test/components/`

The OMC `web-design-guidelines` skill can run this review automatically when invoked. The OMC `designer` agent can be invoked for new component design.
