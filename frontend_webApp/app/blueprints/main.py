from flask import Blueprint, render_template
from app.data.services import FAKE_SERVICES

main_bp = Blueprint("main", __name__)


@main_bp.route("/")
def index():
    return render_template("pages/all_services.html", services=FAKE_SERVICES, active_tab="all_services")
