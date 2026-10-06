#!/bin/sh
# Use the TLS server block when a certificate is mounted at /etc/nginx/certs, plain HTTP otherwise.
set -eu
if [ -f /etc/nginx/certs/tls.crt ] && [ -f /etc/nginx/certs/tls.key ]; then
    echo "TLS certificate found: enabling HTTPS"
    cp /etc/nginx/tactic/tactic-tls.conf /etc/nginx/conf.d/default.conf
else
    echo "No TLS certificate at /etc/nginx/certs: serving plain HTTP"
    cp /etc/nginx/tactic/tactic-http.conf /etc/nginx/conf.d/default.conf
fi
