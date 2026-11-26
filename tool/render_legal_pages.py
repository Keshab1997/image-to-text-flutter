#!/usr/bin/env python3
"""Render the two Markdown policy drafts as dependency-free GitHub Pages HTML."""

from __future__ import annotations

import html
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1] / "docs" / "legal"


def inline(markdown: str) -> str:
    text = html.escape(markdown, quote=True)
    text = re.sub(r"\[([^\]]+)\]\(([^)]+)\)", r'<a href="\2">\1</a>', text)
    text = re.sub(r"\*\*(.+?)\*\*", r"<strong>\1</strong>", text)
    text = re.sub(r"`([^`]+)`", r"<code>\1</code>", text)
    return text


def render_body(markdown: str) -> str:
    lines = markdown.splitlines()
    body: list[str] = []
    index = 0
    while index < len(lines):
        line = lines[index].strip()
        if not line:
            index += 1
            continue
        if line.startswith("# "):
            index += 1
            continue
        if line.startswith("**Effective date:**"):
            items = []
            while index < len(lines) and lines[index].strip().startswith("**"):
                items.append(lines[index].strip())
                index += 1
            body.append(
                '<p class="meta">'
                + "<br>".join(inline(item) for item in items)
                + "</p>"
            )
            continue
        if line.startswith("## "):
            body.append(f"<h2>{inline(line[3:])}</h2>")
            index += 1
            continue
        if line.startswith("- "):
            items = []
            while index < len(lines) and lines[index].strip().startswith("- "):
                items.append(f"<li>{inline(lines[index].strip()[2:])}</li>")
                index += 1
            body.append("<ul>" + "".join(items) + "</ul>")
            continue

        paragraph = [line]
        index += 1
        while index < len(lines) and lines[index].strip() and not lines[
            index
        ].strip().startswith(("## ", "- ", "# ")):
            paragraph.append(lines[index].strip())
            index += 1
        body.append(f"<p>{inline(' '.join(paragraph))}</p>")
    return "\n".join(body)


def render_page(
    *, title: str, description: str, source: str, other_slug: str, other_title: str
) -> str:
    content = render_body((ROOT / source).read_text(encoding="utf-8"))
    return f'''<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <meta name="description" content="{html.escape(description, quote=True)}">
  <meta name="theme-color" content="#f97316">
  <title>{html.escape(title)} · SnapText OCR</title>
  <style>
    :root {{ color-scheme: light; --ink:#202124; --muted:#62666c; --line:#e5e7eb; --accent:#c2410c; --paper:#fff; --canvas:#f6f7f8; }}
    * {{ box-sizing:border-box; }}
    body {{ margin:0; background:var(--canvas); color:var(--ink); font:16px/1.72 system-ui,-apple-system,"Segoe UI",sans-serif; }}
    header {{ background:var(--paper); border-bottom:1px solid var(--line); }}
    .top {{ max-width:900px; margin:auto; padding:18px 22px; display:flex; justify-content:space-between; align-items:center; gap:16px; }}
    .brand {{ font-weight:800; letter-spacing:-.03em; color:var(--ink); text-decoration:none; }}
    nav {{ display:flex; flex-wrap:wrap; gap:16px; }}
    nav a, a {{ color:var(--accent); }}
    nav a {{ font-size:14px; font-weight:650; text-decoration:none; }}
    main {{ max-width:820px; margin:42px auto; padding:42px clamp(22px,6vw,64px); background:var(--paper); border:1px solid var(--line); border-radius:18px; box-shadow:0 10px 28px rgba(20,25,30,.04); }}
    .eyebrow {{ margin:0 0 6px; color:var(--accent); text-transform:uppercase; letter-spacing:.12em; font-size:12px; font-weight:800; }}
    h1 {{ margin:0; font-size:clamp(30px,5vw,42px); line-height:1.16; letter-spacing:-.04em; }}
    .meta {{ margin:14px 0 30px; color:var(--muted); font-size:14px; }}
    h2 {{ margin:34px 0 10px; font-size:21px; line-height:1.35; letter-spacing:-.02em; }}
    p {{ margin:12px 0; }}
    ul {{ padding-left:24px; }}
    li {{ margin:9px 0; padding-left:4px; }}
    code {{ background:#f1f2f4; border-radius:4px; padding:2px 5px; font-size:.92em; }}
    footer {{ max-width:820px; margin:-18px auto 36px; padding:0 22px; color:var(--muted); font-size:13px; }}
    @media(max-width:600px) {{ .top {{ align-items:flex-start; flex-direction:column; }} main {{ margin:18px 12px 32px; padding:28px 22px; }} footer {{ margin:0 12px 28px; }} }}
  </style>
</head>
<body>
<header><div class="top"><a class="brand" href="../">SnapText OCR</a><nav aria-label="Policies"><a href="../{other_slug}/">{html.escape(other_title)}</a><a href="mailto:keshabstudios@gmail.com">Contact</a></nav></div></header>
<main><p class="eyebrow">Keshab Studios · Policy</p><h1>{html.escape(title)}</h1>
{content}
</main>
<footer>© 2026 Keshab Studios · Questions? <a href="mailto:keshabstudios@gmail.com">keshabstudios@gmail.com</a></footer>
</body>
</html>
'''


PAGES = (
    {
        "slug": "privacy-policy",
        "title": "Privacy Policy",
        "description": "How SnapText OCR handles images, OCR text, scan history, permissions, and your privacy.",
        "source": "privacy-policy.md",
        "other_slug": "terms-and-conditions",
        "other_title": "Terms & Conditions",
    },
    {
        "slug": "terms-and-conditions",
        "title": "Terms & Conditions",
        "description": "Terms for using SnapText OCR, its OCR results, user content, and services.",
        "source": "terms-and-conditions.md",
        "other_slug": "privacy-policy",
        "other_title": "Privacy Policy",
    },
)

for page in PAGES:
    output = ROOT / "site" / page["slug"] / "index.html"
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(
        render_page(
            title=page["title"],
            description=page["description"],
            source=page["source"],
            other_slug=page["other_slug"],
            other_title=page["other_title"],
        ),
        encoding="utf-8",
    )
    print(output.relative_to(ROOT.parent.parent))
