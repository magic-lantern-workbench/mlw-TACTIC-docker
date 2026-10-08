# Database

Stock `postgres:16` with `shared_buffers`, `effective_cache_size` and `max_connections` set from `.env`. It holds two databases: `sthpw` (users, groups, the list of projects and search types, pipelines and the history of tasks and transactions; see the sthpw schema document) and one database per project (`mlw`). It publishes no host port and is reachable only by the `tactic` service. Its health check gates the start of `tactic`. The password is fixed when the `tactic_db` volume is first initialised.

# Storage

| Volume | Mounted in | Contents |
|--------|------------|----------|
| `tactic_data` | `tactic` | `config/` (including `tactic-conf.xml`), `templates/`, `dist/` |
| `tactic_assets` | `tactic` (read-write), `proxy` (read-only) | Checked-in media, mounted at `tactic_data/assets`. Set `TACTIC_ASSETS` to a host path, such as a NAS mount, to use other storage |
| `tactic_temp` | `tactic` | Upload, download, cache and temp files |
| `tactic_db` | `db` | PostgreSQL data directory |

A host path used for `TACTIC_ASSETS` must be writable by uid 1000.
