// Freela Marketplace — main.js
(function () {
  "use strict";

  const currentPath = window.location.pathname;
  document.querySelectorAll(".nav-tab").forEach(function (tab) {
    if (tab.getAttribute("href") === currentPath) {
      tab.classList.add("active");
    }
  });
})();
