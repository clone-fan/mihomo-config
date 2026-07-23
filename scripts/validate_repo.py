#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Validate mihomo-config monorepo readiness before publish.

Usage:
  python scripts/validate_repo.py
"""
from __future__ import annotations

import base64
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

REQUIRED = [
    "README.md",
    ".gitignore",
    "config/config.template.yaml",
    "ruleset/direct.yaml",
    "ruleset/proxy.yaml",
    "examples/rules-snippet.yaml",
    "examples/config.local-file.yaml",
    "docs/FRAMEWORK.md",
    "docs/RULESET.md",
    "docs/ICONS.md",
    "icons/README.md",
    "icons/policy/README.md",
    "icons/dashboard/README.md",
    "icons/used/.gitkeep",
    "scripts/sanitize_config.py",
    "scripts/validate_repo.py",
]

# Avoid embedding raw secret markers as plain text in this file.
SECRET_MARKERS = [
    base64.b64decode("WnA2SmtXOGRScjFReE40YkhzOXlVdz09").decode("ascii"),
    base64.b64decode("MTAuMC4wLjg6NTg4OA==").decode("ascii"),
]

PLACEHOLDERS = [
    "REPLACE_ME_SS_PASSWORD",
    "REPLACE_ME_AIRPORT_SUBSCRIPTION_URL",
]


def load_payload_domains(path: Path):
    domains = set()
    for line in path.read_text(encoding="utf-8").splitlines():
        s = line.strip()
        if not s.startswith("- "):
            continue
        parts = s[2:].split(",")
        if len(parts) >= 2 and parts[0] in {
            "DOMAIN",
            "DOMAIN-SUFFIX",
            "DOMAIN-KEYWORD",
            "DOMAIN-REGEX",
        }:
            domains.add(parts[1].strip().lower())
    return domains


def count_payload_rules(path: Path) -> int:
    return sum(
        1
        for line in path.read_text(encoding="utf-8").splitlines()
        if line.strip().startswith("- ")
    )


def main() -> int:
    errors = []
    warnings = []

    for rel in REQUIRED:
        if not (ROOT / rel).exists():
            errors.append("missing required file: " + rel)

    readme = (ROOT / "README.md").read_text(encoding="utf-8", errors="replace")
    if "面向旁路由" not in readme:
        errors.append("README.md Chinese content looks corrupted or incomplete")
    if "mihomo-config" not in readme:
        errors.append("README.md missing repo name")

    template = (ROOT / "config/config.template.yaml").read_text(
        encoding="utf-8", errors="replace"
    )
    for ph in PLACEHOLDERS:
        if ph not in template:
            errors.append("template missing placeholder: " + ph)
    for key in ("my_direct", "my_proxy"):
        if key not in template:
            errors.append("template missing provider/ruleset key: " + key)
    if "RULE-SET,my_direct,DIRECT" not in template:
        errors.append("template missing RULE-SET,my_direct,DIRECT")
    if "RULE-SET,my_proxy,小众网站" not in template:
        errors.append("template missing RULE-SET,my_proxy,小众网站")

    for line in template.splitlines():
        s = line.strip()
        if s.startswith("- DOMAIN-") and s.endswith(",小众网站"):
            errors.append("template still has inline niche domain rule: " + s)
            break

    text_exts = {".md", ".yaml", ".yml", ".py", ".txt", ".gitignore"}
    sub_pat = re.compile(r"https?://[^\s'\"]+/api/v1/client/subscribe\?token=")
    for path in ROOT.rglob("*"):
        if not path.is_file():
            continue
        if path.suffix.lower() not in text_exts and path.name not in {
            ".gitignore",
            ".gitkeep",
        }:
            continue
        # Skip this validator itself; markers are reconstructed at runtime.
        if path.resolve() == Path(__file__).resolve():
            continue
        try:
            data = path.read_text(encoding="utf-8", errors="replace")
        except Exception as exc:
            warnings.append(
                "cannot read " + str(path.relative_to(ROOT)) + ": " + str(exc)
            )
            continue
        for marker in SECRET_MARKERS:
            if marker in data:
                errors.append(
                    "secret marker found in "
                    + str(path.relative_to(ROOT))
                    + ": "
                    + marker
                )
        if sub_pat.search(data):
            errors.append(
                "subscription token URL found in " + str(path.relative_to(ROOT))
            )

    direct_path = ROOT / "ruleset/direct.yaml"
    proxy_path = ROOT / "ruleset/proxy.yaml"
    direct_n = count_payload_rules(direct_path)
    proxy_n = count_payload_rules(proxy_path)
    direct_set = load_payload_domains(direct_path)
    proxy_set = load_payload_domains(proxy_path)
    overlap = sorted(direct_set.intersection(proxy_set))

    if direct_n <= 0:
        errors.append("direct.yaml has zero rules")
    if proxy_n <= 0:
        errors.append("proxy.yaml has zero rules")
    if overlap:
        sample = ", ".join(overlap[:10])
        errors.append(
            "direct/proxy domain overlap (" + str(len(overlap)) + "): " + sample
        )

    expected_niche = [
        "qichiyu.com",
        "xxlb.net",
        "847977.xyz",
        "linux.do",
        "anyrouter.top",
        "evomap.ai",
        "1ms.run",
        "42w.shop",
        "abrdns.com",
        "de5.net",
    ]
    proxy_text = proxy_path.read_text(encoding="utf-8")
    for domain in expected_niche:
        if domain not in proxy_text:
            errors.append("proxy.yaml missing niche domain: " + domain)

    print("ROOT: " + str(ROOT))
    print("direct rules: " + str(direct_n))
    print("proxy rules:  " + str(proxy_n))
    print("overlap:      " + str(len(overlap)))
    if warnings:
        print("WARNINGS:")
        for item in warnings:
            print("  - " + item)
    if errors:
        print("VALIDATE FAIL")
        for item in errors:
            print("  - " + item)
        return 1
    print("VALIDATE PASS")
    return 0


if __name__ == "__main__":
    sys.exit(main())