#!/usr/bin/env bash
# sync-cold-pool.sh — Sales-side daily merge into canonical cold-pool.json.
#
# Per Sales-Distribution Shared Ops v0.1 Component 1
# (https://github.com/aibtcdev/agent-news/issues/650). Run on Sales DRI's
# 23:00Z EOD cycle. Append-only, earlier-timestamp-wins on collision.
#
# Reads:  daemon/sales-pipeline.json from secret-mars/drx4 (raw via curl)
# Writes: skills/shared-ops/cold-pool.json (this repo, via PR)
#
# Usage (intended cadence: daily 23:00Z, invoked by Sales-side EOD cycle):
#   bash skills/shared-ops/sync-cold-pool.sh
#
# Invariants (per Opal's #650-4320256310 ack):
# 1. Append-only — never overwrite first_touched_by / first_touched_at if the
#    pre-existing entry has an earlier first_touched_at. Newer hits append to
#    stream_history[], not headline fields.
# 2. Earlier timestamp wins on cross-stream collision (not seat-of-PR). Keeps
#    "who touched first" honest across cross-repo clock skew.
# 3. Commit message format: "cold-pool: sales sync YYYY-MM-DD (N new, M updated)"
#    so `git log --grep "sales sync"` is the per-day audit trail.
# 4. DNC entries with stage matching ^lost-deleted-by-recipient$ |
#    ^lost-renewal-silent$ are flagged dnc=true; others remain dnc=false.

set -euo pipefail

cd "$(dirname "$0")/../.."

SALES_PIPELINE_URL="https://raw.githubusercontent.com/secret-mars/drx4/main/daemon/sales-pipeline.json"
COLD_POOL="skills/shared-ops/cold-pool.json"
TODAY=$(date -u +%Y-%m-%d)

# Fetch Sales-side pipeline
sales_pipeline=$(curl -fsS --max-time 15 "$SALES_PIPELINE_URL" 2>/dev/null) || {
  echo "ERROR: could not fetch Sales pipeline at $SALES_PIPELINE_URL" >&2
  exit 1
}

# Initialize cold-pool.json if it doesn't exist (first run)
if [[ ! -f "$COLD_POOL" ]]; then
  echo '{"version":"1","last_sync_at":null,"entries":[]}' > "$COLD_POOL"
fi

# Build merge plan: extract Sales prospects with a touch timestamp + GH handle
sales_entries=$(echo "$sales_pipeline" | jq '
  [.prospects[]
    | select(.touches != null and (.touches | length > 0))
    | select(.repo // "" | test("/"))
    | {
        gh_handle: ((.repo // "" | split("/"))[0]),
        first_touched_at: ((.touches | map(.at // .ts) | min) // .last_touch_at),
        last_touched_at: (.last_touch_at // (.touches | map(.at // .ts) | max)),
        outcome: (
          if .stage == "closed" or .stage == "posted" then "live"
          elif .stage == "closed_pending_publish" then "pending"
          elif (.stage | startswith("lost")) then .stage
          elif (.stage | startswith("pitched")) then "pitched"
          else .stage end
        ),
        ref: (.last_touch_url // (.touches | map(.proof_url // .url) | first) // null),
        dnc: (.stage == "lost-deleted-by-recipient" or .stage == "lost-renewal-silent"),
        dnc_source: (if .stage == "lost-deleted-by-recipient" or .stage == "lost-renewal-silent" then "sales:" + .id else null end)
      }
    | select(.first_touched_at != null)
  ]
')

# Apply merge (append-only, earlier-timestamp-wins) into cold-pool.json
new_pool=$(jq --argjson new "$sales_entries" --arg today "${TODAY}T23:00:00Z" '
  . as $existing |
  ($existing.entries // []) as $entries |
  reduce $new[] as $n (
    {pool: $entries, n_new: 0, n_updated: 0};
    .pool as $p |
    ($p | map(.key == "github:" + $n.gh_handle) | index(true)) as $idx |
    if $idx == null then
      .pool += [{
        key: ("github:" + $n.gh_handle),
        aliases: [],
        first_touched_by: "sales",
        first_touched_at: $n.first_touched_at,
        last_touched_at: $n.last_touched_at,
        stream_history: [{stream: "sales", at: $n.last_touched_at, outcome: $n.outcome, ref: $n.ref}],
        dnc: $n.dnc,
        dnc_source: $n.dnc_source
      }]
      | .n_new += 1
    else
      .pool[$idx] |= (
        .last_touched_at = ($n.last_touched_at // .last_touched_at)
        | .stream_history += [{stream: "sales", at: $n.last_touched_at, outcome: $n.outcome, ref: $n.ref}]
        # earlier-timestamp-wins on first_touched_at
        | if $n.first_touched_at < .first_touched_at then
            .first_touched_at = $n.first_touched_at | .first_touched_by = "sales"
          else . end
        # DNC is sticky once true
        | .dnc = (.dnc or $n.dnc)
        | .dnc_source = (.dnc_source // $n.dnc_source)
      )
      | .n_updated += 1
    end
  ) |
  {
    version: "1",
    last_sync_at: $today,
    entries: .pool,
    _audit: {sales_n_new: .n_new, sales_n_updated: .n_updated}
  }
' "$COLD_POOL")

echo "$new_pool" | jq '.' > "$COLD_POOL"

# Commit message format per Opal's invariant
n_new=$(echo "$new_pool" | jq -r '._audit.sales_n_new')
n_updated=$(echo "$new_pool" | jq -r '._audit.sales_n_updated')
COMMIT_MSG="cold-pool: sales sync ${TODAY} (${n_new} new, ${n_updated} updated)"

echo ""
echo "=== Sales sync complete ==="
echo "  New entries:     $n_new"
echo "  Updated entries: $n_updated"
echo "  Commit message:  $COMMIT_MSG"
echo ""
echo "To commit:"
echo "  git add $COLD_POOL"
echo "  git commit -m '$COMMIT_MSG'"
