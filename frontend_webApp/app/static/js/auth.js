/**
 * auth.js — Browser-side Cognito PKCE authentication
 *
 * All token operations happen in the user's browser so that the ECS
 * container in a private subnet never needs to reach the Cognito token
 * endpoint.
 *
 * Storage strategy (security trade-offs):
 *   - sessionStorage  → tokens live only for the browser tab/session.
 *     Survives page refreshes but not new tabs or closing the browser.
 *     Not accessible from other origins (same-origin policy).
 *   - The PKCE code_verifier is kept only in sessionStorage and deleted
 *     immediately after the token exchange succeeds.
 *   - Tokens are never written to localStorage (survives indefinitely,
 *     bigger XSS attack surface) or cookies (CSRF risk, sent on every
 *     request).
 *
 * Public surface:
 *   window.Auth.isAuthenticated()  → bool
 *   window.Auth.getUser()          → { name, email, sub } | null
 *   window.Auth.getAccessToken()   → string | null  (auto-refreshes)
 *   window.Auth.login()            → starts the PKCE flow
 *   window.Auth.logout()           → clears tokens, redirects to Cognito
 */

(function (global) {
  "use strict";

  // ─── Constants ────────────────────────────────────────────────────────────

  const STORAGE_KEYS = {
    ACCESS_TOKEN: "auth_access_token",
    ID_TOKEN: "auth_id_token",
    REFRESH_TOKEN: "auth_refresh_token",
    EXPIRES_AT: "auth_expires_at",   // Unix ms
    USER: "auth_user",               // JSON-serialised { name, email, sub }
    PKCE_VERIFIER: "auth_pkce_verifier",
    PKCE_STATE: "auth_pkce_state",
  };

  // ─── Helpers ──────────────────────────────────────────────────────────────

  /**
   * Generate a cryptographically random Base64url string of `byteLen` bytes.
   */
  async function randomBase64Url(byteLen) {
    const buf = new Uint8Array(byteLen);
    crypto.getRandomValues(buf);
    return bufToBase64Url(buf);
  }

  function bufToBase64Url(buf) {
    return btoa(String.fromCharCode(...buf))
      .replace(/\+/g, "-")
      .replace(/\//g, "_")
      .replace(/=/g, "");
  }

  async function sha256Base64Url(plain) {
    const enc = new TextEncoder().encode(plain);
    const hash = await crypto.subtle.digest("SHA-256", enc);
    return bufToBase64Url(new Uint8Array(hash));
  }

  function decodeJwtPayload(token) {
    try {
      const part = token.split(".")[1];
      const padded = part + "===".slice(0, (4 - (part.length % 4)) % 4);
      return JSON.parse(atob(padded.replace(/-/g, "+").replace(/_/g, "/")));
    } catch {
      return null;
    }
  }

  function sessionSet(key, value) {
    try { sessionStorage.setItem(key, value); } catch { /* quota */ }
  }

  function sessionGet(key) {
    try { return sessionStorage.getItem(key); } catch { return null; }
  }

  function sessionDel(key) {
    try { sessionStorage.removeItem(key); } catch { /* noop */ }
  }

  function clearAllTokens() {
    Object.values(STORAGE_KEYS).forEach(sessionDel);
  }

  // ─── Config (loaded once) ─────────────────────────────────────────────────

  let _cfg = null;

  async function getConfig() {
    if (_cfg) return _cfg;
    const resp = await fetch("/auth/config.json");
    if (!resp.ok) throw new Error("Failed to load auth config");
    _cfg = await resp.json();
    return _cfg;
  }

  // ─── Token store ──────────────────────────────────────────────────────────

  function saveTokens(tokens) {
    const { access_token, id_token, refresh_token, expires_in } = tokens;
    if (!access_token || !id_token) return false;

    const expiresAt = Date.now() + (expires_in || 3600) * 1000;
    sessionSet(STORAGE_KEYS.ACCESS_TOKEN, access_token);
    sessionSet(STORAGE_KEYS.ID_TOKEN, id_token);
    sessionSet(STORAGE_KEYS.EXPIRES_AT, String(expiresAt));
    if (refresh_token) sessionSet(STORAGE_KEYS.REFRESH_TOKEN, refresh_token);

    const claims = decodeJwtPayload(id_token);
    if (claims) {
      const user = {
        name: claims.name || claims["cognito:username"] || claims.email || "User",
        email: claims.email || "",
        sub: claims.sub || "",
        groups: claims["cognito:groups"] || [],
      };
      sessionSet(STORAGE_KEYS.USER, JSON.stringify(user));
    }
    return true;
  }

  function isExpired() {
    const exp = sessionGet(STORAGE_KEYS.EXPIRES_AT);
    if (!exp) return true;
    // Treat tokens as expired 60 s early to avoid edge cases
    return Date.now() > Number(exp) - 60_000;
  }

  // ─── Token refresh ────────────────────────────────────────────────────────

  async function refreshTokens() {
    const refreshToken = sessionGet(STORAGE_KEYS.REFRESH_TOKEN);
    if (!refreshToken) return false;

    const cfg = await getConfig();
    const body = new URLSearchParams({
      grant_type: "refresh_token",
      client_id: cfg.client_id,
      refresh_token: refreshToken,
    });

    const resp = await fetch(`${cfg.cognito_base}/oauth2/token`, {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body: body.toString(),
    });

    if (!resp.ok) {
      // Refresh token is invalid/expired — force re-login
      clearAllTokens();
      return false;
    }

    const tokens = await resp.json();
    // Cognito does not return a new refresh_token on refresh — preserve old one
    if (!tokens.refresh_token) {
      tokens.refresh_token = refreshToken;
    }
    return saveTokens(tokens);
  }

  // ─── PKCE login ───────────────────────────────────────────────────────────

  async function login() {
    const cfg = await getConfig();

    const verifier = await randomBase64Url(64);
    const challenge = await sha256Base64Url(verifier);
    const state = await randomBase64Url(32);

    // Persist so the callback page can retrieve them
    sessionSet(STORAGE_KEYS.PKCE_VERIFIER, verifier);
    sessionSet(STORAGE_KEYS.PKCE_STATE, state);

    const params = new URLSearchParams({
      response_type: "code",
      client_id: cfg.client_id,
      redirect_uri: cfg.redirect_uri,
      scope: "openid email profile",
      state,
      code_challenge: challenge,
      code_challenge_method: "S256",
    });

    window.location.href = `${cfg.cognito_base}/oauth2/authorize?${params}`;
  }

  // ─── Callback handler (called on /auth/callback) ──────────────────────────

  async function handleCallback() {
    const params = new URLSearchParams(window.location.search);
    const error = params.get("error");
    if (error) {
      console.error("Cognito auth error:", error, params.get("error_description"));
      window.location.replace("/");
      return;
    }

    const code = params.get("code");
    const returnedState = params.get("state");
    const verifier = sessionGet(STORAGE_KEYS.PKCE_VERIFIER);
    const savedState = sessionGet(STORAGE_KEYS.PKCE_STATE);

    // Validate state to prevent CSRF
    if (!returnedState || !savedState || returnedState !== savedState) {
      console.error("OAuth state mismatch — possible CSRF");
      clearAllTokens();
      window.location.replace("/");
      return;
    }

    if (!code || !verifier) {
      console.error("Missing code or PKCE verifier");
      window.location.replace("/");
      return;
    }

    // Clean up PKCE ephemeral values immediately
    sessionDel(STORAGE_KEYS.PKCE_VERIFIER);
    sessionDel(STORAGE_KEYS.PKCE_STATE);

    const cfg = await getConfig();
    const body = new URLSearchParams({
      grant_type: "authorization_code",
      client_id: cfg.client_id,
      redirect_uri: cfg.redirect_uri,
      code,
      code_verifier: verifier,
    });

    try {
      const resp = await fetch(`${cfg.cognito_base}/oauth2/token`, {
        method: "POST",
        headers: { "Content-Type": "application/x-www-form-urlencoded" },
        body: body.toString(),
      });

      if (!resp.ok) {
        throw new Error(`Token exchange failed: HTTP ${resp.status}`);
      }

      const tokens = await resp.json();
      if (!saveTokens(tokens)) {
        throw new Error("Invalid token response from Cognito");
      }

      // Remove code/state from the URL bar (clean history entry)
      history.replaceState(null, "", "/auth/callback");
      window.location.replace("/");
    } catch (err) {
      console.error(err);
      clearAllTokens();
      window.location.replace("/");
    }
  }

  // ─── Logout ───────────────────────────────────────────────────────────────

  async function logout() {
    clearAllTokens();
    // The Flask /auth/logout route redirects to Cognito's logout endpoint
    window.location.href = "/auth/logout";
  }

  // ─── Public API ───────────────────────────────────────────────────────────

  function isAuthenticated() {
    return !!sessionGet(STORAGE_KEYS.ACCESS_TOKEN);
  }

  function getUser() {
    const raw = sessionGet(STORAGE_KEYS.USER);
    if (!raw) return null;
    try { return JSON.parse(raw); } catch { return null; }
  }

  /**
   * Returns a valid access token, refreshing silently if needed.
   * Returns null if the user is not authenticated or refresh fails.
   */
  async function getAccessToken() {
    if (!isAuthenticated()) return null;
    if (isExpired()) {
      const ok = await refreshTokens();
      if (!ok) return null;
    }
    return sessionGet(STORAGE_KEYS.ACCESS_TOKEN);
  }

  // ─── DOM helpers ──────────────────────────────────────────────────────────

  /**
   * Update the header to reflect the current auth state.
   * Called on DOMContentLoaded and after a successful token refresh.
   */
  function updateHeaderUI() {
    const user = getUser();
    const authenticated = isAuthenticated() && !!user;

    const authSection = document.getElementById("auth-header-section");
    if (!authSection) return;

    if (authenticated) {
      authSection.innerHTML = `
        <a href="/auth/profile" class="btn-profile" aria-label="Profile">
          <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" fill="none"
               viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
            <circle cx="12" cy="8" r="4"/>
            <path d="M4 20c0-4 3.6-7 8-7s8 3 8 7"/>
          </svg>
          ${escapeHtml(user.name)} Profile
        </a>
        <button class="btn-logout" aria-label="Logout" onclick="Auth.logout()">
          <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" fill="none"
               viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
            <path d="M17 16l4-4m0 0l-4-4m4 4H7m6 4v1a2 2 0 01-2 2H5a2 2 0 01-2-2V7a2 2 0 012-2h6a2 2 0 012 2v1"/>
          </svg>
          Logout
        </button>`;
    } else {
      authSection.innerHTML = `
        <a href="/auth/register" class="btn-register" aria-label="Create Account">
          Create Account
        </a>
        <a href="/auth/login" class="btn-login" aria-label="Login">
          <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" fill="none"
               viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
            <circle cx="12" cy="8" r="4"/>
            <path d="M4 20c0-4 3.6-7 8-7s8 3 8 7"/>
          </svg>
          Login
        </a>`;
    }
  }

  function escapeHtml(str) {
    return String(str)
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")
      .replace(/"/g, "&quot;")
      .replace(/'/g, "&#39;");
  }

  // ─── Auto-refresh: silently refresh 2 min before expiry ───────────────────

  function scheduleRefresh() {
    const exp = sessionGet(STORAGE_KEYS.EXPIRES_AT);
    if (!exp || !sessionGet(STORAGE_KEYS.REFRESH_TOKEN)) return;
    const msUntilRefresh = Number(exp) - Date.now() - 120_000; // 2 min early
    if (msUntilRefresh <= 0) {
      refreshTokens().then(updateHeaderUI);
      return;
    }
    setTimeout(async () => {
      await refreshTokens();
      updateHeaderUI();
      scheduleRefresh(); // reschedule for the next cycle
    }, msUntilRefresh);
  }

  // ─── Bootstrap ────────────────────────────────────────────────────────────

  document.addEventListener("DOMContentLoaded", function () {
    // If this is the callback page, handle the OAuth response
    if (window.location.pathname === "/auth/callback") {
      handleCallback();
      return;
    }

    updateHeaderUI();
    scheduleRefresh();
  });

  // Expose public API
  global.Auth = { isAuthenticated, getUser, getAccessToken, login, logout };
})(window);
