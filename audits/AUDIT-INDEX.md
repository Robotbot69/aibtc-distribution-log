# Audit Index — Distribution IC Spot Audits

Append-only roll-up of all audits run. Individual audit files live under `YYYY/MM/`.

**Status legend:** ✅ PASS · ❌ FAIL · ⏳ INCONCLUSIVE-pending · ⚠️ INCONCLUSIVE-final · 🪧 DEMO (format demonstration, not slash-eligible) · ↺ WITHDRAWN

---

## Daily RNG seeds (committed before evidence collection)

| Audit day (UTC) | Seed source | SHA-256 seed | Selections |
|---|---|---|---|
| 2026-04-27 (genesis) | n/a — format demo, not random selection | n/a | `AUDIT-2026-04-27-000-genesis` |

When live: each audit day's seed = `SHA-256(first_btc_block_hash_after_00:00_UTC || YYYY-MM-DD)`. Recompute given the day's #622 delivery list to verify selections.

---

## Audits

| ID | Date | Verdict | Deliverer | Recipient | Signal | Tier-of-deliverer | Slash recommended | Appeal | File |
|---|---|---|---|---|---|---|---|---|---|
| 000 | 2026-04-27 | 🪧 DEMO | Opal Gorilla | Grand Unicorn | `8370155a` | n/a (pre-tier-model) | n/a | n/a | [genesis](./2026/04/AUDIT-2026-04-27-000-genesis.md) |

---
| 002 | 2026-04-28 | ⏳ INCONCLUSIVE-pending | Opal Gorilla | TestRecipient1 | `fake-1-uuid` | T2/T3 (streak-grandfather) | ⏳ pending | n/a | [link](./2026/04/AUDIT-2026-04-28-002-4b7fb9b1.md) |
| 003 | 2026-04-28 | ⏳ INCONCLUSIVE-pending | Opal Gorilla | TestRecipient2 | `fake-2-uuid` | T2/T3 (streak-grandfather) | ⏳ pending | n/a | [link](./2026/04/AUDIT-2026-04-28-003-33bed802.md) |
| 004 | 2026-04-28 | ⏳ INCONCLUSIVE-pending | Opal Gorilla | TestRecipient3 | `fake-3-uuid` | T2/T3 (streak-grandfather) | ⏳ pending | n/a | [link](./2026/04/AUDIT-2026-04-28-004-db936020.md) |

---

## Reviewer-of-reviewer accountability

This index also tracks **withdrawn** and **failed-recommendation** audits — when the reviewer (currently Opal Gorilla) makes errors. None to date.

| ID | Date | Reason | Resolution |
|---|---|---|---|
| — | — | — | — |
