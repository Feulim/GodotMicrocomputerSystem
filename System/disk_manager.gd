extends RefCounted
class_name DiskManager

const secret_types = ["DV", "DSK", "SCRT"]
const system_types = ["SYS", "SYSDATA"]

var system: System
var disk_names: Dictionary = {}
var current_disk_name: String = "SY"
var current_path: String = ""
var builtin_count: int = 0
var external_count: int = 0

const SYSTEM_SIGNATURE = "SYSTEMOSBK"

func initialize(sys: System) -> void:
	system = sys
	if not system:
		return
	var disk_ids = system.get_disk_list()
	builtin_count = 0
	for disk_id in disk_ids:
		if builtin_count == 0:
			disk_names["SY"] = disk_id
		else:
			disk_names["DK" + str(builtin_count - 1)] = disk_id
		builtin_count += 1
	if disk_names.is_empty():
		pass
	current_disk_name = "SY" if disk_names.has("SY") else (disk_names.keys()[0] if not disk_names.is_empty() else "")
	current_path = ""

func add_external_disk(disk: VirtualDisk) -> String:
	if not system:
		return ""
	var disk_id = disk.disk_id
	if disk_id.is_empty():
		disk_id = "ext_" + str(Time.get_unix_time_from_system()) + "_" + str(randi())
		disk.disk_id = disk_id
	if not system.add_disk(disk):
		return ""
	var name = "BY" + str(external_count)
	external_count += 1
	disk_names[name] = disk_id
	return name

func remove_external_disk(disk_name: String) -> bool:
	if not disk_names.has(disk_name):
		return false
	if not disk_name.begins_with("BY"):
		return false
	var disk_id = disk_names[disk_name]
	if system.remove_disk(disk_id):
		disk_names.erase(disk_name)
		if current_disk_name == disk_name:
			current_disk_name = disk_names.keys()[0] if not disk_names.is_empty() else ""
		return true
	return false

func get_disk_by_name(name: String) -> VirtualDisk:
	if not disk_names.has(name):
		return null
	return system.get_disk(disk_names[name])

func get_current_disk() -> VirtualDisk:
	return get_disk_by_name(current_disk_name)

func get_working_directory() -> String:
	if current_disk_name.is_empty():
		return ""
	var path = current_path
	if not path.is_empty() and not path.ends_with("/"):
		path += "/"
	return current_disk_name + ":" + path

func _resolve_full_path(path: String) -> Dictionary:
	var disk_name = current_disk_name
	var rel_path = path
	
	if path.contains(":"):
		var parts = path.split(":", true, 1)
		if parts.size() == 2:
			disk_name = parts[0]
			rel_path = parts[1]
		else:
			return {}
	if not disk_names.has(disk_name):
		return {}
	
	if not rel_path.begins_with("/"):
		if current_path.is_empty() or disk_name != current_disk_name:
			rel_path = rel_path
		else:
			rel_path = current_path + "/" + rel_path
	var normalized = _normalize_path(rel_path)
	return { "disk_name": disk_name, "rel_path": normalized }

func _normalize_path(path: String) -> String:
	var parts = path.split("/", false)
	var stack = []
	for part in parts:
		if part == "." or part == "":
			continue
		elif part == "..":
			if stack.size() > 0:
				stack.pop_back()
		else:
			stack.append(part)
	return "/".join(stack)

func get_item_type(path: String) -> int:
	var resolved = _resolve_full_path(path)
	if resolved.is_empty():
		return 0
	var disk = get_disk_by_name(resolved.disk_name)
	if not disk:
		return 0
	var rel = resolved.rel_path
	var base_type = disk.get_path_type(rel)
	if base_type == 0:
		return 0
	if base_type == 1:
		return 1
	return _check_file_type(disk, rel)

func _check_file_type(disk: VirtualDisk, rel_path: String) -> int:
	var filename = rel_path.get_file()
	var ext = filename.get_extension().to_upper()
	if ext and ext in system_types:
		var data = disk.read_file(rel_path)
		if data.size() >= len(SYSTEM_SIGNATURE):
			var sig = data.get_string_from_utf8()
			if sig.begins_with(SYSTEM_SIGNATURE):
				return -1
	if filename.begins_with("."):
		return -2
	if ext in secret_types:
		return -2
	return 2

func change_directory(path: String) -> bool:
	var resolved = _resolve_full_path(path)
	if resolved.is_empty():
		return false
	var disk = get_disk_by_name(resolved.disk_name)
	if not disk:
		return false
	var rel = resolved.rel_path
	if rel == "":
		current_disk_name = resolved.disk_name
		current_path = ""
		disk.update_cache("")
		return true
	if disk.directory_exists(rel):
		current_disk_name = resolved.disk_name
		current_path = rel
		disk.update_cache(rel)
		return true
	return false

func list_directory(path: String = "") -> Dictionary:
	var resolved = _resolve_full_path(path if not path.is_empty() else "")
	if resolved.is_empty():
		return {"err": -2}
	var disk = get_disk_by_name(resolved.disk_name)
	Debug.update_debug_label3(JSON.stringify(disk._cache, " "))
	if not disk or not disk.directory_exists(resolved.rel_path):
		return {"err": -1}
	var normalized = resolved.rel_path
	var content = disk.get_directory_content(normalized)
	var result = {}
	for name in content:
		if name.is_empty():
			continue
		var info = content[name]
		if info["type"] == 1:
			result[name] = { "size": 0, "type": 1 }
		else:
			var full_rel = normalized + ("" if normalized == "" else "/") + name
			var file_type = _check_file_type(disk, full_rel)
			if file_type == -2:
				continue
			result[name] = { "size": info["size"], "type": file_type }
	return {"err": 0, "disk": resolved.disk_name, "path": resolved.rel_path, "contains": result}

func system_read_file(path: String) -> PackedByteArray:
	var resolved = _resolve_full_path(path)
	if resolved.is_empty():
		return PackedByteArray()
	var disk = get_disk_by_name(resolved.disk_name)
	if not disk:
		return PackedByteArray()
	return disk.read_file(resolved.rel_path)

func internal_read_file(path: String) -> PackedByteArray:
	var type = get_item_type(path)
	if type == -1 or type == -2:
		return PackedByteArray()
	return system_read_file(path)

func write_file(path: String, data: PackedByteArray) -> bool:
	var type = get_item_type(path)
	var ext = path.get_file().get_extension().to_upper()
	if type == 0 and (ext in system_types or ext in secret_types):
		return false
	if type == -1 or type == -2 or type == 1:
		return false
	var resolved = _resolve_full_path(path)
	if resolved.is_empty():
		return false
	var disk = get_disk_by_name(resolved.disk_name)
	if not disk:
		return false
	return disk.write_file(resolved.rel_path, data)

func delete_file(path: String) -> bool:
	var type = get_item_type(path)
	if type == -1 or type == -2 or type == 1:
		return false
	var resolved = _resolve_full_path(path)
	if resolved.is_empty():
		return false
	var disk = get_disk_by_name(resolved.disk_name)
	if not disk:
		return false
	return disk.delete_file(resolved.rel_path)

func create_directory(path: String) -> bool:
	var type = get_item_type(path)
	if type != 0:
		return false
	var resolved = _resolve_full_path(path)
	if resolved.is_empty():
		return false
	var disk = get_disk_by_name(resolved.disk_name)
	if not disk:
		return false
	return disk.create_directory(resolved.rel_path)

func delete_directory(path: String, recursive: bool = false) -> bool:
	var type = get_item_type(path)
	if type != 1:
		return false
	var resolved = _resolve_full_path(path)
	if resolved.is_empty():
		return false
	var disk = get_disk_by_name(resolved.disk_name)
	if not disk:
		return false
	return disk.delete_directory(resolved.rel_path, recursive)

func update_directory_cache() -> void:
	var disk = get_current_disk()
	if disk:
		disk.update_cache(current_path)

func rename_file(path: String, new_name: String) -> bool:
	var resolved = _resolve_full_path(path)
	if resolved.is_empty():
		return false
	var disk = get_disk_by_name(resolved.disk_name)
	if not disk:
		return false
	var old_rel = resolved.rel_path
	var item_type = get_item_type(path)
	if item_type == 1:
		return false
	var base_dir = old_rel.get_base_dir()
	var new_rel = base_dir + "/" + new_name if base_dir != "" else new_name
	if disk.directory_exists(new_rel + "/") or disk.file_exists(new_rel):
		return false
	return disk.rename_file(old_rel, new_rel)

func rename_directory(path: String, new_name: String) -> bool:
	var resolved = _resolve_full_path(path)
	if resolved.is_empty():
		return false
	var disk = get_disk_by_name(resolved.disk_name)
	if not disk:
		return false
	var old_rel = resolved.rel_path
	if not disk.directory_exists(old_rel + "/"):
		return false
	var base_dir = old_rel.get_base_dir()
	var new_rel = base_dir + "/" + new_name if base_dir != "" else new_name
	if disk.directory_exists(new_rel + "/") or disk.file_exists(new_rel):
		return false
	return disk.rename_directory(old_rel, new_rel)

func move_file(src: String, dst: String) -> bool:
	var src_res = _resolve_full_path(src)
	var dst_res = _resolve_full_path(dst)
	if src_res.is_empty() or dst_res.is_empty():
		return false
	var src_disk = get_disk_by_name(src_res.disk_name)
	var dst_disk = get_disk_by_name(dst_res.disk_name)
	if not src_disk or not dst_disk:
		return false
	var src_rel = src_res.rel_path
	var dst_rel = dst_res.rel_path
	if src_disk.directory_exists(src_rel + "/"):
		return false
	if not src_disk.file_exists(src_rel):
		return false
	if src_res.disk_name == dst_res.disk_name:
		return src_disk.rename_file(src_rel, dst_rel)
	var data = src_disk.read_file(src_rel)
	if data.is_empty():
		return false
	if dst_disk.write_file(dst_rel, data):
		src_disk.delete_file(src_rel)
		return true
	return false

func move_directory(src: String, dst: String) -> bool:
	var src_res = _resolve_full_path(src)
	var dst_res = _resolve_full_path(dst)
	if src_res.is_empty() or dst_res.is_empty():
		return false
	if src_res.disk_name != dst_res.disk_name:
		return false
	var disk = get_disk_by_name(src_res.disk_name)
	if not disk:
		return false
	var src_rel = src_res.rel_path
	var dst_rel = dst_res.rel_path
	if not disk.directory_exists(src_rel + "/"):
		return false
	if disk.directory_exists(dst_rel + "/") or disk.file_exists(dst_rel):
		return false
	return disk.rename_directory(src_rel, dst_rel)

func format_disk(disk_name: String = "") -> bool:
	if disk_name.is_empty():
		disk_name = current_disk_name
	var disk = get_disk_by_name(disk_name)
	if not disk:
		return false
	return disk.format()

func get_disks_info() -> Dictionary:
	return disk_names.duplicate()

func get_current_disk_name() -> String:
	return current_disk_name

func get_current_relative_path() -> String:
	return current_path
