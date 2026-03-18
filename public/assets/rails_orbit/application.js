(function() {
  "use strict";

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
    if (this.timer) {
      clearInterval(this.timer);
      this.timer = null;
    }
  };

  OrbitPollController.prototype.poll = function() {
    var self = this;
    fetch(this.url, { headers: { "Accept": "text/vnd.turbo-stream.html" } })
      .then(function(response) {
        if (!response.ok) return;
        return response.text();
      })
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
    var parser = new DOMParser();
    var doc = parser.parseFromString(html, "text/html");
    doc.querySelectorAll("turbo-stream").forEach(function(stream) {
      var action   = stream.getAttribute("action");
      var targetId = stream.getAttribute("target");
      var target   = document.getElementById(targetId);
      if (!target) return;
      var template = stream.querySelector("template");
      if (!template) return;
      if (action === "update" || action === "replace") {
        target.innerHTML = template.innerHTML;
      }
    });
  };

  OrbitPollController.prototype.refreshTimestamp = function() {
    var el = document.getElementById("orbit-last-updated");
    if (!el) return;
    el.dataset.time = new Date().toISOString();
    el.textContent  = "Updated just now";
  };

  function startTimestampTicker() {
    setInterval(function() {
      var el = document.getElementById("orbit-last-updated");
      if (!el || !el.dataset.time) return;
      var seconds = Math.floor((Date.now() - new Date(el.dataset.time).getTime()) / 1000);
      if (seconds < 5)       el.textContent = "Updated just now";
      else if (seconds < 60) el.textContent = "Updated " + seconds + "s ago";
      else                   el.textContent = "Updated " + Math.floor(seconds / 60) + "m ago";
    }, 5000);
  }

  document.addEventListener("DOMContentLoaded", function() {
    document.querySelectorAll("[data-controller='orbit-poll']").forEach(function(el) {
      var controller = new OrbitPollController(el);
      controller.start();
    });
    startTimestampTicker();
  });
})();
