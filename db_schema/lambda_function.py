import os
import json
import boto3
import psycopg2
import logging

logger = logging.getLogger()
logger.setLevel(logging.INFO)

secrets = boto3.client("secretsmanager")

def get_secret():

    logger.info("Getting secret ARN")

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
        f"Connecting to database host={secret['host']} port={secret['port']} db={secret['database']}"
    )

    connection = psycopg2.connect(
        host=secret["host"],
        port=secret["port"],
        dbname=secret["database"],
        user=secret["username"],
        password=secret["password"],
        connect_timeout=10
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