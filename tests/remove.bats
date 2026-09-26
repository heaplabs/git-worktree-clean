#!/usr/bin/env bats
# The remove command: acts only on REMOVE/PRUNE rows, re-checks, reports space.

load helpers

@test "remove --yes removes finished worktrees and leaves the rest" {
  new_wt done; push_wt done; land done merge
  mkdir -p "$ROOT/done/node_modules" && echo 1 >"$ROOT/done/node_modules/a.js"
  new_wt wip
  run wt remove --yes --no-forge "$ROOT"
  [ "$status" -eq 0 ]
  [ ! -e "$ROOT/done" ]
  [ -d "$ROOT/wip" ]
  [[ "$output" == *"REMOVED done"* ]]
  [[ "$output" == *"freed:"* ]]
  git -C "$REPO" rev-parse -q --verify refs/heads/done >/dev/null   # branch kept by default
}

@test "--delete-branches deletes the local branch" {
  new_wt done; push_wt done; land done squash
  run wt remove --yes --delete-branches --no-forge "$ROOT"
  [ "$status" -eq 0 ]
  ! git -C "$REPO" rev-parse -q --verify refs/heads/done >/dev/null
}

@test "without --yes and without a terminal, nothing is removed" {
  new_wt done; push_wt done; land done merge
  run wt remove --no-forge "$ROOT" </dev/null
  [ "$status" -eq 1 ]
  [[ "$output" == *"Aborted"* ]]
  [ -d "$ROOT/done" ]
}

@test "stale registration is pruned" {
  new_wt gone
  mv "$ROOT/gone" "$T/elsewhere"
  run wt remove --yes --no-forge "$ROOT"
  [ "$status" -eq 0 ]
  [[ "$output" == *PRUNED* ]]
  ! git -C "$REPO" worktree list --porcelain | grep -q "$ROOT/gone"
}

@test "a PR that reopened between plan and removal is skipped" {
  new_wt feat; push_wt feat
  git -C "$REPO" checkout -q main
  echo "feat plus review fixups" >"$REPO/feat.txt"
  git -C "$REPO" add -A; git -C "$REPO" commit -qm "squash with fixups"; git -C "$REPO" push -q origin main
  h=$(head_of feat)
  fake_prs "[{\"number\":7,\"headRefName\":\"feat\",\"headRefOid\":\"$h\",\"state\":\"MERGED\",\"isCrossRepository\":false}]"
  export FAKE_GH_FRESH="$T/fresh.json"
  echo "[{\"number\":7,\"headRefName\":\"feat\",\"headRefOid\":\"$h\",\"state\":\"OPEN\",\"isCrossRepository\":false}]" >"$FAKE_GH_FRESH"
  run wt remove --yes "$ROOT"
  [[ "$output" == *"SKIP"*"now KEEP"* ]]
  [ -d "$ROOT/feat" ]
}

@test "nothing to do exits 0" {
  new_wt wip
  run wt remove --yes --no-forge "$ROOT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Nothing is safe to remove"* ]]
}

@test "bad usage exits 2" {
  run wt frobnicate
  [ "$status" -eq 2 ]
  run wt remove --json
  [ "$status" -eq 2 ]
}
