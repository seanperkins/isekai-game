#!/usr/bin/env bash
# Start the creature review page and open it in the browser. Arguments go to server.py: --content DIR, --port N, --no-open.
set -euo pipefail
cd "$(dirname "$0")/../.."
exec python3 tools/review/server.py "$@"
