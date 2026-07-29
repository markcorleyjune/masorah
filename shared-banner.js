/* ════════════════════════════════════════════════════════════
   Masorah — shared-banner.js  (v1, 2026-07-30)

   Single source of truth for three things that were drifting
   page-to-page across the workbench:
     1. Brand-glyph click target (gated tool pages -> workbench.html;
        public pages [archives.html, map.html] -> index.html).
     2. The "A− 100% A+" UI zoom control — same localStorage key
        ('masorah.scale') and same 70-160% clamp everywhere, so
        changing zoom on one page carries to the next.
     3. A lightweight runtime check against the server's canonical
        nav list (GET /api/v1/system/nav, main_api.py) that logs a
        console warning if a page's <nav class="nav"> has drifted
        from the declared source of truth — this is the "tool to
        make sure info is shared/updated and consistent" (item 7).

   Usage: include right before </body>, optionally preceded by
     <script>window.MASORAH_BRAND_TARGET='index.html';</script>
   on public pages (default is 'workbench.html').

   workbench.html and publish.html already implement all of this
   inline (they predate this file) — this script no-ops around
   anything already present rather than duplicating it.
   ════════════════════════════════════════════════════════════ */
(function () {
  function ready(fn) {
    if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', fn);
    else fn();
  }

  ready(function () {
    wireBrandClick();
    injectFontCtrl();
    checkNavConsistency();
  });

  // ── 1. Brand click ──────────────────────────────────────────
  function wireBrandClick() {
    var brand = document.querySelector('.brand');
    if (!brand) return;
    var here = (location.pathname.split('/').pop() || '').toLowerCase();
    var target = window.MASORAH_BRAND_TARGET || 'workbench.html';
    if (here === target) return; // already home; leave any existing handler alone
    brand.style.cursor = 'pointer';
    brand.onclick = function () { location.href = target; };
  }

  // ── 2. Zoom / UI scale control ──────────────────────────────
  window.szPct = parseInt(localStorage.getItem('masorah.scale') || '100', 10);
  window.applyScale = function () {
    document.documentElement.style.fontSize = (window.szPct * 0.16) + 'px'; // 16px base × pct/100
    var lbl = document.getElementById('szLbl');
    if (lbl) lbl.textContent = window.szPct + '%';
    localStorage.setItem('masorah.scale', window.szPct);
  };
  window.scale = function (dir) {
    window.szPct = Math.max(70, Math.min(160, window.szPct + dir * 5));
    window.applyScale();
  };

  function injectFontCtrl() {
    if (document.querySelector('.font-ctrl')) { window.applyScale(); return; } // workbench.html / publish.html already have one
    var cluster = document.querySelector('.status-cluster');
    if (!cluster) return;
    var css = document.createElement('style');
    css.textContent =
      ".font-ctrl{display:flex;align-items:center;border:1px solid var(--bdr);border-radius:20px;background:var(--paper);overflow:hidden}" +
      ".font-ctrl button{border:none;background:transparent;padding:5px 11px;cursor:pointer;font-family:'Cinzel',serif;font-weight:600;color:var(--gold-dk);transition:background .14s}" +
      ".font-ctrl button:hover{background:var(--gold-pale)}" +
      ".font-ctrl .sz{font-size:11px;padding:5px 9px;color:var(--ink3);border-left:1px solid var(--bdr);border-right:1px solid var(--bdr);min-width:46px;text-align:center}";
    document.head.appendChild(css);
    var wrap = document.createElement('div');
    wrap.className = 'font-ctrl';
    wrap.title = 'Adjust UI scale';
    wrap.innerHTML = '<button onclick="scale(-1)" aria-label="Decrease">A−</button><span class="sz" id="szLbl">100%</span><button onclick="scale(1)" aria-label="Increase">A+</button>';
    cluster.insertBefore(wrap, cluster.firstChild ? cluster.firstChild.nextSibling : null);
    window.applyScale();
  }

  // ── 3. Nav-drift check against server-declared canonical list ──
  function checkNavConsistency() {
    var API_BASE = window.API_BASE || 'http://localhost:8000';
    var here = (location.pathname.split('/').pop() || '').toLowerCase();
    fetch(API_BASE + '/api/v1/system/nav', { signal: AbortSignal.timeout(3000) })
      .then(function (r) { return r.json(); })
      .then(function (d) {
        if (!d.nav) return;
        var local = Array.prototype.map.call(document.querySelectorAll('.nav a'), function (a) { return a.getAttribute('href'); });
        var canonical = d.nav.map(function (n) { return n.href; }).filter(function (h) { return h !== here; });
        var missing = canonical.filter(function (h) { return local.indexOf(h) === -1; });
        var extra = local.filter(function (h) { return canonical.indexOf(h) === -1 && h !== here; });
        if (missing.length || extra.length) {
          console.warn('[masorah-nav-check] ' + here + ' nav has drifted from /api/v1/system/nav — missing:', missing, 'extra:', extra);
        }
      })
      .catch(function () { /* API offline — silent, probeAPI() on each page already surfaces this */ });
  }
})();
