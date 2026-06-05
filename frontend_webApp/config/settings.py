import os


class Config:
    SECRET_KEY = os.environ.get("SECRET_KEY", "a8f3d7c2e6b1f9a4d5c8e2b7a1f6d3c9e4b8a5f2d7c1e6b9a3f4d8c2e7b5a1")
    DEBUG = False
    TESTING = False


class DevelopmentConfig(Config):
    DEBUG = True


class ProductionConfig(Config):
    DEBUG = False


class TestingConfig(Config):
    TESTING = True
    DEBUG = True


config_map = {
    "development": DevelopmentConfig,
    "production": ProductionConfig,
    "testing": TestingConfig,
    "default": DevelopmentConfig,
}
