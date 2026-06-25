import os
import json
import boto3
import psycopg2
import logging

logger = logging.getLogger()
logger.setLevel(logging.INFO)

secrets = boto3.client("secretsmanager")
APP_ENV = os.getenv("APP_ENV", "prod")
IS_DEV = APP_ENV.lower() == "dev"

def get_secret():

    if IS_DEV:
        logger.info("Development mode - using environment variables")
        return {
            "username": os.environ["DB_USER"],
            "password": os.environ["DB_PASSWORD"]
        }

    logger.info("Production mode - retrieving credentials from Secrets Manager")
    secret_arn = os.environ["DB_SECRET_ARN"]
    response = secrets.get_secret_value(
        SecretId=secret_arn
    )
    logger.info("Secret retrieved")
    return json.loads(response["SecretString"])


def handler(event, context):

    logger.info("Lambda started")

    secret = get_secret()

    logger.info(
        f"Connecting to database host={os.environ['DB_HOST']} port={os.environ['DB_PORT']} db={os.environ['DB_NAME']}"
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

    return {
        "success": True
    }