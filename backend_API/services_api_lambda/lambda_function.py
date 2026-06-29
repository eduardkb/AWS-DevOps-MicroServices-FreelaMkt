import os
import json
import uuid

from aws_lambda_powertools import Logger  # type: ignore
from aws_lambda_powertools.event_handler import APIGatewayHttpResolver  # type: ignore
from aws_lambda_powertools.event_handler import Response  # type: ignore

from shared_db import db_execute # type: ignore
from shared_helpers import ( # type: ignore
    access_validation, bad_request, not_found, parse_uuid, lambda_response
)

logger = Logger()
app = APIGatewayHttpResolver()


# ============================================================
# Services
# ============================================================

@app.get("/api/service")
def list_service():
    auth_error = access_validation(app, logger)
    if auth_error:
        return auth_error

    logger.info("GET /api/service request received")

    def _query(cursor):
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

    return db_execute(_query, logger)


@app.post("/api/service")
def create_service():
    auth_error = access_validation(app, logger)
    if auth_error:
        return auth_error

    logger.info("POST /api/service request received")

    try:
        body = app.current_event.json_body
    except Exception:
        return bad_request("Invalid JSON body")

    required_fields = ["user_id", "title", "category", "price"]
    missing = [f for f in required_fields if not body.get(f)]
    if missing:
        return bad_request(f"Missing required fields: {', '.join(missing)}")

    user_id, err = parse_uuid(body["user_id"], "user_id")
    if err:
        return err

    title = str(body["title"]).strip()
    if not title or len(title) > 255:
        return bad_request("title must be between 1 and 255 characters")

    category = str(body["category"]).strip()
    if not category or len(category) > 100:
        return bad_request("category must be between 1 and 100 characters")

    try:
        price = float(body["price"])
        if price < 0:
            raise ValueError()
    except (ValueError, TypeError):
        return bad_request("price must be a non-negative number")

    description = body.get("description")
    if description is not None:
        description = str(description).strip() or None

    portfolio_keys = body.get("portfolio_keys")
    if portfolio_keys is not None and not isinstance(portfolio_keys, (list, dict)):
        return bad_request("portfolio_keys must be a JSON object or array")

    active = body.get("active", True)
    if not isinstance(active, bool):
        return bad_request("active must be a boolean")

    def _insert(cursor):
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

    return db_execute(_insert, logger)


@app.get("/api/service/<service_id>")
def get_service(service_id: str):
    auth_error = access_validation(app, logger)
    if auth_error:
        return auth_error

    logger.info(f"GET /api/service/{service_id} request received")

    service_id, err = parse_uuid(service_id, "service_id")
    if err:
        return err

    def _query(cursor):
        cursor.execute("""
            SELECT id, user_id, title, description, category, price,
                   portfolio_keys, active, created_at, updated_at
            FROM services
            WHERE id = %s
        """, (service_id,))
        row = cursor.fetchone()
        if not row:
            return not_found("Service not found")
        columns = [desc[0] for desc in cursor.description]
        service = dict(zip(columns, row))
        logger.info(f"Service retrieved: id={service_id}")
        return Response(
            status_code=200,
            content_type="application/json",
            body=json.dumps({"success": True, "data": service}, default=str)
        )

    return db_execute(_query, logger)


@app.put("/api/service/<service_id>")
def update_service(service_id: str):
    auth_error = access_validation(app, logger)
    if auth_error:
        return auth_error

    logger.info(f"PUT /api/service/{service_id} request received")

    service_id, err = parse_uuid(service_id, "service_id")
    if err:
        return err

    try:
        body = app.current_event.json_body
    except Exception:
        return bad_request("Invalid JSON body")

    allowed_fields = {"title", "description", "category", "price", "portfolio_keys", "active"}
    updates = {k: v for k, v in body.items() if k in allowed_fields}

    if not updates:
        return bad_request("No valid fields provided for update")

    if "title" in updates:
        title = str(updates["title"]).strip()
        if not title or len(title) > 255:
            return bad_request("title must be between 1 and 255 characters")
        updates["title"] = title

    if "category" in updates:
        category = str(updates["category"]).strip()
        if not category or len(category) > 100:
            return bad_request("category must be between 1 and 100 characters")
        updates["category"] = category

    if "price" in updates:
        try:
            price = float(updates["price"])
            if price < 0:
                raise ValueError()
            updates["price"] = round(price, 2)
        except (ValueError, TypeError):
            return bad_request("price must be a non-negative number")

    if "description" in updates:
        desc = updates["description"]
        updates["description"] = str(desc).strip() if desc is not None else None

    if "portfolio_keys" in updates:
        pk = updates["portfolio_keys"]
        if pk is not None and not isinstance(pk, (list, dict)):
            return bad_request("portfolio_keys must be a JSON object or array")
        updates["portfolio_keys"] = json.dumps(pk) if pk is not None else None

    if "active" in updates:
        if not isinstance(updates["active"], bool):
            return bad_request("active must be a boolean")

    def _update(cursor):
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
            return not_found("Service not found")
        columns = [desc[0] for desc in cursor.description]
        service = dict(zip(columns, row))
        logger.info(f"Service updated: id={service_id}")
        return Response(
            status_code=200,
            content_type="application/json",
            body=json.dumps({"success": True, "data": service}, default=str)
        )

    return db_execute(_update, logger)


@app.delete("/api/service/<service_id>")
def delete_service(service_id: str):
    auth_error = access_validation(app, logger)
    if auth_error:
        return auth_error

    logger.info(f"DELETE /api/service/{service_id} request received")

    service_id, err = parse_uuid(service_id, "service_id")
    if err:
        return err

    def _delete(cursor):
        cursor.execute("DELETE FROM services WHERE id = %s RETURNING id", (service_id,))
        row = cursor.fetchone()
        if not row:
            return not_found("Service not found")
        logger.info(f"Service deleted: id={service_id}")
        return Response(
            status_code=200,
            content_type="application/json",
            body=json.dumps({"success": True, "message": f"Service {service_id} deleted successfully"})
        )

    return db_execute(_delete, logger)


# ============================================================
# Lambda Entry Point
# ============================================================

@logger.inject_lambda_context
def handler(event, context):
    logger.info("Services API request received")

    try:
        response = app.resolve(event, context)

        if response is None:
            return lambda_response(500, {"error": "Empty response from app.resolve"})

        if isinstance(response, dict) and "statusCode" in response:
            return response

        return lambda_response(200, response)

    except Exception as e:
        logger.exception("Unhandled error in ServicesApi")
        return lambda_response(500, {"error": str(e)})
