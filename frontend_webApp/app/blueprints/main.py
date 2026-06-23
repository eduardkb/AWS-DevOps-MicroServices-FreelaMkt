import os
import requests
from flask import Blueprint, render_template, jsonify

main_bp = Blueprint("main", __name__)


@main_bp.route("/")
def index():
    return render_template("pages/all_services.html", active_tab="all_services")


@main_bp.route("/api/service")
def api_services():
    api_url = os.environ.get("API_URL", "")
    try:
        response = requests.get(api_url + "/service", timeout=60)
        response.raise_for_status()
        return jsonify({"success": True, "data": response.json()})
    except requests.exceptions.Timeout:
        return jsonify({"success": False, "error": "Request timed out after 60 seconds."}), 504
    except requests.exceptions.ConnectionError as e:
        return jsonify({"success": False, "error": f"Could not connect to the API: {e}"}), 502
    except requests.exceptions.HTTPError as e:
        return jsonify({"success": False, "error": f"API returned an error: {e}"}), 502
    except Exception as e:
        return jsonify({"success": False, "error": str(e)}), 500
