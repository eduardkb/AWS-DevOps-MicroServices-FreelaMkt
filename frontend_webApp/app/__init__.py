import os
from flask import Flask
from config import config_map


def create_app(env: str = None) -> Flask:
    if env is None:
        env = os.environ.get("FLASK_ENV", "default")

    app = Flask(__name__, template_folder="templates", static_folder="static")
    app.config.from_object(config_map[env])

    from app.blueprints.main import main_bp
    from app.blueprints.services import services_bp
    from app.blueprints.bookings import bookings_bp

    app.register_blueprint(main_bp)
    app.register_blueprint(services_bp, url_prefix="/services")
    app.register_blueprint(bookings_bp, url_prefix="/bookings")

    return app
