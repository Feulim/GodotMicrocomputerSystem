extends Node
class_name VirtualDisk

@export var disk_id: String = ""
@export var capacity: int = 1048576

const TYPE_DIR: int = 1
const TYPE_FILE: int = 2

var _base_path: String = "user://disks/"
var _current_path: String = ""
var _cache: Dictionary[String, Dictionary] = {}
var _cache_loaded: bool = false
var _used_size: int = -1

func _ready() -> void:
	if disk_id.is_empty():
		disk_id = _generate_unique_id()
	_ensure_directory()
	_load_cache()

func _generate_unique_id() -> String:
	return "disk_" + str(Time.get_unix_time_from_system()) + "_" + str(randi())

func _ensure_directory() -> void:
	var dir = DirAccess.open(_base_path)
	if not dir:
		DirAccess.make_dir_recursive_absolute(_base_path)
	var disk_dir = _base_path + disk_id + "/"
	if not DirAccess.dir_exists_absolute(disk_dir):
		DirAccess.make_dir_recursive_absolute(disk_dir)

func _load_cache() -> void:
	_cache.clear()
	_current_path = ""
	_used_size = -1

func _normalize_path(path: String, as_directory: bool = false) -> String:
	var p = path
	if p.begins_with("/"):
		p = p.substr(1)
	if as_directory and not p.is_empty() and not p.ends_with("/"):
		p += "/"
	return p

func _get_parent_dir(path: String) -> String:
	var base = path.get_base_dir()
	if base.is_empty():
		return ""
	return base + "/"

func _ensure_cache_for_dir(dir_path: String) -> void:
	var norm = _normalize_path(dir_path, true)
	if norm == _current_path and _cache_loaded:
		return
	_load_directory_cache(norm)

func _load_directory_cache(dir_path: String) -> void:
	_cache.clear()
	_current_path = dir_path
	var full_dir = _base_path + disk_id + "/" + dir_path
	if not DirAccess.dir_exists_absolute(full_dir):
		return
	var dir = DirAccess.open(full_dir)
	if not dir:
		return
	dir.list_dir_begin()
	var entry = dir.get_next()
	while entry != "":
		if entry == "." or entry == "..":
			entry = dir.get_next()
			continue
		var full_entry = full_dir + entry
		if dir.current_is_dir():
			_cache[entry] = { "type": TYPE_DIR, "size": 0 }
		else:
			var size = FileAccess.get_size(full_entry)
			_cache[entry] = { "type": TYPE_FILE, "size": size }
		entry = dir.get_next()
	dir.list_dir_end()
	if not _cache_loaded:
		_cache_loaded = true

func _compute_total_size() -> int:
	var disk_path = _base_path + disk_id + "/"
	return _walk_size(disk_path)

func _walk_size(dir_path: String) -> int:
	var dir = DirAccess.open(dir_path)
	if not dir:
		return 0
	var total = 0
	dir.list_dir_begin()
	var entry = dir.get_next()
	while entry != "":
		if entry == "." or entry == "..":
			entry = dir.get_next()
			continue
		var full = dir_path + entry
		if dir.current_is_dir():
			total += _walk_size(full + "/")
		else:
			total += FileAccess.get_size(full)
		entry = dir.get_next()
	dir.list_dir_end()
	return total

func _ensure_path(path: String) -> bool:
	var dir_path = _base_path + disk_id + "/" + path.get_base_dir()
	if dir_path == _base_path + disk_id + "/":
		return true
	if not DirAccess.dir_exists_absolute(dir_path):
		var err = DirAccess.make_dir_recursive_absolute(dir_path)
		return err == OK
	return true

func update_cache(path: String) -> void:
	if directory_exists(path):
		_ensure_cache_for_dir(path)

func get_path_type(path: String) -> int:
	var full = _base_path + disk_id + "/" + path
	if DirAccess.dir_exists_absolute(full):
		return TYPE_DIR
	if FileAccess.file_exists(full):
		return TYPE_FILE
	return 0

func get_directory_content(path: String) -> Dictionary[String, Dictionary]:
	var norm = _normalize_path(path, true)
	_ensure_cache_for_dir(norm)
	var result: Dictionary[String, Dictionary] = {}
	for key in _cache:
		result[key] = _cache[key].duplicate()
	return result

func get_free_space() -> int:
	return capacity - get_used_space()

func get_used_space() -> int:
	if _used_size == -1:
		_used_size = _compute_total_size()
	return _used_size

func write_file(filename: String, data: PackedByteArray) -> bool:
	var parent = _get_parent_dir(filename)
	_ensure_cache_for_dir(parent)

	var _name = filename.get_file()
	var old_size = 0
	if _cache.has(_name) and _cache[_name]["type"] == TYPE_FILE:
		old_size = _cache[_name]["size"]

	var available = get_free_space() + old_size
	if data.size() > available:
		return false

	if not _ensure_path(filename):
		return false

	var file_path = _base_path + disk_id + "/" + filename
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	if not file:
		return false
	file.store_buffer(data)
	file.close()

	_cache[_name] = { "type": TYPE_FILE, "size": data.size() }
	if _used_size != -1:
		_used_size = _used_size - old_size + data.size()
	return true

func read_file(filename: String) -> PackedByteArray:
	var file_path = _base_path + disk_id + "/" + filename
	if not FileAccess.file_exists(file_path):
		return PackedByteArray()
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		return PackedByteArray()
	var data = file.get_buffer(file.get_length())
	file.close()
	return data

func delete_file(filename: String) -> bool:
	var parent = _get_parent_dir(filename)
	_ensure_cache_for_dir(parent)

	var _name = filename.get_file()
	if not _cache.has(_name) or _cache[_name]["type"] != TYPE_FILE:
		return false

	var file_path = _base_path + disk_id + "/" + filename
	if not FileAccess.file_exists(file_path):
		return false

	var err = DirAccess.remove_absolute(file_path)
	if err != OK:
		return false

	var old_size = _cache[_name]["size"]
	_cache.erase(_name)
	if _used_size != -1:
		_used_size -= old_size
	return true

func list_files() -> Dictionary[String, int]:
	if _cache.is_empty() and _current_path == "":
		_ensure_cache_for_dir("")
	var result: Dictionary[String, int] = {}
	for key in _cache:
		if _cache[key]["type"] == TYPE_FILE:
			result[key] = _cache[key]["size"]
	return result

func list_directory(path: String) -> Dictionary[String, int]:
	var content = get_directory_content(path)
	var result: Dictionary[String, int] = {}
	for _name in content:
		result[_name] = content[_name]["size"]
	return result

func directory_exists(path: String) -> bool:
	return get_path_type(path) == TYPE_DIR

func file_exists(filename: String) -> bool:
	return get_path_type(filename) == TYPE_FILE

func write_text(filename: String, text: String) -> bool:
	return write_file(filename, text.to_utf8_buffer())

func read_text(filename: String) -> String:
	var data = read_file(filename)
	if data.is_empty():
		return ""
	return data.get_string_from_utf8()

func create_directory(path: String) -> bool:
	var norm = _normalize_path(path, true)
	var parent = _get_parent_dir(norm)
	var full_path = _base_path + disk_id + "/" + norm

	var err = DirAccess.make_dir_recursive_absolute(full_path)
	if err != OK:
		return false

	_ensure_cache_for_dir(parent)
	var dir_name = norm.trim_suffix("/").get_file()
	if not _cache.has(dir_name):
		_cache[dir_name] = { "type": TYPE_DIR, "size": 0 }
	_load_directory_cache(parent)
	return true

func delete_directory(path: String, recursive: bool = false) -> bool:
	var norm = _normalize_path(path, true)
	var parent = _get_parent_dir(norm)
	_ensure_cache_for_dir(parent)

	var dir_name = norm.trim_suffix("/").get_file()
	if not _cache.has(dir_name) or _cache[dir_name]["type"] != TYPE_DIR:
		return false

	if not recursive:
		var full = _base_path + disk_id + "/" + norm
		var dir = DirAccess.open(full)
		if not dir:
			return false
		dir.list_dir_begin()
		var entry = dir.get_next()
		var has_entries = false
		while entry != "":
			if entry != "." and entry != "..":
				has_entries = true
				break
			entry = dir.get_next()
		dir.list_dir_end()
		if has_entries:
			return false

	var full_path = _base_path + disk_id + "/" + norm
	if DirAccess.dir_exists_absolute(full_path):
		var err = DirAccess.remove_absolute(full_path)
		if err != OK:
			return false

	_cache.erase(dir_name)
	_used_size = -1
	if _current_path == norm:
		_load_directory_cache(parent)
	return true

func rename_file(old_name: String, new_name: String) -> bool:
	var old_parent = _get_parent_dir(old_name)
	var new_parent = _get_parent_dir(new_name)
	var old_file = old_name.get_file()
	var new_file = new_name.get_file()

	if old_parent == new_parent:
		_ensure_cache_for_dir(old_parent)
		if not _cache.has(old_file) or _cache[old_file]["type"] != TYPE_FILE:
			return false
		if _cache.has(new_file):
			return false
		var old_path = _base_path + disk_id + "/" + old_name
		var new_path = _base_path + disk_id + "/" + new_name
		if FileAccess.file_exists(new_path):
			return false
		var err = DirAccess.rename_absolute(old_path, new_path)
		if err != OK:
			return false
		var info = _cache[old_file]
		_cache.erase(old_file)
		_cache[new_file] = info
		return true
	else:
		_ensure_cache_for_dir(old_parent)
		if not _cache.has(old_file) or _cache[old_file]["type"] != TYPE_FILE:
			return false
		if _cache.has(new_file):
			return false

		var old_path = _base_path + disk_id + "/" + old_name
		var new_path = _base_path + disk_id + "/" + new_name
		if FileAccess.file_exists(new_path):
			return false

		var err = DirAccess.rename_absolute(old_path, new_path)
		if err != OK:
			return false

		var info = _cache[old_file]
		_cache.erase(old_file)
		_ensure_cache_for_dir(new_parent)
		_cache[new_file] = info
		return true

func rename_directory(old_name: String, new_name: String) -> bool:
	var old_parent = _get_parent_dir(old_name)
	var new_parent = _get_parent_dir(new_name)
	var old_dir = old_name.get_file()
	var new_dir = new_name.get_file()

	if old_parent == new_parent:
		_ensure_cache_for_dir(old_parent)
		if not _cache.has(old_dir) or _cache[old_dir]["type"] != TYPE_DIR:
			return false
		if _cache.has(new_dir):
			return false
		var old_path = _base_path + disk_id + "/" + old_name
		var new_path = _base_path + disk_id + "/" + new_name
		if DirAccess.dir_exists_absolute(new_path):
			return false
		var err = DirAccess.rename_absolute(old_path, new_path)
		if err != OK:
			return false
		var info = _cache[old_dir]
		_cache.erase(old_dir)
		_cache[new_dir] = info
		_used_size = -1
		return true
	else:
		_ensure_cache_for_dir(old_parent)
		if not _cache.has(old_dir) or _cache[old_dir]["type"] != TYPE_DIR:
			return false
		if _cache.has(new_dir):
			return false
		var old_path = _base_path + disk_id + "/" + old_name
		var new_path = _base_path + disk_id + "/" + new_name
		if DirAccess.dir_exists_absolute(new_path):
			return false
		var err = DirAccess.rename_absolute(old_path, new_path)
		if err != OK:
			return false
		var info = _cache[old_dir]
		_cache.erase(old_dir)
		_ensure_cache_for_dir(new_parent)
		_cache[new_dir] = info
		_used_size = -1
		return true

func format() -> bool:
	var disk_path = _base_path + disk_id + "/"
	var err
	if DirAccess.dir_exists_absolute(disk_path):
		err = DirAccess.remove_absolute(disk_path)
		if err != OK:
			return false
	err = DirAccess.make_dir_recursive_absolute(disk_path)
	if err != OK:
		return false
	_load_cache()
	return true

func reload_cache() -> void:
	_load_cache()

func get_configuration_warnings() -> PackedStringArray:
	if disk_id.is_empty():
		return ["Disk ID is empty. It will be generated on _ready()."]
	return []
