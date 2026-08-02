extends RefCounted
class_name DrivesDriver

class PhysicalDisk:
	var disk: Disk
	var by_name: String
	var total_size: int
	var volumes: Dictionary = {}

	func _init(p_disk: Disk, p_by_name: String):
		disk = p_disk
		by_name = p_by_name
		total_size = disk.get_capacity()

var system: System
var physical_disks: Dictionary = {}
var logical_volumes: Dictionary = {}

var current_volume_letter: String = ""
var current_relative_path: String = ""

func _init(p_system: System):
	system = p_system
	_scan_disks()

func _scan_disks():
	physical_disks.clear()
	logical_volumes.clear()
	var disk_list = system.get_disk_list()
	var index = 0
	for disk_id in disk_list:
		var disk = system.get_disk(disk_id)
		if disk:
			var by_name = "BY" + str(index)
			var pd = PhysicalDisk.new(disk, by_name)
			_read_partitions(pd)
			physical_disks[by_name] = pd
			index += 1
	if physical_disks.is_empty():
		_create_test_disks()

func _read_partitions(pd: PhysicalDisk):
	pd.volumes.clear()
	var mbr = pd.disk.read_sector(0)
	if mbr.size() < 512:
		return
	if mbr[510] != 0x55 or mbr[511] != 0xAA:
		return
	for i in range(4):
		var offset = 446 + i * 16
		var entry_data = mbr.slice(offset, offset + 16)
		if entry_data.size() < 16:
			continue
		var type = entry_data[4]
		var lba_start = entry_data[8] | (entry_data[9] << 8) | (entry_data[10] << 16) | (entry_data[11] << 24)
		var sector_count = entry_data[12] | (entry_data[13] << 8) | (entry_data[14] << 16) | (entry_data[15] << 24)
		if type == 0x01:
			var letter = _assign_volume_letter()
			if letter == "":
				continue
			var fat_vol = FatVolume.new(pd.disk, lba_start, letter, sector_count)
			pd.volumes[letter] = { "fat_volume": fat_vol, "start_sector": lba_start, "sectors": sector_count }
			logical_volumes[letter] = fat_vol

func _assign_volume_letter() -> String:
	var used = logical_volumes.keys()
	for code in range(ord('A'), ord('Z')+1):
		var letter = String.chr(code)
		if not used.has(letter):
			return letter
	return ""

func _create_test_disks():
	var disk1 = Disk.new()
	disk1.disk_id = "disk1"
	disk1.capacity = 1 * 1024 * 1024
	disk1._ready()
	system.add_disk(disk1)
	
	var disk2 = Disk.new()
	disk2.disk_id = "disk2"
	disk2.capacity = 2 * 1024 * 1024
	disk2._ready()
	system.add_disk(disk2)
	
	_format_disk(disk1, {"C": 1 * 1024 * 1024})
	_format_disk(disk2, {"D": 2 * 1024 * 1024})
	
	_scan_disks()

func _format_disk(disk: Disk, volume_config: Dictionary) -> bool:
	var sector_size = 512
	var used_sectors = 0
	var partition_entries = []
	var letters = []
	for letter in volume_config.keys():
		var size = volume_config[letter]
		if size <= 0: return false
		var sectors = size / sector_size
		if sectors < 1: return false
		var lba_start = used_sectors + 1
		var entry = {
			"status": 0x80 if used_sectors == 0 else 0x00,
			"type": 0x01,
			"lba_start": lba_start,
			"sector_count": sectors
		}
		partition_entries.append(entry)
		used_sectors += sectors
		letters.append(letter)
	var mbr = PackedByteArray()
	mbr.resize(512)
	mbr.fill(0)
	var offset = 446
	for i in range(min(4, partition_entries.size())):
		var entry = partition_entries[i]
		var data = _partition_entry_to_bytes(entry)
		for j in range(16):
			mbr[offset + i*16 + j] = data[j]
	mbr[510] = 0x55
	mbr[511] = 0xAA
	if not disk.write_sector(0, mbr):
		return false
	for i in range(partition_entries.size()):
		var entry = partition_entries[i]
		var fat12 = FAT12.new(disk, entry.lba_start)
		if not fat12.format(entry.sector_count):
			return false
	return true

func _partition_entry_to_bytes(entry: Dictionary) -> PackedByteArray:
	var data = PackedByteArray()
	data.resize(16)
	data.fill(0)
	data[0] = entry.status
	data[4] = entry.type
	data[8] = entry.lba_start & 0xFF
	data[9] = (entry.lba_start >> 8) & 0xFF
	data[10] = (entry.lba_start >> 16) & 0xFF
	data[11] = (entry.lba_start >> 24) & 0xFF
	data[12] = entry.sector_count & 0xFF
	data[13] = (entry.sector_count >> 8) & 0xFF
	data[14] = (entry.sector_count >> 16) & 0xFF
	data[15] = (entry.sector_count >> 24) & 0xFF
	return data

func get_physical_disk(by_name: String) -> PhysicalDisk:
	return physical_disks.get(by_name, null)

func get_logical_volume(letter: String) -> FatVolume:
	return logical_volumes.get(letter, null)

func get_current_display_name() -> String:
	if current_volume_letter != "":
		return current_volume_letter + ":"
	return ""

func get_current_full_path() -> String:
	if current_volume_letter == "":
		return ""
	return "/" + current_relative_path

func get_free_space() -> int:
	if current_volume_letter == "":
		return 0
	var vol = logical_volumes.get(current_volume_letter)
	if vol:
		return vol.get_free_space()
	return 0

func mount_volume(letter: String) -> bool:
	var upper = letter.to_upper()
	var vol = logical_volumes.get(upper)
	if not vol:
		return false
	unmount_current()
	current_volume_letter = upper
	current_relative_path = ""
	system.set_current_disk(vol.disk.disk_id)
	return true

func unmount_current() -> bool:
	if current_volume_letter == "":
		return false
	current_volume_letter = ""
	current_relative_path = ""
	system.set_current_disk("")
	return true

func change_directory(new_path: String) -> bool:
	if current_volume_letter == "":
		return false
	var vol = logical_volumes[current_volume_letter]
	var parts = []
	if current_relative_path != "":
		parts = current_relative_path.split("/", false)
	var new_parts = new_path.split("/", false)
	for part in new_parts:
		match part:
			".":
				continue
			"..":
				if parts.size() > 0:
					parts.remove_at(parts.size() - 1)
			_:
				parts.append(part)
	var new_relative = "/".join(parts)
	var abs_path = _get_absolute_path(new_relative)
	if not vol.directory_exists(abs_path):
		if new_relative != "":
			return false
	current_relative_path = new_relative
	return true

func change_volume(letter: String) -> bool:
	return mount_volume(letter)

func cd(target: String) -> bool:
	if target.is_empty():
		target = "/"
	var letter = ""
	var rest = target
	var colon_pos = target.find(":")
	if colon_pos == 1:
		var ch = target[0].to_upper()
		if ch >= "A" and ch <= "Z":
			letter = ch
			rest = target.substr(2) if target.length() > 2 else ""
	if letter != "":
		if not mount_volume(letter):
			return false
		if rest != "":
			if rest.begins_with("/") or rest.begins_with("\\"):
				rest = rest.substr(1)
			if rest != "":
				return change_directory(rest)
			else:
				return true
		else:
			return true
	else:
		if current_volume_letter == "":
			return false
		return change_directory(target)

func list_current_directory() -> Dictionary:
	if current_volume_letter == "":
		return {}
	var vol = logical_volumes[current_volume_letter]
	var abs_path = _get_absolute_path(current_relative_path)
	var files = vol.list_directory(abs_path)
	var result = {}
	for name in files.keys():
		var full_abs = abs_path + "/" + name
		var is_dir = vol.directory_exists(full_abs)
		result[name] = { "size": files[name], "is_dir": is_dir }
	return result

func read_current_file(filename: String) -> PackedByteArray:
	if current_volume_letter == "":
		return PackedByteArray()
	var abs_path = _build_abs_path(filename)
	return logical_volumes[current_volume_letter].read_file(abs_path)

func write_current_file(filename: String, data: PackedByteArray) -> bool:
	if current_volume_letter == "":
		return false
	var vol = logical_volumes[current_volume_letter]
	var free = vol.get_free_space()
	if data.size() > free:
		return false
	var abs_path = _build_abs_path(filename)
	return vol.write_file(abs_path, data)

func delete_current_file(filename: String) -> bool:
	if current_volume_letter == "":
		return false
	var abs_path = _build_abs_path(filename)
	return logical_volumes[current_volume_letter].delete_file(abs_path)

func create_current_directory(dirname: String) -> bool:
	if current_volume_letter == "":
		return false
	var abs_path = _build_abs_path(dirname)
	return logical_volumes[current_volume_letter].create_directory(abs_path)

func exists(target: String) -> bool:
	var resolved = _resolve_target(target)
	if resolved.is_empty():
		return false
	return resolved.disk.directory_exists(resolved.path) or resolved.disk.file_exists(resolved.path)

func is_directory(target: String) -> bool:
	var resolved = _resolve_target(target)
	if resolved.is_empty():
		return false
	return resolved.disk.directory_exists(resolved.path)

func is_file(target: String) -> bool:
	var resolved = _resolve_target(target)
	if resolved.is_empty():
		return false
	return resolved.disk.file_exists(resolved.path)

func get_disk_state(by_name: String) -> Dictionary:
	var pd = get_physical_disk(by_name)
	if not pd:
		return {}
	var result = {
		"by_name": by_name,
		"mounted": !pd.volumes.is_empty(),
		"total_size": pd.total_size,
		"volumes": {}
	}
	for letter in pd.volumes.keys():
		var vol = pd.volumes[letter].fat_volume
		result.volumes[letter] = {
			"path": "/",
			"size": vol.get_capacity(),
			"used": vol.get_capacity() - vol.get_free_space()
		}
	return result

func list_all_disks() -> Array:
	var result = []
	for by in physical_disks.keys():
		var state = get_disk_state(by)
		result.append(state)
	for letter in logical_volumes.keys():
		var vol = logical_volumes[letter]
		result.append({
			"type": "logical",
			"letter": letter,
			"by_name": vol.disk.disk_id,
			"root_path": "/",
			"size": vol.get_capacity(),
			"used": vol.get_capacity() - vol.get_free_space()
		})
	return result

func _get_absolute_path(relative: String) -> String:
	if relative == "":
		return ""
	return relative

func _build_abs_path(relative: String) -> String:
	if current_relative_path == "":
		return relative
	else:
		return current_relative_path + "/" + relative

func _resolve_target(target: String) -> Dictionary:
	var letter = ""
	var rest = target
	var colon_pos = target.find(":")
	if colon_pos == 1:
		var ch = target[0].to_upper()
		if ch >= "A" and ch <= "Z":
			letter = ch
			rest = target.substr(2) if target.length() > 2 else ""
	var vol = null
	if letter != "":
		vol = logical_volumes.get(letter)
		if not vol:
			return {}
	else:
		if current_volume_letter == "":
			return {}
		vol = logical_volumes[current_volume_letter]
		if rest == "":
			rest = current_relative_path
		else:
			if not rest.begins_with("/"):
				if current_relative_path != "":
					rest = current_relative_path + "/" + rest
			else:
				rest = rest.substr(1)
	var parts = rest.split("/", false)
	var new_parts = []
	for part in parts:
		match part:
			".":
				continue
			"..":
				if new_parts.size() > 0:
					new_parts.remove_at(new_parts.size() - 1)
			_:
				new_parts.append(part)
	var resolved_path = "/".join(new_parts)
	return { "disk": vol, "path": resolved_path }

func delete_current_directory(dirname: String, recursive: bool = false) -> bool:
	if current_volume_letter == "":
		return false
	var abs_path = _build_abs_path(dirname)
	return logical_volumes[current_volume_letter].delete_directory(abs_path, recursive)

func format_disk(by_name: String, volume_config: Dictionary) -> bool:
	var pd = get_physical_disk(by_name)
	if not pd:
		return false
	for letter in pd.volumes.keys():
		logical_volumes.erase(letter)
	pd.volumes.clear()
	return _format_disk(pd.disk, volume_config)
