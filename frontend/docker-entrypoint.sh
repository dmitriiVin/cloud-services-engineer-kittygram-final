#!/usr/bin/env sh
set -eu

if [ ! -d /static ]; then
  echo "Expected /static volume to be mounted" >&2
  exit 1
fi

# Copy index.html and root assets
cp -f /build/index.html /static/index.html
for f in /build/*; do
  name="$(basename "$f")"
  if [ "$name" = "static" ]; then
    continue
  fi
  if [ -f "$f" ]; then
    cp -f "$f" "/static/$name"
  fi
done

# Copy CRA build static assets so they are available at /static/js, /static/css, ...
if [ -d /build/static ]; then
  cp -R /build/static/* /static/
fi

exit 0
