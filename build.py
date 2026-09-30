#!/usr/bin/env python3
"""Build the shellkit site: index.html, docs/*.html and sitemap.html, from src/ and a docs/ dir.

    python3 build.py DOCS_DIR      # DOCS_DIR: docs/ of a shellkit checkout (branch main)

The Markdown is rendered by GitHub's own API (`gh api markdown`, needs gh logged in or
GH_TOKEN), so a page reads as it does on github.com. The build fails when an internal
link or anchor of the output doesn't resolve, or when GitHub's markup changed under the
rewrites below: fix build.py then, don't ship broken pages.
Run by .github/workflows/pages.yml on main at every push that touches docs/.
"""
import html
import posixpath
import re
import shutil
import struct
import subprocess
import sys
from pathlib import Path

SITE = Path(__file__).resolve().parent
SRC = SITE / "src"
URL = "https://fmatsos.github.io/shellkit/"
REPO = "https://github.com/fmatsos/shellkit"
TAGLINE = ("A plain zsh / bash setup for Linux and macOS, with an async, themeable prompt "
           "that never makes you wait for the network. No framework, zsh starts in about 35 ms.")


def fail(msg):
    sys.exit(f"build.py: {msg}")


def text(fragment):
    return html.unescape(re.sub(r"<[^>]+>", "", fragment)).strip()


def inline_md(s):
    """`code` in a title from docs/README.md."""
    return re.sub(r"`([^`]+)`", r"<code>\1</code>", html.escape(s, quote=False))


def render(md):
    return subprocess.run(["gh", "api", "markdown", "-f", "mode=markdown", "-F", f"text=@{md}"],
                          check=True, capture_output=True, text=True).stdout


def png_size(path):
    data = path.read_bytes()[:24]
    if data[:8] != b"\x89PNG\r\n\x1a\n":
        fail(f"{path}: only PNG images are supported in docs/")
    return struct.unpack(">II", data[16:24])


def rewrite_href(href):
    """A link of a docs/*.md, as seen from docs/<page>.html."""
    if re.match(r"[a-z]+:|#", href):
        return href
    m = re.fullmatch(r"([\w.-]+)\.md(#.*)?", href)
    if m:
        return ("index.html" if m[1] == "README" else f"{m[1]}.html") + (m[2] or "")
    m = re.fullmatch(r"\.\./README\.md(#.*)?", href)
    if m:
        return "../" + (m[1] or "")
    if href.startswith("../"):
        path = href[3:]
        return f"{REPO}/{'tree' if path.endswith('/') else 'blob'}/main/{path}"
    fail(f"unexpected link {href!r}")


def convert(raw, docs, out_assets):
    """GitHub's HTML -> ours: plain headings with ids, table regions, no presentational markup."""
    h = re.sub(r'<div class="markdown-heading"><h([1-6]) class="heading-element">(.*?)</h\1>'
               r'<a id="user-content-([^"]+)" class="anchor"[^>]*>.*?</a></div>',
               r'<h\1 id="\3">\2</h\1>', raw, flags=re.S)
    # lang="text" on a code block isn't a language (RGAA 8.7): drop it with GitHub's other noise
    h = re.sub(r' (?:dir="auto"|class="notranslate"|role="table"|data-component="Octicon"|style="[^"]*"|lang="[^"]*")', "", h)
    h = h.replace("octicon mr-2", "octicon").replace('<p align="center">', '<p class="center">')

    # a table scrolls on its own on a narrow screen: a named, focusable region (RGAA 10.11, 12.8)
    out, last = [], "Table"
    for part in re.split(r"(<h[2-6] id=\"[^\"]+\">.*?</h[2-6]>|<markdown-accessiblity-table>|</markdown-accessiblity-table>)", h):
        if part.startswith("<h"):
            last = text(part)
        elif part == "<markdown-accessiblity-table>":
            part = f'<div class="table" tabindex="0" role="region" aria-label="Table: {html.escape(last)}">'
        elif part == "</markdown-accessiblity-table>":
            part = "</div>"
        out.append(part)
    h = "".join(out)

    h = re.sub(r'<a [^>]*href="assets/[^"]*"[^>]*>(<img [^>]*>)</a>', r"\1", h)  # GitHub links each image to itself
    h = re.sub(r'href="([^"]*)"', lambda m: f'href="{html.escape(rewrite_href(html.unescape(m[1])))}"', h)

    def img(m):
        tag, src = m[0], m[1].split("?")[0]
        if not src.startswith("assets/"):
            fail(f"image outside docs/assets: {src}")
        (out_assets / Path(src).name).write_bytes((docs / src).read_bytes())
        w, hh = png_size(docs / src)
        tag = re.sub(r' (?:width|height)="[^"]*"', "", tag).replace(f'src="{m[1]}"', f'src="{src}"')
        return tag.replace("<img ", f'<img width="{w}" height="{hh}" loading="lazy" ', 1)
    h = re.sub(r'<img src="([^"]+)"[^>]*>', img, h)

    for bad in ("user-content-", "align=", "markdown-heading", "markdown-accessiblity", r'href="(?![a-z]+:)[^"]*\.md[#"]'):
        if re.search(bad, h):
            fail(f"GitHub's markup changed: {bad!r} left in the output, update convert()")
    return h


def page(layout, css, js, *, root, path, title, og_title, description, main, head="", docs_current="", sitemap_current=""):
    out = layout
    for k, v in (("head", head), ("css", css), ("js", js), ("main", main), ("title", html.escape(title)),
                 ("og_title", html.escape(og_title)), ("description", html.escape(description)),
                 ("url", URL + path.replace("index.html", "")), ("site", URL), ("docs_current", docs_current),
                 ("sitemap_current", sitemap_current), ("root", root)):
        out = out.replace("{{" + k + "}}", v)
    if "{{" in out:
        fail(f"{path}: unfilled placeholder {re.search(r'{{[^}]*}}', out)[0]}")
    (SITE / path).write_text(out)
    return out


def check_links(pages):
    """Every internal href must hit a built page, and its #fragment an id there."""
    ids = {p: set(re.findall(r' id="([^"]+)"', h)) for p, h in pages.items()}
    for p, h in pages.items():
        base = posixpath.dirname(p)
        for href in re.findall(r'href="([^"]+)"', h):
            href = html.unescape(href)
            if re.match(r"[a-z]+:", href):
                continue
            target, _, frag = href.partition("#")
            t = posixpath.normpath(posixpath.join(base, target)) if target else p
            if target.endswith("/") or t in (".", "docs"):
                t = posixpath.normpath(posixpath.join(t, "index.html"))
            if t not in pages:
                if (SITE / t).is_file() and not frag:
                    continue
                fail(f"{p}: broken link {href}")
            if frag and frag not in ids[t]:
                fail(f"{p}: no #{frag} in {t}")


def main():
    if len(sys.argv) != 2:
        fail("usage: build.py DOCS_DIR")
    docs = Path(sys.argv[1]).resolve()
    layout, css, js = ((SRC / f).read_text() for f in ("layout.html", "site.css", "site.js"))

    # the order and short descriptions come from docs/README.md
    toc = [(m[2], m[1], m[3]) for m in re.finditer(r"^\d+\. \[(.+?)\]\(([\w-]+)\.md\)(?::\s*(.+))?$",
                                                    (docs / "README.md").read_text(), re.M)]
    if not toc:
        fail("no page list in docs/README.md")

    out_docs = SITE / "docs"
    shutil.rmtree(out_docs, ignore_errors=True)
    (out_docs / "assets").mkdir(parents=True)

    rendered = {}
    for name in ["README"] + [n for n, _, _ in toc]:
        body = convert(render(docs / f"{name}.md"), docs, out_docs / "assets")
        m = re.match(r'\s*<h1 id="[^"]+">(.*?)</h1>\s*', body, re.S)
        if not m:
            fail(f"docs/{name}.md doesn't start with a # title")
        rendered[name] = (m[1], body[m.end():])

    pages = {}
    nav = "\n".join(f'<li><a href="{n}.html"{{cur_{n}}}>{inline_md(t)}</a></li>' for n, t, _ in toc)
    order = [n for n, _, _ in toc]
    for name, (h1, body) in rendered.items():
        index = name == "README"
        path = "docs/index.html" if index else f"docs/{name}.html"
        plain = text(h1)
        first_p = re.search(r"<p>(.*?)</p>", body, re.S)
        desc = next((d for n, _, d in toc if n == name and d), None) or (text(first_p[1]) if first_p else plain)
        desc = re.sub(r"\s+", " ", desc.replace("`", ""))
        desc = desc if len(desc) < 160 else desc[:156].rsplit(" ", 1)[0] + "…"
        pager = ""
        if not index:
            i = order.index(name)
            links = []
            if i > 0:
                links.append(f'<a class="prev" href="{order[i-1]}.html"><small>Previous</small>{inline_md(toc[i-1][1])}</a>')
            if i + 1 < len(order):
                links.append(f'<a class="next" href="{order[i+1]}.html"><small>Next</small>{inline_md(toc[i+1][1])}</a>')
            pager = f'<nav class="pager" aria-label="Previous and next pages">{"".join(links)}</nav>'
        side = nav
        for n in order:
            side = side.replace(f"{{cur_{n}}}", ' aria-current="page"' if n == name else "")
        main_html = (
            f'<div class="band"><div class="wrap"><div class="sticker">'
            + ("" if index else '<p class="kicker"><a href="index.html">shellkit docs</a></p>')
            + f'<h1>{h1}</h1></div></div></div>\n'
            f'<div class="wrap doc">\n<nav class="toc" aria-label="Documentation pages"><ul class="plain">\n{side}\n</ul></nav>\n'
            f'<div class="prose">\n{body}\n{pager}\n</div>\n</div>')
        pages[path] = page(layout, css, js, root="../", path=path,
                           title=f"{plain} · shellkit docs" if not index else "shellkit documentation",
                           og_title=plain, description=desc, main=main_html,
                           docs_current=' aria-current="page"' if index else "")

    cards = "\n".join(f'      <li><a href="docs/{n}.html"><b>{inline_md(t)}</b><span>{html.escape(d or text(re.search(r"<p>(.*?)</p>", rendered[n][1], re.S)[1]).split(". ")[0])}</span></a></li>'
                      for n, t, d in toc)
    home = (SRC / "home.html").read_text().replace("{{docs_cards}}", cards)
    ld = ('<script type="application/ld+json">{"@context":"https://schema.org","@type":"SoftwareSourceCode",'
          f'"name":"shellkit","description":"{TAGLINE}","codeRepository":"{REPO}",'
          '"programmingLanguage":"Shell","license":"https://unlicense.org","url":"' + URL + '"}</script>\n'
          '<link rel="preload" as="image" type="image/avif" imagesrcset="assets/hero-640.avif 640w, assets/hero-1200.avif 1200w" '
          'imagesizes="(max-width: 860px) calc(100vw - 44px), 560px" fetchpriority="high">')
    pages["index.html"] = page(layout, css, js, root="./", path="index.html", title="shellkit: a funky, plain zsh / bash setup",
                               og_title="shellkit", description=TAGLINE, main=home, head=ld)

    items = "\n".join(f'<li><a href="docs/{n}.html">{inline_md(t)}</a></li>' for n, t, _ in toc)
    sitemap = (f'<div class="band"><div class="wrap"><div class="sticker"><h1>Site map</h1></div></div></div>\n'
               f'<div class="wrap doc one"><div class="prose"><ul>\n'
               f'<li><a href="./">Home</a><ul><li><a href="./#features">Features</a></li><li><a href="./#start">Quick start</a></li></ul></li>\n'
               f'<li><a href="docs/">Documentation</a><ul>\n{items}\n</ul></li>\n'
               f'<li><a href="sitemap.html" aria-current="page">Site map</a></li>\n</ul></div></div>')
    pages["sitemap.html"] = page(layout, css, js, root="./", path="sitemap.html", title="Site map · shellkit",
                                 og_title="shellkit site map", description="Every page of the shellkit site.",
                                 main=sitemap, sitemap_current=' aria-current="page"')
    check_links(pages)
    print(f"build.py: {len(pages)} pages")


if __name__ == "__main__":
    main()
