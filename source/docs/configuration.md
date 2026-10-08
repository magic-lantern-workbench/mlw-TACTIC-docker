# Configuration

Runtime settings come from `.env`, passed through `docker-compose.yml`. The TACTIC config template maps them as follows:

| Variable | Used for |
|----------|----------|
| `DB_HOST`, `DB_PORT`, `DB_USER`, `DB_PASSWORD` | `<database>` section |
| `TACTIC_HOSTNAME` | `<install><hostname>`, the public base URL |
| `TACTIC_PROTOCOL` | `<security><protocol>`, `http` or `https` |
| `TACTIC_PORTS` | Worker ports read by `monitor.py` |
| `TACTIC_BIND_HOST` | Worker bind address, set in the image |
| `TACTIC_PROJECT_ENABLED`, `TACTIC_PLUGIN`, `TACTIC_PROJECT_CODE`, `TACTIC_PROJECT_TITLE` | First-start project (read by `bootstrap_project.py`) |
| `TACTIC_ASSETS` | Volume name or host path mounted for media |

Build-time settings are `TACTIC_REPO` and `TACTIC_REF`.
