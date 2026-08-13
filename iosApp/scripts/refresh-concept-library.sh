#!/usr/bin/env bash
# Regenerate the bundled offline concept corpus (iosApp/iosApp/ConceptLibrary.json)
# from the running backend's GET /concepts endpoint.
#
# Run this whenever the backend seed data changes so the app's offline snapshot
# stays in step. The backend must be running and reseeded first (see backend
# docker-compose + SeedData.kt).
#
# Usage: BACKEND_URL=http://localhost:8081 ./scripts/refresh-concept-library.sh
set -euo pipefail

BACKEND_URL="${BACKEND_URL:-http://localhost:8081}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT="$SCRIPT_DIR/../iosApp/ConceptLibrary.json"

echo "Fetching corpus from $BACKEND_URL/concepts ..."
curl -fsS "$BACKEND_URL/concepts" | python3 -c "
import sys, json
data = json.load(sys.stdin)
if not isinstance(data, list) or not data:
    sys.exit('Refusing to write: endpoint returned no concepts')
# Stable ordering for a readable, diff-friendly snapshot.
data.sort(key=lambda c: (c['type'], c['name'].lower()))
with open('$OUT', 'w') as f:
    json.dump(data, f, indent=2, ensure_ascii=False)
    f.write('\n')
print(f'Wrote {len(data)} concepts to $OUT')
"
