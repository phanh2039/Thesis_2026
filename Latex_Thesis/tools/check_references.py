#!/usr/bin/env python3
"""Validate URLs and DOI links in References.bib.

The script performs network checks for each BibTeX entry with a DOI or URL-like
field and writes a CSV report. HTTP 403/405 are treated as reachable-but-blocked
because many publishers reject automated HEAD/GET checks while the DOI itself is
syntactically resolvable.
"""
from __future__ import annotations

import csv
import re
import sys
from pathlib import Path
from urllib.parse import quote

import bibtexparser
import requests

ROOT = Path(__file__).resolve().parents[1]
BIB = ROOT / "References.bib"
OUT = ROOT / "reference_link_check.csv"
TIMEOUT = 20
URL_RE = re.compile(r"https?://[^}\\\s]+")


def clean_latex(value: str) -> str:
    value = value.replace("\\url{", "").replace("}", "")
    return value.strip().strip("{}")


def candidates(entry: dict[str, str]) -> list[tuple[str, str]]:
    out: list[tuple[str, str]] = []
    if doi := entry.get("doi"):
        doi = clean_latex(doi)
        out.append(("doi", f"https://doi.org/{quote(doi, safe='/().:-')}") )
    for field in ("url", "howpublished", "note"):
        if value := entry.get(field):
            for url in URL_RE.findall(value):
                out.append((field, clean_latex(url)))
    # Preserve order, remove duplicates.
    seen = set()
    unique = []
    for item in out:
        if item not in seen:
            seen.add(item)
            unique.append(item)
    return unique


def check(url: str) -> tuple[str, int | str, str]:
    headers = {"User-Agent": "Mozilla/5.0 reference-link-check"}
    try:
        response = requests.get(url, headers=headers, allow_redirects=False, timeout=TIMEOUT, stream=True)
        status = response.status_code
        final_url = response.headers.get("Location", response.url)
        response.close()
        if 200 <= status < 400:
            return "ok", status, final_url
        if status in (401, 403, 405, 429):
            return "reachable_blocked", status, final_url
        return "bad_status", status, final_url
    except requests.RequestException as exc:
        return "error", "", str(exc)


def main() -> int:
    with BIB.open(encoding="utf-8") as fh:
        db = bibtexparser.load(fh)

    rows = []
    failed = False
    for entry in db.entries:
        key = entry.get("ID", "")
        links = candidates(entry)
        if not links:
            rows.append({"key": key, "field": "", "url": "", "status": "no_link", "http_code": "", "final_url_or_error": ""})
            continue
        for field, url in links:
            status, code, final = check(url)
            if status in {"bad_status", "error"}:
                failed = True
            rows.append({"key": key, "field": field, "url": url, "status": status, "http_code": code, "final_url_or_error": final})

    with OUT.open("w", encoding="utf-8", newline="") as fh:
        writer = csv.DictWriter(fh, fieldnames=["key", "field", "url", "status", "http_code", "final_url_or_error"])
        writer.writeheader()
        writer.writerows(rows)

    print(f"Checked {len(rows)} links/entries; report written to {OUT}")
    bad = [r for r in rows if r["status"] in {"bad_status", "error"}]
    if bad:
        print("Failures:")
        for row in bad:
            print(f"- {row['key']} {row['url']} -> {row['status']} {row['http_code']} {row['final_url_or_error']}")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
