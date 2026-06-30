import os
import re
import json

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

EMAIL_RE = re.compile(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
USERNAME_RE = re.compile(r'^[a-zA-Z0-9_.-]{3,100}$')


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

    try:
        body = app.current_event.json_body
    except Exception:
        return bad_request("Invalid JSON body")

    required = ["cognito_sub", "email", "preferred_username", "full_name"]
    missing = [f for f in required if not body.get(f)]
    if missing:
        return bad_request(f"Missing required fields: {', '.join(missing)}")

    cognito_sub = str(body["cognito_sub"]).strip()
    if not cognito_sub or len(cognito_sub) > 255:
        return bad_request("cognito_sub must be between 1 and 255 characters")

    email = str(body["email"]).strip().lower()
    if not EMAIL_RE.match(email) or len(email) > 255:
        return bad_request("Invalid email address")

    preferred_username = str(body["preferred_username"]).strip()
    if not USERNAME_RE.match(preferred_username):
        return bad_request(
            "preferred_username must be 3–100 characters and contain only letters, numbers, underscores, dots, or hyphens"
        )

    full_name = str(body["full_name"]).strip()
    if not full_name or len(full_name) > 255:
        return bad_request("full_name must be between 1 and 255 characters")

    bio = body.get("bio")
    if bio is not None:
        bio = str(bio).strip() or None

    avatar_key = body.get("avatar_key")
    if avatar_key is not None:
        avatar_key = str(avatar_key).strip()
        if len(avatar_key) > 500:
            return bad_request("avatar_key must not exceed 500 characters")
        avatar_key = avatar_key or None

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
                return conflict("preferred_username is already taken")

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

    return db_execute(_insert, logger)


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
                "preferred_username must be 3–100 characters and contain only letters, numbers, underscores, dots, or hyphens"
            )
        updates["preferred_username"] = preferred_username

    if "full_name" in updates:
        full_name = str(updates["full_name"]).strip()
        if not full_name or len(full_name) > 255:
            return bad_request("full_name must be between 1 and 255 characters")
        updates["full_name"] = full_name

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
