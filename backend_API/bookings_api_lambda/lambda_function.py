import os
import json
import uuid
import boto3
import psycopg2
import jwt

from aws_lambda_powertools import Logger # type: ignore
from aws_lambda_powertools.event_handler import APIGatewayHttpResolver # type: ignore
from aws_lambda_powertools.event_handler import Response # type: ignore

logger = Logger()

app = APIGatewayHttpResolver()

VALID_STATUSES = {"PENDING", "ACCEPTED", "REJECTED", "COMPLETED", "CANCELLED"}
APP_ENV = os.getenv("APP_ENV", "prod")
IS_DEV = APP_ENV.lower() == "dev"

# ============================================================
# Secrets Manager Helpers
# ============================================================

def get_secret():
    if IS_DEV:
        logger.info("Development mode - using environment variables")
        return {
            "username": os.environ["DB_USER"],
            "password": os.environ["DB_PASSWORD"]
        }

    secrets_client = boto3.client("secretsmanager")
    logger.info("Production mode - retrieving credentials from Secrets Manager")
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

    if IS_DEV:
        db_timeout = 15
    else:
        db_timeout = 60
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
        connect_timeout=db_timeout,
        options="-c statement_timeout=5000"
    )

    logger.info("Database connection established")

    return connection


# ============================================================
# Access Validation Helper
# ============================================================

def access_validation():    
    if not IS_DEV:
        expected_secret = os.environ.get("CLOUDFRONT_SECRET_HEADER")
        header_value = app.current_event.get_header_value(
        name="x-cloudfront-secret",
        default_value=None
    )
        # Validate cloudfront secret
        if not expected_secret or header_value != expected_secret:
            logger.warning("Invalid CloudFront secret header received")
        return Response(
            status_code=403,
            content_type="application/json",
            body='{"message":"Forbidden. Invalid request source."}'
        )

    

    # Validate access tokenclaim
    authorization = app.current_event.get_header_value(
        name="authorization",
        default_value=None
    )
    print(jwt.__version__)
    if authorization:
        if authorization.lower().startswith("bearer "):
            token = authorization[7:].strip()
        else:
            token = authorization.strip()

        try:
            # Decode without verifying the signature.            
            claims = jwt.decode(
                token,
                options={"verify_signature": False}
            )

            groups = claims.get("cognito:groups", [])

            if (
                not isinstance(groups, list)
                or not any(group in ("admin", "user") for group in groups)
            ):
                logger.warning(
                    "Access denied. Missing or invalid Cognito group."
                )

                return Response(
                    status_code=403,
                    content_type="application/json",
                    body='{"message":"Forbidden. API access is denied. Contact a administrator."}'
                )

        except Exception as e:
            logger.exception("Failed to decode token")

            return Response(
                status_code=403,
                content_type="application/json",
                body='{"message":"Forbidden. API access is denied."}'
            )
    return None



# ============================================================
# Helpers
# ============================================================

def bad_request(message):
    return Response(
        status_code=400,
        content_type="application/json",
        body=json.dumps({"success": False, "message": message})
    )


def not_found(message="Booking not found"):
    return Response(
        status_code=404,
        content_type="application/json",
        body=json.dumps({"success": False, "message": message})
    )


def parse_uuid(value, field_name):
    """Returns (uuid_str, None) or (None, Response)."""
    try:
        return str(uuid.UUID(str(value))), None
    except (ValueError, AttributeError):
        return None, bad_request(f"Invalid {field_name} format (must be UUID)")


def db_execute(fn):
    """Opens a connection/cursor, calls fn(cursor), commits, returns result."""
    connection = None
    cursor = None
    try:
        connection = get_db_connection()
        cursor = connection.cursor()
        result = fn(cursor)
        connection.commit()
        return result
    except psycopg2.OperationalError:
        logger.exception("Database connection error")
        if connection:
            connection.rollback()
        return Response(
            status_code=500,
            content_type="application/json",
            body=json.dumps({"success": False, "message": "Unable to connect to database"})
        )
    except psycopg2.Error:
        logger.exception("Database query error")
        if connection:
            connection.rollback()
        return Response(
            status_code=500,
            content_type="application/json",
            body=json.dumps({"success": False, "message": "Database query failed"})
        )
    except Exception:
        logger.exception("Unexpected error")
        if connection:
            connection.rollback()
        return Response(
            status_code=500,
            content_type="application/json",
            body=json.dumps({"success": False, "message": "Internal server error"})
        )
    finally:
        if cursor:
            cursor.close()
        if connection:
            connection.close()
        logger.info("Request completed")


BOOKING_COLUMNS = ["id", "service_id", "customer_id", "freelancer_id",
                   "status", "message", "created_at", "updated_at"]


def row_to_dict(row, columns):
    return {col: (str(val) if hasattr(val, 'hex') else val) for col, val in zip(columns, row)}


# ============================================================
# Bookings
# ============================================================

@app.get("/api/booking")
def get_booking():
    auth_error = access_validation()
    if auth_error:
        return auth_error

    logger.info("GET /api/booking request received")

    params = app.current_event.query_string_parameters or {}

    filters = []
    values = []

    for field in ("service_id", "customer_id", "freelancer_id"):
        if field in params:
            parsed, err = parse_uuid(params[field], field)
            if err:
                return err
            filters.append(f"{field} = %s")
            values.append(parsed)

    if "status" in params:
        status = params["status"].upper()
        if status not in VALID_STATUSES:
            return bad_request(f"Invalid status. Must be one of: {', '.join(sorted(VALID_STATUSES))}")
        filters.append("status = %s")
        values.append(status)

    where_clause = f"WHERE {' AND '.join(filters)}" if filters else ""

    def _query(cursor):
        cursor.execute(
            f"""
            SELECT id, service_id, customer_id, freelancer_id,
                   status, message, created_at, updated_at
            FROM bookings
            {where_clause}
            ORDER BY created_at DESC
            """,
            values
        )
        rows = cursor.fetchall()
        columns = [desc[0] for desc in cursor.description]
        bookings = [row_to_dict(row, columns) for row in rows]
        logger.info(f"Successfully returning {len(bookings)} bookings")
        return Response(
            status_code=200,
            content_type="application/json",
            body=json.dumps({"success": True, "count": len(bookings), "data": bookings}, default=str)
        )

    return db_execute(_query)


@app.post("/api/booking")
def create_booking():
    auth_error = access_validation()
    if auth_error:
        return auth_error

    logger.info("POST /api/booking request received")

    try:
        body = app.current_event.json_body
    except Exception:
        return bad_request("Invalid JSON body")

    # Required UUID fields
    uuid_fields = ["service_id", "customer_id", "freelancer_id"]
    missing = [f for f in uuid_fields if not body.get(f)]
    if missing:
        return bad_request(f"Missing required fields: {', '.join(missing)}")

    parsed_ids = {}
    for field in uuid_fields:
        parsed, err = parse_uuid(body[field], field)
        if err:
            return err
        parsed_ids[field] = parsed

    # customer_id and freelancer_id must differ
    if parsed_ids["customer_id"] == parsed_ids["freelancer_id"]:
        return bad_request("customer_id and freelancer_id must be different users")

    # Optional message
    message = body.get("message")
    if message is not None:
        message = str(message).strip() or None

    def _insert(cursor):
        cursor.execute(
            """
            INSERT INTO bookings (service_id, customer_id, freelancer_id, status, message)
            VALUES (%s, %s, %s, 'PENDING', %s)
            RETURNING id, service_id, customer_id, freelancer_id,
                      status, message, created_at, updated_at
            """,
            (parsed_ids["service_id"], parsed_ids["customer_id"],
             parsed_ids["freelancer_id"], message)
        )
        row = cursor.fetchone()
        columns = [desc[0] for desc in cursor.description]
        booking = row_to_dict(row, columns)
        logger.info(f"Booking created with id={booking['id']}")
        return Response(
            status_code=201,
            content_type="application/json",
            body=json.dumps({"success": True, "data": booking}, default=str)
        )

    return db_execute(_insert)


@app.put("/api/booking/<booking_id>/status")
def update_booking(booking_id: str):
    auth_error = access_validation()
    if auth_error:
        return auth_error

    logger.info(f"PUT /api/booking/{booking_id}/status request received")

    parsed_id, err = parse_uuid(booking_id, "booking_id")
    if err:
        return err

    try:
        body = app.current_event.json_body
    except Exception:
        return bad_request("Invalid JSON body")

    if not body.get("status"):
        return bad_request("Missing required field: status")

    new_status = str(body["status"]).upper()
    if new_status not in VALID_STATUSES:
        return bad_request(f"Invalid status. Must be one of: {', '.join(sorted(VALID_STATUSES))}")

    def _update(cursor):
        cursor.execute(
            """
            UPDATE bookings
            SET status = %s, updated_at = CURRENT_TIMESTAMP
            WHERE id = %s
            RETURNING id, service_id, customer_id, freelancer_id,
                      status, message, created_at, updated_at
            """,
            (new_status, parsed_id)
        )
        row = cursor.fetchone()
        if not row:
            return not_found()
        columns = [desc[0] for desc in cursor.description]
        booking = row_to_dict(row, columns)
        logger.info(f"Booking {parsed_id} status updated to {new_status}")
        return Response(
            status_code=200,
            content_type="application/json",
            body=json.dumps({"success": True, "data": booking}, default=str)
        )

    return db_execute(_update)


# ============================================================
# Lambda Entry Point
# ============================================================

@logger.inject_lambda_context
def handler(event, context):
    logger.info("Bookings API request received")

    try:
        response = app.resolve(event, context)

        # Ensure response is valid
        if response is None:
            return _response(500, {"error": "Empty response from app.resolve"})

        # If already correct format, return as-is
        if isinstance(response, dict) and "statusCode" in response:
            return response

        # Otherwise force JSON-safe wrapping
        return _response(200, response)

    except Exception as e:
        logger.exception("Unhandled error in ServicesApi")
        return _response(500, {"error": str(e)})


def _response(status_code, body):
    return {
        "statusCode": status_code,
        "headers": {
            "Content-Type": "application/json"
        },
        "body": json.dumps(body, default=str)
    }