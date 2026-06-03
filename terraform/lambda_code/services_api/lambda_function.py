import os
import json
import boto3
import psycopg2

from aws_lambda_powertools import Logger
from aws_lambda_powertools.event_handler import APIGatewayHttpResolver
from aws_lambda_powertools.event_handler import Response

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
# Services
# ============================================================

@app.get("/services")
def list_services():

    logger.info("GET /services request received")

    connection = None
    cursor = None

    try:

        logger.info("Opening database connection")

        connection = get_db_connection()

        logger.info("Creating cursor")

        cursor = connection.cursor()

        query = """
        SELECT *
        FROM services
        ORDER BY id
        """

        logger.info("Executing query")
        logger.info(query)

        cursor.execute(query)

        logger.info("Fetching rows")

        rows = cursor.fetchall()

        logger.info(f"Rows retrieved: {len(rows)}")

        columns = [desc[0] for desc in cursor.description]

        logger.info(f"Columns found: {columns}")

        services = []

        for row in rows:
            services.append(
                dict(zip(columns, row))
            )

        logger.info(
            f"Successfully returning {len(services)} services"
        )

        return Response(
            status_code=200,
            content_type="application/json",
            body=json.dumps(
                {
                    "success": True,
                    "count": len(services),
                    "data": services
                },
                default=str
            )
        )

    except psycopg2.OperationalError as error:

        logger.exception("Database connection error")

        return Response(
            status_code=500,
            content_type="application/json",
            body=json.dumps(
                {
                    "success": False,
                    "message": "Unable to connect to database"
                }
            )
        )

    except psycopg2.Error as error:

        logger.exception("Database query error")

        return Response(
            status_code=500,
            content_type="application/json",
            body=json.dumps(
                {
                    "success": False,
                    "message": "Database query failed"
                }
            )
        )

    except KeyError as error:

        logger.exception("Missing environment variable or secret field")

        return Response(
            status_code=500,
            content_type="application/json",
            body=json.dumps(
                {
                    "success": False,
                    "message": f"Configuration error: {str(error)}"
                }
            )
        )

    except Exception as error:

        logger.exception("Unexpected error")

        return Response(
            status_code=500,
            content_type="application/json",
            body=json.dumps(
                {
                    "success": False,
                    "message": "Internal server error"
                }
            )
        )

    finally:

        if cursor:
            logger.info("Closing cursor")
            cursor.close()

        if connection:
            logger.info("Closing database connection")
            connection.close()

        logger.info("Request completed")

@app.post("/services")
def create_service():
    return Response(
        status_code=200,
        content_type="application/json",
        body='{"message":"Service created"}'
    )

@app.get("/services/<service_id>")
def get_service(service_id: str):
    return Response(
        status_code=200,
        content_type="application/json",
        body=f'{{"message":"Service {service_id} retrieved"}}'
    )


@app.put("/services/<service_id>")
def update_service(service_id: str):
    return Response(
        status_code=200,
        content_type="application/json",
        body=f'{{"message":"Service {service_id} updated"}}'
    )


@app.delete("/services/<service_id>")
def delete_service(service_id: str):
    return Response(
        status_code=200,
        content_type="application/json",
        body=f'{{"message":"Service {service_id} deleted"}}'
    )

# ============================================================
# Lambda Entry Point
# ============================================================

@logger.inject_lambda_context
def handler(event, context):
    logger.info("Services API request received")
    return app.resolve(event, context)