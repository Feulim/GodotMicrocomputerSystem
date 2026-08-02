extends RefCounted
class_name FAT12

var disk: Disk
var partition_start_sector: int
var bytes_per_sector: int
var sectors_per_cluster: int
var reserved_sectors: int
var fat_count: int
var root_entries: int
var total_sectors: int
var media_descriptor: int
var sectors_per_fat: int
var sectors_per_track: int
var head_count: int
var hidden_sectors: int

var root_dir_sectors: int
var data_start_sector: int
var root_dir_start_sector: int
var fat_start_sector: int
var fat_size_bytes: int
var cluster_size_bytes: int
var total_clusters: int

var fat_cache: PackedByteArray = PackedByteArray()

func _init(p_disk: Disk, p_partition_start: int = 0):
	disk = p_disk
	partition_start_sector = p_partition_start
	bytes_per_sector = 512
	sectors_per_cluster = 1
	reserved_sectors = 1
	fat_count = 2
	root_entries = 224
	media_descriptor = 0xF0
	sectors_per_fat = 9
	sectors_per_track = 18
	head_count = 2
	hidden_sectors = 0

func format(total_sectors_override: int = -1) -> bool:
	if total_sectors_override > 0:
		total_sectors = total_sectors_override
	else:
		total_sectors = int(float(disk.get_capacity()) / bytes_per_sector) - partition_start_sector

	if total_sectors < 1:
		printerr("FAT12: слишком мало секторов")
		return false

	root_dir_sectors = int(float(root_entries * 32 + bytes_per_sector - 1) / bytes_per_sector)
	data_start_sector = reserved_sectors + fat_count * sectors_per_fat + root_dir_sectors
	var data_sectors = total_sectors - data_start_sector
	total_clusters = int(float(data_sectors) / sectors_per_cluster)

	if total_clusters > 4086:
		printerr("FAT12: слишком много кластеров (%d), максимум 4086" % total_clusters)
		return false

	var boot = _create_boot_sector()
	if not disk.write_sector(partition_start_sector, boot):
		return false

	var fat_data = _create_empty_fat()
	for i in range(fat_count):
		var fat_sector = partition_start_sector + reserved_sectors + i * sectors_per_fat
		if not _write_fat_at(fat_sector, fat_data):
			return false

	var root_sector = partition_start_sector + reserved_sectors + fat_count * sectors_per_fat
	var empty_root = PackedByteArray()
	empty_root.resize(root_dir_sectors * bytes_per_sector)
	empty_root.fill(0)
	if not disk.write_bytes(root_sector * bytes_per_sector, empty_root):
		return false

	print("FAT12: форматирование завершено, кластеров: %d" % total_clusters)
	return true

func _create_empty_fat() -> PackedByteArray:
	var fat_size = sectors_per_fat * bytes_per_sector
	var fat = PackedByteArray()
	fat.resize(fat_size)
	fat.fill(0)
	_set_fat_entry(fat, 0, 0xFFF)
	_set_fat_entry(fat, 1, 0xFFF)
	return fat

func _write_fat_at(sector_index: int, fat_data: PackedByteArray) -> bool:
	var offset = sector_index * bytes_per_sector
	return disk.write_bytes(offset, fat_data)

func _read_fat() -> bool:
	if fat_cache.size() > 0:
		return true
	var fat_start = (partition_start_sector + reserved_sectors) * bytes_per_sector
	fat_cache = disk.read_bytes(fat_start, sectors_per_fat * bytes_per_sector)
	if fat_cache.size() < sectors_per_fat * bytes_per_sector:
		printerr("FAT12: не удалось прочитать FAT")
		return false
	return true

func _flush_fat() -> bool:
	if fat_cache.size() == 0:
		return true
	var fat_start = (partition_start_sector + reserved_sectors) * bytes_per_sector
	if not disk.write_bytes(fat_start, fat_cache):
		return false
	var fat2_start = (partition_start_sector + reserved_sectors + sectors_per_fat) * bytes_per_sector
	if not disk.write_bytes(fat2_start, fat_cache):
		return false
	return true

func _get_fat_entry(fat: PackedByteArray, cluster: int) -> int:
	var index = int(float(cluster * 3) / 2)
	var lo = fat[index]
	var hi = fat[index+1]
	if cluster % 2 == 0:
		return (lo | ((hi & 0x0F) << 8)) & 0x0FFF
	else:
		return ((lo >> 4) | (hi << 4)) & 0x0FFF

func _set_fat_entry(fat: PackedByteArray, cluster: int, value: int):
	var index = int(float(cluster * 3) / 2)
	if cluster % 2 == 0:
		fat[index] = value & 0xFF
		fat[index+1] = (fat[index+1] & 0xF0) | ((value >> 8) & 0x0F)
	else:
		fat[index] = (fat[index] & 0x0F) | ((value & 0x0F) << 4)
		fat[index+1] = (value >> 4) & 0xFF

func _find_free_cluster() -> int:
	if not _read_fat(): return -1
	for i in range(2, total_clusters):
		if _get_fat_entry(fat_cache, i) == 0:
			return i
	return -1

func _allocate_cluster_chain(size: int) -> int:
	if size == 0:
		return 0
	var clusters_needed = int(float(size + cluster_size_bytes - 1) / cluster_size_bytes)
	var first = _find_free_cluster()
	if first == -1:
		return -1
	var current = first
	for i in range(clusters_needed - 1):
		var next = _find_free_cluster()
		if next == -1:
			var c = first
			while true:
				var n = _get_fat_entry(fat_cache, c)
				_set_fat_entry(fat_cache, c, 0)
				if n >= 0xFF8 or n == 0: break
				c = n
			return -1
		_set_fat_entry(fat_cache, current, next)
		current = next
	_set_fat_entry(fat_cache, current, 0xFFF)
	return first

func _read_cluster_data(cluster: int) -> PackedByteArray:
	var lba = _cluster_to_lba(cluster)
	var offset = lba * bytes_per_sector
	return disk.read_bytes(offset, cluster_size_bytes)

func _write_cluster_data(cluster: int, data: PackedByteArray) -> bool:
	if data.size() != cluster_size_bytes:
		return false
	var lba = _cluster_to_lba(cluster)
	var offset = lba * bytes_per_sector
	return disk.write_bytes(offset, data)

func _cluster_to_lba(cluster: int) -> int:
	return partition_start_sector + reserved_sectors + fat_count * sectors_per_fat + root_dir_sectors + (cluster - 2) * sectors_per_cluster

class DirectoryEntry:
	var name: String
	var attr: int
	var first_cluster: int
	var file_size: int
	var time: int
	var date: int

	func _init(p_name: String = "", p_attr: int = 0x20, p_first: int = 0, p_size: int = 0):
		name = p_name
		attr = p_attr
		first_cluster = p_first
		file_size = p_size

	func to_bytes() -> PackedByteArray:
		var data = PackedByteArray()
		data.resize(32)
		data.fill(0)
		var short = _to_short_name(name)
		var name_bytes = short.to_ascii_buffer()
		for i in range(11):
			data[i] = name_bytes[i] if i < name_bytes.size() else 0x20
		data[11] = attr
		data[22] = time & 0xFF
		data[23] = (time >> 8) & 0xFF
		data[24] = date & 0xFF
		data[25] = (date >> 8) & 0xFF
		data[26] = first_cluster & 0xFF
		data[27] = (first_cluster >> 8) & 0xFF
		data[28] = file_size & 0xFF
		data[29] = (file_size >> 8) & 0xFF
		data[30] = (file_size >> 16) & 0xFF
		data[31] = (file_size >> 24) & 0xFF
		return data

	static func from_bytes(data: PackedByteArray) -> DirectoryEntry:
		if data.size() < 32: return null
		if data[0] == 0x00 or data[0] == 0xE5: return null
		var name_bytes = data.slice(0, 11)
		var _name = _from_short_name(name_bytes)
		var _attr = data[11]
		var first = data[26] | (data[27] << 8)
		var size = data[28] | (data[29] << 8) | (data[30] << 16) | (data[31] << 24)
		var _time = data[22] | (data[23] << 8)
		var _date = data[24] | (data[25] << 8)
		var entry = DirectoryEntry.new(_name, _attr, first, size)
		entry.time = _time
		entry.date = _date
		return entry

	static func _to_short_name(_name: String) -> String:
		var parts = _name.split(".")
		var basename = parts[0].to_upper()
		var ext = parts[1] if parts.size() > 1 else ""
		basename = basename.substr(0, 8)
		if basename.length() < 8:
			basename += " ".repeat(8 - basename.length())
		ext = ext.substr(0, 3)
		if ext.length() < 3:
			ext += " ".repeat(3 - ext.length())
		return basename + ext

	static func _from_short_name(bytes: PackedByteArray) -> String:
		var _name = bytes.slice(0, 8).get_string_from_ascii().strip_edges()
		var ext = bytes.slice(8, 11).get_string_from_ascii().strip_edges()
		if ext == "":
			return _name
		else:
			return _name + "." + ext

func _read_directory_entries(cluster: int) -> Array:
	var entries = []
	if cluster == 0:
		var root_offset = (partition_start_sector + reserved_sectors + fat_count * sectors_per_fat) * bytes_per_sector
		for i in range(root_entries):
			var offset = root_offset + i * 32
			var data = disk.read_bytes(offset, 32)
			if data.size() < 32: break
			var entry = DirectoryEntry.from_bytes(data)
			if entry:
				entries.append(entry)
			elif data[0] == 0x00:
				break
	else:
		if not _read_fat(): return []
		var current = cluster
		while true:
			var data = _read_cluster_data(current)
			if data.size() < cluster_size_bytes:
				break
			for i in range(0, cluster_size_bytes, 32):
				var entry_data = data.slice(i, i+32)
				if entry_data.size() < 32: break
				var entry = DirectoryEntry.from_bytes(entry_data)
				if entry:
					entries.append(entry)
				elif entry_data[0] == 0x00:
					pass
			var next = _get_fat_entry(fat_cache, current)
			if next >= 0xFF8 or next == 0:
				break
			current = next
	return entries

func _write_directory_entries(cluster: int, entries: Array) -> bool:
	if cluster == 0:
		var root_offset = (partition_start_sector + reserved_sectors + fat_count * sectors_per_fat) * bytes_per_sector
		var max_entries = root_entries
		var data = PackedByteArray()
		data.resize(max_entries * 32)
		data.fill(0)
		var idx = 0
		for entry in entries:
			if idx >= max_entries: break
			var bytes = entry.to_bytes()
			for i in range(32):
				data[idx*32 + i] = bytes[i]
			idx += 1
		return disk.write_bytes(root_offset, data)
	else:
		if not _read_fat(): return false
		var data_to_write = PackedByteArray()
		for entry in entries:
			data_to_write += entry.to_bytes()
		var total_size = data_to_write.size()
		var cluster_count = (total_size + cluster_size_bytes - 1) / cluster_size_bytes
		var needed_clusters = cluster_count
		var cluster_list = []
		var c = cluster
		while true:
			cluster_list.append(c)
			var n = _get_fat_entry(fat_cache, c)
			if n >= 0xFF8 or n == 0:
				break
			c = n
		var existing = cluster_list.size()
		if existing < needed_clusters:
			var last = cluster_list[-1]
			for i in range(existing, needed_clusters):
				var new_cluster = _find_free_cluster()
				if new_cluster == -1:
					printerr("FAT12: не хватает кластеров для каталога")
					return false
				_set_fat_entry(fat_cache, last, new_cluster)
				last = new_cluster
			_set_fat_entry(fat_cache, last, 0xFFF)
		elif existing > needed_clusters:
			var last = cluster_list[needed_clusters - 1]
			var next = _get_fat_entry(fat_cache, last)
			_set_fat_entry(fat_cache, last, 0xFFF)
			var c2 = next
			while c2 >= 2 and c2 < 0xFF8:
				var n2 = _get_fat_entry(fat_cache, c2)
				_set_fat_entry(fat_cache, c2, 0)
				c2 = n2
		var write_idx = 0
		for cl in cluster_list.slice(0, needed_clusters):
			var chunk = data_to_write.slice(write_idx, write_idx + cluster_size_bytes)
			if chunk.size() < cluster_size_bytes:
				var padded = chunk.duplicate()
				padded.resize(cluster_size_bytes)
				chunk = padded
			if not _write_cluster_data(cl, chunk):
				return false
			write_idx += cluster_size_bytes
		_flush_fat()
		return true

func _resolve_path(path: String) -> Dictionary:
	var parts = path.split("/", false)
	if parts.size() == 0 or (parts.size() == 1 and parts[0] == ""):
		return { "parent_cluster": 0, "name": "", "is_root": true }
	var current_cluster = 0
	for i in range(parts.size() - 1):
		var part = parts[i]
		if part == "":
			continue
		if part == ".":
			continue
		if part == "..":
			if current_cluster == 0:
				continue
			continue
		var entries = _read_directory_entries(current_cluster)
		var found = false
		for entry in entries:
			if entry.attr & 0x10 != 0 and entry.name == part:
				current_cluster = entry.first_cluster
				found = true
				break
		if not found:
			return { "parent_cluster": -1, "name": "", "is_root": false }
	var last = parts[-1]
	if last == "":
		return { "parent_cluster": current_cluster, "name": "", "is_root": current_cluster == 0 }
	return { "parent_cluster": current_cluster, "name": last, "is_root": false }

func _find_entry_in_directory(cluster: int, name: String) -> DirectoryEntry:
	var entries = _read_directory_entries(cluster)
	for entry in entries:
		if entry.name == name:
			return entry
	return null

func _create_entry_in_directory(cluster: int, entry: DirectoryEntry) -> bool:
	var entries = _read_directory_entries(cluster)
	var idx = -1
	for i in range(entries.size()):
		if entries[i] == null or entries[i].name == "":
			idx = i
			break
	if idx == -1:
		entries.append(entry)
	else:
		entries[idx] = entry
	return _write_directory_entries(cluster, entries)

func _delete_entry_in_directory(cluster: int, name: String) -> bool:
	var entries = _read_directory_entries(cluster)
	var found = false
	for i in range(entries.size()):
		if entries[i] and entries[i].name == name:
			entries[i] = null
			found = true
			break
	if not found:
		return false
	return _write_directory_entries(cluster, entries)

func file_exists(path: String) -> bool:
	var resolved = _resolve_path(path)
	if resolved.is_root or resolved.parent_cluster == -1:
		return false
	var entry = _find_entry_in_directory(resolved.parent_cluster, resolved.name)
	return entry != null and (entry.attr & 0x10 == 0)

func directory_exists(path: String) -> bool:
	if path == "" or path == "/":
		return true
	var resolved = _resolve_path(path)
	if resolved.parent_cluster == -1:
		return false
	var entry = _find_entry_in_directory(resolved.parent_cluster, resolved.name)
	return entry != null and (entry.attr & 0x10 != 0)

func read_file(path: String) -> PackedByteArray:
	if not file_exists(path):
		printerr("FAT12: файл не найден: %s" % path)
		return PackedByteArray()
	var resolved = _resolve_path(path)
	var entry = _find_entry_in_directory(resolved.parent_cluster, resolved.name)
	if entry == null or entry.first_cluster == 0:
		return PackedByteArray()
	var result = PackedByteArray()
	if not _read_fat(): return PackedByteArray()
	var cluster = entry.first_cluster
	var remaining = entry.file_size
	while true:
		if cluster >= total_clusters or cluster < 2:
			break
		var data = _read_cluster_data(cluster)
		var to_add = min(data.size(), remaining)
		result += data.slice(0, to_add)
		remaining -= to_add
		if remaining <= 0:
			break
		var next = _get_fat_entry(fat_cache, cluster)
		if next >= 0xFF8 or next == 0:
			break
		cluster = next
	return result

func write_file(path: String, data: PackedByteArray) -> bool:
	if file_exists(path):
		if not delete_file(path):
			return false
	var resolved = _resolve_path(path)
	if resolved.parent_cluster == -1 or resolved.is_root:
		printerr("FAT12: недопустимый путь")
		return false
	var first_cluster = 0
	var size = data.size()
	if size > 0:
		first_cluster = _allocate_cluster_chain(size)
		if first_cluster == -1:
			printerr("FAT12: не хватает места")
			return false
		var current = first_cluster
		var pos = 0
		while pos < size:
			var chunk = data.slice(pos, pos + cluster_size_bytes)
			if chunk.size() < cluster_size_bytes:
				var padded = chunk.duplicate()
				padded.resize(cluster_size_bytes)
				chunk = padded
			if not _write_cluster_data(current, chunk):
				return false
			pos += cluster_size_bytes
			if pos < size:
				var next = _get_fat_entry(fat_cache, current)
				if next >= 0xFF8 or next == 0:
					printerr("FAT12: ошибка цепочки кластеров")
					return false
				current = next
		_flush_fat()
	var entry = DirectoryEntry.new(resolved.name, 0x20, first_cluster, size)
	entry.time = _get_current_time()
	entry.date = _get_current_date()
	return _create_entry_in_directory(resolved.parent_cluster, entry)

func delete_file(path: String) -> bool:
	if not file_exists(path):
		return false
	var resolved = _resolve_path(path)
	var entry = _find_entry_in_directory(resolved.parent_cluster, resolved.name)
	if entry == null:
		return false
	if entry.first_cluster != 0:
		if not _read_fat(): return false
		var cluster = entry.first_cluster
		while true:
			var next = _get_fat_entry(fat_cache, cluster)
			_set_fat_entry(fat_cache, cluster, 0)
			if next >= 0xFF8 or next == 0:
				break
			cluster = next
		_flush_fat()
	return _delete_entry_in_directory(resolved.parent_cluster, resolved.name)

func create_directory(path: String) -> bool:
	if directory_exists(path):
		return true
	var resolved = _resolve_path(path)
	if resolved.parent_cluster == -1 or resolved.is_root:
		return false
	var cluster = _allocate_cluster_chain(cluster_size_bytes)
	if cluster == -1:
		return false
	var dot_entry = DirectoryEntry.new(".", 0x10, cluster, 0)
	var dotdot_entry = DirectoryEntry.new("..", 0x10, resolved.parent_cluster, 0)
	var entries = [dot_entry, dotdot_entry]
	if not _write_directory_entries(cluster, entries):
		return false
	var new_entry = DirectoryEntry.new(resolved.name, 0x10, cluster, 0)
	new_entry.time = _get_current_time()
	new_entry.date = _get_current_date()
	return _create_entry_in_directory(resolved.parent_cluster, new_entry)

func delete_directory(path: String, recursive: bool = false) -> bool:
	if not directory_exists(path) or path == "" or path == "/":
		return false
	var resolved = _resolve_path(path)
	if resolved.parent_cluster == -1:
		return false
	var entry = _find_entry_in_directory(resolved.parent_cluster, resolved.name)
	if entry == null or (entry.attr & 0x10 == 0):
		return false
	var sub_entries = _read_directory_entries(entry.first_cluster)
	var has_children = false
	for e in sub_entries:
		if e.name != "." and e.name != "..":
			has_children = true
			break
	if has_children and not recursive:
		return false
	if recursive:
		for e in sub_entries:
			if e.name == "." or e.name == "..":
				continue
			var child_path = path + "/" + e.name
			if e.attr & 0x10 != 0:
				if not delete_directory(child_path, true):
					return false
			else:
				if not delete_file(child_path):
					return false
	if entry.first_cluster != 0:
		if not _read_fat(): return false
		var cluster = entry.first_cluster
		while true:
			var next = _get_fat_entry(fat_cache, cluster)
			_set_fat_entry(fat_cache, cluster, 0)
			if next >= 0xFF8 or next == 0:
				break
			cluster = next
		_flush_fat()
	return _delete_entry_in_directory(resolved.parent_cluster, resolved.name)

func list_directory(path: String) -> Dictionary:
	if path == "" or path == "/":
		path = ""
	var resolved = _resolve_path(path)
	if resolved.parent_cluster == -1:
		return {}
	var cluster = 0
	if resolved.is_root:
		cluster = 0
	else:
		var entry = _find_entry_in_directory(resolved.parent_cluster, resolved.name)
		if entry == null or (entry.attr & 0x10 == 0):
			return {}
		cluster = entry.first_cluster
	var entries = _read_directory_entries(cluster)
	var result = {}
	for e in entries:
		if e.name == "." or e.name == "..":
			continue
		result[e.name] = e.file_size
	return result

func get_free_space() -> int:
	if not _read_fat(): return 0
	var free = 0
	for i in range(2, total_clusters):
		if _get_fat_entry(fat_cache, i) == 0:
			free += 1
	return free * cluster_size_bytes

func _create_boot_sector() -> PackedByteArray:
	var sector = PackedByteArray()
	sector.resize(bytes_per_sector)
	sector.fill(0)

	sector[0] = 0xEB
	sector[1] = 0x3C
	sector[2] = 0x90

	var oem = "ELEKTRON".to_ascii_buffer()
	for i in range(8):
		sector[3+i] = oem[i] if i < oem.size() else 0x20

	var off = 11
	sector[off] = bytes_per_sector & 0xFF
	sector[off+1] = (bytes_per_sector >> 8) & 0xFF
	sector[off+2] = sectors_per_cluster
	sector[off+3] = reserved_sectors & 0xFF
	sector[off+4] = (reserved_sectors >> 8) & 0xFF
	sector[off+5] = fat_count
	sector[off+6] = root_entries & 0xFF
	sector[off+7] = (root_entries >> 8) & 0xFF
	if total_sectors < 65536:
		sector[off+8] = total_sectors & 0xFF
		sector[off+9] = (total_sectors >> 8) & 0xFF
	else:
		sector[off+8] = 0
		sector[off+9] = 0
	sector[off+10] = media_descriptor
	sector[off+11] = sectors_per_fat & 0xFF
	sector[off+12] = (sectors_per_fat >> 8) & 0xFF
	sector[off+13] = sectors_per_track & 0xFF
	sector[off+14] = (sectors_per_track >> 8) & 0xFF
	sector[off+15] = head_count & 0xFF
	sector[off+16] = (head_count >> 8) & 0xFF
	sector[off+17] = hidden_sectors & 0xFF
	sector[off+18] = (hidden_sectors >> 8) & 0xFF
	sector[off+19] = (hidden_sectors >> 16) & 0xFF
	sector[off+20] = (hidden_sectors >> 24) & 0xFF
	if total_sectors >= 65536:
		sector[off+21] = total_sectors & 0xFF
		sector[off+22] = (total_sectors >> 8) & 0xFF
		sector[off+23] = (total_sectors >> 16) & 0xFF
		sector[off+24] = (total_sectors >> 24) & 0xFF
	sector[off+25] = 0x80
	sector[off+26] = 0
	sector[off+27] = 0x29
	randomize()
	var serial = randi() % 0xFFFFFFFF
	sector[off+28] = serial & 0xFF
	sector[off+29] = (serial >> 8) & 0xFF
	sector[off+30] = (serial >> 16) & 0xFF
	sector[off+31] = (serial >> 24) & 0xFF
	var label = "NO NAME    ".to_ascii_buffer()
	for i in range(11):
		sector[off+32+i] = label[i] if i < label.size() else 0x20
	var fs_type = "FAT12   ".to_ascii_buffer()
	for i in range(8):
		sector[off+43+i] = fs_type[i] if i < fs_type.size() else 0x20

	sector[510] = 0x55
	sector[511] = 0xAA
	return sector

func _get_current_time() -> int:
	var dt = Time.get_datetime_dict_from_system()
	return (dt.hour << 11) | (dt.minute << 5) | (dt.second >> 1)

func _get_current_date() -> int:
	var dt = Time.get_datetime_dict_from_system()
	var year = dt.year - 1980
	return (year << 9) | (dt.month << 5) | dt.day
