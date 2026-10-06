# mlw-TACTIC-docker

Docker and Docker Compose setup for [TACTIC](https://github.com/magic-lantern-workbench/TACTIC), running the app server against a PostgreSQL database.

The image clones TACTIC at build time (this repo contains no TACTIC source), installs its Python dependencies, and runs it on CherryPy. On first start the `sthpw` database is created and populated automatically.

## Quick start

```bash
cp .env.example .env      # then edit .env and set DB_PASSWORD (required)
docker compose up -d --build
```

The first start takes about 30 seconds while the database is created. Then open <http://localhost/tactic> and log in with:

- **Username:** `admin`
- **Password:** `tactic`

Change the admin password after your first login.

## Architecture

For a diagram of the components and a detailed description of each, see the [architecture document](doc/mlw-TACTIC-docker_Architecture.docx).

For every table and column in the `sthpw` system database, see the [sthpw schema document](doc/mlw-TACTIC-docker_sthpw_Schema.docx).

```
client -> proxy (nginx: TLS, static files, load balancing)
            -> tactic (monitor.py: 3 CherryPy workers on 8081-8083, auto-restarted)
                 -> db (PostgreSQL 16)
```

- **proxy** terminates TLS, serves `/assets` and `/context` directly, gzips responses and balances across the workers, failing over if one dies.
- **tactic** runs upstream's `monitor.py`, which supervises the worker processes and restarts any that stop responding. The image is a multi-stage build, so compilers are not in the runtime image. It runs as a non-root user under `tini` with all capabilities dropped.
- **db** is only reachable on the compose network.
- All services restart automatically, have rotated logs, and the app and database have health checks.

## HTTPS

Put `tls.crt` and `tls.key` in `./certs` (or point `TLS_CERT_DIR` at another directory) and restart the proxy. HTTPS is enabled automatically when both files exist, and HTTP redirects to it. Also set `TACTIC_PROTOCOL=https` and `TACTIC_HOSTNAME` to your public name so generated links are correct.

```bash
docker compose up -d --force-recreate proxy
```

Without certificates the proxy serves plain HTTP on port 80.

## Configuration

Settings are read from `.env` (see `.env.example`):

| Variable                  | Default                                                 | Description                                      |
|---------------------------|---------------------------------------------------------|--------------------------------------------------|
| `DB_PASSWORD`             | none, **required**                                      | PostgreSQL password                              |
| `DB_USER`                 | `postgres`                                              | PostgreSQL user                                  |
| `HTTP_PORT`/`HTTPS_PORT`  | `80` / `443`                                            | Host ports for the proxy                         |
| `TACTIC_HOSTNAME`         | `localhost`                                             | Public hostname written to the TACTIC config     |
| `TACTIC_PROTOCOL`         | `http`                                                  | `https` when serving TLS                         |
| `TLS_CERT_DIR`            | `./certs`                                               | Directory with `tls.crt` and `tls.key`           |
| `TACTIC_REPO`             | `https://github.com/magic-lantern-workbench/TACTIC.git` | Git repo cloned at build time                    |
| `TACTIC_REF`              | `5.0`                                                   | Branch or tag to build; pin a tag for production |
| `TACTIC_MEM_LIMIT`        | `4g`                                                    | Memory limit for the app container               |
| `PG_SHARED_BUFFERS`, `PG_EFFECTIVE_CACHE_SIZE`, `PG_MAX_CONNECTIONS` | `256MB`, `768MB`, `200` | PostgreSQL tuning |

`TACTIC_REPO` and `TACTIC_REF` are build arguments, so changing them requires `docker compose build`.

To change the number of workers, edit `TACTIC_PORTS` in `docker-compose.yml` and the matching `server` lines in `docker/nginx/tactic-upstream.inc`, then rebuild the proxy.

## Common commands

```bash
docker compose logs -f tactic       # follow app logs
docker compose ps                   # service and health status
docker compose restart tactic       # restart the app
docker compose down                 # stop, keep data
docker compose down -v              # stop and DELETE all data
docker compose build --no-cache     # rebuild, re-cloning TACTIC
```

## Data and persistence

Named volumes keep state across restarts:

| Volume         | Mount                          | Contents                       |
|----------------|--------------------------------|--------------------------------|
| `tactic_db`    | `/var/lib/postgresql/data`     | PostgreSQL data                |
| `tactic_data`  | `/opt/tactic/tactic_data`      | Config, assets, project templates |
| `tactic_temp`  | `/opt/tactic/tactic_temp`      | Temp and upload files          |

`tactic-conf.xml` is generated from the environment variables **only on first run**. Later changes to `.env` (for example `DB_PASSWORD`) do not update it. Edit `/opt/tactic/tactic_data/config/tactic-conf.xml` in the `tactic_data` volume, or run `docker compose down -v` to start fresh. The Postgres password is also fixed at first initialisation of `tactic_db`.

## Backups

```bash
# Database
docker compose exec -T db pg_dump -U postgres -Fc sthpw > sthpw-$(date +%F).dump
# Restore into an empty database
docker compose exec -T db pg_restore -U postgres -d sthpw --clean < sthpw-YYYY-MM-DD.dump

# Assets and config (the tactic_data volume)
docker run --rm -v mlw-tactic-docker_tactic_data:/data -v "$PWD":/backup alpine \
    tar czf /backup/tactic_data-$(date +%F).tgz -C /data .
```

The volume name is prefixed with your compose project name (the directory name by default); check `docker volume ls`.

## Layout

- `Dockerfile` — builds the TACTIC image
- `docker-compose.yml` — proxy, TACTIC app and PostgreSQL services
- `docker/entrypoint.sh` — seeds the data dir, renders the config, waits for Postgres, bootstraps the DB
- `docker/bootstrap_db.py` — creates and populates the `sthpw` database on first run
- `docker/tactic-conf.xml.template` — TACTIC config template
- `docker/nginx/` — proxy config (HTTP and TLS variants, worker upstream)

## Notes

- The image patches upstream's `startup.py` at build time so workers bind to `TACTIC_BIND_HOST` (`0.0.0.0`). Upstream derives the bind address from the config hostname, which is also the public URL.
- The default admin password is public. Change it before exposing the service.
