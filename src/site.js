/* shellkit site: the animations switch, copy buttons, hero tilt; on the landing page the
   full-screen sections, their entrances and the scroll rail. */
(() => {
  const html = document.documentElement, btn = document.getElementById("motion"), status = document.getElementById("status");
  const on = () => html.dataset.motion === "on";

  // decorative sprites: loaded after the page, and only while animations are on
  let loaded = false;
  const sprites = () => {
    if (loaded || !on() || document.readyState !== "complete") return;
    loaded = true;
    document.querySelectorAll("img[data-src]").forEach(i => { i.src = i.dataset.src; });
  };
  addEventListener("load", sprites);

  // RGAA 13.8: every looping animation can be stopped, and the choice sticks
  btn.hidden = false;
  btn.setAttribute("aria-pressed", String(on()));
  btn.addEventListener("click", () => {
    html.dataset.motion = on() ? "off" : "on";
    btn.setAttribute("aria-pressed", String(on()));
    try { localStorage.setItem("shkit-motion", html.dataset.motion); } catch (e) {}
    sprites();
  });

  // copy buttons: the commands without prompts or comments, a status message, confetti
  const colors = ["#ff6b1a", "#ff2e88", "#14c4bd", "#ffd23f", "#7b3fe4"];
  const confetti = (x, y) => {
    for (let i = 0; i < 24; i++) {
      const c = document.createElement("span"), a = Math.random() * 2 * Math.PI, d = 60 + Math.random() * 90;
      c.className = "confetti";
      c.style.cssText = `left:${x}px;top:${y}px;background:${colors[i % colors.length]};--dx:${Math.cos(a) * d}px;--dy:${Math.sin(a) * d}px;--r:${Math.random() * 720}deg`;
      c.addEventListener("animationend", () => c.remove());
      document.body.append(c);
    }
  };
  document.querySelectorAll(".copy").forEach(b => b.addEventListener("click", () => {
    const text = b.previousElementSibling.innerText.split("\n")
      .map(l => l.replace(/^\$ /, "").replace(/\s+# .*$/, "")).join("\n").trim();
    navigator.clipboard.writeText(text).then(() => {
      status.textContent = "Commands copied to the clipboard.";
      if (on()) { const r = b.getBoundingClientRect(); confetti(r.left + r.width / 2, r.top + r.height / 2); }
    }, () => { status.textContent = "Copy failed: select the commands and copy them by hand."; });
    setTimeout(() => { status.textContent = ""; }, 4000);
  }));

  // hero art follows the pointer a little
  const art = document.querySelector(".art");
  if (art && matchMedia("(hover: hover)").matches) {
    art.parentElement.addEventListener("pointermove", e => {
      const r = art.getBoundingClientRect();
      art.style.setProperty("--tx", ((e.clientX - r.left) / r.width - .5) * 10 + "deg");
      art.style.setProperty("--ty", ((e.clientY - r.top) / r.height - .5) * -10 + "deg");
    });
    art.parentElement.addEventListener("pointerleave", () => { art.style.removeProperty("--tx"); art.style.removeProperty("--ty"); });
  }

  if (!html.classList.contains("landing")) return;

  // ---- landing: sections, one screen each ----
  const secs = [...document.querySelectorAll(".sec")], top = document.querySelector(".top");
  const links = [...document.querySelectorAll(".rail a")];
  const max = () => document.documentElement.scrollHeight - innerHeight;

  // the typed lines of the quick start: one span per line, shown one after the other
  document.querySelectorAll(".start pre").forEach(pre => {
    pre.innerHTML = pre.innerHTML.split("\n").map((l, i) => `<span class="ln" style="--i:${i}">${l}</span>`).join("\n");
  });

  // mandatory snapping only when every section fits the screen; proximity otherwise (zoom, small screens)
  const fit = () => {
    html.style.setProperty("--hh", top.offsetHeight + "px");
    const room = innerHeight - top.offsetHeight + 1;
    html.classList.toggle("snap", secs.every(s => s.offsetHeight <= room));
  };
  new ResizeObserver(fit).observe(top);
  // the features' crab jumps from card to card, and each card gives under it; positions come
  // from the cards themselves, so it works on 4 columns, 2 x 2 and the phone carousel alike
  const cards = document.querySelector(".cards"), grid = cards.querySelector(".grid"), hopper = cards.querySelector(".walker");
  const features = document.getElementById("features"), all = [...grid.children];
  let at = -1, timer;
  const spot = c => {  // standing on card c, in .cards coordinates
    const r = cards.getBoundingClientRect(), k = c.getBoundingClientRect();
    return [k.left - r.left + (k.width - hopper.offsetWidth) / 2, k.top - r.top - hopper.offsetHeight + 8];
  };
  // position in `translate`, the outermost transform: `scale` then squashes the crab around its feet
  // without scaling its offset, and `transform` only holds the flip, kept after landing
  const pose = ([x, y]) => `${x}px ${y}px`;
  const stand = () => { if (at >= 0) hopper.style.translate = pose(spot(all[at])); };
  const hop = () => {
    clearTimeout(timer);
    if (!on() || cur !== features) return;   // only while it can be seen
    const g = grid.getBoundingClientRect();
    // the cards fully in view, first row only: landing on a lower row would cover the text above it
    const seen = all.filter(c => { const k = c.getBoundingClientRect(); return k.left >= g.left - 2 && k.right <= g.right + 2 && k.top < all[0].getBoundingClientRect().bottom; });
    if (!seen.length) { timer = setTimeout(hop, 800); return; }
    const next = seen.find(c => all.indexOf(c) > at) || seen[0];   // one card in view: it bounces on it
    const from = at >= 0 ? spot(all[at]) : spot(next), to = spot(next);
    const dx = to[0] - from[0], dy = to[1] - from[1], dist = Math.hypot(dx, dy);
    if (Math.abs(dx) > 1) hopper.style.transform = dx < 0 ? "scaleX(-1)" : "";
    // a ballistic arc: x linear in time, y a parabola, sampled finely so nothing reads as a corner
    const height = Math.min(150, 50 + dist * .18), duration = Math.min(1150, 650 + dist * .6), n = 24;
    const frames = Array.from({ length: n + 1 }, (_, i) => {
      const t = i / n;
      return { translate: pose([from[0] + dx * t, from[1] + dy * t - 4 * height * t * (1 - t)]) };
    });
    // anticipation: crouch, stretch on take-off, squash on landing
    const crouch = hopper.animate([{ scale: "1 1" }, { scale: "1.08 .9" }], { duration: 160, easing: "ease-out", fill: "forwards" });
    crouch.onfinish = () => {
      crouch.cancel();
      hopper.animate([{ scale: "1.08 .9" }, { scale: ".94 1.08", offset: .25 }, { scale: "1 1", offset: .6 }, { scale: "1 1" }], { duration, easing: "linear" });
      const jump = hopper.animate(frames, { duration, easing: "linear", fill: "forwards" });
      jump.onfinish = () => {
        at = all.indexOf(next); stand(); jump.cancel();
        hopper.animate([{ scale: "1.1 .88" }, { scale: ".98 1.03", offset: .55 }, { scale: "1 1" }], { duration: 320, easing: "ease-out" });
        next.animate([{ translate: "0 0" }, { translate: "0 8px", scale: "1.01 .97" }, { translate: "0 0" }], { duration: 380, easing: "ease-out" });
        timer = setTimeout(hop, 1300);
      };
    };
  };
  btn.addEventListener("click", hop);
  grid.addEventListener("scroll", stand, { passive: true });
  addEventListener("resize", () => { hopper.getAnimations().forEach(a => a.cancel()); stand(); });
  addEventListener("resize", fit);

  // the section under the middle of the screen is the current one (the last one at the very bottom)
  let cur;
  const current = () => {
    const mid = innerHeight / 2, end = scrollY >= max() - 2;
    const s = end ? secs.at(-1) : secs.find(x => { const r = x.getBoundingClientRect(); return r.top <= mid && r.bottom > mid; });
    if (!s || s === cur) return;
    cur = s;
    secs.forEach(x => x.classList.toggle("active", x === s));
    links.forEach(a => a.getAttribute("href") === "#" + s.id ? a.setAttribute("aria-current", "true") : a.removeAttribute("aria-current"));
    hop();
  };

  // the rail: the crab thumb follows the scroll, and can be dragged; a click on the track jumps there
  const rail = document.querySelector(".rail"), thumb = rail.querySelector(".rail-thumb");
  // between sections, a transition of shellkit's own: it covers the screen, the page jumps under it,
  // then it uncovers the new section; each has its own (a wave, the prompt's segments, a sunburst,
  // polka dots, a crab-shell diamond, a book closing). One wheel step or arrow key is one move:
  // the rest of a tall section first, then the next section. Touch and motion off scroll natively.
  const veil = document.querySelector(".veil"), veilLine = veil.querySelector(".veil-line");
  const shapes = {
    wave: [["ellipse(150% 0% at 50% 100%)", "ellipse(150% 150% at 50% 100%)"], ["ellipse(150% 150% at 50% 0%)", "ellipse(150% 0% at 50% 0%)"]],
    segments: [["inset(0 100% 0 0)", "inset(0 0 0 0)"], ["inset(0 0 0 0)", "inset(0 0 0 100%)"]],
    sunburst: [["circle(0% at 50% 50%)", "circle(75% at 50% 50%)"], ["circle(75% at 50% 50%)", "circle(0% at 50% 50%)"]],
    dots: [["inset(0 0 100% 0)", "inset(0 0 0 0)"], ["inset(0 0 0 0)", "inset(100% 0 0 0)"]],
    shell: [["polygon(50% 50%, 50% 50%, 50% 50%, 50% 50%)", "polygon(50% -60%, 160% 50%, 50% 160%, -60% 50%)"], ["polygon(50% -60%, 160% 50%, 50% 160%, -60% 50%)", "polygon(50% 50%, 50% 50%, 50% 50%, 50% 50%)"]],
    book: [["inset(0 50% 0 50%)", "inset(0 0 0 0)"], ["inset(0 0 0 0)", "inset(0 50% 0 50%)"]],
  };
  const kinds = Object.keys(shapes);
  const label = s => { const a = links.find(l => l.getAttribute("href") === "#" + s.id); return a ? a.textContent.trim() : s.id; };
  const topOf = s => s.getBoundingClientRect().top + scrollY - top.offsetHeight;
  let moving = false, last = 0;
  const travel = s => {
    const y = Math.max(0, Math.round(topOf(s)));
    if (!on()) { scrollTo({ top: y, behavior: "instant" }); return; }
    moving = true;
    const kind = kinds[secs.indexOf(s) % kinds.length], [inn, out] = shapes[kind], ease = "cubic-bezier(.65, 0, .35, 1)";
    veil.dataset.kind = kind;
    veilLine.textContent = label(s);
    veil.classList.add("on");
    // timers drive the steps, the animations only draw them: a hidden tab holds animation events back
    const cover = veil.animate({ clipPath: inn }, { duration: 450, easing: ease, fill: "forwards" });
    setTimeout(() => scrollTo({ top: y, behavior: "instant" }), 450);
    setTimeout(() => {
      const reveal = veil.animate({ clipPath: out }, { duration: 500, easing: ease, fill: "forwards" });
      cover.cancel();
      setTimeout(() => { reveal.cancel(); veil.classList.remove("on"); moving = false; }, 500);
    }, 630);
  };
  const fine = matchMedia("(pointer: fine)");
  addEventListener("wheel", e => {
    if (!on() || !fine.matches || e.ctrlKey || Math.abs(e.deltaX) > Math.abs(e.deltaY)) return;
    e.preventDefault();
    const now = performance.now(), fresh = now - last > 200;   // a trackpad's inertia counts once
    last = now;
    if (!fresh || moving) return;
    step(Math.sign(e.deltaY));
  }, { passive: false });
  // the arrow keys step the same way, except in a form field
  addEventListener("keydown", e => {
    if (!on() || !["ArrowDown", "ArrowUp"].includes(e.key)) return;
    if (e.altKey || e.ctrlKey || e.metaKey || e.shiftKey || e.target.closest("input, textarea, select, [contenteditable]")) return;
    e.preventDefault();
    if (!moving) step(e.key === "ArrowDown" ? 1 : -1);
  });
  function step(dir) {
    const hh = top.offsetHeight, i = secs.indexOf(cur), s = secs[i];
    const r = s.getBoundingClientRect();
    if (dir > 0) {
      if (r.bottom > innerHeight + 2) scrollTo({ top: scrollY + Math.min(r.bottom - innerHeight, (innerHeight - hh) * .8), behavior: "smooth" });
      else if (secs[i + 1]) travel(secs[i + 1]);
    } else {
      if (r.top < hh - 2) scrollTo({ top: scrollY - Math.min(hh - r.top, (innerHeight - hh) * .8), behavior: "smooth" });
      else if (secs[i - 1]) travel(secs[i - 1]);
    }
  }
  document.querySelectorAll("a[href^='#']").forEach(a => {
    const s = secs.find(x => "#" + x.id === a.getAttribute("href"));
    if (s) a.addEventListener("click", e => {
      if (!on() || e.metaKey || e.ctrlKey || e.shiftKey || e.altKey) return;
      e.preventDefault();
      history.pushState(null, "", "#" + s.id);
      if (s !== cur && !moving) travel(s);
    });
  });

  const place = () => { thumb.style.transform = `translateY(${(scrollY / Math.max(1, max())) * (rail.clientHeight - thumb.offsetHeight)}px)`; };
  addEventListener("scroll", () => { current(); requestAnimationFrame(place); }, { passive: true });
  ["load", "hashchange", "resize"].forEach(e => addEventListener(e, () => { current(); place(); }));
  place(); current();
  html.classList.add("ready");
  const toY = e => {
    const r = rail.getBoundingClientRect();
    return Math.min(1, Math.max(0, (e.clientY - r.top - thumb.offsetHeight / 2) / (r.height - thumb.offsetHeight))) * max();
  };
  thumb.addEventListener("pointerdown", e => {
    e.preventDefault(); thumb.setPointerCapture(e.pointerId); html.classList.add("dragging");
    const move = ev => scrollTo({ top: toY(ev), behavior: "instant" });
    const up = () => { html.classList.remove("dragging"); thumb.removeEventListener("pointermove", move); thumb.removeEventListener("pointerup", up); };
    thumb.addEventListener("pointermove", move); thumb.addEventListener("pointerup", up);
  });
  rail.addEventListener("click", e => { if (!e.target.closest("a") && !e.target.closest(".rail-thumb")) scrollTo({ top: toY(e) }); });
  // WCAG 1.4.13: Escape hides the labels shown on hover / focus
  addEventListener("keydown", e => { if (e.key === "Escape") rail.classList.add("quiet"); });
  rail.addEventListener("pointerleave", () => rail.classList.remove("quiet"));
  rail.addEventListener("focusout", () => rail.classList.remove("quiet"));
})();
