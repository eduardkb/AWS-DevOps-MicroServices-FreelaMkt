import os
import json
import boto3
import psycopg2

APP_ENV = os.getenv("APP_ENV", "prod")
IS_DEV = APP_ENV.lower() == "dev"

# Module-level connection cache (reused across warm Lambda invocations)
_connection = None


def get_secret():
    if IS_DEV:
        return {
            "username": os.environ["DB_USER"],
            "password": os.environ["DB_PASSWORD"]
        }

    secrets_client = boto3.client("secretsmanager")
    secret_arn = os.environ["DB_SECRET_ARN"]
    response = secrets_client.get_secret_value(SecretId=secret_arn)
    return json.loads(response["SecretString"])


def get_db_connection():
    """Return a cached connection, creating or reconnecting as needed."""
    global _connection

    if _connection is not None:
        try:
            # Cheap liveness check — avoids a full reconnect on warm invocations
            _connection.cursor().execute("SELECT 1")
            return _connection
        except Exception:
            try:
                _connection.close()
            except Exception:
                pass
            _connection = None

    db_timeout = 15 if IS_DEV else 60
    secret = get_secret()

    _connection = psycopg2.connect(
        host=os.environ["DB_HOST"],
        port=os.environ["DB_PORT"],
        dbname=os.environ["DB_NAME"],
        user=secret["username"],
        password=secret["password"],
        connect_timeout=db_timeout,
        options="-c statement_timeout=5000"
    )
    return _connection


def db_execute(fn, logger=None):
    """
    Opens a cursor on the shared connection, calls fn(cursor), commits,
    and returns the result. Rolls back and returns an error Response on
    database exceptions.  Imports Response lazily to avoid a hard
    dependency on aws_lambda_powertools in the migration lambda.
    """
    from aws_lambda_powertools.event_handler import Response  # noqa

    connection = None
    cursor = None
    try:
        connection = get_db_connection()
        cursor = connection.cursor()
        result = fn(cursor)
        connection.commit()
        return result
    except psycopg2.OperationalError:
        if logger:
            logger.exception("Database connection error")
        if connection:
            try:
                connection.rollback()
            except Exception:
                pass
        # Force reconnect on next call
        global _connection
        _connection = None
        return Response(
            status_code=500,
            content_type="application/json",
            body=json.dumps({"success": False, "message": "Unable to connect to database"})
        )
    except psycopg2.Error:
        if logger:
            logger.exception("Database query error")
        if connection:
            try:
                connection.rollback()
            except Exception:
                pass
        return Response(
            status_code=500,
            content_type="application/json",
            body=json.dumps({"success": False, "message": "Database query failed"})
        )
    except Exception:
        if logger:
            logger.exception("Unexpected error")
        if connection:
            try:
                connection.rollback()
            except Exception:
                pass
        return Response(
            status_code=500,
            content_type="application/json",
            body=json.dumps({"success": False, "message": "Internal server error"})
        )
    finally:
        if cursor:
            try:
                cursor.close()
            except Exception:
                pass
