#!/usr/bin/env bats
# Plain-git verdicts: no pull-request lookups (--no-forge), so these hold on any host.

load helpers

@test "merged with a merge commit -> REMOVE" {
  new_wt feat; push_wt feat; land feat merge
  [ "$(verdict_of feat --no-forge)" = REMOVE ]
  [[ "$(reason_of feat --no-forge)" == merged* ]] || false
}

@test "squash-merged, then main edits the same file -> REMOVE via patch-id" {
  new_wt feat; push_wt feat; land feat squash; main_edits feat.txt
  [ "$(verdict_of feat --no-forge)" = REMOVE ]
  [[ "$(reason_of feat --no-forge)" == squash-merged* ]] || false
}

@test "squash-merged, main untouched since -> REMOVE via content" {
  new_wt feat; push_wt feat; land feat squash
  [ "$(verdict_of feat --no-forge)" = REMOVE ]
  [[ "$(reason_of feat --no-forge)" == "content already in target"* ]] || false
}

@test "rebase-merged (two commits), then main edits the file -> REMOVE via cherry" {
  new_wt feat
  echo more >>"$ROOT/feat/feat.txt"; git -C "$ROOT/feat" commit -qam "second"
  push_wt feat
  main_edits file.txt                      # main moved on, so the rebased commits get new SHAs
  land feat rebase; main_edits feat.txt
  [ "$(verdict_of feat --no-forge)" = REMOVE ]
  [[ "$(reason_of feat --no-forge)" == rebased* ]] || false
}

@test "commits that were never pushed -> KEEP" {
  new_wt feat
  [ "$(verdict_of feat --no-forge)" = KEEP ]
  [[ "$(reason_of feat --no-forge)" == "1 commit(s) exist only here" ]] || false
}

@test "pushed but not merged, no forge -> REVIEW" {
  new_wt feat; push_wt feat
  [ "$(verdict_of feat --no-forge)" = REVIEW ]
}

@test "merged but with a modified tracked file -> KEEP" {
  new_wt feat; push_wt feat; land feat merge
  echo dirty >>"$ROOT/feat/file.txt"
  [ "$(verdict_of feat --no-forge)" = KEEP ]
  [[ "$(reason_of feat --no-forge)" == *uncommitted* ]] || false
}

@test "merged but with an untracked file -> KEEP" {
  new_wt feat; push_wt feat; land feat merge
  echo notes >"$ROOT/feat/notes.md"
  [ "$(verdict_of feat --no-forge)" = KEEP ]
}

@test "merged but with an ignored .env -> KEEP, names the file" {
  new_wt feat; push_wt feat; land feat merge
  echo SECRET=1 >"$ROOT/feat/.env"
  [ "$(verdict_of feat --no-forge)" = KEEP ]
  [[ "$(reason_of feat --no-forge)" == *".env"* ]] || false
}

@test "merged with only ignored node_modules -> REMOVE (disposable)" {
  new_wt feat; push_wt feat; land feat merge
  mkdir -p "$ROOT/feat/node_modules/x" && echo 1 >"$ROOT/feat/node_modules/x/index.js"
  [ "$(verdict_of feat --no-forge)" = REMOVE ]
}

@test "--disposable can declare .env disposable" {
  new_wt feat; push_wt feat; land feat merge
  echo SECRET=1 >"$ROOT/feat/.env"
  [ "$(verdict_of feat --no-forge --disposable .env)" = REMOVE ]
}

@test "locked worktree -> KEEP" {
  new_wt feat; push_wt feat; land feat merge
  git -C "$REPO" worktree lock "$ROOT/feat"
  [ "$(verdict_of feat --no-forge)" = KEEP ]
  [ "$(reason_of feat --no-forge)" = locked ]
}

@test "a process with its cwd inside the worktree -> KEEP" {
  new_wt feat; push_wt feat; land feat merge
  mkdir -p "$ROOT/feat/sub"
  ( cd "$ROOT/feat/sub" && exec sleep 30 ) &
  pid=$!
  sleep 0.5
  v=$(verdict_of feat --no-forge); r=$(reason_of feat --no-forge)
  kill "$pid"
  [ "$v" = KEEP ]
  [[ "$r" == "in use by"* ]] || false
}

@test "folder deleted behind git's back -> PRUNE" {
  new_wt feat
  mv "$ROOT/feat" "$T/moved-away"
  wt status --json --no-forge "$ROOT" | jq -e 'select(.verdict == "PRUNE")' >/dev/null
}

@test "path with spaces is handled" {
  git -C "$REPO" worktree add -q -b spaced "$ROOT/with space" origin/main
  echo x >"$ROOT/with space/x.txt"; git -C "$ROOT/with space" add -A; git -C "$ROOT/with space" commit -qm x
  git -C "$ROOT/with space" push -q origin spaced 2>/dev/null; land spaced merge
  [ "$(verdict_of "with space" --no-forge)" = REMOVE ]
}

@test "fetch fails but the work is already in origin/main -> REMOVE, says remote not refreshed" {
  new_wt feat; push_wt feat; land feat merge
  git -C "$REPO" fetch -q origin
  git -C "$REPO" remote set-url origin "$T/github.com/acme/gone.git"
  [ "$(verdict_of feat --no-forge)" = REMOVE ]
  [[ "$(reason_of feat --no-forge)" == *"remote not refreshed"* ]] || false
}

@test "detached HEAD on a commit already in main -> REMOVE" {
  git -C "$REPO" worktree add -q --detach "$ROOT/review" origin/main
  [ "$(verdict_of review --no-forge)" = REMOVE ]
}

@test "the main worktree is never listed" {
  new_wt feat
  [ "$(wt status --json --no-forge "$ROOT" | jq -s '[.[] | select(.path | endswith("/app"))] | length')" = 0 ]
}

@test "json output is valid, one object per worktree" {
  new_wt a; new_wt b
  [ "$(wt status --json --no-forge "$ROOT" | jq -s length)" = 2 ]
}

@test "a locked worktree whose folder is missing (unplugged drive) -> KEEP, not PRUNE" {
  new_wt feat
  git -C "$REPO" worktree lock --reason "on external drive" "$ROOT/feat"
  mv "$ROOT/feat" "$T/drive-unplugged"
  [ "$(wt status --json --no-forge "$ROOT" | jq -r .verdict)" = KEEP ]
}

@test "a rename whose old path still exists in main is not 'content already in target'" {
  git -C "$REPO" worktree add -q -b mover "$ROOT/mover" origin/main
  git -C "$ROOT/mover" mv file.txt moved.txt; git -C "$ROOT/mover" commit -qm "move"
  git -C "$ROOT/mover" push -q origin mover 2>/dev/null
  # main gains moved.txt with the same content but keeps file.txt: the deletion never landed
  git -C "$REPO" checkout -q main; cp "$REPO/file.txt" "$REPO/moved.txt"
  git -C "$REPO" add -A; git -C "$REPO" commit -qm "copy"; git -C "$REPO" push -q origin main
  [ "$(verdict_of mover --no-forge)" != REMOVE ]
}

@test "--add-disposable extends the default list instead of replacing it" {
  new_wt feat; push_wt feat; land feat merge
  echo SECRET=1 >"$ROOT/feat/.env"; mkdir -p "$ROOT/feat/node_modules" && echo 1 >"$ROOT/feat/node_modules/a.js"
  [ "$(verdict_of feat --no-forge --add-disposable .env)" = REMOVE ]
}

@test "git config worktree-clean.disposable is honoured, on top of the defaults" {
  new_wt feat; push_wt feat; land feat merge
  echo SECRET=1 >"$ROOT/feat/.env"; mkdir -p "$ROOT/feat/node_modules" && echo 1 >"$ROOT/feat/node_modules/a.js"
  git config --global --add worktree-clean.disposable ".env,.tmp"
  [ "$(verdict_of feat --no-forge)" = REMOVE ]
}
