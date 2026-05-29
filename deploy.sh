#!/usr/bin/env bash
#
# Build the Flutter web app and deploy the prebuilt output to Vercel.
#
# Vercel's build image has no Flutter, so we build locally and deploy the
# static build/web directory. `flutter build web` wipes build/web each run,
# so this script (re)writes vercel.json and (re)links the project every time.
#
# Usage:
#   ./deploy.sh            # production deploy
#   ./deploy.sh --preview  # preview deploy (no --prod)
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
if [[ "${1:-}" == "--preview" ]]; then
  PROD=""
fi

TOKEN_ARG=()
if [[ -n "${VERCEL_TOKEN:-}" ]]; then
  TOKEN_ARG=(--token "$VERCEL_TOKEN")
fi

echo "==> flutter build web --release"
flutter build web --release

echo "==> writing $OUT/vercel.json (SPA rewrite)"
cat > "$OUT/vercel.json" <<'JSON'
{
  "$schema": "https://openapi.vercel.sh/vercel.json",
  "cleanUrls": true,
  "rewrites": [
    { "source": "/((?!.*\\.).*)", "destination": "/index.html" }
  ]
}
JSON

echo "==> linking Vercel project '$PROJECT'"
vercel link --cwd "$OUT" --project "$PROJECT" --yes "${TOKEN_ARG[@]}"

echo "==> deploying"
vercel deploy --cwd "$OUT" $PROD --yes "${TOKEN_ARG[@]}"
