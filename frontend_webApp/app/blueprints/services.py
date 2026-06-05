from flask import Blueprint, render_template

services_bp = Blueprint("services", __name__)


@services_bp.route("/my")
def my_services():
    return render_template("pages/my_services.html", active_tab="my_services")
