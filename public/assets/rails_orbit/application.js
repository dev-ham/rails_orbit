(() => {
  "use strict";

  // ── Poll Controller ───────────────────────────────────────────────────────

  class OrbitPollController {
    constructor(element) {
      this.element  = element;
      this.url      = element.dataset.orbitPollUrlValue;
      this.interval = parseInt(element.dataset.orbitPollIntervalValue, 10) || 5000;
      this.timer    = null;
    }

    start() {
      if (!this.url) return;
      this.poll();
      this.timer = setInterval(() => this.poll(), this.interval);
    }

    stop() {
      if (this.timer) { clearInterval(this.timer); this.timer = null; }
    }

    async poll() {
      try {
        const response = await fetch(this.url, {
          headers: { "Accept": "text/vnd.turbo-stream.html" }
        });
        if (!response.ok) return;

        const html = await response.text();
        if (!html) return;

        if (typeof Turbo !== "undefined" && Turbo.renderStreamMessage) {
          Turbo.renderStreamMessage(html);
        } else {
          this.fallbackUpdate(html);
        }
        this.refreshTimestamp();
      } catch (err) {
        // Silently swallow network errors — will retry on next interval
      }
    }

    fallbackUpdate(html) {
      const doc = new DOMParser().parseFromString(html, "text/html");
      for (const stream of doc.querySelectorAll("turbo-stream")) {
        const target = document.getElementById(stream.getAttribute("target"));
        if (!target) continue;
        const tpl = stream.querySelector("template");
        if (!tpl) continue;
        const action = stream.getAttribute("action");
        if (action === "update" || action === "replace") {
          target.innerHTML = tpl.innerHTML;
        }
      }
    }

    refreshTimestamp() {
      const el = document.getElementById("orbit-last-updated");
      if (!el) return;
      el.dataset.time = new Date().toISOString();
      el.textContent  = "Updated just now";
    }
  }

  // ── Timestamp Ticker ──────────────────────────────────────────────────────

  function startTimestampTicker() {
    setInterval(() => {
      const el = document.getElementById("orbit-last-updated");
      if (!el || !el.dataset.time) return;
      const s = Math.floor((Date.now() - new Date(el.dataset.time).getTime()) / 1000);
      if (s < 5)       el.textContent = "Updated just now";
      else if (s < 60) el.textContent = `Updated ${s}s ago`;
      else             el.textContent = `Updated ${Math.floor(s / 60)}m ago`;
    }, 5000);
  }

  // ── Interactive SVG Chart ─────────────────────────────────────────────────

  class OrbitChart {
    constructor(container) {
      this.container = container;
      this.data      = JSON.parse(container.dataset.chart || "[]");
      this.unit      = container.dataset.unit || "";
      this.color     = container.dataset.color || "var(--orbit-primary)";
      this.gradId    = container.dataset.gradientId || `orbit-grad-${Math.random().toString(36).slice(2, 8)}`;

      if (this.data.length > 0) this.render();
    }

    render() {
      const W = 700, H = 90, PAD_TOP = 5, PAD_BOT = 5;
      const { data, unit, color, gradId } = this;
      const vals  = data.map(d => d.v);
      const maxV  = Math.max(...vals) || 1;
      const minV  = Math.min(...vals);
      const range = maxV - minV || 1;
      const stepX = data.length > 1 ? W / (data.length - 1) : W;

      const yPos = v => PAD_TOP + ((maxV - v) / range) * (H - PAD_TOP - PAD_BOT);

      const points = data.map((d, i) => ({
        x: (i * stepX).toFixed(1),
        y: yPos(d.v).toFixed(1)
      }));

      const polyline = points.map(p => `${p.x},${p.y}`).join(" ");
      const polygon  = `0,${H} ${polyline} ${W},${H}`;

      const ns = "http://www.w3.org/2000/svg";
      const svg = document.createElementNS(ns, "svg");
      svg.setAttribute("viewBox", `0 0 ${W} ${H + 2}`);
      svg.setAttribute("preserveAspectRatio", "none");
      svg.setAttribute("class", "orbit-chart");

      svg.innerHTML =
        `<defs><linearGradient id="${gradId}" x1="0" y1="0" x2="0" y2="1">` +
        `<stop offset="0%" stop-color="${color}" stop-opacity="0.25"/>` +
        `<stop offset="100%" stop-color="${color}" stop-opacity="0.02"/>` +
        `</linearGradient></defs>` +
        `<polygon points="${polygon}" fill="url(#${gradId})"/>` +
        `<polyline points="${polyline}" fill="none" stroke="${color}" stroke-width="1.5" stroke-linejoin="round"/>`;

      const hitZones = document.createElementNS(ns, "g");
      hitZones.setAttribute("class", "orbit-chart__hitzone");

      for (let i = 0; i < points.length; i++) {
        const rect = document.createElementNS(ns, "rect");
        const x0 = i === 0 ? 0 : parseFloat(points[i].x) - stepX / 2;
        rect.setAttribute("x", x0);
        rect.setAttribute("y", 0);
        rect.setAttribute("width", stepX);
        rect.setAttribute("height", H);
        rect.setAttribute("fill", "transparent");
        rect.setAttribute("data-idx", i);
        hitZones.appendChild(rect);
      }
      svg.appendChild(hitZones);

      const dot = document.createElementNS(ns, "circle");
      dot.setAttribute("r", "3");
      dot.setAttribute("fill", color);
      dot.setAttribute("class", "orbit-chart__dot");
      dot.style.display = "none";
      svg.appendChild(dot);

      const vLine = document.createElementNS(ns, "line");
      vLine.setAttribute("y1", "0");
      vLine.setAttribute("y2", H);
      vLine.setAttribute("stroke", "var(--orbit-border-hover)");
      vLine.setAttribute("stroke-width", "1");
      vLine.setAttribute("stroke-dasharray", "2,2");
      vLine.setAttribute("class", "orbit-chart__vline");
      vLine.style.display = "none";
      svg.appendChild(vLine);

      const tooltip = document.createElement("div");
      tooltip.className = "orbit-chart__tooltip";
      tooltip.style.display = "none";

      const wrap = document.createElement("div");
      wrap.className = "orbit-chart-wrap";
      wrap.appendChild(svg);
      wrap.appendChild(tooltip);

      const labels = document.createElement("div");
      labels.className = "orbit-chart__labels";
      labels.innerHTML =
        `<span class="orbit-chart__label">${minV.toFixed(1)}${unit}</span>` +
        `<span class="orbit-chart__label orbit-chart__label--current">${data[data.length - 1].v.toFixed(1)}${unit} now</span>` +
        `<span class="orbit-chart__label">${maxV.toFixed(1)}${unit} peak</span>`;
      wrap.appendChild(labels);

      this.container.innerHTML = "";
      this.container.appendChild(wrap);

      svg.addEventListener("mousemove", e => {
        const rect = svg.getBoundingClientRect();
        const mx = (e.clientX - rect.left) / rect.width * W;
        let idx = Math.round(mx / stepX);
        idx = Math.max(0, Math.min(idx, data.length - 1));

        const pt = points[idx];
        dot.setAttribute("cx", pt.x);
        dot.setAttribute("cy", pt.y);
        dot.style.display = "";

        vLine.setAttribute("x1", pt.x);
        vLine.setAttribute("x2", pt.x);
        vLine.style.display = "";

        tooltip.textContent = `${this.formatTime(data[idx].t)}  ${data[idx].v.toFixed(1)}${unit}`;
        tooltip.style.display = "";

        const pctX = parseFloat(pt.x) / W * 100;
        tooltip.style.left = `${pctX}%`;
        tooltip.style.transform = pctX > 80 ? "translateX(-100%)" : (pctX < 20 ? "translateX(0)" : "translateX(-50%)");
      });

      svg.addEventListener("mouseleave", () => {
        dot.style.display = "none";
        vLine.style.display = "none";
        tooltip.style.display = "none";
      });
    }

    formatTime(ts) {
      if (!ts) return "";
      const d = new Date(ts.replace(" ", "T") + (ts.includes("Z") ? "" : "Z"));
      if (isNaN(d.getTime())) return ts;
      const h = d.getHours().toString().padStart(2, "0");
      const m = d.getMinutes().toString().padStart(2, "0");
      const mon = d.toLocaleString("en", { month: "short" });
      return `${mon} ${d.getDate()} ${h}:${m}`;
    }
  }

  // ── Init ──────────────────────────────────────────────────────────────────

  function initAll() {
    for (const el of document.querySelectorAll("[data-controller='orbit-poll']")) {
      new OrbitPollController(el).start();
    }
    for (const el of document.querySelectorAll(".orbit-chart-interactive")) {
      new OrbitChart(el);
    }
    startTimestampTicker();
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", initAll);
  } else {
    initAll();
  }
})();
