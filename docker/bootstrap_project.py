"""Create the production project from one of TACTIC's built-in plugins.

Does what the Create Project dialog does when a built-in template is selected:
install src/plugins/TACTIC/<plugin> into a new project database. Does nothing if
the project already exists, so it is safe to run on every start.

Settings (environment):
  TACTIC_PLUGIN         plugin directory under src/plugins/TACTIC (default: mlw)
  TACTIC_PROJECT_CODE   project code, also the database name (default: the plugin name)
  TACTIC_PROJECT_TITLE  project title (default: the plugin name in capitals)
"""
import os
import sys

import tacticenv  # noqa: F401  (sets up sys.path and TACTIC_* env)

from pyasm.biz import Project
from pyasm.command import Command
from pyasm.common import Environment
from pyasm.security import Batch
from tactic.command import ProjectTemplateInstallerCmd

plugin = os.environ.get("TACTIC_PLUGIN", "mlw")
code = os.environ.get("TACTIC_PROJECT_CODE") or plugin
title = os.environ.get("TACTIC_PROJECT_TITLE") or plugin.upper()

Batch(project_code="admin")

if Project.get_by_code(code):
    print("Project '%s' already exists, skipping install." % code)
    sys.exit(0)

plugin_dir = os.path.join(Environment.get_builtin_plugin_dir(), "TACTIC", plugin)
if not os.path.exists(os.path.join(plugin_dir, "manifest.xml")):
    sys.exit("Plugin '%s' not found at %s" % (plugin, plugin_dir))

print("Installing the '%s' plugin into project '%s' ..." % (plugin, code))
cmd = ProjectTemplateInstallerCmd(
    project_code=code,
    template_code=plugin,
    path=plugin_dir,
    is_template=False,
    force_database=True,
)
Command.execute_cmd(cmd)

# The installer derives the title from the code; apply the configured one
Batch(project_code="admin")
project = Project.get_by_code(code)
if project and title and project.get_value("title") != title:
    project.set_value("title", title)
    project.commit()

print("Project '%s' installed." % code)
