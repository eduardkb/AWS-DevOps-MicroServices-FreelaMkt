import os
import logging
import psycopg2

from shared_db import get_secret

logger = logging.getLogger()
logger.setLevel(logging.INFO)

APP_ENV = os.getenv("APP_ENV", "prod")


def handler(event, context):
    logger.info("Lambda started")
    logger.info(f"APP_ENV = {APP_ENV}")

    secret = get_secret()

    logger.info(
        f"Connecting to database host={os.environ['DB_HOST']} "
        f"port={os.environ['DB_PORT']} db={os.environ['DB_NAME']}"
    )

    connection = psycopg2.connect(
        host=os.environ["DB_HOST"],
        port=os.environ["DB_PORT"],
        dbname=os.environ["DB_NAME"],
        user=secret["username"],
        password=secret["password"],
        connect_timeout=30
    )

    logger.info("Database connected")

    connection.autocommit = True
    cursor = connection.cursor()

    logger.info("Opening migration.sql")

    with open("migration.sql", "r") as file:
        sql = file.read()

    logger.info("Executing migration SQL")
    cursor.execute(sql)
    logger.info("Migration completed")

    cursor.close()
    connection.close()
    logger.info("Connection closed")

    return {"success": True}
