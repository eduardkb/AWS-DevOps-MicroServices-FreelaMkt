import os
import re
import json

import boto3  # type: ignore
from botocore.exceptions import ClientError  # type: ignore

from aws_lambda_powertools import Logger  # type: ignore
from aws_lambda_powertools.event_handler import APIGatewayHttpResolver  # type: ignore
from aws_lambda_powertools.event_handler import Response  # type: ignore

from shared_db import db_execute # type: ignore
from shared_helpers import ( # type: ignore
    access_validation, bad_request, not_found, conflict,
    get_cognito_sub, lambda_response
)

logger = Logger()
app = APIGatewayHttpResolver()

cognito_client = boto3.client("cognito-idp")
COGNITO_USER_POOL_ID = os.environ.get("COGNITO_USER_POOL_ID")
COGNITO_USER_GROUP = "user"

EMAIL_RE = re.compile(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')

# Letters (upper/lower), spaces, underscores, dashes and dots only.
# Must start with a letter, 3-100 characters total.
USERNAME_RE = re.compile(r'^[A-Za-z][A-Za-z _.-]{3,20}$')

# At least 8 characters, with at least one lowercase, one uppercase,
# one digit and one special character.
PASSWORD_RE = re.compile(r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[^\w\s]).{8,99}$')


# ============================================================
# Cognito helpers
# ============================================================

def _delete_cognito_user(username):
    """Best-effort rollback of a Cognito user. Never raises."""
    try:
        cognito_client.admin_delete_user(
            UserPoolId=COGNITO_USER_POOL_ID,
            Username=username
        )
        logger.info(f"Rolled back Cognito user: username={username}")
    except ClientError:
        logger.exception(f"Failed to roll back Cognito user: username={username}")


# ============================================================
# Users
# ============================================================

@app.get("/api/user/me")
def get_user():
    auth_error = access_validation(app, logger)
    if auth_error:
        return auth_error

    logger.info("GET /api/user/me request received")
    
    cognito_sub = get_cognito_sub(app)
    if not cognito_sub:
        return bad_request(f"Missing or invalid user SubID: {cognito_sub}")

    def _query(cursor):
        cursor.execute(
            """
            SELECT id, cognito_sub, email, preferred_username,
                   full_name, bio, avatar_key, created_at, updated_at
            FROM users
            WHERE cognito_sub = %s
            """,
            (cognito_sub,)
        )
        row = cursor.fetchone()
        if not row:
            return not_found("User not found")
        columns = [desc[0] for desc in cursor.description]
        user = dict(zip(columns, row))
        logger.info(f"User retrieved: cognito_sub={cognito_sub}")
        return Response(
            status_code=200,
            content_type="application/json",
            body=json.dumps({"success": True, "data": user}, default=str)
        )

    return db_execute(_query, logger)


@app.post("/api/user")
def create_user():
    auth_error = access_validation(app, logger)
    if auth_error:
        return auth_error

    logger.info("POST /api/user request received")

    if not COGNITO_USER_POOL_ID:
        logger.error("COGNITO_USER_POOL_ID environment variable is not configured")
        return Response(
            status_code=500,
            content_type="application/json",
            body=json.dumps({"success": False, "error": "Server misconfiguration: missing Cognito user pool"})
        )

    try:
        body = app.current_event.json_body
    except Exception:
        return bad_request("Invalid JSON body")

    # ------------------------------------------------------------------
    # Field verification: Full Name, Email, Preferred User Name, Password
    # ------------------------------------------------------------------
    field_labels = {
        "full_name": "Full Name",
        "email": "Email",
        "preferred_username": "Preferred User Name",
        "password": "Password",
    }
    missing = [label for field, label in field_labels.items() if not body.get(field)]
    if missing:
        return bad_request(f"Missing required fields: {', '.join(missing)}")

    email = str(body["email"]).strip().lower()
    if not EMAIL_RE.match(email) or len(email) > 255:
        return bad_request("Email must be a valid email address")

    preferred_username = str(body["preferred_username"]).strip()
    if not USERNAME_RE.match(preferred_username):
        return bad_request(
            "Preferred User Name must be 3-100 characters and contain only letters, spaces, underscores, dots, or hyphens, starting with a letter"
        )

    full_name = str(body["full_name"]).strip()
    if not full_name or len(full_name) > 255:
        return bad_request("Full Name must be between 1 and 255 characters")

    password = str(body["password"])
    if not PASSWORD_RE.match(password):
        return bad_request(
            "Password must be at least 8 characters long and include an uppercase letter, a lowercase letter, a number, and a special character"
        )

    bio = body.get("bio")
    if bio is not None:
        bio = str(bio).strip() or None

    avatar_key = body.get("avatar_key")
    if avatar_key is not None:
        avatar_key = str(avatar_key).strip()
        if len(avatar_key) > 500:
            return bad_request("avatar_key must not exceed 500 characters")
        avatar_key = avatar_key or None

    # ------------------------------------------------------------------
    # Step 1: Create the user in Cognito, set their password, and add
    # them to the "user" group.
    # ------------------------------------------------------------------
    cognito_sub = None
    try:
        create_resp = cognito_client.admin_create_user(
            UserPoolId=COGNITO_USER_POOL_ID,
            Username=preferred_username,
            UserAttributes=[
                {"Name": "email", "Value": email},
                {"Name": "email_verified", "Value": "true"},
                {"Name": "name", "Value": full_name},
            ],
            MessageAction="SUPPRESS",
        )
        cognito_sub = next(
            (attr["Value"] for attr in create_resp["User"]["Attributes"] if attr["Name"] == "sub"),
            None
        )
        if not cognito_sub:
            raise RuntimeError("Cognito did not return a sub for the newly created user")

        cognito_client.admin_set_user_password(
            UserPoolId=COGNITO_USER_POOL_ID,
            Username=preferred_username,
            Password=password,
            Permanent=True,
        )

        cognito_client.admin_add_user_to_group(
            UserPoolId=COGNITO_USER_POOL_ID,
            Username=preferred_username,
            GroupName=COGNITO_USER_GROUP,
        )

    except ClientError as e:
        logger.exception("Cognito error while creating user")
        if cognito_sub:
            _delete_cognito_user(preferred_username)
        error_code = e.response.get("Error", {}).get("Code", "")
        if error_code == "UsernameExistsException":
            return conflict("A user with this Preferred User Name already exists")
        message = e.response.get("Error", {}).get("error", str(e))
        return bad_request(f"Failed to create user account: {message}")
    except Exception as e:
        logger.exception("Unexpected error while creating Cognito user")
        if cognito_sub:
            _delete_cognito_user(preferred_username)
        return bad_request(f"Failed to create user account: {str(e)}")

    # ------------------------------------------------------------------
    # Step 2: Add the user to the RDS table. If this fails for any
    # reason, roll back the Cognito user we just created.
    # ------------------------------------------------------------------
    def _insert(cursor):
        cursor.execute(
            "SELECT cognito_sub, email, preferred_username FROM users WHERE cognito_sub = %s OR email = %s OR preferred_username = %s",
            (cognito_sub, email, preferred_username)
        )
        existing = cursor.fetchone()
        if existing:
            ex_sub, ex_email, ex_uname = existing
            if ex_sub == cognito_sub:
                return conflict("A user with this Cognito account already exists")
            if ex_email == email:
                return conflict("Email address is already in use")
            if ex_uname == preferred_username:
                return conflict("Preferred User Name is already taken")

        cursor.execute(
            """
            INSERT INTO users (cognito_sub, email, preferred_username, full_name, bio, avatar_key)
            VALUES (%s, %s, %s, %s, %s, %s)
            RETURNING id, cognito_sub, email, preferred_username,
                      full_name, bio, avatar_key, created_at, updated_at
            """,
            (cognito_sub, email, preferred_username, full_name, bio, avatar_key)
        )
        row = cursor.fetchone()
        columns = [desc[0] for desc in cursor.description]
        user = dict(zip(columns, row))
        logger.info(f"User created: id={user['id']} cognito_sub={cognito_sub}")
        return Response(
            status_code=201,
            content_type="application/json",
            body=json.dumps({"success": True, "data": user}, default=str)
        )

    try:
        result = db_execute(_insert, logger)
    except Exception as e:
        logger.exception("Unexpected error while inserting user into RDS")
        _delete_cognito_user(preferred_username)
        return bad_request(
            "Failed to create user record in the database. The Cognito account has been rolled back, please try again."
        )

    # db_execute / conflict / not_found all return Response objects.
    # Anything other than a successful 201 means the RDS write did not
    # go through, so the Cognito user must be rolled back too.
    if not isinstance(result, Response) or result.status_code != 201:
        _delete_cognito_user(preferred_username)

    return result


@app.put("/api/user/me")
def update_user():
    auth_error = access_validation(app, logger)
    if auth_error:
        return auth_error

    logger.info("PUT /api/user/me request received")

    cognito_sub = get_cognito_sub(app)
    if not cognito_sub:
        return bad_request("Missing or invalid authorization context")

    try:
        body = app.current_event.json_body
    except Exception:
        return bad_request("Invalid JSON body")

    allowed_fields = {"preferred_username", "full_name", "bio", "avatar_key"}
    updates = {k: v for k, v in body.items() if k in allowed_fields}

    if not updates:
        return bad_request(f"No valid fields provided. Updatable fields: {', '.join(sorted(allowed_fields))}")

    if "preferred_username" in updates:
        preferred_username = str(updates["preferred_username"]).strip()
        if not USERNAME_RE.match(preferred_username):
            return bad_request(
                "Preferred User Name must be 3-100 characters and contain only letters, spaces, underscores, dots, or hyphens, starting with a letter"
            )
        updates["preferred_username"] = preferred_username

    if "full_name" in updates:
        full_name = str(updates["full_name"]).strip()
        if not full_name or len(full_name) > 255:
            return bad_request("full_name must be between 1 and 255 characters")

    if "bio" in updates:
        bio = updates["bio"]
        updates["bio"] = str(bio).strip() if bio is not None else None

    if "avatar_key" in updates:
        ak = updates["avatar_key"]
        if ak is not None:
            ak = str(ak).strip()
            if len(ak) > 500:
                return bad_request("avatar_key must not exceed 500 characters")
        updates["avatar_key"] = ak or None

    def _update(cursor):
        if "preferred_username" in updates:
            cursor.execute(
                "SELECT id FROM users WHERE preferred_username = %s AND cognito_sub != %s",
                (updates["preferred_username"], cognito_sub)
            )
            if cursor.fetchone():
                return conflict("preferred_username is already taken")

        set_clause = ", ".join(f"{col} = %s" for col in updates.keys())
        set_clause += ", updated_at = CURRENT_TIMESTAMP"
        values = list(updates.values()) + [cognito_sub]

        cursor.execute(
            f"""
            UPDATE users
            SET {set_clause}
            WHERE cognito_sub = %s
            RETURNING id, cognito_sub, email, preferred_username,
                      full_name, bio, avatar_key, created_at, updated_at
            """,
            values
        )
        row = cursor.fetchone()
        if not row:
            return not_found("User not found")
        columns = [desc[0] for desc in cursor.description]
        user = dict(zip(columns, row))
        logger.info(f"User updated: cognito_sub={cognito_sub}")
        return Response(
            status_code=200,
            content_type="application/json",
            body=json.dumps({"success": True, "data": user}, default=str)
        )

    return db_execute(_update, logger)


@app.get("/api/user/healthcheck")
def healthcheck():
    auth_error = access_validation(app, logger)
    if auth_error:
        return auth_error

    return Response(
        status_code=200,
        content_type="application/json",
        body='{"message":"API up and running"}'
    )


@app.get("/api/user/getparam")
def getparam():
    auth_error = access_validation(app, logger)
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

    try:
        response = app.resolve(event, context)

        if response is None:
            return lambda_response(500, {"error": "Empty response from app.resolve"})

        if isinstance(response, dict) and "statusCode" in response:
            return response

        return lambda_response(200, response)

    except Exception as e:
        logger.exception("Unhandled error in UsersApi")
        return lambda_response(500, {"error": str(e)})
