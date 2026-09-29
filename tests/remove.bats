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
  [[ "$output" == *"REMOVED done"* ]] || false
  [[ "$output" == *"freed:"* ]] || false
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
  [[ "$output" == *"Aborted"* ]] || false
  [ -d "$ROOT/done" ]
}

@test "stale registration is pruned" {
  new_wt gone
  mv "$ROOT/gone" "$T/elsewhere"
  run wt remove --yes --no-forge "$ROOT"
  [ "$status" -eq 0 ]
  [[ "$output" == *PRUNED* ]] || false
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
  [[ "$output" == *"SKIP"*"now KEEP"* ]] || false
  [ -d "$ROOT/feat" ]
}

@test "nothing to do exits 0" {
  new_wt wip
  run wt remove --yes --no-forge "$ROOT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Nothing is safe to remove"* ]] || false
}

@test "bad usage exits 2" {
  run wt frobnicate
  [ "$status" -eq 2 ]
  run wt remove --json
  [ "$status" -eq 2 ]
}

@test "a shell that opens in a worktree after the plan is seen before removal" {
  new_wt a1; push_wt a1; land a1 merge
  new_wt b2; push_wt b2; land b2 merge
  # Whichever is removed first starts a shell inside the other during its re-check.
  export FAKE_GH_SPAWN_a1="$ROOT/b2" FAKE_GH_SPAWN_b2="$ROOT/a1" FAKE_GH_SPAWN_PIDFILE="$T/spawn.pid"
  run wt remove --yes "$ROOT"
  kill "$(cat "$T/spawn.pid")" 2>/dev/null || true
  [[ "$output" == *"SKIP"*"in use by"* ]] || false
  [ -d "$ROOT/a1" ] || [ -d "$ROOT/b2" ]
}

@test "a linked worktree that sorts before the main one does not become the repo's home" {
  git -C "$REPO" worktree add -q -b early "$ROOT/0-early" origin/main
  echo e >"$ROOT/0-early/e.txt"; git -C "$ROOT/0-early" add -A; git -C "$ROOT/0-early" commit -qm e
  git -C "$ROOT/0-early" push -q origin early 2>/dev/null; land early merge
  new_wt late; push_wt late; land late merge
  run wt remove --yes --no-forge "$ROOT"
  [ "$status" -eq 0 ]
  [ ! -e "$ROOT/0-early" ] && [ ! -e "$ROOT/late" ]
}
