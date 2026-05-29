#!/usr/bin/env bash
#
# Build the Flutter web app and deploy the prebuilt output to Vercel.
#
# Vercel's build image has no Flutter, so we build locally and deploy the
# static build/web directory. `flutter build web` wipes build/web each run,
# so this script (re)writes vercel.json and (re)links the project every time.
#
# Usage:
#   ./deploy.sh                  # production deploy (JS/canvaskit)
#   ./deploy.sh --preview        # preview deploy (no --prod)
#   ./deploy.sh --wasm           # WebAssembly (skwasm) build + COOP/COEP headers
#   ./deploy.sh --wasm --preview # combine flags
#
# Requirements: `flutter` and `vercel` on PATH, and either `vercel login`
# already done or a VERCEL_TOKEN env var.
#
# Env overrides:
#   VERCEL_PROJECT  (default: sudoku)
#   VERCEL_TOKEN    (optional; passed to vercel as --token)

set -euo pipefail
cd "$(dirname "$0")"

PROJECT="${VERCEL_PROJECT:-sudoku}"
OUT="build/web"

PROD="--prod"
WASM=0
for arg in "$@"; do
  case "$arg" in
    --preview) PROD="" ;;
    --wasm) WASM=1 ;;
    *) echo "Unknown option: $arg" >&2; exit 1 ;;
  esac
done

TOKEN_ARG=()
if [[ -n "${VERCEL_TOKEN:-}" ]]; then
  TOKEN_ARG=(--token "$VERCEL_TOKEN")
fi

if [[ "$WASM" == "1" ]]; then
  echo "==> flutter build web --release --wasm"
  flutter build web --release --wasm
  # skwasm needs a cross-origin-isolated context (SharedArrayBuffer).
  HEADERS=',
  "headers": [
    {
      "source": "/(.*)",
      "headers": [
        { "key": "Cross-Origin-Opener-Policy", "value": "same-origin" },
        { "key": "Cross-Origin-Embedder-Policy", "value": "require-corp" }
      ]
    }
  ]'
else
  echo "==> flutter build web --release"
  flutter build web --release
  HEADERS=''
fi

echo "==> writing $OUT/vercel.json"
cat > "$OUT/vercel.json" <<JSON
{
  "\$schema": "https://openapi.vercel.sh/vercel.json",
  "cleanUrls": true,
  "rewrites": [
    { "source": "/((?!.*\\\\.).*)", "destination": "/index.html" }
  ]$HEADERS
}
JSON

echo "==> linking Vercel project '$PROJECT'"
vercel link --cwd "$OUT" --project "$PROJECT" --yes "${TOKEN_ARG[@]}"

echo "==> deploying"
vercel deploy --cwd "$OUT" $PROD --yes "${TOKEN_ARG[@]}"
