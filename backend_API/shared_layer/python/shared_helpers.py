import os
import json
import uuid
import jwt

from aws_lambda_powertools.event_handler import Response  # type: ignore

APP_ENV = os.getenv("APP_ENV", "prod")
IS_DEV = APP_ENV.lower() == "dev"


# ============================================================
# Response Helpers
# ============================================================

def bad_request(message):
    return Response(
        status_code=400,
        content_type="application/json",
        body=json.dumps({"success": False, "message": message})
    )


def not_found(message="Resource not found"):
    return Response(
        status_code=404,
        content_type="application/json",
        body=json.dumps({"success": False, "message": message})
    )


def conflict(message):
    return Response(
        status_code=409,
        content_type="application/json",
        body=json.dumps({"success": False, "message": message})
    )


def lambda_response(status_code, body):
    return {
        "statusCode": status_code,
        "headers": {"Content-Type": "application/json"},
        "body": json.dumps(body, default=str)
    }


# ============================================================
# UUID Helper
# ============================================================

def parse_uuid(value, field_name):
    """Returns (uuid_str, None) or (None, Response)."""
    try:
        return str(uuid.UUID(str(value))), None
    except (ValueError, AttributeError):
        return None, bad_request(f"Invalid {field_name} format (must be UUID)")


# ============================================================
# DB Row Helper
# ============================================================

def row_to_dict(row, columns):
    return {col: (str(val) if hasattr(val, 'hex') else val) for col, val in zip(columns, row)}


# ============================================================
# Access Validation
# ============================================================

def access_validation(app, logger=None):
    """
    Validates CloudFront secret header (prod only) and Cognito group membership.
    Returns a Response on failure, None on success.
    `app` is the APIGatewayHttpResolver instance from the calling lambda.
    """
    if not IS_DEV:
        expected_secret = os.environ.get("CLOUDFRONT_SECRET_HEADER")
        header_value = app.current_event.get_header_value(
            name="x-cloudfront-secret",
            default_value=None
        )
        if not expected_secret or header_value != expected_secret:
            if logger:
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

    if authorization:
        token = authorization[7:].strip() if authorization.lower().startswith("bearer ") else authorization.strip()

        try:
            claims = jwt.decode(token, options={"verify_signature": False})
            groups = claims.get("cognito:groups", [])

            if (
                not isinstance(groups, list)
                or not any(group in ("admin", "user") for group in groups)
            ):
                if logger:
                    logger.warning("Access denied. Missing or invalid Cognito group.")
                return Response(
                    status_code=403,
                    content_type="application/json",
                    body='{"message":"Forbidden. API access is denied. Contact a administrator."}'
                )

        except Exception:
            if logger:
                logger.exception("Failed to decode token")
            return Response(
                status_code=403,
                content_type="application/json",
                body='{"message":"Forbidden. API access is denied."}'
            )

    return None


# ============================================================
# Cognito Sub Extractor
# ============================================================

def get_cognito_sub(app):
    """Extract cognito sub from the Cognito authorizer JWT claims."""
    try:
        return (
            app.current_event.request_context
            .get("authorizer", {})
            .get("jwt", {})
            .get("claims", {})
            .get("sub")
        )
    except Exception:
        return None
