#!/usr/bin/env bats
# remove --discard: worktrees kept only by local files, offered one at a time.

load helpers

# answers y n q ...: the replies the "terminal" gives, in order.
answers() { printf '%s\n' "$@" >"$T/answers"; export GIT_WORKTREE_CLEAN_TTY="$T/answers"; }
no_terminal() { export GIT_WORKTREE_CLEAN_TTY="$T/no-such-terminal"; }

# A pushed branch with a modified tracked file and an untracked note: nothing but local files.
dirty_wt() {
  new_wt "$1"; push_wt "$1"
  echo "edited" >>"$ROOT/$1/file.txt"
  echo "scratch notes" >"$ROOT/$1/notes.md"
}

@test "yes: changes go to the stash, the worktree is removed, the branch is kept" {
  dirty_wt wip
  answers y
  run wt remove --discard --no-forge "$ROOT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"DISCARD?"* ]] || false
  [[ "$output" == *"DISCARDED wip"* ]] || false
  [ ! -e "$ROOT/wip" ]
  git -C "$REPO" rev-parse -q --verify refs/heads/wip >/dev/null
  git -C "$REPO" stash list | grep -q "discarded from .*/projects/wip (wip)"   # git prints the resolved path
  git -C "$REPO" stash show -p 'stash@{0}' | grep -q '^+edited'
  [ "$(git -C "$REPO" show 'stash@{0}^3:notes.md')" = "scratch notes" ]
}

@test "the prompt lists every file that would be lost" {
  dirty_wt wip
  echo SECRET=1 >"$ROOT/wip/.env"
  answers n
  run wt remove --discard --no-forge "$ROOT"
  [[ "$output" == *" M file.txt"* ]] || false
  [[ "$output" == *"?? notes.md"* ]] || false
  [[ "$output" == *"deleted with no copy"*"!! .env"* ]] || false
}

@test "no: the worktree and its files stay, and it is not a failure" {
  dirty_wt wip
  answers n
  run wt remove --discard --no-forge "$ROOT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"KEPT"*"wip"* ]] || false
  [ -f "$ROOT/wip/notes.md" ]
  grep -q edited "$ROOT/wip/file.txt"
  [ -z "$(git -C "$REPO" stash list)" ]
}

@test "without --discard it is only pointed out" {
  dirty_wt wip
  run wt remove --yes --no-forge "$ROOT"
  [ -d "$ROOT/wip" ]
  [[ "$output" == *"remove --discard"* ]] || false
  [ "$(status_of wip --no-forge | jq -r .discardable)" = true ]
}

@test "--yes does not answer for --discard: with no terminal nothing is discarded" {
  new_wt done; push_wt done; land done merge
  dirty_wt wip
  no_terminal
  run wt remove --yes --discard --no-forge "$ROOT"
  [ "$status" -eq 0 ]
  [ ! -e "$ROOT/done" ]                     # the safe removal still happens
  [ -f "$ROOT/wip/notes.md" ]
  [[ "$output" == *"NOT OFFERED"* ]] || false
}

@test "--yes does not answer for --discard: the question is still asked" {
  dirty_wt wip
  answers n
  run wt remove --yes --discard --no-forge "$ROOT"
  [[ "$output" == *"Discard these"* ]] || false
  [ -f "$ROOT/wip/notes.md" ]
}

@test "an open pull request is never offered" {
  dirty_wt wip
  fake_prs "[{\"number\":7,\"headRefName\":\"wip\",\"headRefOid\":\"$(head_of wip)\",\"state\":\"OPEN\",\"isCrossRepository\":false}]"
  answers y
  run wt remove --discard "$ROOT"
  [ -f "$ROOT/wip/notes.md" ]
  [[ "$output" != *"DISCARD?"* ]] || false
  [ "$(status_of wip | jq -r .discardable)" = false ]
}

@test "a merged pull request with leftover files is offered" {
  dirty_wt wip
  fake_prs "[{\"number\":7,\"headRefName\":\"wip\",\"headRefOid\":\"$(head_of wip)\",\"state\":\"MERGED\",\"isCrossRepository\":false}]"
  answers y
  run wt remove --discard "$ROOT"
  [[ "$output" == *"PR #7 merged"* ]] || false
  [ ! -e "$ROOT/wip" ]
}

@test "a pull request lookup that fails is never read as 'no pull request'" {
  dirty_wt wip
  export FAKE_GH_FAIL=1
  answers y
  run wt remove --discard "$ROOT"
  [ -f "$ROOT/wip/notes.md" ]
  [ "$(status_of wip | jq -r .discardable)" = false ]
}

@test "a pull request that opens between the plan and the question is skipped" {
  dirty_wt wip
  export FAKE_GH_FRESH="$T/fresh.json"
  echo "[{\"number\":7,\"headRefName\":\"wip\",\"headRefOid\":\"$(head_of wip)\",\"state\":\"OPEN\",\"isCrossRepository\":false}]" >"$FAKE_GH_FRESH"
  answers y
  run wt remove --discard "$ROOT"
  [[ "$output" == *"SKIP"*"PR #7 is open"* ]] || false
  [ -f "$ROOT/wip/notes.md" ]
}

@test "a detached HEAD with a commit on no remote is never offered" {
  git -C "$REPO" worktree add -q --detach "$ROOT/loose" origin/main
  echo x >"$ROOT/loose/x.txt"; git -C "$ROOT/loose" add -A; git -C "$ROOT/loose" commit -qm "only here"
  echo "scratch" >"$ROOT/loose/notes.md"
  answers y
  run wt remove --discard --no-forge "$ROOT"
  [ -d "$ROOT/loose" ]
  [ "$(status_of loose --no-forge | jq -r .discardable)" = false ]
}

@test "a detached HEAD already on a remote is offered" {
  git -C "$REPO" worktree add -q --detach "$ROOT/review" origin/main
  echo "lockfile churn" >>"$ROOT/review/file.txt"
  answers y
  run wt remove --discard --no-forge "$ROOT"
  [ ! -e "$ROOT/review" ]
}

@test "a branch with commits on no remote is offered, and the branch keeps them" {
  new_wt wip                                 # one commit, never pushed
  echo "scratch" >"$ROOT/wip/notes.md"
  answers y
  run wt remove --discard --no-forge "$ROOT"
  [[ "$output" == *"1 commit(s) that are on no remote"* ]] || false
  [ ! -e "$ROOT/wip" ]
  [ "$(git -C "$REPO" log -1 --format=%s wip)" = "work on wip" ]
}

@test "only ignored files: offered, listed, deleted, and nothing is stashed" {
  new_wt wip; push_wt wip
  echo SECRET=1 >"$ROOT/wip/.env"
  answers y
  run wt remove --discard --no-forge "$ROOT"
  [[ "$output" == *"!! .env"* ]] || false
  [ ! -e "$ROOT/wip" ]
  [ -z "$(git -C "$REPO" stash list)" ]
}

@test "a worktree in use is never offered" {
  dirty_wt wip
  ( cd "$ROOT/wip" && exec sleep 30 ) 3>&- &
  pid=$!
  sleep 0.5
  answers y
  run wt remove --discard --no-forge "$ROOT"
  kill "$pid"
  [ -f "$ROOT/wip/notes.md" ]
  [[ "$output" != *"DISCARD?"* ]] || false
}

@test "q stops asking and leaves the rest alone" {
  dirty_wt one; dirty_wt two
  answers q
  run wt remove --discard --no-forge "$ROOT"
  [ "$status" -eq 0 ]
  [ -d "$ROOT/one" ] && [ -d "$ROOT/two" ]
  [ "$(grep -c "DISCARD?" <<<"$output")" -eq 1 ]
}

@test "files that change while you decide are not discarded" {
  dirty_wt wip
  mkfifo "$T/tty"
  exec 8<>"$T/tty"                          # held open, so opening it to read never blocks
  export GIT_WORKTREE_CLEAN_TTY="$T/tty"
  wt remove --discard --no-forge "$ROOT" >"$T/out" 2>&1 3>&- &
  pid=$!
  for _ in $(seq 1 100); do grep -q "Discard these" "$T/out" && break; sleep 0.1; done
  echo "written after the question" >"$ROOT/wip/late.txt"
  echo y >&8
  wait "$pid"
  exec 8>&-
  grep -q "changed while you were deciding" "$T/out"
  [ -f "$ROOT/wip/late.txt" ] && [ -f "$ROOT/wip/notes.md" ]
  [ -z "$(git -C "$REPO" stash list)" ]
}

@test "--discard is for remove only" {
  run wt status --discard "$ROOT"
  [ "$status" -eq 2 ]
}
