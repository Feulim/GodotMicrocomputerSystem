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

func add_disk(disk: Disk) -> bool:
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

func get_disk_list() -> Array:
	return disks.keys()

func get_disk(disk_id: String) -> Disk:
	return disks.get(disk_id, null)

func set_current_disk(disk_id: String) -> void:
	current_disk_id = disk_id
	pass

func _generate_disk_id() -> String:
	return "disk_" + str(Time.get_unix_time_from_system()) + "_" + str(randi())
