# Security and hardening

- Only the proxy is exposed. The database and workers are reachable only on the compose network.
- `DB_PASSWORD` has no default; compose refuses to start without it.
- `tactic` runs as a non-root user with all capabilities dropped. `no-new-privileges` is set on every service.
- The proxy mounts only the media volume, read-only. It cannot read the TACTIC configuration or the database password.
- nginx hides its version (`server_tokens off`) and sends HSTS when TLS is enabled.
- TACTIC's default `admin` / `tactic` login is public and must be changed after first login.
- Root filesystems are writable. Read-only mode has not been tried.

# Operations

- **Restart policy:** all services use `restart: always`.
- **Logs:** `json-file` driver, 10 MB per file, 5 files per service.
- **Resources:** the app container is limited by `TACTIC_MEM_LIMIT` (default 4 GB).
- **Scaling workers:** change `TACTIC_PORTS` in `docker-compose.yml` and the `server` lines in `docker/nginx/tactic-upstream.inc`, then rebuild the proxy.
- **Backups:** `pg_dump` for the `sthpw` and `mlw` databases, and archives of the `tactic_data` and `tactic_assets` volumes. See the README for commands.

# Known limitations

- The workers share one container and one memory limit. A runaway worker can affect the others.
- Each worker logs "Starting Scheduler" at start-up; TACTIC's optional job queue and watch-folder services are not enabled.
- EXR frames get no thumbnails or web renditions (see the MLW project section).
- If the project install fails part way, the project record can already exist. The next start then skips the install and leaves the project incomplete. Remove the project and its `mlw` database, or the volumes on a new installation, before retrying.
- Upstream is at version `5.0.0.a02` (alpha), so behaviour may change between builds of the `magiclantern` branch. Pin `TACTIC_REF` to a tag for repeatable deployments.
