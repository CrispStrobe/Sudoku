#!/usr/bin/env python3
"""Take an uploaded build all the way to an App Store submission.

The `v*` tag builds, signs and uploads an IPA. That is only half a release:
the build lands in App Store Connect and then nothing happens to it. v1.1.0
through v1.3.0 each uploaded a build that sat in TestFlight while the public
listing stayed on 1.0.3. This is the other half.

    ASC_KEY_ID=... ASC_ISSUER_ID=... ASC_API_KEY_P8=AuthKey.p8 \
        python3 tool/asc_release.py [--submit] [--dry-run]

What it does, all idempotent:

  * reads the version and build number from pubspec.yaml
  * finds that build in App Store Connect and waits for it to finish processing
  * creates the App Store version if it does not exist
  * attaches the build
  * creates any missing storefront localization and pushes every field from
    fastlane/metadata/<locale>/
  * with --submit, submits for review via the three-step reviewSubmissions flow

Without --submit it stops at PREPARE_FOR_SUBMISSION with everything filled in,
which is the state a human can look at and press Submit from. Submitting starts
Apple's review, so it is opt-in.
"""

from __future__ import annotations

import argparse
import base64
import json
import os
import pathlib
import re
import sys
import time
import urllib.error
import urllib.request

API = "https://api.appstoreconnect.apple.com"
BUNDLE_ID = "com.crispstrobe.sudoku"
ROOT = pathlib.Path(__file__).resolve().parent.parent
METADATA = ROOT / "fastlane" / "metadata"

# Version-level fields, and the file each comes from.
VERSION_FIELDS = {
    "description": "description",
    "keywords": "keywords",
    "whatsNew": "release_notes",
    "promotionalText": "promotional_text",
    "marketingUrl": "marketing_url",
    "supportUrl": "support_url",
}
# App-level fields: the name and subtitle live on appInfoLocalizations, not on
# the version, which is a genuinely confusing split in this API.
APP_INFO_FIELDS = {"name": "name", "subtitle": "subtitle",
                   "privacyPolicyUrl": "privacy_url"}

EDITABLE = {"PREPARE_FOR_SUBMISSION", "DEVELOPER_REJECTED", "REJECTED",
            "METADATA_REJECTED", "INVALID_BINARY"}


def token() -> str:
    from cryptography.hazmat.primitives import hashes, serialization
    from cryptography.hazmat.primitives.asymmetric import ec, utils

    def b64(data: bytes) -> str:
        return base64.urlsafe_b64encode(data).rstrip(b"=").decode()

    with open(os.environ["ASC_API_KEY_P8"], "rb") as handle:
        private = serialization.load_pem_private_key(handle.read(), password=None)
    now = int(time.time())
    head = {"alg": "ES256", "kid": os.environ["ASC_KEY_ID"], "typ": "JWT"}
    body = {"iss": os.environ["ASC_ISSUER_ID"], "iat": now, "exp": now + 1190,
            "aud": "appstoreconnect-v1"}
    signing = (f"{b64(json.dumps(head, separators=(',', ':')).encode())}."
               f"{b64(json.dumps(body, separators=(',', ':')).encode())}")
    der = private.sign(signing.encode(), ec.ECDSA(hashes.SHA256()))
    r, s = utils.decode_dss_signature(der)
    return f"{signing}.{b64(r.to_bytes(32, 'big') + s.to_bytes(32, 'big'))}"


def call(method: str, path: str, body: dict | None = None) -> dict:
    data = json.dumps(body).encode() if body is not None else None
    request = urllib.request.Request(
        API + path, data=data, method=method,
        headers={"Authorization": f"Bearer {TOKEN}",
                 "Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(request) as response:
            raw = response.read()
            return json.loads(raw) if raw else {}
    except urllib.error.HTTPError as error:
        raise SystemExit(f"{method} {path} -> {error.code}\n"
                         f"{error.read().decode()[:700]}")


def pubspec_version() -> tuple[str, str]:
    text = (ROOT / "pubspec.yaml").read_text()
    match = re.search(r"^version:\s*([0-9.]+)\+([0-9]+)", text, re.M)
    if not match:
        raise SystemExit("could not read version from pubspec.yaml")
    return match.group(1), match.group(2)


def read(locale: str, field: str) -> str | None:
    path = METADATA / locale / f"{field}.txt"
    return path.read_text().strip() if path.exists() else None


def locales() -> list[str]:
    """Storefront locales, from the directories that exist."""
    return sorted(d.name for d in METADATA.iterdir()
                  if d.is_dir() and d.name != "android"
                  and (d / "description.txt").exists())


def wait_for_build(app: str, build_number: str, timeout: int = 1800) -> dict:
    deadline = time.time() + timeout
    while True:
        builds = call("GET", f"/v1/builds?filter%5Bapp%5D={app}"
                             f"&filter%5Bversion%5D={build_number}&limit=1")["data"]
        if builds:
            state = builds[0]["attributes"]["processingState"]
            if state == "VALID":
                return builds[0]
            if state in ("INVALID", "FAILED"):
                raise SystemExit(f"build {build_number} is {state}")
            print(f"  build {build_number}: {state}, waiting")
        else:
            print(f"  build {build_number} not visible yet, waiting")
        if time.time() > deadline:
            raise SystemExit(f"build {build_number} did not become VALID in time")
        time.sleep(30)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--submit", action="store_true",
                        help="submit for App Review (starts Apple's review)")
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    version_string, build_number = pubspec_version()
    print(f"pubspec: {version_string} (build {build_number})")

    apps = call("GET", "/v1/apps?limit=200")["data"]
    app = next(a for a in apps if a["attributes"]["bundleId"] == BUNDLE_ID)
    print(f"app {app['id']} ({app['attributes']['name']})")

    build = wait_for_build(app["id"], build_number)
    print(f"build {build_number} is VALID ({build['id']})")

    versions = call("GET", f"/v1/apps/{app['id']}/appStoreVersions?limit=20")["data"]
    version = next((v for v in versions
                    if v["attributes"].get("platform") == "IOS"
                    and v["attributes"].get("versionString") == version_string), None)

    if version is None:
        print(f"creating version {version_string}")
        if args.dry_run:
            return
        version = call("POST", "/v1/appStoreVersions", {
            "data": {"type": "appStoreVersions",
                     "attributes": {"platform": "IOS",
                                    "versionString": version_string,
                                    # Wait for a human to release after
                                    # approval, matching every prior release.
                                    "releaseType": "MANUAL"},
                     "relationships": {"app": {
                         "data": {"type": "apps", "id": app["id"]}}}}})["data"]
    state = version["attributes"]["appStoreState"]
    print(f"version {version_string} ({state})")
    if state not in EDITABLE:
        raise SystemExit(
            f"version {version_string} is {state} and cannot be edited. "
            "Cancel its review submission first if you need to change it.")

    if args.dry_run:
        print(f"would attach build, push {len(locales())} locale(s): "
              f"{', '.join(locales())}"
              + (", and submit" if args.submit else ""))
        return

    call("PATCH", f"/v1/appStoreVersions/{version['id']}/relationships/build",
         {"data": {"type": "builds", "id": build["id"]}})
    print("  build attached")

    # App-level localizations (name, subtitle, privacy URL).
    info = call("GET", f"/v1/apps/{app['id']}/appInfos?limit=10")["data"]
    editable_info = next((i for i in info
                          if i["attributes"].get("appStoreState") in EDITABLE), info[0])
    info_locales = {
        loc["attributes"]["locale"]: loc["id"]
        for loc in call("GET", f"/v1/appInfos/{editable_info['id']}"
                               "/appInfoLocalizations?limit=50")["data"]}

    version_locales = {
        loc["attributes"]["locale"]: loc["id"]
        for loc in call("GET", f"/v1/appStoreVersions/{version['id']}"
                               "/appStoreVersionLocalizations?limit=50")["data"]}

    for locale in locales():
        attrs = {key: read(locale, field)
                 for key, field in APP_INFO_FIELDS.items()
                 if read(locale, field) is not None}
        if locale in info_locales:
            call("PATCH", f"/v1/appInfoLocalizations/{info_locales[locale]}",
                 {"data": {"type": "appInfoLocalizations",
                           "id": info_locales[locale], "attributes": attrs}})
        else:
            call("POST", "/v1/appInfoLocalizations", {
                "data": {"type": "appInfoLocalizations",
                         "attributes": {"locale": locale, **attrs},
                         "relationships": {"appInfo": {
                             "data": {"type": "appInfos",
                                      "id": editable_info["id"]}}}}})
            print(f"  {locale}: created app-level localization")

        attrs = {key: read(locale, field)
                 for key, field in VERSION_FIELDS.items()
                 if read(locale, field) is not None}
        if locale in version_locales:
            call("PATCH",
                 f"/v1/appStoreVersionLocalizations/{version_locales[locale]}",
                 {"data": {"type": "appStoreVersionLocalizations",
                           "id": version_locales[locale], "attributes": attrs}})
            print(f"  {locale}: updated version localization")
        else:
            call("POST", "/v1/appStoreVersionLocalizations", {
                "data": {"type": "appStoreVersionLocalizations",
                         "attributes": {"locale": locale, **attrs},
                         "relationships": {"appStoreVersion": {
                             "data": {"type": "appStoreVersions",
                                      "id": version["id"]}}}}})
            print(f"  {locale}: created version localization")

    if not args.submit:
        print(f"\n{version_string} is ready to submit. Review it, then rerun "
              "with --submit (or press Submit in App Store Connect).")
        return

    submission = call("POST", "/v1/reviewSubmissions", {
        "data": {"type": "reviewSubmissions",
                 "attributes": {"platform": "IOS"},
                 "relationships": {"app": {
                     "data": {"type": "apps", "id": app["id"]}}}}})["data"]
    call("POST", "/v1/reviewSubmissionItems", {
        "data": {"type": "reviewSubmissionItems",
                 "relationships": {
                     "reviewSubmission": {"data": {"type": "reviewSubmissions",
                                                   "id": submission["id"]}},
                     "appStoreVersion": {"data": {"type": "appStoreVersions",
                                                  "id": version["id"]}}}}})
    result = call("PATCH", f"/v1/reviewSubmissions/{submission['id']}", {
        "data": {"type": "reviewSubmissions", "id": submission["id"],
                 "attributes": {"submitted": True}}})["data"]
    print(f"\nsubmitted for review: {result['attributes']['state']}")


if __name__ == "__main__":
    TOKEN = token()
    main()
