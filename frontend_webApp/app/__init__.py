import os
from flask import Flask
from dotenv import load_dotenv
from config import config_map

load_dotenv("appVersion.env")
load_dotenv(".env", override=False)


def create_app(env: str = None) -> Flask:
    if env is None:
        env = os.environ.get("FLASK_ENV", "default")

    app = Flask(__name__, template_folder="templates", static_folder="static")
    app.config.from_object(config_map[env])
    app.config["APP_VERSION"] = os.environ.get("APP_VERSION", "")

    from app.blueprints.main import main_bp
    from app.blueprints.services import services_bp
    from app.blueprints.bookings import bookings_bp
    from app.blueprints.auth import auth_bp

    app.register_blueprint(main_bp)
    app.register_blueprint(services_bp, url_prefix="/service")
    app.register_blueprint(bookings_bp, url_prefix="/booking")
    app.register_blueprint(auth_bp, url_prefix="/auth")

    return app
