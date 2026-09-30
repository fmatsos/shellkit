# shellkit website

The `gh-pages` branch: <https://fmatsos.github.io/shellkit/>, served as is (`.nojekyll`).

| Path | Role |
|------|------|
| `src/layout.html` | every page: head (meta, Open Graph), header, footer |
| `src/home.html` | the landing page's content |
| `src/site.css`, `src/site.js` | inlined into each page by `build.py` |
| `build.py` | builds `index.html`, `docs/*.html`, `sitemap.html` |
| `assets/` | images (Codex-generated illustrations, sprites), fonts (OFL, `fonts/LICENSE.txt`) |

`docs/`, `index.html` and `sitemap.html` are generated: edit `src/`, then

```bash
python3 build.py ~/shellkit/docs    # main's docs/; needs gh logged in
```

and commit the result. On `main`, `.github/workflows/pages.yml` does the same at every
push that touches `docs/`.

The site targets RGAA 4.1 and a Lighthouse score of 100 in each category: every page has
a skip link, the same menu and footer, a site map; looping animations only run under
`html[data-motion="on"]`, which the **Animations** button turns off (and which is off
without JavaScript or with `prefers-reduced-motion`).

The landing page is one full-screen section per topic (`.sec`), each with its crab
sprite (`.buddy`, sheets in `assets/crab-*.webp`, 6 frames of 128 px). `site.js` marks
the section under the middle of the screen `.active`, which plays its entrance, and
drives the rail on the right (section links, the crab thumb can be dragged). Snapping is
`mandatory` only when every section fits the screen, `proximity` otherwise.
