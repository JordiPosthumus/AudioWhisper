#!/bin/bash
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."
# Run the full suite by default; allow callers to pass --filter and other SwiftPM options.
exec swift test "$@"
