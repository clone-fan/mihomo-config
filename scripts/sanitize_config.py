#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Sanitize a live mihomo config into a publishable template.

Usage:
  python scripts/sanitize_config.py --input live.yaml --output config/config.template.yaml
"""
from __future__ import annotations

import argparse
import re
from pathlib import Path

PROXY_RAW = "https://gh-proxy.com/raw.githubusercontent.com/clone-fan/mihomo-config/main"
NICHE_GROUP = "小众网站"

PASSWORD_DQ = re.compile(r'password:\s*"[^"]*"')
PASSWORD_SQ = re.compile(r"password:\s*'[^']*'")
URL_ANY = re.compile(r"""url:\s*['"][^'"]+['"]""")


def sanitize(text: str) -> str:
    lines = text.splitlines()
    out = []
    i = 0
    while i < len(lines):
        line = lines[i]

        if i == 0 and line.startswith("#"):
            out.extend(
                [
                    "# mihomo-config / smart config template",
                    "# Replace before use: airport subscription URL, home SS password, NIC, ports",
                    "# mihomo smart releases: https://github.com/vernesong/mihomo/releases",
                    "",
                ]
            )
            i += 1
            while i < len(lines) and (lines[i].startswith("#") or lines[i].strip() == ""):
                s = lines[i].strip()
                body_starts = (
                    s.startswith("mixed-port")
                    or s.startswith("port:")
                    or s.startswith("mode:")
                    or s.startswith("proxies:")
                    or s.startswith("proxy-groups:")
                    or s.startswith("rule-providers:")
                    or s.startswith("rules:")
                    or s.startswith("dns:")
                    or s.startswith("tun:")
                    or s.startswith("external-controller")
                    or s.startswith("allow-lan")
                    or s.startswith("bind-address")
                    or s.startswith("log-level")
                    or s.startswith("ipv6")
                    or s.startswith("profile:")
                    or s.startswith("sniffer:")
                    or s.startswith("listeners:")
                    or s.startswith("proxy-providers:")
                    or s.startswith("hosts:")
                )
                if body_starts:
                    break
                i += 1
            continue

        if "password:" in line:
            window = "\n".join(lines[max(0, i - 6) : i + 3])
            if any(k in window for k in ("SS-IN", "ss-in", "listeners", "inbound")):
                line = PASSWORD_DQ.sub('password: "REPLACE_ME_SS_PASSWORD"', line)
                line = PASSWORD_SQ.sub("password: 'REPLACE_ME_SS_PASSWORD'", line)

        if "url:" in line and "Airport" in "\n".join(lines[max(0, i - 8) : i + 1]):
            line = URL_ANY.sub("url: 'REPLACE_ME_AIRPORT_SUBSCRIPTION_URL'", line, count=1)

        if line.strip() == "rule-providers:":
            out.append(line)
            out.append("  # custom rulesets from this repo")
            out.append(
                "  my_direct: {type: http, interval: 86400, behavior: classical, format: yaml, url: '%s/ruleset/direct.yaml'}"
                % PROXY_RAW
            )
            out.append(
                "  my_proxy:  {type: http, interval: 86400, behavior: classical, format: yaml, url: '%s/ruleset/proxy.yaml'}"
                % PROXY_RAW
            )
            i += 1
            while i < len(lines) and (
                lines[i].strip().startswith("my_direct:")
                or lines[i].strip().startswith("my_proxy:")
                or lines[i].strip().startswith("# custom rulesets")
            ):
                i += 1
            if i < len(lines) and lines[i].strip().startswith("#Domain_direct"):
                out.append("  # Domain_direct")
                i += 1
            continue

        if line.strip() == "- RULE-SET,gamedownload_direct,DIRECT":
            out.append(line)
            if not (
                i + 1 < len(lines)
                and lines[i + 1].strip() == "- RULE-SET,my_direct,DIRECT"
            ):
                out.append("  - RULE-SET,my_direct,DIRECT")
            i += 1
            if i < len(lines) and lines[i].strip() == "- RULE-SET,my_direct,DIRECT":
                i += 1
            continue

        s = line.strip()
        niche_inline = s.startswith("- DOMAIN-") and s.endswith("," + NICHE_GROUP)
        niche_comment = ("自定义规则" in s) or ("小众网站" in s and s.startswith("#"))
        if niche_comment or niche_inline:
            if not any(x.strip() == "- RULE-SET,my_proxy," + NICHE_GROUP for x in out[-12:]):
                out.append("    # custom ruleset (niche / multi-hit proxy)")
                out.append("  - RULE-SET,my_proxy," + NICHE_GROUP)
            i += 1
            while i < len(lines):
                t = lines[i].strip()
                if t.startswith("- DOMAIN-") and t.endswith("," + NICHE_GROUP):
                    i += 1
                    continue
                if t.startswith("#") and ("小众网站" in t or "自定义" in t):
                    i += 1
                    continue
                break
            continue

        out.append(line)
        i += 1

    return "\n".join(out).rstrip() + "\n"


def main() -> None:
    ap = argparse.ArgumentParser(description="Sanitize live mihomo config into a template")
    ap.add_argument("--input", required=True)
    ap.add_argument("--output", required=True)
    args = ap.parse_args()
    src = Path(args.input).read_text(encoding="utf-8")
    Path(args.output).parent.mkdir(parents=True, exist_ok=True)
    Path(args.output).write_text(sanitize(src), encoding="utf-8", newline="\n")
    print("wrote %s" % args.output)


if __name__ == "__main__":
    main()