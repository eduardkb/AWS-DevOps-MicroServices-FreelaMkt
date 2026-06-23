import os
import logging
from flask import Blueprint, redirect, render_template, request, jsonify

auth_bp = Blueprint("auth", __name__)
logger = logging.getLogger(__name__)


def _cognito_base():
    return f"https://{os.environ['COGNITO_DOMAIN']}"


def _logout_url():
    client_id = os.environ["COGNITO_CLIENT_ID"]
    logout_uri = os.environ["COGNITO_LOGOUT_URI"]
    return f"{_cognito_base()}/logout?client_id={client_id}&logout_uri={logout_uri}"


@auth_bp.route("/login")
def login():
    """
    Redirect the browser to Cognito's /oauth2/authorize.
    PKCE (code_verifier / code_challenge) is generated entirely in the
    browser (auth.js) so the ECS container never needs outbound internet
    access to the Cognito token endpoint.
    The redirect goes to /auth/callback, which is a plain HTML page that
    lets auth.js finish the flow.
    """
    redirect_uri = os.environ["COGNITO_REDIRECT_URI"]
    client_id = os.environ["COGNITO_CLIENT_ID"]
    # Render a tiny page that immediately triggers the JS-driven login flow
    return render_template(
        "pages/login_redirect.html",
        cognito_base=_cognito_base(),
        client_id=client_id,
        redirect_uri=redirect_uri,
    )


@auth_bp.route("/callback")
def callback():
    """
    Landing page after Cognito redirects back with ?code=…&state=…
    auth.js picks up the query-string params, exchanges the code for
    tokens directly from the browser, and stores them in sessionStorage.
    """
    return render_template("pages/callback.html")


@auth_bp.route("/logout")
def logout():
    """
    Clear client-side tokens (handled by auth.js before this redirect is
    followed) and send the browser to Cognito's logout endpoint.
    """
    return redirect(_logout_url())


@auth_bp.route("/register")
def register():
    return render_template("pages/register.html", active_tab="")


@auth_bp.route("/profile")
def profile():
    """Profile data is populated client-side from stored tokens."""
    return render_template("pages/profile.html", active_tab="")


@auth_bp.route("/config.json")
def auth_config():
    """
    Expose only the public OAuth config that the browser needs.
    No secrets are returned — Cognito public clients have no client_secret.
    """
    return jsonify(
        {
            "cognito_base": _cognito_base(),
            "client_id": os.environ["COGNITO_CLIENT_ID"],
            "redirect_uri": os.environ["COGNITO_REDIRECT_URI"],
            "logout_uri": os.environ["COGNITO_LOGOUT_URI"],
        }
    )
