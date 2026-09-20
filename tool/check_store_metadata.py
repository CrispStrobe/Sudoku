#!/usr/bin/env python3
"""Check fastlane/metadata against App Store Connect's field limits.

Apple counts *characters*, not bytes, and rejects the whole submission for one
field that is one character over — after the upload, the version creation and
the wait. Cheaper to find out here.

    python3 tool/check_store_metadata.py
"""

from __future__ import annotations

import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
METADATA = ROOT / "fastlane" / "metadata"

# Field -> (character limit, required?)
FIELDS = {
    "name": (30, True),
    "subtitle": (30, False),
    "keywords": (100, True),
    "promotional_text": (170, False),
    "description": (4000, True),
    "release_notes": (4000, True),
    "marketing_url": (255, False),
    "support_url": (255, True),
    "privacy_url": (255, False),
}


def main() -> int:
    locales = sorted(
        d.name for d in METADATA.iterdir()
        if d.is_dir() and d.name != "android" and (d / "description.txt").exists()
    )
    if not locales:
        print("no storefront locales found under fastlane/metadata/")
        return 1

    problems: list[str] = []
    for locale in locales:
        print(locale)
        for field, (limit, required) in FIELDS.items():
            path = METADATA / locale / f"{field}.txt"
            if not path.exists():
                if required:
                    problems.append(f"{locale}/{field}.txt is missing")
                    print(f"  {field:18} MISSING (required)")
                continue
            text = path.read_text().strip()
            count = len(text)
            if not text and required:
                problems.append(f"{locale}/{field}.txt is empty")
            over = count > limit
            if over:
                problems.append(
                    f"{locale}/{field} is {count} characters, limit {limit}")
            print(f"  {field:18} {count:5}/{limit}{'  <-- OVER' if over else ''}")

    # Keywords are comma-separated with no spaces after the comma; a stray
    # space costs a character and Apple keeps it.
    for locale in locales:
        path = METADATA / locale / "keywords.txt"
        if path.exists() and ", " in path.read_text():
            problems.append(
                f"{locale}/keywords.txt has a space after a comma — "
                "that space counts against the 100-character limit")

    if problems:
        print("\nproblems:")
        for problem in problems:
            print(f"  - {problem}")
        return 1
    print(f"\n{len(locales)} storefront(s) within limits")
    return 0


if __name__ == "__main__":
    sys.exit(main())
