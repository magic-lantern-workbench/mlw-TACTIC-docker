"""Create and populate the TACTIC `sthpw` database if it does not exist yet.

Mirrors the database portion of src/install/install.py without its
interactive/system-install steps.
"""
import tacticenv  # noqa: F401  (sets up sys.path and TACTIC_* env)

from pyasm.search import DatabaseImpl, DbContainer, DatabaseException

PROJECT = "sthpw"

database = DatabaseImpl.get()

exists = False
try:
    exists = database.database_exists(PROJECT)
except DatabaseException:
    pass

if exists:
    print("Database '%s' already exists, skipping install." % PROJECT)
    raise SystemExit(0)

print("Creating database '%s' ..." % PROJECT)
database.create_database(PROJECT)
database.import_schema(PROJECT, PROJECT)
database.import_default_data(PROJECT, PROJECT)

db = DbContainer.get(PROJECT)
db.do_update('''
INSERT INTO login_group (login_group, description)
VALUES ('admin', 'Site Administration');
-- default admin password is 'tactic'
INSERT INTO "login" ("login", "password", "upn", first_name, last_name)
VALUES ('admin', '39195b0707436a7ecb92565bf3411ab1', 'admin', 'Admin', '');
INSERT INTO login_in_group ("login", login_group) VALUES ('admin', 'admin');
''')
db.do_update('''
INSERT INTO notification (code, description, "type", search_type, event)
VALUES ('asset_attr_change', 'Attribute Changes For Assets', 'email', 'prod/asset', 'update|prod/asset');
INSERT INTO notification (code, description, "type", search_type, event)
VALUES ('shot_attr_change', 'Attribute Changes For Shots', 'email', 'prod/shot', 'update|prod/shot');
''')

print("Upgrading the database schema ...")
from pyasm.search.upgrade import Upgrade
from pyasm.security import Batch

Batch()
with open("%s/VERSION" % __import__("os").environ["TACTIC_INSTALL_DIR"]) as f:
    version = f.readline().strip()
# is_confirmed answers the upgrade step that would otherwise prompt "Run now? (y/n)".
# With no terminal that prompt raises EOFError and aborts every later upgrade step.
Upgrade(version, is_forced=True, project_code=None, quiet=True, is_confirmed=True).execute()
print("TACTIC database installed.")
