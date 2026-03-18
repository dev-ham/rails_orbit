// rails_orbit — self-contained dashboard JS
(function() {
  "use strict";

  class OrbitPollController {
    constructor(element) {
      this.element = element;
      this.url = element.dataset.orbitPollUrlValue;
      this.interval = parseInt(element.dataset.orbitPollIntervalValue) || 5000;
      this.timer = null;
    }

    start() {
      if (!this.url) return;
      this.poll();
      this.timer = setInterval(() => this.poll(), this.interval);
    }

    stop() {
      if (this.timer) {
        clearInterval(this.timer);
        this.timer = null;
      }
    }

    async poll() {
      try {
        const response = await fetch(this.url, {
          headers: { "Accept": "text/vnd.turbo-stream.html" }
        });
        if (response.ok) {
          const html = await response.text();
          if (typeof Turbo !== "undefined" && Turbo.renderStreamMessage) {
            Turbo.renderStreamMessage(html);
          } else {
            this.fallbackUpdate(html);
          }
        }
      } catch (e) {
        // Silently retry on next interval
      }
    }

    fallbackUpdate(html) {
      const parser = new DOMParser();
      const doc = parser.parseFromString(html, "text/html");
      doc.querySelectorAll("turbo-stream").forEach(function(stream) {
        var action = stream.getAttribute("action");
        var targetId = stream.getAttribute("target");
        var target = document.getElementById(targetId);
        if (!target) return;
        var template = stream.querySelector("template");
        if (!template) return;
        if (action === "update" || action === "replace") {
          target.innerHTML = template.innerHTML;
        }
      });
    }
  }

  document.addEventListener("DOMContentLoaded", function() {
    var elements = document.querySelectorAll("[data-controller='orbit-poll']");
    elements.forEach(function(el) {
      var controller = new OrbitPollController(el);
      controller.start();
    });
  });
})();
