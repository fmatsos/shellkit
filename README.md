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
