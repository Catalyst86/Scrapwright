extends Node
## Audit harness: compile every script and load+instantiate every scene with
## autoloads active. Prints a machine-greppable summary line per failure.

var _fail_scripts: Array[String] = []
var _fail_scenes: Array[String] = []

func _ready() -> void:
	var gd_files: Array[String] = []
	var tscn_files: Array[String] = []
	_walk("res://", gd_files, tscn_files)
	print("AUDIT: found %d scripts, %d scenes" % [gd_files.size(), tscn_files.size()])
	for p in gd_files:
		var s = ResourceLoader.load(p, "", ResourceLoader.CACHE_MODE_REUSE)
		if s == null:
			_fail_scripts.append(p)
			print("AUDIT_SCRIPT_FAIL: load null -> ", p)
		elif s is Script and not s.can_instantiate():
			_fail_scripts.append(p)
			print("AUDIT_SCRIPT_FAIL: cannot instantiate -> ", p)
	for p in tscn_files:
		var ps = ResourceLoader.load(p)
		if ps == null or not (ps is PackedScene):
			_fail_scenes.append(p)
			print("AUDIT_SCENE_FAIL: load -> ", p)
			continue
		if not ps.can_instantiate():
			_fail_scenes.append(p)
			print("AUDIT_SCENE_FAIL: can_instantiate false -> ", p)
			continue
		var n = ps.instantiate()
		if n == null:
			_fail_scenes.append(p)
			print("AUDIT_SCENE_FAIL: instantiate null -> ", p)
		else:
			n.free()
	print("AUDIT_DONE: script_failures=%d scene_failures=%d" % [_fail_scripts.size(), _fail_scenes.size()])
	get_tree().quit()

func _walk(dir_path: String, gd: Array[String], tscn: Array[String]) -> void:
	var d := DirAccess.open(dir_path)
	if d == null:
		return
	d.list_dir_begin()
	var f := d.get_next()
	while f != "":
		if f.begins_with("."):
			f = d.get_next()
			continue
		var full := dir_path.path_join(f)
		if d.current_is_dir():
			if f != "_audit" and f != "addons":
				_walk(full, gd, tscn)
		elif f.ends_with(".gd"):
			gd.append(full)
		elif f.ends_with(".tscn"):
			tscn.append(full)
		f = d.get_next()
	d.list_dir_end()
