from app import create_app
import os

app = create_app()
flask_env = os.getenv("FLASK_ENV", "").lower()
bDebug = flask_env in ("dev", "development")

if __name__ == "__main__":
    app.run(debug=bDebug, host="0.0.0.0", port=80)
