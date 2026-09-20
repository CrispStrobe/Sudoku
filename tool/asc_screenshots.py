#!/usr/bin/env python3
"""Replace the App Store screenshot sets for the newest editable iOS version.

Reads the manifest written by tool/capture_store_screenshots.sh and uploads
each image to App Store Connect, deleting whatever set was there first.

    ASC_KEY_ID=... ASC_ISSUER_ID=... ASC_API_KEY_P8=/path/to/AuthKey.p8 \
        python3 tool/asc_screenshots.py appstore-shots [--dry-run]

Uploading an asset is a three-step dance and the middle step is easy to miss:
POST the metadata to get a presigned URL, PUT the raw bytes to *that* URL, then
PATCH the resource with `uploaded: true` and the file's MD5. Skip the PATCH and
the image sits in App Store Connect for ever in an incomplete state.
"""

from __future__ import annotations

import argparse
import base64
import hashlib
import json
import os
import pathlib
import sys
import time
import urllib.error
import urllib.request

API = "https://api.appstoreconnect.apple.com"
BUNDLE_ID = "com.crispstrobe.sudoku"

# Versions in these states still accept metadata edits. Anything else (in
# review, or already released) must not be touched.
EDITABLE = {
    "PREPARE_FOR_SUBMISSION",
    "DEVELOPER_REJECTED",
    "REJECTED",
    "METADATA_REJECTED",
    "INVALID_BINARY",
}


def token() -> str:
    from cryptography.hazmat.primitives import hashes, serialization
    from cryptography.hazmat.primitives.asymmetric import ec, utils

    key_id = os.environ["ASC_KEY_ID"]
    issuer = os.environ["ASC_ISSUER_ID"]
    key_path = os.environ["ASC_API_KEY_P8"]

    def b64(data: bytes) -> str:
        return base64.urlsafe_b64encode(data).rstrip(b"=").decode()

    with open(key_path, "rb") as handle:
        private = serialization.load_pem_private_key(handle.read(), password=None)
    now = int(time.time())
    header = {"alg": "ES256", "kid": key_id, "typ": "JWT"}
    payload = {"iss": issuer, "iat": now, "exp": now + 1190,
               "aud": "appstoreconnect-v1"}
    signing_input = (f"{b64(json.dumps(header, separators=(',', ':')).encode())}."
                     f"{b64(json.dumps(payload, separators=(',', ':')).encode())}")
    der = private.sign(signing_input.encode(), ec.ECDSA(hashes.SHA256()))
    r, s = utils.decode_dss_signature(der)
    return f"{signing_input}.{b64(r.to_bytes(32, 'big') + s.to_bytes(32, 'big'))}"


def call(method: str, path: str, body: dict | None = None) -> dict:
    url = path if path.startswith("http") else API + path
    data = json.dumps(body).encode() if body is not None else None
    request = urllib.request.Request(
        url, data=data, method=method,
        headers={"Authorization": f"Bearer {TOKEN}",
                 "Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(request) as response:
            raw = response.read()
            return json.loads(raw) if raw else {}
    except urllib.error.HTTPError as error:
        detail = error.read().decode()[:600]
        raise SystemExit(f"{method} {path} -> {error.code}\n{detail}")


def put_bytes(operation: dict, blob: bytes) -> None:
    headers = {h["name"]: h["value"] for h in operation.get("requestHeaders", [])}
    request = urllib.request.Request(
        operation["url"], data=blob, method=operation.get("method", "PUT"),
        headers=headers)
    try:
        urllib.request.urlopen(request).read()
    except urllib.error.HTTPError as error:
        raise SystemExit(f"asset PUT failed: {error.code} {error.read()[:300]}")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("directory")
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    root = pathlib.Path(args.directory)
    manifest = json.loads((root / "manifest.json").read_text())

    apps = call("GET", "/v1/apps?limit=200")["data"]
    app = next(a for a in apps if a["attributes"]["bundleId"] == BUNDLE_ID)
    print(f"app {app['id']} ({app['attributes']['name']})")

    versions = call("GET", f"/v1/apps/{app['id']}/appStoreVersions?limit=20")["data"]
    editable = [v for v in versions
                if v["attributes"].get("platform") == "IOS"
                and v["attributes"].get("appStoreState") in EDITABLE]
    if not editable:
        states = ", ".join(f"{v['attributes']['versionString']}="
                           f"{v['attributes']['appStoreState']}"
                           for v in versions[:5])
        raise SystemExit(
            "no iOS version is in an editable state; screenshots cannot be "
            f"changed while a version is in review. Saw: {states}")
    version = editable[0]
    print(f"version {version['attributes']['versionString']} "
          f"({version['attributes']['appStoreState']})")

    locales = {
        loc["attributes"]["locale"]: loc["id"]
        for loc in call(
            "GET",
            f"/v1/appStoreVersions/{version['id']}/appStoreVersionLocalizations"
            "?limit=50")["data"]
    }

    wanted: dict[tuple[str, str], list[dict]] = {}
    for row in manifest:
        wanted.setdefault((row["locale"], row["displayType"]), []).append(row)

    for (locale, display), rows in sorted(wanted.items()):
        if locale not in locales:
            print(f"  skip {locale}: no localization on this version")
            continue
        loc_id = locales[locale]
        existing = call(
            "GET",
            f"/v1/appStoreVersionLocalizations/{loc_id}/appScreenshotSets?limit=50"
        )["data"]
        for candidate in existing:
            if candidate["attributes"]["screenshotDisplayType"] == display:
                print(f"  {locale}/{display}: deleting old set")
                if not args.dry_run:
                    call("DELETE", f"/v1/appScreenshotSets/{candidate['id']}")

        if args.dry_run:
            print(f"  {locale}/{display}: would upload {len(rows)} images")
            continue

        new_set = call("POST", "/v1/appScreenshotSets", {
            "data": {"type": "appScreenshotSets",
                     "attributes": {"screenshotDisplayType": display},
                     "relationships": {"appStoreVersionLocalization": {
                         "data": {"type": "appStoreVersionLocalizations",
                                  "id": loc_id}}}}})["data"]

        for row in sorted(rows, key=lambda r: r["name"]):
            blob = (root / row["name"]).read_bytes()
            created = call("POST", "/v1/appScreenshots", {
                "data": {"type": "appScreenshots",
                         "attributes": {"fileName": row["name"],
                                        "fileSize": len(blob)},
                         "relationships": {"appScreenshotSet": {
                             "data": {"type": "appScreenshotSets",
                                      "id": new_set["id"]}}}}})["data"]
            for operation in created["attributes"]["uploadOperations"]:
                put_bytes(operation, blob)
            call("PATCH", f"/v1/appScreenshots/{created['id']}", {
                "data": {"type": "appScreenshots", "id": created["id"],
                         "attributes": {
                             "uploaded": True,
                             "sourceFileChecksum": hashlib.md5(blob).hexdigest()}}})
            print(f"  uploaded {row['name']}")

    print("done")


if __name__ == "__main__":
    TOKEN = token()
    main()
