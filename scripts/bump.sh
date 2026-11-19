#!/usr/bin/env bash
# Usage: scripts/bump.sh [new-branch...]   e.g. scripts/bump.sh        (bump all)
#                                               scripts/bump.sh 8.6    (also add 8.6)
#
# Rewrites versions.json, the list of PHP versions CI builds: every entry
# becomes the latest release of its branch on php.net, and each branch given
# as an argument is added. EOL branches have no new releases and stay put.
# Prints one line per change; commit the result through a PR.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
file="$root/versions.json"

latest() {
  curl -fsSL "https://www.php.net/releases/index.php?json&version=$1" | jq -r '.version // empty'
}

branches="$(jq -r '.[] | split(".")[:2] | join(".")' "$file")"
for b in "$@"; do
  [[ "$b" =~ ^[0-9]+\.[0-9]+$ ]] || { echo "not a branch (want X.Y): $b" >&2; exit 1; }
  branches="$branches"$'\n'"$b"
done

new=()
for b in $(printf '%s\n' "$branches" | sort -u -t. -k1,1nr -k2,2nr); do
  v="$(latest "$b")"
  if [ -z "$v" ]; then
    echo "php.net lists no release for $b" >&2
    exit 1
  fi
  old="$(jq -r --arg b "$b." '.[] | select(startswith($b))' "$file")"
  [ "$old" != "$v" ] && echo "$b: ${old:-(new)} -> $v"
  new+=("$v")
done

printf '%s\n' "${new[@]}" | jq -R . | jq -sc . > "$file"
