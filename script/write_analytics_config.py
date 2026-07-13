#!/usr/bin/env python3
"""Write the ignored analytics plist from environment variables."""

from __future__ import annotations

import os
from pathlib import Path
import plistlib
import re
import tempfile
from urllib.parse import urlparse


ROOT_DIR = Path(__file__).resolve().parent.parent
OUTPUT_PATH = ROOT_DIR / "Config" / "AnalyticsConfig.local.plist"
KEY_ID_PATTERN = re.compile(r"^[A-Za-z0-9._-]+$")
SECRET_PATTERN = re.compile(r"^[A-Za-z0-9_-]{32,}$")
AUDIENCES = {"debug", "test", "beta", "production"}


def required_environment(name: str) -> str:
    value = os.environ.get(name, "").strip()
    if not value:
        raise SystemExit(f"Missing required environment variable: {name}")
    return value


def validate_base_url(value: str) -> None:
    parsed = urlparse(value)
    if parsed.scheme not in {"http", "https"} or not parsed.netloc:
        raise SystemExit("CLIPBOARD_MARKUP_ANALYTICS_BASE_URL must be an HTTP(S) URL")
    if parsed.query or parsed.fragment or not parsed.path.rstrip("/").endswith("/clipboard-markup"):
        raise SystemExit(
            "CLIPBOARD_MARKUP_ANALYTICS_BASE_URL must end in /clipboard-markup "
            "and must not include a query or fragment"
        )


def main() -> None:
    base_url = required_environment("CLIPBOARD_MARKUP_ANALYTICS_BASE_URL").rstrip("/")
    key_id = required_environment("CLIPBOARD_MARKUP_ANALYTICS_KEY_ID")
    secret = required_environment("CLIPBOARD_MARKUP_ANALYTICS_SECRET")
    audience = os.environ.get("CLIPBOARD_MARKUP_ANALYTICS_AUDIENCE", "debug").strip()

    validate_base_url(base_url)
    if not KEY_ID_PATTERN.fullmatch(key_id):
        raise SystemExit("CLIPBOARD_MARKUP_ANALYTICS_KEY_ID contains unsupported characters")
    if not SECRET_PATTERN.fullmatch(secret):
        raise SystemExit(
            "CLIPBOARD_MARKUP_ANALYTICS_SECRET must be at least 32 URL-safe characters"
        )
    if audience not in AUDIENCES:
        raise SystemExit(
            "CLIPBOARD_MARKUP_ANALYTICS_AUDIENCE must be debug, test, beta, or production"
        )

    configuration = {
        "analyticsBaseUrl": base_url,
        "analyticsKeyId": key_id,
        "analyticsSecret": secret,
        "audience": audience,
    }
    OUTPUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    descriptor, temporary_name = tempfile.mkstemp(
        dir=OUTPUT_PATH.parent,
        prefix=f".{OUTPUT_PATH.name}.",
    )
    temporary_path = Path(temporary_name)
    try:
        with os.fdopen(descriptor, "wb") as output:
            plistlib.dump(configuration, output, fmt=plistlib.FMT_XML, sort_keys=True)
        temporary_path.chmod(0o600)
        temporary_path.replace(OUTPUT_PATH)
        OUTPUT_PATH.chmod(0o600)
    finally:
        temporary_path.unlink(missing_ok=True)

    print(f"Wrote {OUTPUT_PATH}")


if __name__ == "__main__":
    main()
