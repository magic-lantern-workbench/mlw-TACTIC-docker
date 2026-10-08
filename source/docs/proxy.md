# Proxy (`proxy`)

Built from the `proxy` target of the `Dockerfile`. Configuration lives in `docker/nginx/`:

| File | Purpose |
|------|---------|
| `tactic-upstream.inc` | Worker upstream. Its ports must match `TACTIC_PORTS` in `docker-compose.yml` |
| `tactic-common.inc` | Static locations, gzip, proxy headers, long timeouts, unlimited upload size (TACTIC enforces its own limits) |
| `tactic-http.conf` | Plain HTTP server on port 80 |
| `tactic-tls.conf` | HTTPS server on 443 (TLS 1.2/1.3, HSTS) plus the port 80 redirect |
| `10-select-config.sh` | Container start hook. Installs the TLS config when `/etc/nginx/certs/tls.crt` and `tls.key` both exist, otherwise the HTTP config |

Certificates come from `TLS_CERT_DIR` (default `./certs`), mounted read-only.
