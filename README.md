# mlw-TACTIC-docker

Docker and Docker Compose setup for [TACTIC](https://github.com/magic-lantern-workbench/TACTIC), configured for Magic Lantern Workbench (MLW) production: the app server runs against a PostgreSQL database, and an MLW project is created on first start from the `mlw` plugin on the TACTIC `magiclantern` branch.

The image clones TACTIC at build time (this repo contains no TACTIC source), installs its Python dependencies, and runs it on CherryPy. On first start the `sthpw` database is created and populated automatically.

## Quick start

```bash
cp .env.example .env      # then edit .env and set DB_PASSWORD (required)
docker compose up -d --build
```

The first start takes about 30 seconds while the database is created. Then open <http://localhost/tactic/mlw> for the MLW project (or <http://localhost/tactic> for the project list) and log in with:

- **Username:** `admin`
- **Password:** `tactic`

Change the admin password after your first login.

## MLW production project

The image is built from the `magiclantern` branch of the TACTIC repository (`TACTIC_REF`), which adds the `mlw` plugin at `src/plugins/TACTIC/mlw`. On first start the app installs that plugin into a new project, the same way the Create Project dialog does for a built-in template. The project gets its own database (`mlw` by default) and includes:

- **Data model:** episodes, sequences, shots, assets, plates, layers, cameras, textures, renders, reviews, submissions, storyboards, schedules and the joins between them, under the `mlw/` namespace (`mlw/shot`, `mlw/asset_in_shot`, and so on).
- **Pipelines:** a shot pipeline and an asset pipeline (Model, Layout, Animation, Effects, Lighting, Assemble, Render, Compositing and others), with task creation and status tracking.
- **Interface configuration:** the shot planner, custom layouts, side bar, naming conventions and triggers that ship with the plugin.

At the time of writing the `mlw` plugin is TACTIC's VFX template renamed: with `vfx` replaced by `mlw` in names and contents, the two plugin directories are identical. The VFX plugin is still in the image, so you can use it instead.

The installer is skipped when the project already exists, so restarts are safe. To change it, set these in `.env` before the first start:

| Variable                 | Default                    | Description                                                              |
|--------------------------|----------------------------|--------------------------------------------------------------------------|
| `TACTIC_PROJECT_ENABLED` | `true`                     | Set to `false` to start with the system database only                    |
| `TACTIC_PLUGIN`          | `mlw`                      | Plugin directory under `src/plugins/TACTIC`, for example `mlw` or `vfx`  |
| `TACTIC_PROJECT_CODE`    | the plugin name            | Project code; also the name of the project's database                    |
| `TACTIC_PROJECT_TITLE`   | the plugin name, capitals  | Title shown in the interface                                             |

The image includes the tools TACTIC calls for media: ImageMagick (thumbnails and web proxies), FFmpeg and ffprobe (video, review media), Ghostscript (PDF and EPS) and ExifTool (metadata).

**Frame formats.** DPX, Cineon, TIFF, JPEG 2000, PNG and JPEG are handled by ImageMagick. EXR is not: Debian's ImageMagick is built without OpenEXR, so EXR frames can be checked in and stored, but TACTIC will not make thumbnails or web proxies for them. FFmpeg can read EXR, so proxies can be made outside TACTIC and checked in alongside.

**Media storage.** Check-ins are stored in the `tactic_assets` volume. For a real production, point `TACTIC_ASSETS` at a host path such as a NAS mount. The path must be writable by uid 1000, which is the `tactic` user inside the container.

## Architecture

The documentation is also published as a website: <https://magic-lantern-workbench.github.io/mlw-TACTIC-docker/>.

For a diagram of the components and a detailed description of each, see the [architecture document](doc/mlw-TACTIC-docker_Architecture.docx).

For every table and column in the `sthpw` system database, see the [sthpw schema document](doc/mlw-TACTIC-docker_sthpw_Schema.docx).

For every table and column in the `mlw` project database, see the [MLW schema document](doc/mlw-TACTIC-docker_mlw_Schema.docx).

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
| `TACTIC_REF`              | `magiclantern`                                          | Branch or tag to build; pin a tag for production |
| `TACTIC_MEM_LIMIT`        | `4g`                                                    | Memory limit for the app container               |
| `TACTIC_PROJECT_ENABLED`, `TACTIC_PLUGIN`, `TACTIC_PROJECT_CODE`, `TACTIC_PROJECT_TITLE` | `true`, `mlw`, plugin name, plugin name | Production project; see [MLW production project](#mlw-production-project) |
| `TACTIC_ASSETS`           | `tactic_assets` volume                                  | Docker volume name or host path for media        |
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
| `tactic_data`  | `/opt/tactic/tactic_data`      | Config and project templates   |
| `tactic_assets` (or `TACTIC_ASSETS`) | `/opt/tactic/tactic_data/assets` | Checked-in media |
| `tactic_temp`  | `/opt/tactic/tactic_temp`      | Temp and upload files          |

`tactic-conf.xml` is generated from the environment variables **only on first run**. Later changes to `.env` (for example `DB_PASSWORD`) do not update it. Edit `/opt/tactic/tactic_data/config/tactic-conf.xml` in the `tactic_data` volume, or run `docker compose down -v` to start fresh. The Postgres password is also fixed at first initialisation of `tactic_db`.

## Backups

```bash
# Database
docker compose exec -T db pg_dump -U postgres -Fc sthpw > sthpw-$(date +%F).dump
# Restore into an empty database
docker compose exec -T db pg_restore -U postgres -d sthpw --clean < sthpw-YYYY-MM-DD.dump

# Project database (also dump sthpw as above)
docker compose exec -T db pg_dump -U postgres -Fc mlw > mlw-$(date +%F).dump

# Config and media (the tactic_data and tactic_assets volumes)
for v in tactic_data tactic_assets; do
  docker run --rm -v mlw-tactic-docker_$v:/data -v "$PWD":/backup alpine \
      tar czf /backup/$v-$(date +%F).tgz -C /data .
done
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
