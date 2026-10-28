#!/usr/bin/env bash
# Run all test suites: engine (pure Dart) + app (Flutter).
set -euo pipefail
cd "$(dirname "$0")/.."

echo "== engine: dart test (packages/planner_engine) =="
(cd packages/planner_engine && dart test)

echo "== app: flutter test (apps/planner) =="
(cd apps/planner && flutter test)

echo "== all green =="
