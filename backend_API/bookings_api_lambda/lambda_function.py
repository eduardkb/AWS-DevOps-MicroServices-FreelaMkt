import os
import json

from aws_lambda_powertools import Logger  # type: ignore
from aws_lambda_powertools.event_handler import APIGatewayHttpResolver  # type: ignore
from aws_lambda_powertools.event_handler import Response  # type: ignore

from shared_db import db_execute
from shared_helpers import (
    access_validation, bad_request, not_found, parse_uuid,
    row_to_dict, lambda_response
)

logger = Logger()
app = APIGatewayHttpResolver()

VALID_STATUSES = {"PENDING", "ACCEPTED", "REJECTED", "COMPLETED", "CANCELLED"}


# ============================================================
# Bookings
# ============================================================

@app.get("/api/booking")
def get_booking():
    auth_error = access_validation(app, logger)
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

    return db_execute(_query, logger)


@app.post("/api/booking")
def create_booking():
    auth_error = access_validation(app, logger)
    if auth_error:
        return auth_error

    logger.info("POST /api/booking request received")

    try:
        body = app.current_event.json_body
    except Exception:
        return bad_request("Invalid JSON body")

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

    if parsed_ids["customer_id"] == parsed_ids["freelancer_id"]:
        return bad_request("customer_id and freelancer_id must be different users")

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

    return db_execute(_insert, logger)


@app.put("/api/booking/<booking_id>/status")
def update_booking(booking_id: str):
    auth_error = access_validation(app, logger)
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
            return not_found("Booking not found")
        columns = [desc[0] for desc in cursor.description]
        booking = row_to_dict(row, columns)
        logger.info(f"Booking {parsed_id} status updated to {new_status}")
        return Response(
            status_code=200,
            content_type="application/json",
            body=json.dumps({"success": True, "data": booking}, default=str)
        )

    return db_execute(_update, logger)


# ============================================================
# Lambda Entry Point
# ============================================================

@logger.inject_lambda_context
def handler(event, context):
    logger.info("Bookings API request received")

    try:
        response = app.resolve(event, context)

        if response is None:
            return lambda_response(500, {"error": "Empty response from app.resolve"})

        if isinstance(response, dict) and "statusCode" in response:
            return response

        return lambda_response(200, response)

    except Exception as e:
        logger.exception("Unhandled error in BookingsApi")
        return lambda_response(500, {"error": str(e)})
