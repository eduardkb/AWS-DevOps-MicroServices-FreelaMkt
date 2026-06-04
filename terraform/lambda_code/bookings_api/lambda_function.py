import os
import json
import boto3
import psycopg2

from aws_lambda_powertools import Logger # type: ignore
from aws_lambda_powertools.event_handler import APIGatewayHttpResolver # type: ignore
from aws_lambda_powertools.event_handler import Response # type: ignore

logger = Logger()

app = APIGatewayHttpResolver()

secrets_client = boto3.client("secretsmanager")


# ============================================================
# Secrets Manager Helpers
# ============================================================

def get_secret():
    logger.info("Retrieving database secret")

    secret_arn = os.environ["DB_SECRET_ARN"]

    logger.info(f"Secret ARN configured: {secret_arn}")

    response = secrets_client.get_secret_value(
        SecretId=secret_arn
    )

    logger.info("Secret successfully retrieved")

    secret = json.loads(response["SecretString"])

    logger.info("Secret parsed successfully")

    return secret


# ============================================================
# Database Helpers
# ============================================================

def get_db_connection():
    logger.info("Creating database connection")

    secret = get_secret()

    logger.info(
        f"Connecting to database "
        f"host={os.environ['DB_HOST']} "
        f"port={os.environ['DB_PORT']} "
        f"db={os.environ['DB_NAME']}"
    )

    connection = psycopg2.connect(
        host=os.environ["DB_HOST"],
        port=os.environ["DB_PORT"],
        dbname=os.environ["DB_NAME"],
        user=secret["username"],
        password=secret["password"],
        connect_timeout=30
    )

    logger.info("Database connection established")

    return connection


# ============================================================
# Bookings
# ============================================================

@app.get("/booking")
def get_booking():
    return Response(
        status_code=200,
        content_type="application/json",
        body='{"message":"Booking returned"}'
    )

@app.post("/booking")
def create_booking():
    return Response(
        status_code=200,
        content_type="application/json",
        body='{"message":"Booking created"}'
    )


@app.put("/booking/<booking_id>/status")
def update_booking(booking_id: str):
    return Response(
        status_code=200,
        content_type="application/json",
        body=f'{{"message":"Booking {booking_id} updated"}}'
    )

# ============================================================
# Lambda Entry Point
# ============================================================

@logger.inject_lambda_context
def handler(event, context):
    logger.info("Bookings API request received")
    return app.resolve(event, context)