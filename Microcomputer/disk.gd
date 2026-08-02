extends Node
class_name Disk

@export var disk_id: String = ""
@export var capacity: int = 1048576
@export var sector_size: int = 512
var image_path: String

var _is_open: bool = false
var _file: FileAccess = null


func _ready():
	image_path = "user://disks/%s.dsk" % disk_id
	_open_or_create()

func _open_or_create():
	var dir = DirAccess.open("user://disks/")
	if not dir:
		DirAccess.make_dir_recursive_absolute("user://disks/")

	if not FileAccess.file_exists(image_path):
		var f = FileAccess.open(image_path, FileAccess.WRITE)
		if not f:
			printerr("DiskDevice: не удалось создать файл '%s'" % image_path)
			return

		var zeros = PackedByteArray()
		zeros.resize(capacity)

		f.store_buffer(zeros)
		f.close()
		print("DiskDevice: создан новый образ '%s' размером %d байт" % [image_path, capacity])

	_file = FileAccess.open(image_path, FileAccess.READ_WRITE)
	if _file:
		_is_open = true
	else:
		printerr("DiskDevice: не удалось открыть файл '%s'" % image_path)


func get_sector_count() -> int:
	return int(float(capacity) / sector_size)


func read_sector(sector_index: int) -> PackedByteArray:
	if not _is_open:
		return PackedByteArray()
	var offset = sector_index * sector_size
	if offset + sector_size > capacity:
		return PackedByteArray()
	_file.seek(offset)
	var data = _file.get_buffer(sector_size)
	if data.size() < sector_size:
		var pad = PackedByteArray()
		pad.resize(sector_size - data.size())
		data += pad
	_file.flush()
	return data

func write_sector(sector_index: int, data: PackedByteArray) -> bool:
	if not _is_open:
		return false
	if data.size() != sector_size:
		printerr("DiskDevice: размер данных (%d) не равен размеру сектора (%d)" % [data.size(), sector_size])
		return false
	var offset = sector_index * sector_size
	if offset + sector_size > capacity:
		return false
	_file.seek(offset)
	_file.store_buffer(data)
	_file.flush()
	return true

func read_bytes(offset: int, length: int) -> PackedByteArray:
	if not _is_open:
		return PackedByteArray()
	if offset + length > capacity:
		return PackedByteArray()
	_file.seek(offset)
	_file.flush()
	return _file.get_buffer(length)

func write_bytes(offset: int, data: PackedByteArray) -> bool:
	if not _is_open:
		return false
	if offset + data.size() > capacity:
		return false
	_file.seek(offset)
	_file.store_buffer(data)
	_file.flush()
	return true

func close():
	if _file:
		_file.close()
		_is_open = false

func get_capacity() -> int:
	return capacity

func flush():
	pass

func _exit_tree() -> void:
	close()
