#!/usr/bin/env sh
set -eu

python - <<'PY'
import os
import socket
import sys
import time

host = os.getenv("POSTGRES_HOST")
port = int(os.getenv("POSTGRES_PORT", "5432"))

if not host:
    sys.exit(0)

deadline = time.time() + 60
while time.time() < deadline:
    try:
        with socket.create_connection((host, port), timeout=2):
            sys.exit(0)
    except OSError:
        time.sleep(1)

print(f"Postgres is not available at {host}:{port}", file=sys.stderr)
sys.exit(1)
PY

python manage.py migrate --noinput
python manage.py collectstatic --noinput

exec gunicorn kittygram_backend.wsgi:application --bind 0.0.0.0:8000
