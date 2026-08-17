from flask import Blueprint, render_template, jsonify, request
from app.lib.api_client import api_get, api_put

main_bp = Blueprint("main", __name__)


@main_bp.route("/")
def index():
    return render_template("pages/all_services.html", active_tab="all_services")


@main_bp.route("/api/service")
def api_services():
    data, status = api_get("/service")
    return jsonify(data), status


@main_bp.route("/api/user/<path:subpath>", methods=["GET", "PUT"])
def api_user_proxy(subpath):
    auth_header = request.headers.get("Authorization", "")
    token = auth_header.removeprefix("Bearer ").strip() if auth_header.startswith("Bearer ") else None

    if request.method == "PUT":
        body = request.get_json(silent=True) or {}
        data, status = api_put(f"/user/{subpath}", token=token, json_body=body)
    else:
        data, status = api_get(f"/user/{subpath}", token=token)

    return jsonify(data), status
