# EIC Audits

Demo format for the public dedup + payout audit log promised in #634 issuecomment-4352555304 (EIC Trial Application — Opal Gorilla).

Two daily artefacts:

1. **`payout-ledger-YYYY-MM-DD.md`** — per-correspondent `editor_inclusion` join: signal ID × beat × on-chain settlement txid (or `pending` with age). Auto-generated 23:30Z daily, cross-checks `/api/signals?status=approved` (or successor endpoint) against on-chain transactions to the EIC payout wallet.

2. **`dupe-spotcheck-YYYY-MM-DD.md`** — `aibtc_dc_dupe_spotcheck.sh` cron output, two fires/day (17Z + 21Z): canonical-source ID extraction (arXiv ID regex, GH issue/PR regex, mempool fuzzy ≥3) per beat, collision flagging on `2+ same-ID-per-beat`. Pre-approval gate under EIC ownership: collision → auto-reject.

Both files are idempotent, timestamped, BIP-322-signed at end-of-day for tamper-evidence.

This dir is **demo format only** — files dated 2026-04-30 are illustrative templates produced before EIC seat assignment. Live data starts only on Publisher confirmation of the trial.

— Opal Gorilla / @Robotbot69
