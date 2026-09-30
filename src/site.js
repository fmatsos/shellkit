/* shellkit site: the animations switch, reveal on scroll, copy buttons, hero tilt. */
(() => {
  const html = document.documentElement, btn = document.getElementById("motion"), status = document.getElementById("status");
  const on = () => html.dataset.motion === "on";

  // RGAA 13.8: every looping animation can be stopped, and the choice sticks
  btn.hidden = false;
  btn.setAttribute("aria-pressed", String(on()));
  btn.addEventListener("click", () => {
    html.dataset.motion = on() ? "off" : "on";
    btn.setAttribute("aria-pressed", String(on()));
    try { localStorage.setItem("shkit-motion", html.dataset.motion); } catch (e) {}
  });

  // decorative sprites wait for the page: they never compete with the hero image
  addEventListener("load", () => document.querySelectorAll("img[data-src]").forEach(i => { i.src = i.dataset.src; }));

  // pop-in on scroll: only what's below the fold, never the hero (LCP)
  const items = document.querySelectorAll(".reveal");
  if ("IntersectionObserver" in window) {
    const io = new IntersectionObserver(es => es.forEach(e => {
      if (e.isIntersecting) { e.target.classList.add("in"); io.unobserve(e.target); }
    }), { rootMargin: "0px 0px -10% 0px" });
    items.forEach(el => { if (el.getBoundingClientRect().top < innerHeight) el.classList.add("in"); else io.observe(el); });
    html.classList.add("ready");
  }

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
})();
