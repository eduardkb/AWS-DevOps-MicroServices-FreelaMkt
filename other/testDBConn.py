import psycopg2
import boto3

password = "VeryStrongPassword123!"

conn = None
try:
    conn = psycopg2.connect(
        host='freelamkt-aurora-instance.cyj86ui6k6rx.us-east-1.rds.amazonaws.com',
        port=5432,
        database='postgres',
        user='postgres',
        password=password
        # sslmode='verify-full',
        # sslrootcert='./global-bundle.pem'
    )
    conn.autocommit = True
    cur = conn.cursor()
    cur.execute('SELECT version();')
    print(cur.fetchone()[0])
    cur.close()
except Exception as e:
    print(f"Database error: {e}")
    raise
finally:
    if conn:
        conn.close()