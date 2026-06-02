import os
import json
import boto3
import psycopg2

secrets = boto3.client("secretsmanager")

def get_secret():

    secret_arn = os.environ["DB_SECRET_ARN"]

    response = secrets.get_secret_value(
        SecretId=secret_arn
    )

    return json.loads(response["SecretString"])


def handler(event, context):

    secret = get_secret()

    connection = psycopg2.connect(
        host=secret["host"],
        port=secret["port"],
        dbname=secret["database"],
        user=secret["username"],
        password=secret["password"]
    )

    connection.autocommit = True

    cursor = connection.cursor()

    with open("migration.sql", "r") as file:
        sql = file.read()

    cursor.execute(sql)

    cursor.close()
    connection.close()

    return {
        "success": True
    }