extends RefCounted
class_name FatVolume

var disk: Disk
var fat12: FAT12
var volume_letter: String
var partition_start: int
var total_size: int

func _init(p_disk: Disk, p_partition_start: int, p_letter: String, p_total_sectors: int):
	disk = p_disk
	partition_start = p_partition_start
	volume_letter = p_letter
	total_size = p_total_sectors * 512
	fat12 = FAT12.new(disk, partition_start)

func get_disk_id() -> String:
	return volume_letter + ":"

func get_capacity() -> int:
	return total_size

func get_free_space() -> int:
	return fat12.get_free_space()

func read_file(filename: String) -> PackedByteArray:
	var path = _normalize_path(filename)
	return fat12.read_file(path)

func write_file(filename: String, data: PackedByteArray) -> bool:
	var path = _normalize_path(filename)
	return fat12.write_file(path, data)

func delete_file(filename: String) -> bool:
	var path = _normalize_path(filename)
	return fat12.delete_file(path)

func list_directory(path: String) -> Dictionary:
	var norm = _normalize_path(path)
	return fat12.list_directory(norm)

func directory_exists(path: String) -> bool:
	var norm = _normalize_path(path)
	return fat12.directory_exists(norm)

func create_directory(path: String) -> bool:
	var norm = _normalize_path(path)
	return fat12.create_directory(norm)

func delete_directory(path: String, recursive: bool = false) -> bool:
	var norm = _normalize_path(path)
	return fat12.delete_directory(norm, recursive)

func _normalize_path(path: String) -> String:
	if path == "" or path == "/" or path == "\\":
		return ""
	path = path.replace("\\", "/")
	if path.begins_with("/"):
		path = path.substr(1)
	if path.ends_with("/"):
		path = path.left(path.length() - 1)
	return path
