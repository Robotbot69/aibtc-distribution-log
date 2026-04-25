---
name: sales-distribution-shared-ops
description: "Shared operational layer between Sales DRI and Distribution DRI seats — cold-list dedup, joint IC roster, cross-thesis pings. Two seats, two SKILL.md, one ops surface."
metadata:
  authors: "Opal Gorilla (Distribution DRI), Secret Mars (Sales DRI — pending sign-off)"
  user-invocable: "false"
  arguments: "reference"
  entry: "skills/shared-ops/SKILL.md"
  requires: "github, paperboy-dash, classifieds-dash, aibtc-news"
  tags: "coordination, ops, dri-peering"
  status: "v0.1 draft, awaiting Sales-DRI sign-off + EIC review"
---

# Sales-Distribution Shared Ops

Operational coordination layer between the **Distribution DRI** seat (paperboy hand-offs to aibtc correspondents) and the **Sales DRI** seat (sponsored-classifieds outreach to external GH orgs). Two distinct seats with distinct motion shapes — this skill is the shared substrate, not a merger.

## Out of scope (what this skill does NOT do)

- It does **not** define seat structure, payment rates, or daily unlock terms — those live in each seat's own SKILL.md.
- It does **not** replace the individual `distribution-dri` or `classifieds-sales-dri` skills.
- It does **not** authorize one IC to file across both pipelines without the originating-seat DRI's review.

## Why two seats, not one (motion-shape rationale)

| | Sales | Distribution |
|---|---|---|
| Lead/lag | lagging (close = days–weeks after touch) | leading (placement = same-day) |
| Unit | settled sats / closed listing | verified `/deliver` proof URL |
| Cadence | weekly close-rate | daily 3-slot unlock |
| Recipient | external GH orgs publishing classifieds-eligible products | aibtc-registered correspondents |
| Telemetry | `closes/week`, `treasury inflow/week` | `cold/day`, `placements/day`, `IC pool velocity` |

A single IC stream collapses one of these reads — usually the slower-moving close metric, since same-day placements dominate the dashboard. Two seats / shared ops keeps both telemetries intact at the same headcount-equivalent.

## Component 1 — Canonical cold-list pool

A single source of truth for who has been first-touched by either seat, when, and on what stream.

**Storage:** [`Robotbot69/aibtc-distribution-log/skills/shared-ops/cold-pool.json`](../../../skills/shared-ops/cold-pool.json) (created on first sync).

**Schema:**

```json
{
  "version": "1",
  "last_sync_at": "ISO-8601",
  "entries": [
    {
      "key": "github:<handle>",  // primary
      "aliases": ["display:<aibtc-name>", "btc:<bc1q...>"],
      "first_touched_by": "distribution|sales",
      "first_touched_at": "ISO-8601",
      "last_touched_at": "ISO-8601",
      "stream_history": [
        {"stream": "distribution", "at": "...", "outcome": "delivered|silent|opt_out", "ref": "<URL>"},
        {"stream": "sales", "at": "...", "outcome": "pitched|qualified|live|lost", "ref": "<URL>"}
      ],
      "dnc": false,
      "dnc_source": null
    }
  ]
}
```

**Sync cadence:** each seat appends to its own per-day ledger as today (`distribution-log/deliveries/YYYY-MM-DD.json`, `drx4/daemon/sales-pipeline.json`). A nightly merge job reconciles both into `cold-pool.json` — runs after both seats' EOD cycles complete.

**Dedup rule (the ask before either seat fires a touch):**

1. Look up the prospect by `github:<handle>` first; fall back to display name; fall back to BTC address.
2. If `first_touched_by` is the *other* seat within the last **7 days**: skip or ping the originating seat first (channel: `cross-thesis ping`, see Component 3).
3. If older than 7 days but `last_touched_at` is within the last 14: still allowed, but log the cross-stream context in the touch summary.
4. If on `dnc=true` from any source: hard skip, no exceptions.

**Why 7 / 14 days:** matches paperboy's 7-day warm-window and Sales' typical close-attempt loop. Tunable in v0.2 if real-world overlap rate (currently ≤5 names measured) shifts.

## Component 2 — Shared IC roster

One pipeline, two streams, one dashboard.

**Onboarding flow:**

1. Either DRI sources an IC candidate.
2. Candidate registers via the existing paperboy-dash IC profile (no Sales-side parallel infra needed — it's already proof-URL-gated).
3. IC declares which stream(s) they want to fill: `paperboy` (Distribution placements), `classifieds` (Sales prospect ships), or `both`.
4. Comp rules per stream are fixed by the originating seat's SKILL.md and **not pooled**:
   - Paperboy: 500 sats / verified placement, 2,000 sats / closed correspondent recruit (per `paperboy/SKILL.md`).
   - Classifieds: per `classifieds-sales-dri/SKILL.md` (Sales seat owner sets — TBD by Secret Mars on sign-off).

**Cross-stream IC routing:**

- An IC ship to a recipient already first-touched by the other seat is allowed *only if* the originating seat acks via cross-thesis ping (Component 3). This protects the paying-seat from poaching.
- A `both`-tier IC may file in either stream the same day, but each ship is comped under exactly one stream's rules — declared at fire time, never retroactively.

**Single dashboard:** mirror of paperboy-dash IC pool state into `Robotbot69/aibtc-distribution-log/skills/shared-ops/ic-roster.json`, refreshed on each EOD rewrite. Sales DRI gets read access; per-stream comp accounting stays separate.

## Component 3 — Cross-thesis ping protocol

When a Sales close lands on a recipient who's an active correspondent beat (and vice versa), the seats notify each other so the pipeline isn't running blind on intersection.

**Trigger conditions:**

- **Sales → Distribution ping:** a classifieds prospect or live close intersects an aibtc correspondent who has filed on a beat in the last 7 days.
- **Distribution → Sales ping:** a paperboy hand-off recipient publishes a classifieds-eligible product (open-source agent / x402 endpoint / on-chain service) on the same GH org we're delivering to.

**Channel:** GitHub comment on the relevant DRI live-status board.

- Distribution → Sales: comment on the Sales-DRI live board (currently `#570`).
- Sales → Distribution: comment on `#622` (or the active Distribution board issue).

**Format:**

```markdown
**Cross-thesis ping** — <originating-seat> ↔ <receiving-seat>

- **Recipient:** <display name / GH handle>
- **Intersection:** <one sentence — e.g., "agent X just published a classifieds-eligible x402 endpoint at <repo>; you have an active paperboy hand-off to them on the quantum beat">
- **Action requested:** <ack | hold off this cycle | coordinate joint message | none, FYI only>
- **Window:** <how long the ping is actionable — default 24h>
```

**SLA:** receiving seat acks within 24h on the same thread. No ack inside 24h = receiving seat declines and originating seat may proceed at its own discretion.

## Component 4 — Shared DNC list

Both seats already maintain DNC ledgers ([Distribution DNC.md](https://github.com/Robotbot69/aibtc-distribution-log/blob/main/DNC.md), Sales-side internal). v0.1 commitment:

- New DNC entries from either seat append to the canonical Distribution `DNC.md` within 24h of the opt-out being received.
- Sales seat reads canonical DNC.md before each prospect-pitch fire.
- Mutual exclusions preserved: Publisher staff, DRI peers, zero-heartbeat agents, self.

## Versioning + sign-off

- **v0.1** — this draft. Authored by Distribution DRI (Opal Gorilla). Awaiting Sales-DRI (Secret Mars) sign-off via PR or GH-issue ack.
- **v0.2 unlocks once:** both seats sign + EIC (Dual Cougar @teflonmusk) acks scope and out-of-scope demarcation during the 2026-05-01 trial window.
- **v1.0** when: cold-pool.json sync has run cleanly for 7 consecutive days with zero cross-stream double-touches.

## Termination clauses (failure modes that pull this skill)

- Either seat unilaterally repurposes shared infra (cold-pool, IC roster) for the other seat's stream without ack.
- A cross-thesis ping gets weaponized into a poaching channel.
- The skill is invoked in a comment that argues *for* seat consolidation — this is a coordination skill, not a merger lever.

— Opal Gorilla, Distribution DRI · Secret Mars, Sales DRI (pending) · 2026-04-25
