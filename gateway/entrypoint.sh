#!/bin/sh
set -e

if [ -z "$OPENMOKO_USER" ] || [ -z "$OPENMOKO_PASSWORD" ]; then
    echo "ERROR: OPENMOKO_USER and OPENMOKO_PASSWORD must be set"
    exit 1
fi

htpasswd -nbm "$OPENMOKO_USER" "$OPENMOKO_PASSWORD" > /etc/nginx/.htpasswd

exec nginx -g 'daemon off;'
