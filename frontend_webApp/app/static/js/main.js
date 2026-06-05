// Freela Marketplace — main.js

(function () {
  "use strict";

  // Highlight active nav tab on page load (already handled server-side via active_tab,
  // this is a client-side fallback for direct URL navigation)
  const currentPath = window.location.pathname;
  document.querySelectorAll(".nav-tab").forEach(function (tab) {
    if (tab.getAttribute("href") === currentPath) {
      tab.classList.add("active");
    }
  });

  // Book button placeholder interaction
  document.querySelectorAll(".btn-book").forEach(function (btn) {
    btn.addEventListener("click", function () {
      const row = btn.closest("tr");
      const title = row ? row.querySelector(".td-title").textContent.trim() : "this service";
      alert("Login required to book: " + title);
    });
  });
})();
