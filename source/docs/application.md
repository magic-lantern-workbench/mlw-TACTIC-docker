# Application (`tactic`)

## Image build

The `Dockerfile` has three stages:

- **build**: clones TACTIC at `TACTIC_REPO`/`TACTIC_REF` (by default the `magiclantern` branch), records the commit in `/opt/tactic/REVISION`, builds a virtualenv with the requirements, `CherryPy` and `pycryptodomex`, and installs the `tacticenv` module that upstream's installer would normally copy into site-packages. It also patches `startup.py` so the bind address comes from `TACTIC_BIND_HOST`. Compilers exist only in this stage.
- **tactic**: the runtime image. It copies the virtualenv and TACTIC from the build stage and adds `tini`, `postgresql-client` and `gettext-base` (for `envsubst`), plus the media tools TACTIC runs: ImageMagick, FFmpeg and ffprobe, Ghostscript and ExifTool.
- **proxy**: the nginx image, with TACTIC's static `context` files copied in.

`pycryptodomex` is needed because TACTIC's license check imports `Cryptodome`, while the `crypto` requirement installs a conflicting `Crypto` package.

## Process model

The container runs as the unprivileged `tactic` user (uid 1000), with `tini` as PID 1, then `entrypoint.sh`, then `python monitor.py`. `monitor.py` starts one worker per port in `TACTIC_PORTS` (`8081|8082|8083`), watches each one's `/test` endpoint, and restarts any that stop responding. The container also has a Docker health check against `127.0.0.1:8081/test`.

Workers bind to `0.0.0.0` through `TACTIC_BIND_HOST`. Upstream derives the bind address from `<install><hostname>`, which is also TACTIC's public base URL, so the two could not be set independently without the patch.

## Startup sequence

`docker/entrypoint.sh` runs on every container start:

1. Applies defaults for the `DB_*`, `TACTIC_HOSTNAME`, `TACTIC_PROTOCOL` and `TACTIC_PLUGIN`/`TACTIC_PROJECT_*` variables.
2. Creates the directories in `tactic_data` and copies the project templates and license file there if they are missing.
3. Renders `config/tactic-conf.xml` from `docker/tactic-conf.xml.template` with `envsubst`, **only if the file does not exist**. Later edits to the file in the volume are preserved, and later changes to `.env` do not apply to it.
4. Waits for PostgreSQL using `pg_isready`.
5. Runs `docker/bootstrap_db.py`, which does nothing if the `sthpw` database already exists. Otherwise it creates the database, imports the schema and default data, adds the `admin` user and group and the default notifications, and runs TACTIC's schema upgrade steps.
6. Runs `docker/bootstrap_project.py` when `TACTIC_PROJECT_ENABLED` is `true` (the default). See the next section.
7. Replaces itself with the command (`monitor.py`).

The upgrade in step 5 runs with `is_confirmed=True`. One upgrade step otherwise asks "Run now? (y/n)"; with no terminal it fails with `EOFError`, which stops every later upgrade step and leaves the database missing columns that the project installer needs.
