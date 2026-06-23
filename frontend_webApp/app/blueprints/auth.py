import os
import hashlib
import base64
import secrets
import json
import hmac
import logging
import requests
from flask import Blueprint, redirect, request, session, url_for, render_template

auth_bp = Blueprint("auth", __name__)
logger = logging.getLogger(__name__)


def _cognito_base():
    return f"https://{os.environ['COGNITO_DOMAIN']}"


def _token_url():
    return f"{_cognito_base()}/oauth2/token"


def _logout_url():
    client_id = os.environ["COGNITO_CLIENT_ID"]
    logout_uri = os.environ["COGNITO_LOGOUT_URI"]
    return f"{_cognito_base()}/logout?client_id={client_id}&logout_uri={logout_uri}"


def _sign(data: str) -> str:
    key = os.environ.get("SECRET_KEY", "").encode()
    return hmac.new(key, data.encode(), hashlib.sha256).hexdigest()


@auth_bp.route("/login")
def login():
    verifier = secrets.token_urlsafe(64)
    digest = hashlib.sha256(verifier.encode()).digest()
    challenge = base64.urlsafe_b64encode(digest).rstrip(b"=").decode()

    verifier_b64 = base64.urlsafe_b64encode(verifier.encode()).decode()
    state = f"{verifier_b64}.{_sign(verifier_b64)}"

    params = (
        f"response_type=code"
        f"&client_id={os.environ['COGNITO_CLIENT_ID']}"
        f"&redirect_uri={os.environ['COGNITO_REDIRECT_URI']}"
        f"&scope=openid+email+profile"
        f"&state={state}"
        f"&code_challenge={challenge}"
        f"&code_challenge_method=S256"
    )
    return redirect(f"{_cognito_base()}/oauth2/authorize?{params}")


@auth_bp.route("/callback")
def callback():
    error = request.args.get("error")
    if error:
        logger.warning("Cognito auth error: %s", error)
        return redirect(url_for("main.index"))

    state = request.args.get("state", "")
    code = request.args.get("code")

    try:
        verifier_b64, sig = state.rsplit(".", 1)
        assert hmac.compare_digest(sig, _sign(verifier_b64))
        verifier = base64.urlsafe_b64decode(verifier_b64.encode()).decode()
    except Exception:
        logger.warning("Invalid OAuth state received")
        return redirect(url_for("main.index"))

    if not code:
        logger.warning("OAuth callback missing code")
        return redirect(url_for("main.index"))

    resp = requests.post(
        _token_url(),
        data={
            "grant_type": "authorization_code",
            "client_id": os.environ["COGNITO_CLIENT_ID"],
            "redirect_uri": os.environ["COGNITO_REDIRECT_URI"],
            "code": code,
            "code_verifier": verifier,
        },
        headers={"Content-Type": "application/x-www-form-urlencoded"},
        timeout=15,
    )

    if not resp.ok:
        logger.error("Token exchange failed: HTTP %s", resp.status_code)
        return redirect(url_for("main.index"))

    tokens = resp.json()
    id_token = tokens.get("id_token", "")

    try:
        payload_b64 = id_token.split(".")[1]
        padding = 4 - len(payload_b64) % 4
        payload_b64 += "=" * (padding % 4)
        claims = json.loads(base64.urlsafe_b64decode(payload_b64))
    except Exception:
        logger.error("Failed to decode id_token claims")
        return redirect(url_for("main.index"))

    session["user"] = {
        "name": claims.get("name") or claims.get("cognito:username") or claims.get("email", "User"),
        "email": claims.get("email", ""),
        "sub": claims.get("sub", ""),
    }
    session["access_token"] = tokens.get("access_token", "")
    session.modified = True

    return redirect(url_for("main.index"))


@auth_bp.route("/logout")
def logout():
    session.clear()
    return redirect(_logout_url())


@auth_bp.route("/register")
def register():
    return render_template("pages/register.html", active_tab="")


@auth_bp.route("/profile")
def profile():
    user = session.get("user", {})
    return render_template("pages/profile.html", active_tab="", user=user)
