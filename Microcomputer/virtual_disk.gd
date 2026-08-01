extends Node
class_name VirtualDisk

@export var disk_id: String = ""
@export var capacity: int = 1048576

var _base_path: String = "user://disks/"
var _cache_loaded: bool = false
var _files: Dictionary = {}

func _ready():
	if disk_id.is_empty():
		disk_id = _generate_unique_id()
	_ensure_directory()
	_load_cache()

func _generate_unique_id() -> String:
	return "disk_" + str(Time.get_unix_time_from_system()) + "_" + str(randi())

func _ensure_directory():
	var dir = DirAccess.open(_base_path)
	if not dir:
		DirAccess.make_dir_recursive_absolute(_base_path)
	var disk_dir = _base_path + disk_id + "/"
	if not DirAccess.dir_exists_absolute(disk_dir):
		DirAccess.make_dir_recursive_absolute(disk_dir)

func _load_cache():
	_files.clear()
	var disk_path = _base_path + disk_id + "/"
	_walk_directory(disk_path, "")
	_cache_loaded = true

func _walk_directory(dir_path: String, relative_prefix: String):
	var dir = DirAccess.open(dir_path)
	if not dir:
		return
	dir.list_dir_begin()
	var entry = dir.get_next()
	while entry != "":
		if entry == "." or entry == "..":
			entry = dir.get_next()
			continue
		var full_path = dir_path + entry
		var relative_path = relative_prefix + entry
		if dir.current_is_dir():
			_files[relative_path + "/"] = 0
			_walk_directory(full_path + "/", relative_path + "/")
		else:
			var size = FileAccess.get_size(full_path)
			_files[relative_path] = size
		entry = dir.get_next()
	dir.list_dir_end()

func _ensure_path(path: String) -> bool:
	var full_path = _base_path + disk_id + "/" + path.get_base_dir()
	if full_path == _base_path + disk_id + "/":
		return true
	if not DirAccess.dir_exists_absolute(full_path):
		var err = DirAccess.make_dir_recursive_absolute(full_path)
		return err == OK
	return true

func _get_file_path(filename: String) -> String:
	return _base_path + disk_id + "/" + filename

func get_free_space() -> int:
	if not _cache_loaded:
		_load_cache()
	var used = 0
	for size in _files.values():
		used += size
	return capacity - used

func get_used_space() -> int:
	if not _cache_loaded:
		_load_cache()
	var used = 0
	for size in _files.values():
		used += size
	return used

func write_file(filename: String, data: PackedByteArray) -> bool:
	if not _cache_loaded:
		_load_cache()
	if data.size() > get_free_space():
		return false
	if not _ensure_path(filename):
		return false
	var file_path = _get_file_path(filename)
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	if not file:
		return false
	file.store_buffer(data)
	file.close()
	_load_cache()
	return true

func read_file(filename: String) -> PackedByteArray:
	var file_path = _get_file_path(filename)
	if not FileAccess.file_exists(file_path):
		return PackedByteArray()
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		return PackedByteArray()
	var data = file.get_buffer(file.get_length())
	file.close()
	return data

func delete_file(filename: String) -> bool:
	var file_path = _get_file_path(filename)
	if FileAccess.file_exists(file_path):
		var err = DirAccess.remove_absolute(file_path)
		if err == OK:
			_load_cache()
			return true
	return false

func list_files() -> Dictionary:
	if not _cache_loaded:
		_load_cache()
	return _files.duplicate()

func list_directory(path: String) -> Dictionary:
	if not _cache_loaded:
		_load_cache()
	var norm = path
	if norm.begins_with("/"):
		norm = norm.substr(1)
	if norm.ends_with("/"):
		norm = norm.left(norm.length() - 1)
	var prefix = norm
	if prefix != "":
		prefix = prefix + "/"
	var result = {}
	for key in _files.keys():
		if prefix == "":
			var parts = key.split("/", false)
			if parts.size() == 1:
				result[key] = _files[key]
			elif parts.size() == 2 and parts[1] == "":
				result[key] = _files[key]
		else:
			if key.begins_with(prefix):
				var rest = key.substr(prefix.length())
				var clean = rest.trim_suffix("/")
				if not clean.contains("/"):
					result[rest] = _files[key]
	return result

func directory_exists(path: String) -> bool:
	if not _cache_loaded:
		_load_cache()
	var norm = path
	if norm.begins_with("/"):
		norm = norm.substr(1)
	if norm == "":
		return true
	if not norm.ends_with("/"):
		norm = norm + "/"
	return _files.has(norm)

func write_text(filename: String, text: String) -> bool:
	return write_file(filename, text.to_utf8_buffer())

func read_text(filename: String) -> String:
	var data = read_file(filename)
	if data.is_empty():
		return ""
	return data.get_string_from_utf8()

func create_directory(path: String) -> bool:
	var full_path = _base_path + disk_id + "/" + path
	if DirAccess.dir_exists_absolute(full_path):
		return true
	var err = DirAccess.make_dir_recursive_absolute(full_path)
	if err == OK:
		_load_cache()
		return true
	return false

func delete_directory(path: String, recursive: bool = false) -> bool:
	var full_path = _base_path + disk_id + "/" + path
	if not DirAccess.dir_exists_absolute(full_path):
		return false
	if recursive:
		var err = DirAccess.remove_absolute(full_path)
		if err == OK:
			_load_cache()
			return true
		return false
	else:
		var dir = DirAccess.open(full_path)
		if not dir:
			return false
		dir.list_dir_begin()
		var entry = dir.get_next()
		while entry != "":
			if entry != "." and entry != "..":
				return false
			entry = dir.get_next()
		dir.list_dir_end()
		var err = DirAccess.remove_absolute(full_path)
		if err == OK:
			_load_cache()
			return true
		return false

func get_configuration_warnings() -> PackedStringArray:
	if disk_id.is_empty():
		return ["Disk ID is empty. It will be generated on _ready()."]
	return []
