# mlw-TACTIC-docker

Docker and Docker Compose setup for [TACTIC](https://github.com/magic-lantern-workbench/TACTIC), running the app server against a PostgreSQL database.

The image clones TACTIC at build time (this repo contains no TACTIC source), installs its Python dependencies, and runs it on CherryPy. On first start the `sthpw` database is created and populated automatically.

## Quick start

```bash
cp .env.example .env      # then edit .env and set a real DB_PASSWORD
docker compose up -d --build
```

The first start takes about 30 seconds while the database is created. Then open <http://localhost:8081/tactic> and log in with:

- **Username:** `admin`
- **Password:** `tactic`

Change the admin password after your first login.

## Configuration

Settings are read from `.env` (see `.env.example`):

| Variable          | Default                                                  | Description                                  |
|-------------------|----------------------------------------------------------|----------------------------------------------|
| `DB_USER`         | `postgres`                                               | PostgreSQL user                              |
| `DB_PASSWORD`     | `postgres`                                               | PostgreSQL password                          |
| `TACTIC_PORT`     | `8081`                                                   | Host port TACTIC is published on             |
| `TACTIC_HOSTNAME` | `localhost`                                              | Hostname written to the TACTIC config        |
| `TACTIC_REPO`     | `https://github.com/magic-lantern-workbench/TACTIC.git`  | Git repo cloned at build time                |
| `TACTIC_REF`      | `5.0`                                                    | Branch or tag to build (upstream has no `main`) |

`TACTIC_REPO` and `TACTIC_REF` are build arguments, so changing them requires `docker compose build`.

## Common commands

```bash
docker compose logs -f tactic       # follow app logs
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

## Layout

- `Dockerfile` — builds the TACTIC image
- `docker-compose.yml` — TACTIC app and PostgreSQL services
- `docker/entrypoint.sh` — seeds the data dir, renders the config, waits for Postgres, bootstraps the DB
- `docker/bootstrap_db.py` — creates and populates the `sthpw` database on first run
- `docker/tactic-conf.xml.template` — TACTIC config template

## Notes

- TACTIC runs as a single `startup.py` process on CherryPy, not the multi-process monitor or Apache setup from upstream's service files. This suits development and small deployments; it is not tuned for production.
- Put a reverse proxy with TLS in front of it if you expose it beyond localhost.
