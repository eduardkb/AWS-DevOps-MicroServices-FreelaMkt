from flask import Blueprint, render_template

bookings_bp = Blueprint("bookings", __name__)


@bookings_bp.route("/my")
def my_bookings():
    return render_template("pages/my_bookings.html", active_tab="my_bookings")
