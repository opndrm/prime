#!/usr/bin/env bash
set -euo pipefail

lane="${1:-}"
case "$lane" in
  ADAM|FRNKLY.ONE|OPNDRM-APP) ;;
  *) printf 'Choose ADAM, FRNKLY.ONE, or OPNDRM APP.\n' >&2; exit 1 ;;
esac

work_dir="$(mktemp -d)"
trap 'rm -rf "$work_dir"' EXIT
curl -fsSL https://codeload.github.com/opndrm/prime/tar.gz/refs/heads/main | tar -xz -C "$work_dir"
source_dir="$(find "$work_dir" -maxdepth 1 -type d -name 'prime-*' -print -quit)"
exec "$source_dir/scripts/install-macos.sh" "$lane"
