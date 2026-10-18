extends SceneTree
func _init() -> void:
	await process_frame
	var scr: GDScript = load("res://_hr_test/target.gd")
	var n := Node.new()
	n.set_script(scr)
	root.add_child(n)
	n.a = 7
	print(n.value())
	var f := FileAccess.open("res://_hr_test/target.gd", FileAccess.WRITE)
	f.store_string("extends Node\nvar b := 5\nvar a := 1\nfunc value() -> String:\n\treturn \"new a=%d b=%d\" % [a, b]\n")
	f.close()
	scr.source_code = FileAccess.get_file_as_string("res://_hr_test/target.gd")
	print("reload: ", error_string(scr.reload(true)))
	print(n.value())
	f = FileAccess.open("res://_hr_test/target.gd", FileAccess.WRITE)
	f.store_string("extends Node\nvar a := 1\nfunc value( -> String:\n")
	f.close()
	scr.source_code = FileAccess.get_file_as_string("res://_hr_test/target.gd")
	print("reload broken: ", error_string(scr.reload(true)))
	print(n.value())
	quit()
