(function() {
  "use strict";

  // ── Poll Controller ───────────────────────────────────────────────────────

  function OrbitPollController(element) {
    this.element  = element;
    this.url      = element.dataset.orbitPollUrlValue;
    this.interval = parseInt(element.dataset.orbitPollIntervalValue) || 5000;
    this.timer    = null;
  }

  OrbitPollController.prototype.start = function() {
    if (!this.url) return;
    this.poll();
    this.timer = setInterval(this.poll.bind(this), this.interval);
  };

  OrbitPollController.prototype.stop = function() {
    if (this.timer) { clearInterval(this.timer); this.timer = null; }
  };

  OrbitPollController.prototype.poll = function() {
    var self = this;
    fetch(this.url, { headers: { "Accept": "text/vnd.turbo-stream.html" } })
      .then(function(r) { return r.ok ? r.text() : null; })
      .then(function(html) {
        if (!html) return;
        if (typeof Turbo !== "undefined" && Turbo.renderStreamMessage) {
          Turbo.renderStreamMessage(html);
        } else {
          self.fallbackUpdate(html);
        }
        self.refreshTimestamp();
      })
      .catch(function() {});
  };

  OrbitPollController.prototype.fallbackUpdate = function(html) {
    var doc = new DOMParser().parseFromString(html, "text/html");
    doc.querySelectorAll("turbo-stream").forEach(function(stream) {
      var target = document.getElementById(stream.getAttribute("target"));
      if (!target) return;
      var tpl = stream.querySelector("template");
      if (!tpl) return;
      var action = stream.getAttribute("action");
      if (action === "update" || action === "replace") target.innerHTML = tpl.innerHTML;
    });
  };

  OrbitPollController.prototype.refreshTimestamp = function() {
    var el = document.getElementById("orbit-last-updated");
    if (!el) return;
    el.dataset.time = new Date().toISOString();
    el.textContent  = "Updated just now";
  };

  // ── Timestamp Ticker ──────────────────────────────────────────────────────

  function startTimestampTicker() {
    setInterval(function() {
      var el = document.getElementById("orbit-last-updated");
      if (!el || !el.dataset.time) return;
      var s = Math.floor((Date.now() - new Date(el.dataset.time).getTime()) / 1000);
      if (s < 5)       el.textContent = "Updated just now";
      else if (s < 60) el.textContent = "Updated " + s + "s ago";
      else             el.textContent = "Updated " + Math.floor(s / 60) + "m ago";
    }, 5000);
  }

  // ── Interactive SVG Chart ─────────────────────────────────────────────────

  function OrbitChart(container) {
    this.container = container;
    this.data      = JSON.parse(container.dataset.chart || "[]");
    this.unit      = container.dataset.unit || "";
    this.color     = container.dataset.color || "var(--orbit-primary)";
    this.gradId    = container.dataset.gradientId || ("orbit-grad-" + Math.random().toString(36).slice(2, 8));

    if (this.data.length === 0) return;
    this.render();
  }

  OrbitChart.prototype.render = function() {
    var W = 700, H = 90, PAD_TOP = 5, PAD_BOT = 5;
    var data  = this.data;
    var vals  = data.map(function(d) { return d.v; });
    var maxV  = Math.max.apply(null, vals) || 1;
    var minV  = Math.min.apply(null, vals);
    var range = maxV - minV || 1;
    var stepX = data.length > 1 ? W / (data.length - 1) : W;
    var self  = this;

    function yPos(v) {
      return PAD_TOP + ((maxV - v) / range) * (H - PAD_TOP - PAD_BOT);
    }

    var points = data.map(function(d, i) {
      return { x: (i * stepX).toFixed(1), y: yPos(d.v).toFixed(1) };
    });

    var polyline = points.map(function(p) { return p.x + "," + p.y; }).join(" ");
    var polygon  = "0," + H + " " + polyline + " " + W + "," + H;

    var svg = document.createElementNS("http://www.w3.org/2000/svg", "svg");
    svg.setAttribute("viewBox", "0 0 " + W + " " + (H + 2));
    svg.setAttribute("preserveAspectRatio", "none");
    svg.setAttribute("class", "orbit-chart");

    svg.innerHTML =
      '<defs><linearGradient id="' + this.gradId + '" x1="0" y1="0" x2="0" y2="1">' +
      '<stop offset="0%" stop-color="' + this.color + '" stop-opacity="0.25"/>' +
      '<stop offset="100%" stop-color="' + this.color + '" stop-opacity="0.02"/>' +
      '</linearGradient></defs>' +
      '<polygon points="' + polygon + '" fill="url(#' + this.gradId + ')"/>' +
      '<polyline points="' + polyline + '" fill="none" stroke="' + this.color + '" stroke-width="1.5" stroke-linejoin="round"/>';

    var hitZones = document.createElementNS("http://www.w3.org/2000/svg", "g");
    hitZones.setAttribute("class", "orbit-chart__hitzone");

    for (var i = 0; i < points.length; i++) {
      var rect = document.createElementNS("http://www.w3.org/2000/svg", "rect");
      var x0 = i === 0 ? 0 : parseFloat(points[i].x) - stepX / 2;
      rect.setAttribute("x", x0);
      rect.setAttribute("y", 0);
      rect.setAttribute("width", stepX);
      rect.setAttribute("height", H);
      rect.setAttribute("fill", "transparent");
      rect.setAttribute("data-idx", i);
      hitZones.appendChild(rect);
    }
    svg.appendChild(hitZones);

    var dot = document.createElementNS("http://www.w3.org/2000/svg", "circle");
    dot.setAttribute("r", "3");
    dot.setAttribute("fill", this.color);
    dot.setAttribute("class", "orbit-chart__dot");
    dot.style.display = "none";
    svg.appendChild(dot);

    var vLine = document.createElementNS("http://www.w3.org/2000/svg", "line");
    vLine.setAttribute("y1", "0");
    vLine.setAttribute("y2", H);
    vLine.setAttribute("stroke", "var(--orbit-border-hover)");
    vLine.setAttribute("stroke-width", "1");
    vLine.setAttribute("stroke-dasharray", "2,2");
    vLine.setAttribute("class", "orbit-chart__vline");
    vLine.style.display = "none";
    svg.appendChild(vLine);

    var tooltip = document.createElement("div");
    tooltip.className = "orbit-chart__tooltip";
    tooltip.style.display = "none";

    var wrap = document.createElement("div");
    wrap.className = "orbit-chart-wrap";
    wrap.appendChild(svg);
    wrap.appendChild(tooltip);

    var labels = document.createElement("div");
    labels.className = "orbit-chart__labels";
    labels.innerHTML =
      '<span class="orbit-chart__label">' + minV.toFixed(1) + this.unit + '</span>' +
      '<span class="orbit-chart__label orbit-chart__label--current">' +
        data[data.length - 1].v.toFixed(1) + this.unit + ' now</span>' +
      '<span class="orbit-chart__label">' + maxV.toFixed(1) + this.unit + ' peak</span>';
    wrap.appendChild(labels);

    this.container.innerHTML = "";
    this.container.appendChild(wrap);

    svg.addEventListener("mousemove", function(e) {
      var rect = svg.getBoundingClientRect();
      var mx = (e.clientX - rect.left) / rect.width * W;
      var idx = Math.round(mx / stepX);
      if (idx < 0) idx = 0;
      if (idx >= data.length) idx = data.length - 1;

      var pt = points[idx];
      dot.setAttribute("cx", pt.x);
      dot.setAttribute("cy", pt.y);
      dot.style.display = "";

      vLine.setAttribute("x1", pt.x);
      vLine.setAttribute("x2", pt.x);
      vLine.style.display = "";

      var d = data[idx];
      tooltip.textContent = self.formatTime(d.t) + "  " + d.v.toFixed(1) + self.unit;
      tooltip.style.display = "";

      var pctX = parseFloat(pt.x) / W * 100;
      tooltip.style.left = pctX + "%";
      tooltip.style.transform = pctX > 80 ? "translateX(-100%)" : (pctX < 20 ? "translateX(0)" : "translateX(-50%)");
    });

    svg.addEventListener("mouseleave", function() {
      dot.style.display = "none";
      vLine.style.display = "none";
      tooltip.style.display = "none";
    });
  };

  OrbitChart.prototype.formatTime = function(ts) {
    if (!ts) return "";
    var d = new Date(ts.replace(" ", "T") + (ts.indexOf("Z") === -1 ? "Z" : ""));
    if (isNaN(d.getTime())) return ts;
    var h = d.getHours().toString().padStart(2, "0");
    var m = d.getMinutes().toString().padStart(2, "0");
    var mon = d.toLocaleString("en", { month: "short" });
    var day = d.getDate();
    return mon + " " + day + " " + h + ":" + m;
  };

  // ── Init ──────────────────────────────────────────────────────────────────

  function initAll() {
    document.querySelectorAll("[data-controller='orbit-poll']").forEach(function(el) {
      new OrbitPollController(el).start();
    });
    document.querySelectorAll(".orbit-chart-interactive").forEach(function(el) {
      new OrbitChart(el);
    });
    startTimestampTicker();
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", initAll);
  } else {
    initAll();
  }
})();
