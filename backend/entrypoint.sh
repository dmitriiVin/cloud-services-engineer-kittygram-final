#!/usr/bin/env sh
set -eu

python manage.py migrate --noinput
python manage.py collectstatic --noinput

exec gunicorn kittygram_backend.wsgi:application --bind 0.0.0.0:8000
