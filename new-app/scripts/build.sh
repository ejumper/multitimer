#!/usr/bin/env bash
# Build the Linux desktop app (release).
set -euo pipefail
cd "$(dirname "$0")/../apps/planner"

flutter build linux --release "$@"
echo "== binary: apps/planner/build/linux/x64/release/bundle/planner =="
