extends SceneTree
## SupabaseStore against the mock (store_checks.gd). Exits 1 on any failure.
##
##   python3 tools/tests/supabase_mock.py --port 54321 &
##   SUPABASE_URL=http://127.0.0.1:54321 SUPABASE_SECRET_KEY=sb_secret_test \
##       Godot --headless --path . -s tools/tests/test_supabase_store.gd


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var checks: RefCounted = load("res://tools/tests/store_checks.gd").new()
	checks.tree = self
	var fails: int = await checks.run()
	quit(1 if fails > 0 else 0)
