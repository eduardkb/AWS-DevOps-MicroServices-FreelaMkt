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
# Access Validation Helper
# ============================================================

def access_validation():    
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
    
    authorization = app.current_event.get_header_value(
        name="authorization",
        default_value=None
    )

    # Validate access tokenclaim
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
# Response Helpers
# ============================================================

def error_responses():
    return {
        "db_connect": Response(
            status_code=500,
            content_type="application/json",
            body=json.dumps({"success": False, "message": "Unable to connect to database"})
        ),
        "db_query": Response(
            status_code=500,
            content_type="application/json",
            body=json.dumps({"success": False, "message": "Database query failed"})
        ),
        "internal": Response(
            status_code=500,
            content_type="application/json",
            body=json.dumps({"success": False, "message": "Internal server error"})
        ),
    }


def handle_db_errors(func):
    def wrapper(*args, **kwargs):
        connection = None
        cursor = None
        try:
            connection = get_db_connection()
            cursor = connection.cursor()
            result = func(*args, connection=connection, cursor=cursor, **kwargs)
            connection.commit()
            return result
        except psycopg2.OperationalError:
            logger.exception("Database connection error")
            if connection:
                connection.rollback()
            return error_responses()["db_connect"]
        except psycopg2.Error:
            logger.exception("Database query error")
            if connection:
                connection.rollback()
            return error_responses()["db_query"]
        except Exception:
            logger.exception("Unexpected error")
            if connection:
                connection.rollback()
            return error_responses()["internal"]
        finally:
            if cursor:
                cursor.close()
            if connection:
                connection.close()
            logger.info("Request completed")
    return wrapper


# ============================================================
# Services
# ============================================================

@app.get("/api/service")
def list_service():
    auth_error = access_validation()
    if auth_error:
        return auth_error

    logger.info("GET /api/service request received")

    @handle_db_errors
    def _query(connection, cursor):
        cursor.execute("""
            SELECT id, user_id, title, description, category, price,
                   portfolio_keys, active, created_at, updated_at
            FROM services
            ORDER BY created_at DESC
        """)
        rows = cursor.fetchall()
        columns = [desc[0] for desc in cursor.description]
        services = [dict(zip(columns, row)) for row in rows]
        logger.info(f"Successfully returning {len(services)} services")
        return Response(
            status_code=200,
            content_type="application/json",
            body=json.dumps({"success": True, "count": len(services), "data": services}, default=str)
        )

    return _query()


@app.post("/api/service")
def create_service():
    auth_error = access_validation()
    if auth_error:
        return auth_error

    logger.info("POST /api/service request received")

    try:
        body = app.current_event.json_body
    except Exception:
        return Response(
            status_code=400,
            content_type="application/json",
            body=json.dumps({"success": False, "message": "Invalid JSON body"})
        )

    # Required fields
    required_fields = ["user_id", "title", "category", "price"]
    missing = [f for f in required_fields if not body.get(f)]
    if missing:
        return Response(
            status_code=400,
            content_type="application/json",
            body=json.dumps({"success": False, "message": f"Missing required fields: {', '.join(missing)}"})
        )

    # Validate user_id UUID
    try:
        user_id = str(uuid.UUID(str(body["user_id"])))
    except ValueError:
        return Response(
            status_code=400,
            content_type="application/json",
            body=json.dumps({"success": False, "message": "Invalid user_id format (must be UUID)"})
        )

    title = str(body["title"]).strip()
    if not title or len(title) > 255:
        return Response(
            status_code=400,
            content_type="application/json",
            body=json.dumps({"success": False, "message": "title must be between 1 and 255 characters"})
        )

    category = str(body["category"]).strip()
    if not category or len(category) > 100:
        return Response(
            status_code=400,
            content_type="application/json",
            body=json.dumps({"success": False, "message": "category must be between 1 and 100 characters"})
        )

    try:
        price = float(body["price"])
        if price < 0:
            raise ValueError()
    except (ValueError, TypeError):
        return Response(
            status_code=400,
            content_type="application/json",
            body=json.dumps({"success": False, "message": "price must be a non-negative number"})
        )

    description = body.get("description")
    if description is not None:
        description = str(description).strip() or None

    portfolio_keys = body.get("portfolio_keys")
    if portfolio_keys is not None and not isinstance(portfolio_keys, (list, dict)):
        return Response(
            status_code=400,
            content_type="application/json",
            body=json.dumps({"success": False, "message": "portfolio_keys must be a JSON object or array"})
        )

    active = body.get("active", True)
    if not isinstance(active, bool):
        return Response(
            status_code=400,
            content_type="application/json",
            body=json.dumps({"success": False, "message": "active must be a boolean"})
        )

    @handle_db_errors
    def _insert(connection, cursor):
        cursor.execute("""
            INSERT INTO services (user_id, title, description, category, price, portfolio_keys, active)
            VALUES (%s, %s, %s, %s, %s, %s, %s)
            RETURNING id, user_id, title, description, category, price,
                      portfolio_keys, active, created_at, updated_at
        """, (
            user_id, title, description, category, round(price, 2),
            json.dumps(portfolio_keys) if portfolio_keys is not None else None,
            active
        ))
        row = cursor.fetchone()
        columns = [desc[0] for desc in cursor.description]
        service = dict(zip(columns, row))
        logger.info(f"Service created with id={service['id']}")
        return Response(
            status_code=201,
            content_type="application/json",
            body=json.dumps({"success": True, "data": service}, default=str)
        )

    return _insert()


@app.get("/api/service/<service_id>")
def get_service(service_id: str):
    auth_error = access_validation()
    if auth_error:
        return auth_error

    logger.info(f"GET /api/service/{service_id} request received")

    try:
        service_id = str(uuid.UUID(service_id))
    except ValueError:
        return Response(
            status_code=400,
            content_type="application/json",
            body=json.dumps({"success": False, "message": "Invalid service_id format (must be UUID)"})
        )

    @handle_db_errors
    def _query(connection, cursor):
        cursor.execute("""
            SELECT id, user_id, title, description, category, price,
                   portfolio_keys, active, created_at, updated_at
            FROM services
            WHERE id = %s
        """, (service_id,))
        row = cursor.fetchone()
        if not row:
            return Response(
                status_code=404,
                content_type="application/json",
                body=json.dumps({"success": False, "message": "Service not found"})
            )
        columns = [desc[0] for desc in cursor.description]
        service = dict(zip(columns, row))
        logger.info(f"Service retrieved: id={service_id}")
        return Response(
            status_code=200,
            content_type="application/json",
            body=json.dumps({"success": True, "data": service}, default=str)
        )

    return _query()


@app.put("/api/service/<service_id>")
def update_service(service_id: str):
    auth_error = access_validation()
    if auth_error:
        return auth_error

    logger.info(f"PUT /api/service/{service_id} request received")

    try:
        service_id = str(uuid.UUID(service_id))
    except ValueError:
        return Response(
            status_code=400,
            content_type="application/json",
            body=json.dumps({"success": False, "message": "Invalid service_id format (must be UUID)"})
        )

    try:
        body = app.current_event.json_body
    except Exception:
        return Response(
            status_code=400,
            content_type="application/json",
            body=json.dumps({"success": False, "message": "Invalid JSON body"})
        )

    allowed_fields = {"title", "description", "category", "price", "portfolio_keys", "active"}
    updates = {k: v for k, v in body.items() if k in allowed_fields}

    if not updates:
        return Response(
            status_code=400,
            content_type="application/json",
            body=json.dumps({"success": False, "message": "No valid fields provided for update"})
        )

    # Validate provided fields
    if "title" in updates:
        title = str(updates["title"]).strip()
        if not title or len(title) > 255:
            return Response(
                status_code=400,
                content_type="application/json",
                body=json.dumps({"success": False, "message": "title must be between 1 and 255 characters"})
            )
        updates["title"] = title

    if "category" in updates:
        category = str(updates["category"]).strip()
        if not category or len(category) > 100:
            return Response(
                status_code=400,
                content_type="application/json",
                body=json.dumps({"success": False, "message": "category must be between 1 and 100 characters"})
            )
        updates["category"] = category

    if "price" in updates:
        try:
            price = float(updates["price"])
            if price < 0:
                raise ValueError()
            updates["price"] = round(price, 2)
        except (ValueError, TypeError):
            return Response(
                status_code=400,
                content_type="application/json",
                body=json.dumps({"success": False, "message": "price must be a non-negative number"})
            )

    if "description" in updates:
        desc = updates["description"]
        updates["description"] = str(desc).strip() if desc is not None else None

    if "portfolio_keys" in updates:
        pk = updates["portfolio_keys"]
        if pk is not None and not isinstance(pk, (list, dict)):
            return Response(
                status_code=400,
                content_type="application/json",
                body=json.dumps({"success": False, "message": "portfolio_keys must be a JSON object or array"})
            )
        updates["portfolio_keys"] = json.dumps(pk) if pk is not None else None

    if "active" in updates:
        if not isinstance(updates["active"], bool):
            return Response(
                status_code=400,
                content_type="application/json",
                body=json.dumps({"success": False, "message": "active must be a boolean"})
            )

    @handle_db_errors
    def _update(connection, cursor):
        set_clauses = ", ".join(f"{col} = %s" for col in updates.keys())
        set_clauses += ", updated_at = CURRENT_TIMESTAMP"
        values = list(updates.values()) + [service_id]

        cursor.execute(f"""
            UPDATE services
            SET {set_clauses}
            WHERE id = %s
            RETURNING id, user_id, title, description, category, price,
                      portfolio_keys, active, created_at, updated_at
        """, values)

        row = cursor.fetchone()
        if not row:
            return Response(
                status_code=404,
                content_type="application/json",
                body=json.dumps({"success": False, "message": "Service not found"})
            )
        columns = [desc[0] for desc in cursor.description]
        service = dict(zip(columns, row))
        logger.info(f"Service updated: id={service_id}")
        return Response(
            status_code=200,
            content_type="application/json",
            body=json.dumps({"success": True, "data": service}, default=str)
        )

    return _update()


@app.delete("/api/service/<service_id>")
def delete_service(service_id: str):
    auth_error = access_validation()
    if auth_error:
        return auth_error

    logger.info(f"DELETE /api/service/{service_id} request received")

    try:
        service_id = str(uuid.UUID(service_id))
    except ValueError:
        return Response(
            status_code=400,
            content_type="application/json",
            body=json.dumps({"success": False, "message": "Invalid service_id format (must be UUID)"})
        )

    @handle_db_errors
    def _delete(connection, cursor):
        cursor.execute("DELETE FROM services WHERE id = %s RETURNING id", (service_id,))
        row = cursor.fetchone()
        if not row:
            return Response(
                status_code=404,
                content_type="application/json",
                body=json.dumps({"success": False, "message": "Service not found"})
            )
        logger.info(f"Service deleted: id={service_id}")
        return Response(
            status_code=200,
            content_type="application/json",
            body=json.dumps({"success": True, "message": f"Service {service_id} deleted successfully"})
        )

    return _delete()


# ============================================================
# Lambda Entry Point
# ============================================================

@logger.inject_lambda_context
def handler(event, context):
    logger.info("Services API request received")
    return app.resolve(event, context)
