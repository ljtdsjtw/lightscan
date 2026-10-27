#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p .build
xcrun swiftc Sources/Scanner.swift Tests/main.swift -o .build/ScannerTests
.build/ScannerTests "$PWD/.build/fixtures"
