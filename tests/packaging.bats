#!/usr/bin/env bats
# The files the workflows and installer name must exist under those names.

@test "release workflow names files that exist" {
  cd "$BATS_TEST_DIRNAME/.."
  names=$(grep -oE '(sha256sum|release create "\$GITHUB_REF_NAME"|p'"'"' ) [A-Za-z0-9._-]+' .github/workflows/release.yml | awk '{print $NF}')
  names+=" $(grep -oE "p' [A-Za-z0-9._-]+\)" .github/workflows/release.yml | tr -d ")" | awk '{print $NF}')"
  [ -n "$names" ]
  for n in $names; do [ -f "$n" ] || { echo "release.yml names missing file: $n"; false; }; done
}
