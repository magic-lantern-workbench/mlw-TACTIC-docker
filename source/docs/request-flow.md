# Request flow

1. The client connects to the proxy on port 80 or 443. When a certificate is present, port 80 redirects to HTTPS.
2. Requests under `/assets/` and `/context/` are answered by nginx directly, from the `tactic_assets` volume (mounted read-only) and from a copy of TACTIC's `src/context` baked into the proxy image. These never reach Python. nginx serves byte ranges, which video review needs. The proxy mounts no other data volume, so it cannot see TACTIC's configuration or the database password.
3. Everything else is proxied to the `tactic_workers` upstream: `tactic:8081`, `8082` and `8083`. nginx uses `least_conn`, passes `Host`, `X-Forwarded-For` and `X-Forwarded-Proto`, and keeps connections alive to the workers.
4. A worker that fails three times within 10 seconds is skipped by nginx (`max_fails=3 fail_timeout=10s`), so one dead worker does not cause errors.
5. Workers query PostgreSQL over the compose network at `db:5432`. The system database and each project's database are separate databases on the same server.
