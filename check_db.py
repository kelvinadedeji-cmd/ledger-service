
import psycopg

with psycopg.connect(
    host="localhost",
    port=5432,
    dbname="ledger",
    user="ledger_user",
    password="ledger_dev_password",
) as connection:
    with connection.cursor() as cursor:
        cursor.execute("SELECT 1")
        result = cursor.fetchone()

        print("Database connection successful!")
        print("Query result:", result[0])
