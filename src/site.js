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
  const stand = () => { if (at >= 0) { const [x, y] = spot(all[at]); hopper.style.transform = `translate(${x}px, ${y}px)`; } };
  const hop = () => {
    clearTimeout(timer);
    if (!on() || cur !== features) return;   // only while it can be seen
    const g = grid.getBoundingClientRect();
    // the cards fully in view, first row only: landing on a lower row would cover the text above it
    const seen = all.filter(c => { const k = c.getBoundingClientRect(); return k.left >= g.left - 2 && k.right <= g.right + 2 && k.top < all[0].getBoundingClientRect().bottom; });
    if (!seen.length) { timer = setTimeout(hop, 800); return; }
    const next = seen.find(c => all.indexOf(c) > at) || seen[0];   // one card in view: it bounces on it
    const from = at >= 0 ? spot(all[at]) : spot(next), to = spot(next);
    const flip = to[0] < from[0] ? " scaleX(-1)" : "", peak = Math.min(from[1], to[1]) - 90;
    const jump = hopper.animate([
      { transform: `translate(${from[0]}px, ${from[1]}px)${flip}`, easing: "ease-out" },
      { transform: `translate(${(from[0] + to[0]) / 2}px, ${peak}px)${flip}`, easing: "ease-in" },
      { transform: `translate(${to[0]}px, ${to[1]}px)${flip}` }], { duration: 700, fill: "forwards" });
    jump.onfinish = () => {
      at = all.indexOf(next); stand(); jump.cancel();
      next.animate([{ translate: "0 0" }, { translate: "0 12px", scale: "1.02 .96" }, { translate: "0 0" }], { duration: 400, easing: "ease-out" });
      timer = setTimeout(hop, 1100);
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
