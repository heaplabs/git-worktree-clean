#!/usr/bin/env bats
# Pull-request verdicts against the fake gh in tests/bin.

load helpers

# A branch whose merge on GitHub included changes that never reached this worktree,
# so plain git cannot prove it landed and only the pull request can.
diverged_squash() {
  new_wt feat; push_wt feat
  git -C "$REPO" checkout -q main
  echo "feat plus review fixups" >"$REPO/feat.txt"
  git -C "$REPO" add -A; git -C "$REPO" commit -qm "squash feat with fixups"
  git -C "$REPO" push -q origin main
}

@test "open PR -> KEEP, even when the content is already merged" {
  new_wt feat; push_wt feat; land feat merge
  fake_prs "[{\"number\":7,\"headRefName\":\"feat\",\"headRefOid\":\"$(head_of feat)\",\"state\":\"OPEN\",\"isCrossRepository\":false}]"
  [ "$(verdict_of feat)" = KEEP ]
  [ "$(reason_of feat)" = "PR #7 is open" ]
}

@test "PR merged at exactly HEAD -> REMOVE, when plain git cannot prove it" {
  diverged_squash
  [ "$(verdict_of feat --no-forge)" = REVIEW ]
  fake_prs "[{\"number\":7,\"headRefName\":\"feat\",\"headRefOid\":\"$(head_of feat)\",\"state\":\"MERGED\",\"isCrossRepository\":false}]"
  [ "$(verdict_of feat)" = REMOVE ]
  [ "$(reason_of feat)" = "PR #7 merged" ]
}

@test "PR merged, but a commit was made here afterwards -> KEEP" {
  diverged_squash
  merged_at=$(head_of feat)
  echo after >>"$ROOT/feat/feat.txt"; git -C "$ROOT/feat" commit -qam "after merge"
  fake_prs "[{\"number\":7,\"headRefName\":\"feat\",\"headRefOid\":\"$merged_at\",\"state\":\"MERGED\",\"isCrossRepository\":false}]"
  [ "$(verdict_of feat)" = KEEP ]
  [[ "$(reason_of feat)" == *"made after PR #7"* ]] || false
}

@test "a fork's merged PR with the same branch name is ignored" {
  diverged_squash
  fake_prs "[{\"number\":9,\"headRefName\":\"feat\",\"headRefOid\":\"$(head_of feat)\",\"state\":\"MERGED\",\"isCrossRepository\":true}]"
  [ "$(verdict_of feat)" = REVIEW ]
}

@test "gh failing -> REVIEW, never REMOVE" {
  diverged_squash
  export FAKE_GH_FAIL=1
  [ "$(verdict_of feat)" = REVIEW ]
  [ "$(reason_of feat)" = "could not read pull requests" ]
}
