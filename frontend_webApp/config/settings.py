import os


class Config:
    SECRET_KEY = os.environ.get("SECRET_KEY", "dev-only-insecure-key-change-in-prod")
    DEBUG = False
    TESTING = False
    # Sessions are no longer used for auth tokens (all auth is browser-side),
    # but Flask may still use the session for CSRF or flash messages, so keep
    # secure defaults.
    SESSION_COOKIE_HTTPONLY = True
    SESSION_COOKIE_SAMESITE = "Lax"
    SESSION_COOKIE_SECURE = True


class DevelopmentConfig(Config):
    DEBUG = True
    SESSION_COOKIE_SECURE = False


class ProductionConfig(Config):
    DEBUG = False

    @classmethod
    def validate(cls):
        required = ["COGNITO_DOMAIN", "COGNITO_CLIENT_ID", "COGNITO_REDIRECT_URI", "COGNITO_LOGOUT_URI"]
        missing = [k for k in required if not os.environ.get(k)]
        if missing:
            raise RuntimeError(f"Missing required environment variables: {', '.join(missing)}")


class TestingConfig(Config):
    TESTING = True
    DEBUG = True
    SECRET_KEY = "testing-key"
    SESSION_COOKIE_SECURE = False


config_map = {
    "development": DevelopmentConfig,
    "production": ProductionConfig,
    "testing": TestingConfig,
    "default": DevelopmentConfig,
}
