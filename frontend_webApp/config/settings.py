import os


class Config:
    SECRET_KEY = os.environ.get("SECRET_KEY", "dev-only-insecure-key-change-in-prod")
    DEBUG = False
    TESTING = False
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
        if not os.environ.get("SECRET_KEY"):
            raise RuntimeError("SECRET_KEY environment variable must be set in production")


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
