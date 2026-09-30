---
name: website
description: Maintain the shellkit website (https://fmatsos.github.io/shellkit/, branch gh-pages) — the landing page, the docs pages built from main's docs/, the templates, CSS and JS, the Pages workflow, and its bar: RGAA 4.1, Lighthouse 100 in every category, Linux-and-macOS-agnostic static files. Use for any change to the site's content, look, animations or build, when a doc change doesn't show up on the site, when the Pages build fails, or to re-check its scores.
---

# The website

The site is the `gh-pages` branch, served as is (`.nojekyll`). Nothing of it is on
`main` except `.github/workflows/pages.yml`, which rebuilds its docs pages.

| On `gh-pages` | Role |
|---------------|------|
| `src/layout.html` | every page: head (meta, Open Graph, fonts preload), header, footer |
| `src/home.html` | the landing page: one `<section class="sec">` per screen, the rail |
| `src/site.css`, `src/site.js` | inlined into every page by `build.py` |
| `build.py` | writes `index.html`, `docs/*.html`, `sitemap.html` (stdlib only) |
| `assets/` | images, sprites, fonts (OFL), `og.jpg`: see the `visuals` skill |
| `index.html`, `docs/`, `sitemap.html` | **generated**: never edit by hand |

## Working on it

Work in a worktree, never switch the main checkout (it holds the user's work):

```bash
W=<scratch dir>/site
git -C ~/www/config fetch -q origin
git -C ~/www/config worktree add "$W" gh-pages && git -C "$W" pull -q --ff-only
python3 "$W/build.py" ~/www/config/docs     # main's docs/; needs gh logged in
python3 -m http.server -d "$W" 8765          # run_in_background; http://localhost:8765/
```

`build.py` renders each `docs/*.md` with GitHub's Markdown API (`gh api markdown`), in the
landing page's design, and **fails** on: a link or `#anchor` that resolves to nothing, a
`.md` href left, GitHub markup it no longer recognises (`markdown-heading`,
`user-content-`, `align=`). A failure is a real bug: fix the doc on `main`, or `convert()`
when GitHub changed its HTML. Page order and short descriptions come from the numbered
list in `docs/README.md`; a new doc page only needs its line there. `docs/assets/*.png`
referenced by a doc are copied along.

Placeholders `{{…}}` in `src/` are filled by `page()`; `{{root}}` is `./` or `../`. URLs
stay relative (the site lives under `/shellkit/`), except canonical and `og:*`, absolute.

## Rules the site keeps

**Accessibility (RGAA 4.1).** Lighthouse 100 is necessary, not sufficient: keep these by design.
- Every page: the skip link to `#main`, `header` / `nav` / `main` / `footer`, the same menu
  and footer, the site map linked from the footer (12.1–12.4), one `h1`, headings in order.
- Every loop runs only under `html[data-motion="on"]`; the **Animations** button
  (`aria-pressed`) sets it, `prefers-reduced-motion` and no-JS mean off (13.8). A "not shown
  yet" state needs `.ready` too, and animates opacity / transform only: the content stays
  in the DOM and its final state is visible. The hero is never hidden (it is the LCP).
- Decorative images (sprites, the header mascot) have `alt=""` and `aria-hidden` wrappers;
  informative ones a real `alt`. A drawing of text (the terminal) is `role="img"` + `aria-label`.
- Contrast ≥ 4.5:1 (3:1 large text); the focus ring is two-tone (ink + cream) so it shows
  on every background. Links in text are underlined.
- Reflow at 320 px and forced text spacing (10.11, 10.12): sections use `min-height`,
  never `height`; code blocks `pre-wrap`; a wide table is a focusable `role="region"`.
- Status messages go through `#status` (`role="status"`). Labels shown on hover are inside
  their link, and Escape hides them.
- HTML must pass the W3C validator (8.2), inline CSS included: no `cqw` / `container-type`
  (the validator rejects them), no `lang="text"` (GitHub's code blocks: `convert()` drops it).
- Don't claim "RGAA-conformant": say what was checked; a formal claim needs a manual audit
  with a screen reader.

**Performance (Lighthouse 100, mobile).**
- Fonts are self-hosted, preloaded, `font-display: optional` (a late font must not
  reflow the page: that was the docs' CLS). Don't add a font or a weight lightly.
- The hero is a `<picture>` AVIF + WebP, 640 / 1200 w, preloaded with `fetchpriority`;
  cards are 4:3 crops, 480 / 800 w, lazy. Sprites load from `data-src` after `load`, and
  only while animations are on.
- No framework, no external request, CSS and JS inlined. Budget: HTML ≤ ~60 KB raw.

**The landing page.** One full-screen `.sec` per topic, each with its crab `.buddy`
(a 6-frame sprite) interacting with its content; `site.js` marks the section under the
middle of the screen `.active` (plays its entrance, sets `aria-current` in the rail).
Snapping is `mandatory` only when every section fits the screen, `proximity` otherwise.
Keep `#features` and `#start`: the menu links to them. New section: a `.sec` with an `id`,
its link in the rail, its buddy, and check it fits a 1280×800 screen.

## Checking

After `build.py`, before committing:

```bash
# HTML validity, every page (0 messages; one "info" on docs/blocks.html is a Nerd Font glyph in a code sample)
for f in index.html sitemap.html docs/*.html; do curl -s -H 'Content-Type: text/html; charset=utf-8' \
  --data-binary @"$W/$f" 'https://validator.w3.org/nu/?out=json' | python3 -c 'import json,sys
m=json.loads(sys.stdin.read(),strict=False)["messages"]; print(sys.argv[1],len(m),[x["message"][:80] for x in m])' "$f"; done
# Lighthouse (mobile, then --preset=desktop); locally ±2 points (no gzip), the live site is the reference
npx -y lighthouse@13 http://localhost:8765/ --quiet --chrome-flags=--headless=new --output=json --output-path=/tmp/lh.json
```

- Look at it: headless `--screenshot` for static layout (add `--force-prefers-reduced-motion`
  to see final states), a real Chrome for animations. Pitfalls: headless doesn't advance
  CSS animations; a background tab (`document.visibilityState == "hidden"`) runs neither
  smooth scrolling nor `requestAnimationFrame`, so hash jumps and entrances seem broken
  there when they aren't. For phone sizes, iframes at 390×844 and 320×640 in a scratch page.
- 320 px and text spacing: inject `*{line-height:1.5!important;letter-spacing:.12em!important;word-spacing:.16em!important}`
  into a copy and screenshot; nothing clipped, no horizontal scroll.
- The animations switch: click it, every loop stops, the choice survives a reload.

## Publishing

Committing to `gh-pages` publishes to a public site: push only when the user says so.
Before each commit, the two secret scans of `AGENTS.md` (Rule #1) on the worktree's index.
Commit the sources **and** the generated files together, with the session's attribution.

Then confirm it's live, not just pushed:

```bash
gh api repos/fmatsos/shellkit/pages/builds/latest --jq '"\(.status) \(.commit)"'   # built + your SHA
curl -s -o /dev/null -w '%{http_code}\n' https://fmatsos.github.io/shellkit/<page>
```

and re-run Lighthouse on the live URLs (the landing 3 times on mobile, median), since the
CDN's gzip is what the scores are about. Remove the worktree at the end
(`git -C ~/www/config worktree remove "$W"`).

**Docs pages follow `main` by themselves**: `pages.yml` runs at each push touching `docs/`
(or *Actions → pages → Run workflow*), commits as `github-actions[bot]` "docs: rebuild from
main@SHA" and requests a Pages build. So pull `gh-pages` before working on it. If a doc
change doesn't show: the workflow run's `Build` step (`build.py`'s message says why).
A change to `build.py` or `src/` doesn't trigger it: rebuild and commit it yourself.
