// Freela Marketplace — main.js
(function () {
  "use strict";

  const currentPath = window.location.pathname;
  document.querySelectorAll(".nav-tab").forEach(function (tab) {
    if (tab.getAttribute("href") === currentPath) {
      tab.classList.add("active");
    }
  });

  // Centralized Messaging System
  window.MessageBus = {
    show: function(message, type) {
      const banner = document.getElementById("message-banner");
      const content = document.getElementById("message-content");
      
      if (!banner || !content) return;

      content.textContent = message;
      banner.className = "message-banner message-banner--" + type;
      banner.style.display = "flex";

      clearTimeout(banner._timeout);
      banner._timeout = setTimeout(function() {
        banner.style.display = "none";
      }, 5000);
    },

    info: function(message) {
      this.show(message, "info");
    },

    success: function(message) {
      this.show(message, "success");
    },

    warning: function(message) {
      this.show(message, "warning");
    },

    error: function(message) {
      this.show(message, "error");
    }
  };
})();
