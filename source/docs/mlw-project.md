# MLW project

`docker/bootstrap_project.py` does what the Create Project dialog does when a built-in template is chosen. It runs TACTIC's `ProjectTemplateInstallerCmd` with the plugin directory `src/plugins/TACTIC/<plugin>`, where the plugin is `mlw` unless `TACTIC_PLUGIN` says otherwise. The `mlw` plugin comes from the `magiclantern` branch of the TACTIC repository. It is TACTIC's VFX template under the `mlw/` namespace: with `vfx` replaced by `mlw`, the two plugin directories are identical, so `TACTIC_PLUGIN=vfx` gives the same project under `vfx` names. The installer:

- creates a project (default code `mlw`) and a PostgreSQL database of the same name;
- registers the plugin's search types, 23 in the `mlw/` namespace, such as `mlw/shot`, `mlw/asset`, `mlw/sequence`, `mlw/plate` and `mlw/review`, and creates their tables in the project database;
- creates the shot and asset pipelines (workflow processes such as Layout, Animation, Effects, Lighting and Compositing);
- loads the interface configuration: about 200 widget configurations (views, layouts, the shot planner and side bar), naming rules, triggers, scripts and production settings.

If the project already exists the script does nothing, so restarts are safe. `TACTIC_PROJECT_CODE` and `TACTIC_PROJECT_TITLE` set the code and title (they default to the plugin name); `TACTIC_PROJECT_ENABLED=false` skips the step so only the system database is created.

Check-ins made in the project are stored in the `tactic_assets` volume. For each check-in TACTIC keeps the original and makes a web rendition and an icon. DPX, Cineon, TIFF, JPEG 2000, PNG and JPEG are handled by ImageMagick; video and review media use FFmpeg. EXR frames can be stored but get no thumbnail or web rendition, because Debian's ImageMagick is built without OpenEXR.
