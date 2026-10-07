"""Create the VFX production project from TACTIC's built-in VFX plugin.

Does what the Create Project dialog does when "VFX (built in)" is selected:
install src/plugins/TACTIC/vfx into a new project database. Does nothing if the
project already exists, so it is safe to run on every start.
"""
import os
import sys

import tacticenv  # noqa: F401  (sets up sys.path and TACTIC_* env)

from pyasm.biz import Project
from pyasm.command import Command
from pyasm.common import Environment
from pyasm.security import Batch
from tactic.command import ProjectTemplateInstallerCmd

code = os.environ.get("VFX_PROJECT_CODE", "vfx")
title = os.environ.get("VFX_PROJECT_TITLE", "VFX")

Batch(project_code="admin")

if Project.get_by_code(code):
    print("VFX project '%s' already exists, skipping install." % code)
    sys.exit(0)

plugin_dir = os.path.join(Environment.get_builtin_plugin_dir(), "TACTIC", "vfx")
if not os.path.exists(os.path.join(plugin_dir, "manifest.xml")):
    sys.exit("VFX plugin not found at %s" % plugin_dir)

print("Installing the VFX plugin into project '%s' ..." % code)
cmd = ProjectTemplateInstallerCmd(
    project_code=code,
    template_code="vfx",
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

print("VFX project '%s' installed." % code)
