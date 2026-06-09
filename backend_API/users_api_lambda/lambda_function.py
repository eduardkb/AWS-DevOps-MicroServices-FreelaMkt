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
# CloudFront Header Validation Helper
# ============================================================

def validate_cloudfront_secret():
    expected_secret = os.environ.get("CLOUDFRONT_SECRET_HEADER")

    header_value = (
        app.current_event.get_header_value(
            name="x-cloudfront-secret",
            default_value=None
        )
    )

    if not expected_secret or header_value != expected_secret:
        logger.warning(
            "Invalid CloudFront secret header received"
        )

        return Response(
            status_code=403,
            content_type="application/json",
            body='{"message":"Forbidden"}'
        )

    return None

# ============================================================
# Users
# ============================================================

@app.get("/api/user/me")
def get_user():
    auth_error = validate_cloudfront_secret()
    if auth_error:
        return auth_error
    
    return Response(
        status_code=200,
        content_type="application/json",
        body='{"message":"User returned"}'
    )

@app.post("/api/user")
def create_user():
    auth_error = validate_cloudfront_secret()
    if auth_error:
        return auth_error

    return Response(
        status_code=200,
        content_type="application/json",
        body='{"message":"User created"}'
    )


@app.put("/api/user/me")
def update_user():
    auth_error = validate_cloudfront_secret()
    if auth_error:
        return auth_error
    
    return Response(
        status_code=200,
        content_type="application/json",
        body=f'{{"message":"User updated"}}'
    )

@app.get("/api/user/healthcheck")
def healthcheck():
    auth_error = validate_cloudfront_secret()
    if auth_error:
        return auth_error
    
    return Response(
        status_code=200,
        content_type="application/json",
        body='{"message":"API up and running"}'
    )


@app.get("/api/user/getparam")
def getparam():
    auth_error = validate_cloudfront_secret()
    if auth_error:
        return auth_error
    
    return Response(
        status_code=200,
        content_type="application/json",
        body=json.dumps({
            "message": "event parameters returned",
            "event": app.current_event.raw_event
        })
    )
# ============================================================
# Lambda Entry Point
# ============================================================

@logger.inject_lambda_context
def handler(event, context):
    logger.info("Users API request received")
    return app.resolve(event, context)