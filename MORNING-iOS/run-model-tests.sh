#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
cp Tests/ReportModelTests.swift "$TMP/main.swift"
swiftc MORNING/ReportModel.swift MORNING/SleepAggregation.swift "$TMP/main.swift" -o "$TMP/morning-model-tests"
"$TMP/morning-model-tests"
