@tool
class_name BuildInfo
## Which build this is (design log 0166): the commit it was made from, so a
## web page can tell it's stale even when the version hasn't changed.
##
## The id is the short commit hash, plus "-dirty.<hash of the changes>" when
## made with uncommitted changes, so any edit makes a new build, and a local
## server and export made from the same files match.
## Exports carry it in FILE (addons/server_address writes it, and puts a copy
## next to index.html for pages to compare with). Deploys write FILE into the
## release (deploy/activate-release.sh), as the server has no git history.
## Run from source, it's read from git.

const FILE := "res://build_id.txt"
## Next to the exported index.html: what the host is serving now.
const SERVED := "build_id.txt"

static var _id := ""


## This build's id, or "" if unknown.
static func id() -> String:
	if _id == "":
		if FileAccess.file_exists(FILE):
			_id = FileAccess.get_file_as_string(FILE).strip_edges()
		elif not OS.has_feature("web"):
			_id = from_git()
	return _id


## The id for the project's current files, from git: `SLICE_BUILD` if set
## (deploys), else the short commit, plus a hash of whatever differs from it
## (changed and new files, not .DS_Store). "" without git.
static func from_git() -> String:
	var given := OS.get_environment("SLICE_BUILD").strip_edges()
	if given != "":
		return given
	var root := ProjectSettings.globalize_path("res://")
	var commit := _git(root, ["rev-parse", "--short", "HEAD"]).strip_edges()
	if commit == "":
		return ""
	var changes := _git(root, ["diff", "HEAD", "--", ".", ":(exclude)*.DS_Store"])
	for path in _git(root, ["ls-files", "--others", "--exclude-standard"]).split("\n", false):
		if not path.ends_with(".DS_Store"):
			changes += "\n" + path + "\n" + FileAccess.get_file_as_string(root.path_join(path))
	if changes.strip_edges() == "":
		return commit
	return "%s-dirty.%s" % [commit, changes.sha1_text().left(6)]


static func _git(root: String, args: Array) -> String:
	var out := []
	if OS.execute("git", ["-C", root] + args, out) != 0 or out.is_empty():
		return ""
	return str(out[0])


## For people: "8fc882d", or "8fc882d + changes a1b2c3".
static func describe(build: String) -> String:
	if build == "":
		return "unknown build"
	return build.replace("-dirty.", " + changes ")
