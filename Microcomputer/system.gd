extends Node
class_name System

var computer: Microcomputer = null

var disks: Dictionary = {}
var current_disk_id: String = ""

func boot(_computer: Microcomputer) -> void:
	computer = _computer
	if computer:
		computer.clear()
		computer.draw_text("System booted", Vector2(0, 0))

func shutdown() -> void:
	computer = null

func input_key(_event: InputEventKey) -> void:
	pass

func update(_delta: float) -> void:
	pass

func draw() -> void:
	pass

func add_disk(disk: VirtualDisk) -> bool:
	if disk.disk_id.is_empty():
		disk.disk_id = _generate_disk_id()
	disks[disk.disk_id] = disk
	if current_disk_id.is_empty():
		current_disk_id = disk.disk_id
	return true

func remove_disk(disk_id: String) -> bool:
	if not disks.has(disk_id):
		return false
	disks.erase(disk_id)
	if current_disk_id == disk_id:
		current_disk_id = disks.keys()[0] if disks.size() > 0 else ""
	return true

func get_disk(disk_id: String) -> VirtualDisk:
	return disks.get(disk_id, null)

func get_current_disk() -> VirtualDisk:
	if current_disk_id.is_empty():
		return null
	return disks.get(current_disk_id, null)

func set_current_disk(disk_id: String) -> bool:
	if disks.has(disk_id):
		current_disk_id = disk_id
		return true
	return false

func get_disk_list() -> Array[String]:
	return disks.keys()

func _generate_disk_id() -> String:
	return "disk_" + str(Time.get_unix_time_from_system()) + "_" + str(randi())

func _resolve_path(full_path: String) -> Dictionary:
	var disk_id: String = ""
	var rel_path: String = full_path
	if full_path.contains(":"):
		var parts = full_path.split(":", true, 1)
		if parts.size() == 2:
			disk_id = parts[0]
			rel_path = parts[1]
		else:
			return {}
	else:
		disk_id = current_disk_id
		if disk_id.is_empty():
			return {}
	var disk = get_disk(disk_id)
	if disk == null:
		return {}
	return { "disk": disk, "relative_path": rel_path }

func read_file(path: String) -> PackedByteArray:
	var resolved = _resolve_path(path)
	if resolved.is_empty():
		return PackedByteArray()
	return resolved.disk.read_file(resolved.relative_path)

func write_file(path: String, data: PackedByteArray) -> bool:
	var resolved = _resolve_path(path)
	if resolved.is_empty():
		return false
	return resolved.disk.write_file(resolved.relative_path, data)

func delete_file(path: String) -> bool:
	var resolved = _resolve_path(path)
	if resolved.is_empty():
		return false
	return resolved.disk.delete_file(resolved.relative_path)

func list_files(path: String) -> Dictionary:
	var resolved = _resolve_path(path)
	if resolved.is_empty():
		return {}
	return resolved.disk.list_files()

func create_directory(path: String) -> bool:
	var resolved = _resolve_path(path)
	if resolved.is_empty():
		return false
	return resolved.disk.create_directory(resolved.relative_path)

func delete_directory(path: String, recursive: bool = false) -> bool:
	var resolved = _resolve_path(path)
	if resolved.is_empty():
		return false
	return resolved.disk.delete_directory(resolved.relative_path, recursive)
	
