extends CommandExecutor
class_name OSBKCommands

signal change_style(accent: int, subaccent: int, contrast: int)

var drives_driver: DrivesDriver

const HELP_TEXT = """
Доступные команды:

  dir [путь]             - список файлов и папок
  ls [путь]              - то же, что dir
  cd [путь]              - сменить текущую директорию (можно с буквой тома, например C:\folder)
  pwd                    - показать текущий путь
  mkfile <имя> [текст]   - создать файл с содержимым (если текст не указан, будет запрошен)
  mkdir <имя>            - создать директорию
  rm <файл>              - удалить файл (с подтверждением)
  rmdir [-r] <папка>     - удалить папку (-r для рекурсивного удаления)
  ren <старое> <новое>   - переименовать файл (только файлы)
  copy <источник> <цель> - копировать файл
  move <источник> <цель> - переместить файл
  type <файл>            - показать содержимое текстового файла
  cat <файл>             - то же, что type
  echo <текст> [> файл]  - вывести текст или записать в файл (перенаправление)
  format <диск> ТОМ=РАЗМЕР ... - отформатировать физический диск с разделами FAT12
                                   Пример: format BY0 C=1048576 D=2097152
  diskinfo               - показать информацию о всех дисках и томах
  mount <буква>          - смонтировать том (сделать текущим)
  unmount                - отмонтировать текущий том
  set tv [acc=число] [sub=число] [con=число] - изменить цвета (0-15)
  cls                    - очистить экран
  help / ?               - показать эту справку
"""

func _init(p_bko: Stream, p_bke: Stream, p_drives_driver: DrivesDriver = null):
	super(p_bko, p_bke)
	drives_driver = p_drives_driver

func parse_command(args: Array) -> Callable:
	if not args or args.size() < 1:
		return unknown_command
	match args[0].to_lower():
		"rnd":   return random_test_command
		"cls":   return cmd_clear
		"set":   return cmd_set
		"dir", "ls":     return cmd_dir
		"cd":            return cmd_cd
		"pwd":           return cmd_pwd
		"mkfile":        return cmd_mkfile
		"mkdir":         return cmd_mkdir
		"rm":            return cmd_rm
		"rmdir":         return cmd_rmdir
		"ren", "rename": return cmd_rename
		"copy":          return cmd_copy
		"move":          return cmd_move
		"type", "cat":   return cmd_type
		"echo":          return cmd_echo
		"format":        return cmd_format
		"diskinfo":      return cmd_diskinfo
		"mount":         return cmd_mount
		"unmount":       return cmd_unmount
		"help", "?":     return cmd_help
		_:
			return unknown_command

func _show_help(_args: Array) -> void:
	write_output(HELP_TEXT)

func _confirm_action(message: String) -> bool:
	write_output(message + " ")
	var response = await confirm()
	return response

func _parse_format_args(args: Array) -> Dictionary:
	if args.size() < 3:
		return { "error": "Недостаточно аргументов. Использование: format <диск> БУКВА=РАЗМЕР ..." }
	var disk_name = args[1]
	var volumes = {}
	for i in range(2, args.size()):
		var pair = args[i]
		var parts = pair.split("=")
		if parts.size() != 2:
			return { "error": "Неверный формат тома: %s (ожидается БУКВА=РАЗМЕР)" % pair }
		var letter = parts[0].to_upper().strip_edges()
		if letter.length() != 1 or letter < "A" or letter > "Z":
			return { "error": "Недопустимая буква тома: %s" % letter }
		var size_str = parts[1].strip_edges()
		if not size_str.is_valid_int():
			return { "error": "Размер должен быть целым числом (байт): %s" % size_str }
		var size = size_str.to_int()
		if size <= 0:
			return { "error": "Размер должен быть положительным: %d" % size }
		volumes[letter] = size
	return { "disk": disk_name, "volumes": volumes }

func random_test_command(_args: Array) -> void:
	write_output("RANDOM TEST COMMAND\n")
	var user_input = await request_user_input()
	if user_input == "1":
		write_output(":)\n")

func cmd_clear(_args: Array) -> void:
	write_output(ESC + "[2J" + ESC + "[H")

func cmd_set(args: Array) -> void:
	if args.size() < 2:
		return
	if args[1].to_lower() != "tv":
		return
	
	var accent = -1
	var subaccent = -1
	var contrast = -1
	
	var i = 2
	while i < args.size() - 1:
		var key = args[i].to_lower()
		if key in ["acc", "sub", "con"]:
			var value_str = args[i + 1]
			if value_str.is_valid_int():
				var value = clamp(int(value_str), 0, 15)
				match key:
					"acc": accent = value
					"sub": subaccent = value
					"con": contrast = value
		i += 1
	write_output("СМЕНА ВНЕШНЕГО ВИДА ПОВЛЕЧЕТ ЗА СОБОЙ ОЧИСТКУ\n")
	write_output("ТЕРМИНАЛА. ПОДТВЕРДИТЬ ДЕЙСТВИЕ ")
	var success = await confirm(true)
	if success:
		change_style.emit(accent, subaccent, contrast)
	else:
		write_output("ДЕЙСТВИЕ ОТМЕНЕНО\n")

func cmd_dir(args: Array) -> void:
	if drives_driver == null:
		write_output("ОШИБКА: драйвер дисков не инициализирован\n")
		return
	var target = ""
	if args.size() > 1: target = args[1]
	var current_vol = drives_driver.current_volume_letter
	var current_path = drives_driver.current_relative_path
	
	var old_vol = current_vol
	var old_path = current_path
	if target != "":
		var letter = ""
		var rest = target
		var colon = target.find(":")
		if colon == 1:
			var ch = target[0].to_upper()
			if ch >= "A" and ch <= "Z":
				letter = ch
				rest = target.substr(2)
		if letter != "":
			if not drives_driver.mount_volume(letter):
				write_output("НЕВОЗМОЖНО СМОНТИРОВАТЬ ТОМ %s\n" % letter)
				return
		if rest != "":
			if not drives_driver.change_directory(rest):
				write_output("НЕВЕРНЫЙ ПУТЬ: %s\n" % target)
				if letter != "":
					drives_driver.mount_volume(old_vol)
					drives_driver.change_directory(old_path)
				return
	
	var list = drives_driver.list_current_directory()
	var keys = list.keys()
	keys.sort()
	if keys.is_empty():
		write_output("ПУСТО\n")
	else:
		for name in keys:
			var info = list[name]
			var size_str = str(info.size) + " байт" if !info.is_dir else "<DIR>"
			var type_str = "D" if info.is_dir else "F"
			write_output("%s  %-20s  %s\n" % [type_str, name, size_str])
	
	if target != "":
		drives_driver.mount_volume(old_vol)
		drives_driver.change_directory(old_path)

# cd
func cmd_cd(args: Array) -> void:
	if drives_driver == null:
		write_output("ОШИБКА: драйвер дисков не инициализирован\n")
		return
	if args.size() < 2:
		if not drives_driver.cd("/"):
			write_output("ОШИБКА ПРИ ПЕРЕХОДЕ В КОРЕНЬ\n")
		return
	var target = args[1]
	if not drives_driver.cd(target):
		write_output("НЕВЕРНЫЙ ПУТЬ: %s\n" % target)

func cmd_pwd(_args: Array) -> void:
	if drives_driver == null:
		write_output("ОШИБКА: драйвер дисков не инициализирован\n")
		return
	var path = drives_driver.get_current_full_path()
	var display = drives_driver.get_current_display_name()
	if display == "":
		write_output("НЕТ СМОНТИРОВАННОГО ТОМА\n")
	else:
		write_output("%s%s\n" % [display, path])

func cmd_mkfile(args: Array) -> void:
	if drives_driver == null:
		write_output("ОШИБКА: драйвер дисков не инициализирован\n")
		return
	if args.size() < 2:
		write_output("ИСПОЛЬЗОВАНИЕ: mkfile <имя> [текст]\n")
		return
	var filename = args[1]
	var content = ""
	if args.size() > 2:
		content = " ".join(args.slice(2))
	else:
		write_output("ВВЕДИТЕ СОДЕРЖИМОЕ ФАЙЛА (ЗАКОНЧИТЕ ПУСТОЙ СТРОКОЙ):\n")
		var lines = []
		while true:
			var line = await request_user_input()
			if line == "":
				break
			lines.append(line)
		content = "\n".join(lines)
	var data = content.to_utf8_buffer()
	if drives_driver.write_current_file(filename, data):
		write_output("ФАЙЛ ЗАПИСАН: %s (%d байт)\n" % [filename, data.size()])
	else:
		write_output("ОШИБКА ЗАПИСИ ФАЙЛА (недостаточно места или ошибка)\n")

func cmd_mkdir(args: Array) -> void:
	if drives_driver == null:
		write_output("ОШИБКА: драйвер дисков не инициализирован\n")
		return
	if args.size() < 2:
		write_output("ИСПОЛЬЗОВАНИЕ: mkdir <имя>\n")
		return
	var dirname = args[1]
	if drives_driver.create_current_directory(dirname):
		write_output("ДИРЕКТОРИЯ СОЗДАНА: %s\n" % dirname)
	else:
		write_output("ОШИБКА СОЗДАНИЯ ДИРЕКТОРИИ (уже существует или недопустимое имя)\n")

func cmd_rm(args: Array) -> void:
	if drives_driver == null:
		write_output("ОШИБКА: драйвер дисков не инициализирован\n")
		return
	if args.size() < 2:
		write_output("ИСПОЛЬЗОВАНИЕ: rm <файл>\n")
		return
	var filename = args[1]
	if not drives_driver.is_file(filename):
		write_output("ФАЙЛ НЕ НАЙДЕН ИЛИ ЭТО ДИРЕКТОРИЯ: %s\n" % filename)
		return
	if not await _confirm_action("УДАЛИТЬ ФАЙЛ %s?" % filename):
		write_output("ОТМЕНЕНО\n")
		return
	if drives_driver.delete_current_file(filename):
		write_output("ФАЙЛ УДАЛЕН: %s\n" % filename)
	else:
		write_output("ОШИБКА УДАЛЕНИЯ ФАЙЛА\n")

func cmd_rmdir(args: Array) -> void:
	if drives_driver == null:
		write_output("ОШИБКА: драйвер дисков не инициализирован\n")
		return
	var recursive = false
	var dirname = ""
	for arg in args.slice(1):
		if arg == "-r":
			recursive = true
		else:
			dirname = arg
	if dirname == "":
		write_output("ИСПОЛЬЗОВАНИЕ: rmdir [-r] <директория>\n")
		return
	if not drives_driver.is_directory(dirname):
		write_output("ДИРЕКТОРИЯ НЕ НАЙДЕНА: %s\n" % dirname)
		return
	var msg = "УДАЛИТЬ ДИРЕКТОРИЮ %s" % dirname
	if recursive:
		msg += " (РЕКУРСИВНО)"
	if not await _confirm_action(msg + "?"):
		write_output("ОТМЕНЕНО\n")
		return
	if drives_driver.delete_current_directory(dirname, recursive):
		write_output("ДИРЕКТОРИЯ УДАЛЕНА: %s\n" % dirname)
	else:
		write_output("ОШИБКА УДАЛЕНИЯ ДИРЕКТОРИИ (возможно, непустая)\n")

func cmd_rename(args: Array) -> void:
	if drives_driver == null:
		write_output("ОШИБКА: драйвер дисков не инициализирован\n")
		return
	if args.size() < 3:
		write_output("ИСПОЛЬЗОВАНИЕ: ren <старое> <новое>\n")
		return
	var old_name = args[1]
	var new_name = args[2]
	if not drives_driver.is_file(old_name):
		write_output("ФАЙЛ НЕ НАЙДЕН ИЛИ ЭТО ДИРЕКТОРИЯ: %s\n" % old_name)
		return
	if drives_driver.is_file(new_name) or drives_driver.is_directory(new_name):
		write_output("ЦЕЛЕВОЙ ФАЙЛ УЖЕ СУЩЕСТВУЕТ: %s\n" % new_name)
		return
	var data = drives_driver.read_current_file(old_name)
	if data.is_empty():
		write_output("ОШИБКА ЧТЕНИЯ ФАЙЛА\n")
		return
	if not drives_driver.write_current_file(new_name, data):
		write_output("ОШИБКА ЗАПИСИ НОВОГО ФАЙЛА\n")
		return
	if not drives_driver.delete_current_file(old_name):
		write_output("ОШИБКА УДАЛЕНИЯ СТАРОГО ФАЙЛА\n")
		drives_driver.delete_current_file(new_name)
		return
	write_output("ФАЙЛ ПЕРЕИМЕНОВАН: %s -> %s\n" % [old_name, new_name])

func cmd_copy(args: Array) -> void:
	if drives_driver == null:
		write_output("ОШИБКА: драйвер дисков не инициализирован\n")
		return
	if args.size() < 3:
		write_output("ИСПОЛЬЗОВАНИЕ: copy <источник> <цель>\n")
		return
	var src = args[1]
	var dst = args[2]
	if not drives_driver.is_file(src):
		write_output("ИСТОЧНИК НЕ ЯВЛЯЕТСЯ ФАЙЛОМ: %s\n" % src)
		return
	if drives_driver.is_directory(dst):
		write_output("ЦЕЛЬ НЕ МОЖЕТ БЫТЬ ДИРЕКТОРИЕЙ (копирование в папки не поддерживается)\n")
		return
	if drives_driver.is_file(dst):
		if not await _confirm_action("ФАЙЛ %s УЖЕ СУЩЕСТВУЕТ. ПЕРЕЗАПИСАТЬ?" % dst):
			write_output("ОТМЕНЕНО\n")
			return
	var data = drives_driver.read_current_file(src)
	if data.is_empty():
		write_output("ОШИБКА ЧТЕНИЯ ИСХОДНОГО ФАЙЛА\n")
		return
	if drives_driver.write_current_file(dst, data):
		write_output("ФАЙЛ СКОПИРОВАН: %s -> %s\n" % [src, dst])
	else:
		write_output("ОШИБКА КОПИРОВАНИЯ (недостаточно места или ошибка)\n")

func cmd_move(args: Array) -> void:
	if drives_driver == null:
		write_output("ОШИБКА: драйвер дисков не инициализирован\n")
		return
	if args.size() < 3:
		write_output("ИСПОЛЬЗОВАНИЕ: move <источник> <цель>\n")
		return
	var src = args[1]
	var dst = args[2]
	if not drives_driver.is_file(src):
		write_output("ИСТОЧНИК НЕ ЯВЛЯЕТСЯ ФАЙЛОМ: %s\n" % src)
		return
	if drives_driver.is_directory(dst):
		write_output("ЦЕЛЬ НЕ МОЖЕТ БЫТЬ ДИРЕКТОРИЕЙ (перемещение в папки не поддерживается)\n")
		return
	if drives_driver.is_file(dst):
		if not await _confirm_action("ФАЙЛ %s УЖЕ СУЩЕСТВУЕТ. ПЕРЕЗАПИСАТЬ?" % dst):
			write_output("ОТМЕНЕНО\n")
			return
	var data = drives_driver.read_current_file(src)
	if data.is_empty():
		write_output("ОШИБКА ЧТЕНИЯ ИСХОДНОГО ФАЙЛА\n")
		return
	if not drives_driver.write_current_file(dst, data):
		write_output("ОШИБКА ЗАПИСИ В ЦЕЛЕВОЙ ФАЙЛ\n")
		return
	if not drives_driver.delete_current_file(src):
		write_output("ОШИБКА УДАЛЕНИЯ ИСХОДНОГО ФАЙЛА (файл скопирован, но не удалён)\n")
		return
	write_output("ФАЙЛ ПЕРЕМЕЩЕН: %s -> %s\n" % [src, dst])

func cmd_type(args: Array) -> void:
	if drives_driver == null:
		write_output("ОШИБКА: драйвер дисков не инициализирован\n")
		return
	if args.size() < 2:
		write_output("ИСПОЛЬЗОВАНИЕ: type <файл>\n")
		return
	var filename = args[1]
	if not drives_driver.is_file(filename):
		write_output("ФАЙЛ НЕ НАЙДЕН: %s\n" % filename)
		return
	var data = drives_driver.read_current_file(filename)
	if data.is_empty():
		write_output("(ПУСТОЙ ФАЙЛ)\n")
	else:
		var text = data.get_string_from_utf8()
		if text == "":
			text = data.get_string_from_ascii()
		write_output(text + "\n")

func cmd_echo(args: Array) -> void:
	if args.size() < 2:
		write_output("ИСПОЛЬЗОВАНИЕ: echo <текст> [> файл]\n")
		return
	var parts = []
	var redirect = false
	var filename = ""
	var current_arg = 1
	while current_arg < args.size():
		var arg = args[current_arg]
		if arg == ">" and not redirect:
			redirect = true
			current_arg += 1
			if current_arg < args.size():
				filename = args[current_arg]
				current_arg += 1
			else:
				write_output("ОШИБКА: не указан файл для перенаправления\n")
				return
		else:
			parts.append(arg)
			current_arg += 1
	var text = " ".join(parts)
	if not redirect:
		write_output(text + "\n")
	else:
		if drives_driver == null:
			write_output("ОШИБКА: драйвер дисков не инициализирован\n")
			return
		var data = text.to_utf8_buffer()
		if drives_driver.write_current_file(filename, data):
			write_output("ЗАПИСАНО В %s: %d байт\n" % [filename, data.size()])
		else:
			write_output("ОШИБКА ЗАПИСИ В ФАЙЛ\n")

func cmd_format(args: Array) -> void:
	if drives_driver == null:
		write_output("ОШИБКА: драйвер дисков не инициализирован\n")
		return
	var parsed = _parse_format_args(args)
	if parsed.has("error"):
		write_output("ОШИБКА: %s\n" % parsed.error)
		return
	var disk_name = parsed.disk
	var volumes = parsed.volumes
	var pd = drives_driver.get_physical_disk(disk_name)
	if not pd:
		write_output("ДИСК %s НЕ НАЙДЕН\n" % disk_name)
		return
	if pd.volumes.size() > 0:
		write_output("ДИСК %s УЖЕ СОДЕРЖИТ ТОМА. ПЕРЕФОРМАТИРОВАНИЕ УНИЧТОЖИТ ВСЕ ДАННЫЕ.\n" % disk_name)
		var confirm_text = "ПРОДОЛЖИТЬ ФОРМАТИРОВАНИЕ?"
		if not await _confirm_action(confirm_text):
			write_output("ОТМЕНЕНО\n")
			return
	var ok = drives_driver.format_disk(disk_name, volumes)
	if ok:
		write_output("ДИСК %s УСПЕШНО ОТФОРМАТИРОВАН\n" % disk_name)
		if drives_driver.has_method("_scan_disks"):
			drives_driver._scan_disks()
	else:
		write_output("ОШИБКА ФОРМАТИРОВАНИЯ ДИСКА\n")

func cmd_diskinfo(_args: Array) -> void:
	if drives_driver == null:
		write_output("ОШИБКА: драйвер дисков не инициализирован\n")
		return
	var info = drives_driver.list_all_disks()
	if info.is_empty():
		write_output("НЕТ ДОСТУПНЫХ ДИСКОВ\n")
		return
	for entry in info:
		if entry.has("type") and entry.type == "logical":
			write_output("ТОМ %s: (на %s) размер %d байт, занято %d байт, свободно %d байт\n" % [
				entry.letter, entry.by_name, entry.size, entry.used, entry.size - entry.used
			])
		else:
			write_output("ФИЗИЧЕСКИЙ ДИСК %s: размер %d байт, томов: %d\n" % [
				entry.by_name, entry.total_size, entry.volumes.size()
			])
			for letter in entry.volumes.keys():
				var vol = entry.volumes[letter]
				write_output("  ТОМ %s: размер %d байт, занято %d байт, свободно %d байт\n" % [
					letter, vol.size, vol.used, vol.size - vol.used
				])
			if entry.has("unallocated"):
				write_output("  НЕРАСПРЕДЕЛЕНО: %d байт\n" % entry.unallocated)

func cmd_mount(args: Array) -> void:
	if drives_driver == null:
		write_output("ОШИБКА: драйвер дисков не инициализирован\n")
		return
	if args.size() < 2:
		write_output("ИСПОЛЬЗОВАНИЕ: mount <буква>\n")
		return
	var letter = args[1].to_upper()
	if drives_driver.mount_volume(letter):
		write_output("ТОМ %s СМОНТИРОВАН\n" % letter)
	else:
		write_output("ОШИБКА МОНТИРОВАНИЯ ТОМА %s\n" % letter)

func cmd_unmount(_args: Array) -> void:
	if drives_driver == null:
		write_output("ОШИБКА: драйвер дисков не инициализирован\n")
		return
	if drives_driver.unmount_current():
		write_output("ТОМ ОТМОНТИРОВАН\n")
	else:
		write_output("НЕТ СМОНТИРОВАННОГО ТОМА\n")

func cmd_help(_args: Array) -> void:
	write_output(HELP_TEXT)

func unknown_command(args: Array) -> void:
	if args.size() == 0 or args.get(0) == "":
		return
	write_output("ВВЕДЕННАЯ ПОСЛЕДОВАТЕЛЬНОСТЬ ")
	write_output(ESC + "[4m" + "\"" + args[0] + "\"" + ESC + "[24m")
	write_output(" НЕ ЯВЛ. ИСПОЛНЯЕМЫМ КОДОМ ИЛИ ПРОГРАММОЙ\n")
