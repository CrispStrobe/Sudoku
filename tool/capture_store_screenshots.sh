#!/usr/bin/env bash
#
# Render the App Store screenshots and write the manifest the uploader reads.
#
# No device, no simulator, no macOS: test/store_screenshots_test.dart renders
# the real screens at exact store pixel dimensions on whatever machine runs it.
#
#   bash tool/capture_store_screenshots.sh [output-dir]
#
# Then verify the images by eye before uploading — they are the shop window.
set -euo pipefail
cd "$(dirname "$0")/.."

output=${1:-appstore-shots}
rm -rf "$output"
mkdir -p "$output"

SCREENSHOT_OUTPUT="$output" flutter test test/store_screenshots_test.dart

python3 - "$output" <<'PY'
import json, pathlib, struct, sys

root = pathlib.Path(sys.argv[1])
rows = []
# Apple accepts the 6.9" iPhone image for the 6.7" slot, and the 13" iPad image
# for the 12.9" slot, so two renders cover both required display types.
devices = (
    ("iphone", "APP_IPHONE_67", (1320, 2868)),
    ("ipad", "APP_IPAD_PRO_3GEN_129", (2064, 2752)),
)
scenes = ("01-home", "02-classic", "03-thermo", "04-killer")

for locale in ("en-US", "de-DE"):
    for scene in scenes:
        for suffix, display, expected in devices:
            name = f"{locale}-{scene}-{suffix}.png"
            path = root / name
            if not path.exists():
                raise SystemExit(f"missing screenshot: {name}")
            with path.open("rb") as image:
                signature = image.read(24)
            if signature[:8] != b"\x89PNG\r\n\x1a\n":
                raise SystemExit(f"not a PNG: {name}")
            actual = struct.unpack(">II", signature[16:24])
            if actual != expected:
                raise SystemExit(
                    f"wrong dimensions for {name}: {actual}, want {expected}")
            rows.append({"name": name, "locale": locale,
                         "displayType": display,
                         "pixels": "x".join(str(n) for n in expected)})

(root / "manifest.json").write_text(json.dumps(rows, indent=2) + "\n")
print(f"prepared {len(rows)} screenshots in {root}")
PY
