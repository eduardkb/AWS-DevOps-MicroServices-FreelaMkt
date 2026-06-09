import os
import requests
from flask import Blueprint, render_template, current_app

main_bp = Blueprint("main", __name__)


@main_bp.route("/")
def index():
    api_url = os.environ.get("API_URL", "")
    services = None
    error = None
    empty = False

    try:
        response = requests.get(api_url + "/service", timeout=10)
        response.raise_for_status()
        data = response.json()
        if data.get("success") and data.get("data"):
            services = data["data"]
        else:
            empty = True
    except Exception as e:
        error = str(e)

    return render_template(
        "pages/all_services.html",
        services=services,
        error=error,
        empty=empty,
        active_tab="all_services",
    )
