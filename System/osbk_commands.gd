extends CommandExecutor
class_name OSBKCommands

signal change_style(accent: int, subaccent: int, contrast: int, margin: int)

var disk_manager: DiskManager

const COMMANDS_INFO = [
	{
		"name": "CLS",
		"synonyms": ["CLEAR"],
		"syntax": "CLS",
		"params": "",
		"description": "ОЧИСТКА ЭКРАНА ТЕРМИНАЛА"
	},
	{
		"name": "SET",
		"synonyms": [],
		"syntax": "SET TV [ACC=X] [SUB=Y] [CON=Z] [MRG=V]",
		"params": "ACC - ОСНОВНОЙ ЦВЕТ (0..15)\nSUB - ДОПОЛНИТЕЛЬНЫЙ ЦВЕТ (0..15)\nCON - КОНТРАСТ (0..15)\nMRG - РАЗМЕР ОТСТУПА (0..80)",
		"description": "НАСТРОЙКА ЦВЕТОВОЙ СХЕМЫ ЭКРАНА"
	},
	{
		"name": "DIR",
		"synonyms": ["DIRECTORY"],
		"syntax": "DIR [ПУТЬ] [/ALP | /VOL | /FZS <ПОДСТРОКА>] [+ | -] [МАСКА]",
		"params": ("ПУТЬ – необязательный, указывает каталог для просмотра (по умолчанию текущий).\n" +
				  "/ALP  – сортировка по алфавиту.\n" +
				  "/VOL  – сортировка по размеру (объёму).\n" +
				  "/FZS <ПОДСТРОКА> – нечёткая сортировка по степени схожести с указанной подстрокой.\n" +
				  "+ / - – направление сортировки (по умолчанию + – по возрастанию).\n" +
				  "МАСКА – шаблон для фильтрации имён. Допускаются символы:\n" +
				  "   *  – любое количество любых символов (включая ноль).\n" +
				  "   %  – ровно один любой символ.\n" +
				  "Пример: DIR *.TXT  – покажет все файлы с расширением TXT."),
		"description": "ВЫВОД СОДЕРЖИМОГО КАТАЛОГА С ВОЗМОЖНОСТЬЮ СОРТИРОВКИ И ФИЛЬТРАЦИИ ПО МАСКЕ"
	},
	{
		"name": "CD",
		"synonyms": ["CHDIR"],
		"syntax": "CD [ПУТЬ]",
		"params": "ПУТЬ - НЕОБЯЗАТЕЛЬНЫЙ.\nЕСЛИ УКАЗАН - СМЕНА ТЕКУЩЕГО КАТАЛОГА;\nЕСЛИ ОПУЩЕН - ПОКАЗЫВАЕТ ТЕКУЩИЙ ПУТЬ.",
		"description": "СМЕНА ИЛИ ОТОБРАЖЕНИЕ ТЕКУЩЕГО КАТАЛОГА"
	},
	{
		"name": "TYPE",
		"synonyms": ["TYP"],
		"syntax": "TYPE <ФАЙЛ>",
		"params": "ФАЙЛ - ИМЯ ТЕКСТОВОГО ФАЙЛА ДЛЯ ВЫВОДА",
		"description": "ВЫВОД СОДЕРЖИМОГО ТЕКСТОВОГО ФАЙЛА НА ЭКРАН"
	},
	{
		"name": "COPY",
		"synonyms": ["COP"],
		"syntax": "COPY <ИСТОЧНИК> <НАЗНАЧЕНИЕ>",
		"params": "ИСТОЧНИК - ИМЯ КОПИРУЕМОГО ФАЙЛА.\nНАЗНАЧЕНИЕ - ИМЯ ФАЙЛА-ПРИЁМНИКА.",
		"description": "КОПИРОВАНИЕ ФАЙЛА (ВНУТРИ ДИСКА ИЛИ МЕЖДУ ДИСКАМИ)"
	},
	{
		"name": "DEL",
		"synonyms": ["DELETE"],
		"syntax": "DEL <ФАЙЛ>",
		"params": "ФАЙЛ - ИМЯ УДАЛЯЕМОГО ФАЙЛА",
		"description": "УДАЛЕНИЕ ФАЙЛА"
	},
	{
		"name": "MKDIR",
		"synonyms": [],
		"syntax": "MKDIR <ПАПКА>",
		"params": "ПАПКА - ИМЯ СОЗДАВАЕМОГО КАТАЛОГА",
		"description": "СОЗДАНИЕ НОВОГО КАТАЛОГА"
	},
	{
		"name": "RMDIR",
		"synonyms": [],
		"syntax": "RMDIR <ПАПКА>",
		"params": "ПАПКА - ИМЯ ПУСТОГО КАТАЛОГА ДЛЯ УДАЛЕНИЯ",
		"description": "УДАЛЕНИЕ ПУСТОГО КАТАЛОГА"
	},
	{
		"name": "REN",
		"synonyms": ["RENAME"],
		"syntax": "REN <СТАРОЕ_ИМЯ> <НОВОЕ_ИМЯ>",
		"params": "СТАРОЕ_ИМЯ - ТЕКУЩЕЕ ИМЯ ФАЙЛА ИЛИ КАТАЛОГА\nНОВОЕ_ИМЯ - НОВОЕ ИМЯ (В ТОЙ ЖЕ ПАПКЕ)",
		"description": "ПЕРЕИМЕНОВАНИЕ ФАЙЛА ИЛИ КАТАЛОГА"
	},
	{
		"name": "MOVE",
		"synonyms": [],
		"syntax": "MOVE <ИСТОЧНИК> <НАЗНАЧЕНИЕ>",
		"params": "ИСТОЧНИК - ПЕРЕМЕЩАЕМЫЙ ФАЙЛ\nНАЗНАЧЕНИЕ - НОВОЕ МЕСТОПОЛОЖЕНИЕ ФАЙЛА",
		"description": "ПЕРЕМЕЩЕНИЕ ФАЙЛА (МЕЖДУ ДИСКАМИ ИЛИ ПАПКАМИ)"
	},
	{
		"name": "FORMAT",
		"synonyms": ["INIT"],
		"syntax": "FORMAT [ДИСК]",
		"params": "ДИСК - НЕОБЯЗАТЕЛЬНЫЙ. ЕСЛИ ОПУЩЕН - ФОРМАТИРУЕТСЯ ТЕКУЩИЙ ДИСК.",
		"description": "ФОРМАТИРОВАНИЕ ДИСКА (ВСЕ ДАННЫЕ УНИЧТОЖАЮТСЯ)"
	},
	{
		"name": "DISK",
		"synonyms": ["SHOW"],
		"syntax": "DISK",
		"params": "",
		"description": "ОТОБРАЖЕНИЕ СПИСКА ДОСТУПНЫХ ДИСКОВ\nТЕКУЩИЙ ОТМЕЧАЕТСЯ [*]."
	},
	{
		"name": "PATH",
		"synonyms": [],
		"syntax": "PATH",
		"params": "",
		"description": "ОТОБРАЖЕНИЕ ТЕКУЩЕГО ПУТИ В ФАЙЛОВОЙ СИСТЕМЕ"
	},
	{
		"name": "HELP",
		"synonyms": [],
		"syntax": "HELP [КОМАНДА]",
		"params": "КОМАНДА - НЕОБЯЗАТЕЛЬНЫЙ ПАРАМЕТР. ЕСЛИ УКАЗАН, ВЫВОДИТСЯ ПОДРОБНАЯ ИНФОРМАЦИЯ О КОНКРЕТНОЙ КОМАНДЕ.",
		"description": "ВЫВОД СПРАВКИ ПО СИСТЕМЕ"
	},
	{
		"name": "COLORAMA",
		"synonyms": ["RAINBOW"],
		"syntax": "COLORAMA",
		"params": "",
		"description": "ТЕСТ ЦВЕТОВ ANSI"
	}
]

func set_disk_manager(manager: DiskManager) -> void:
	disk_manager = manager

func levenshtein(a: String, b: String) -> int:
	var len_a = a.length()
	var len_b = b.length()
	var matrix = []
	for i in range(len_a + 1):
		matrix.append([])
		for j in range(len_b + 1):
			matrix[i].append(0)
	for i in range(len_a + 1):
		matrix[i][0] = i
	for j in range(len_b + 1):
		matrix[0][j] = j
	for i in range(1, len_a + 1):
		for j in range(1, len_b + 1):
			var cost = 0 if a[i-1] == b[j-1] else 1
			matrix[i][j] = min(
				matrix[i-1][j] + 1,
				matrix[i][j-1] + 1,
				matrix[i-1][j-1] + cost
			)
	return matrix[len_a][len_b]

func parse_command(args: Array) -> Callable:
	var command = args[0].to_lower()
	match command:
		"cls", "clear":         return cmd_clear
		"set":                  return cmd_set
		"dir", "directory":     return cmd_dir
		"cd", "chdir":          return cmd_cd
		"type", "typ":          return cmd_type
		"copy", "cop":          return cmd_copy
		"del", "delete":        return cmd_del
		"mkdir":                return cmd_mkdir
		"rmdir":                return cmd_rmdir
		"ren", "rename":        return cmd_ren
		"move":                 return cmd_move
		"format", "init":       return cmd_format
		"disk", "show":         return cmd_disk
		"path":                 return cmd_path
		"help":                 return cmd_help
		"colorama", "rainbow":  return cmd_colorama
		_:                      return unknown_command

func unknown_command(args: Array) -> void:
	if args.size() == 0 or args.get(0) == "":
		return
	report_exception(
		"\nВВЕДЕННАЯ ПОСЛЕДОВАТЕЛЬНОСТЬ " +
		ESC + "[4m" + "\"" + args[0] + "\"" + ESC + "[24m" +
		" НЕ ЯВЛ. ИСПОЛНЯЕМЫМ КОДОМ ИЛИ ПРОГРАММОЙ\n\n"
	)

func cmd_colorama(_args: Array) -> void:
	write_output("\n")
	var hex_chars = "0123456789ABCDEF"
	
	write_output(ESC + "[4m\\│")
	for j in range(16):
		write_output(hex_chars[j] + " ")
	write_output(ESC + "[0m\n")
	
	for i in range(16):
		write_output(hex_chars[i] + "│")
		
		for j in range(16):
			var fg = ""
			if i < 8:
				fg = str(30 + i)
			else:
				fg = str(90 - 8 + i)
			var bg = ""
			if j < 8:
				bg = str(40 + j)
			else:
				bg = str(100 - 8 + j)
			var text = hex_chars[i] + hex_chars[j]
			
			write_output(ESC + "[" + bg + ";" + fg + "m" + text + ESC + "[0m")
			
		write_output("\n")
	write_output("\n")

func cmd_clear(_args: Array) -> void:
	write_output(ESC + "[2J" + ESC + "[H")

func cmd_set(args: Array) -> void:
	write_output("\n")
	if args.size() < 2:
		return
	if args[1].to_lower() != "tv":
		return
	var accent = -1
	var subaccent = -1
	var contrast = -1
	var margin = -1
	var i = 2
	while i < args.size() - 1:
		var key = (args[i]).to_lower()
		if key in ["acc", "sub", "con", "mrg"]:
			var value_str = args[i + 1]
			if value_str.is_valid_int():
				var value = int(value_str)
				match key:
					"acc":
						accent = clamp(value, 0, 15)
					"sub":
						subaccent = clamp(value, 0, 15)
					"con":
						contrast = clamp(value, 0, 15)
					"mrg":
						margin = clamp(value, 0, 80)
		i += 1
	write_output("СМЕНА ВНЕШНЕГО ВИДА ПОВЛЕЧЕТ ЗА СОБОЙ ОЧИСТКУ\n")
	write_output("ТЕРМИНЛА. ПОДТВЕРДИТЬ ДЕЙСТВИЕ ")
	var success = await confirm(true)
	if success:
		change_style.emit(accent, subaccent, contrast, margin)
	else:
		write_output("ДЕЙСТВИЕ ОТМЕНЕНО\n")
	write_output("\n")

func cmd_dir(args: Array) -> void:
	write_output("\n")
	if not disk_manager:
		report_exception("ОШИБКА: МЕНЕДЖЕР ДИСКОВ НЕ ИНИЦИАЛИЗИРОВАН\n")
		return

	var path = ""
	var mask = ""
	var sort_attr = ""
	var sort_order = "+"
	var fuzzy_needle = ""

	var i = 1
	while i < args.size():
		var arg = args[i]
		if arg.begins_with("/"):
			if sort_attr != "":
				report_exception("НЕКОРРЕКТНОЕ ИСПОЛЬЗОВАНИЕ АТРИБУТОВ\n")
				return
			var attr_key = arg.to_lower()
			match attr_key:
				"/alp":
					sort_attr = "alp"
					if i + 1 < args.size() and args[i+1].to_lower() in ["+", "-"]:
						sort_order = args[i+1].to_lower()
						i += 2
					else:
						i += 1
				"/vol":
					sort_attr = "vol"
					if i + 1 < args.size() and args[i+1].to_lower() in ["+", "-"]:
						sort_order = args[i+1].to_lower()
						i += 2
					else:
						i += 1
				"/fzs":
					sort_attr = "fzs"
					if i + 1 >= args.size():
						report_exception("НЕКОРРЕКТНОЕ ИСПОЛЬЗОВАНИЕ АТРИБУТОВ\n")
						return
					fuzzy_needle = args[i+1]
					i += 2
				_:
					report_exception("НЕИЗВЕСТНЫЙ АТРИБУТ: " + arg + "\n")
					return
		else:
			if arg.contains("*") or arg.contains("%"):
				if mask != "":
					report_exception("НЕКОРРЕКТНОЕ ИСПОЛЬЗОВАНИЕ МАСОК\n")
					return
				mask = arg
				i += 1
			else:
				if path != "":
					report_exception("НЕСКОЛЬКО ПУТЕЙ УКАЗАНО\n")
					return
				path = arg
				i += 1

	if sort_attr == "fzs" and fuzzy_needle.is_empty():
		report_exception("НЕКОРРЕКТНОЕ ИСПОЛЬЗОВАНИЕ АТРИБУТОВ\n")
		return

	var result = disk_manager.list_directory(path)
	if not result.has("err"):
		report_exception("ОШИБКА: НЕИЗВЕСТНОЕ ПОВЕДЕНИЕ")
		return
	var err = result.get("err")
	if err == -1 or err == -2:
		write_output("НЕКОРРЕКТНАЯ ДИРЕКТОРИЯ\n\n")
		return
	var dir_disk = result.get("disk", "")
	var dir_path = result.get("path", "")
	var content = result.get("contains", {})
	content["."] = {"size": 0, "type": 1}
	if not dir_path.is_empty():
		content[".."] = {"size": 0, "type": 1}

	var filtered = {}
	if mask != "":
		var mask_lower = mask.to_lower().replace("%", "?")
		for name in content.keys():
			if name.to_lower().match(mask_lower):
				filtered[name] = content[name]
	else:
		filtered = content

	var items = filtered.keys()
	if sort_attr != "":
		match sort_attr:
			"alp":
				items.sort_custom(func(a, b):
					var cmp = a.to_lower() < b.to_lower()
					return cmp if sort_order == "+" else not cmp
				)
			"vol":
				items.sort_custom(func(a, b):
					var type_a = filtered[a].type
					var type_b = filtered[b].type
					var size_a = filtered[a].size if (type_a != 1 and type_a != 0) else 0
					var size_b = filtered[b].size if (type_b != 1 and type_b != 0) else 0
					if size_a != size_b:
						return (size_a < size_b) if sort_order == "+" else (size_a > size_b)
					else:
						return (a.to_lower() < b.to_lower()) if sort_order == "+" else (b.to_lower() < a.to_lower())
				)
			"fzs":
				var needle = fuzzy_needle.to_lower()
				items.sort_custom(func(a, b):
					var dist_a = levenshtein(a.to_lower(), needle)
					var dist_b = levenshtein(b.to_lower(), needle)
					if dist_a != dist_b:
						return dist_a > dist_b
					else:
						return a.to_lower() > b.to_lower()
				)
	else:
		items.sort_custom(func(a, b):
			var type_a = filtered[a].type
			var type_b = filtered[b].type
			if type_a == 1 and type_b == 1:
				if a == ".": return true
				if a == ".." and b != ".": return true
				return a.to_lower() < b.to_lower()
			if type_a == 1 and type_b != 1: return true
			if type_a != 1 and type_b == 1: return false
			return a.to_lower() < b.to_lower()
		)

	var rows = []
	rows.append(["ИМЯ", "ТИП", "РАЗМЕР", ""])

	for name in items:
		var info = filtered[name]
		var type_str = ""
		var size = ["", ""]
		if info.type == 1:
			type_str = "<DIR>"
			size = ["", ""]
		else:
			type_str = "FILE"
			if name.contains("."):
				type_str = name.get_extension().to_upper()
			size = (String.humanize_size(info.size)).split(" ")
		rows.append([name, type_str, size[0], size[1]])

	var table = Table.hor(rows)
	var anchors = [Table.Anchor.LEFT, Table.Anchor.LEFT, Table.Anchor.RIGHT, Table.Anchor.LEFT]
	var output = table.prepare(anchors, "  ")

	write_output("ФИЗИЧЕСКИЙ НОСИТЕЛЬ " + dir_disk + "\n")
	write_output("СОДЕРЖИМОЕ ДИРЕКТОРИИ " + dir_disk + ":" + dir_path + "\n\n")
	write_output(output + "\n\n")

func cmd_cd(args: Array) -> void:
	write_output("\n")
	if not disk_manager:
		report_exception("ОШИБКА: МЕНЕДЖЕР ДИСКОВ НЕ ИНИЦИАЛИЗИРОВАН\n")
		return
	if args.size() < 2:
		write_output("ТЕКУЩАЯ ДИРЕКТОРИЯ: " + disk_manager.get_working_directory().to_upper() + "\n")
		return
	var new_path = args[1]
	if disk_manager.change_directory(new_path):
		write_output("OK\n\n")
	else:
		report_exception("ОШИБКА: ПУТЬ НЕ НАЙДЕН\n")

func cmd_type(args: Array) -> void:
	write_output("\n")
	if not disk_manager:
		report_exception("ОШИБКА: МЕНЕДЖЕР ДИСКОВ НЕ ИНИЦИАЛИЗИРОВАН\n")
		return
	if args.size() < 2:
		write_output("УКАЖИТЕ ИМЯ ФАЙЛА\n")
		return
	var path = args[1]
	var data = disk_manager.internal_read_file(path)
	if data.is_empty():
		report_exception("ОШИБКА: ФАЙЛ НЕ НАЙДЕН ИЛИ НЕДОСТУПЕН\n")
		return
	var text = data.get_string_from_utf8()
	write_output(text.to_upper())
	if not text.ends_with("\n"):
		write_output("\n")
	write_output("\n")

func cmd_copy(args: Array) -> void:
	write_output("\n")
	if args.size() < 3:
		write_output("НЕДОСТАТОЧНО АРГУМЕНТОВ\n")
		return
	var src = args[1]
	var dst = args[2]
	if not disk_manager:
		report_exception("ОШИБКА: МЕНЕДЖЕР ДИСКОВ НЕ ИНИЦИАЛИЗИРОВАН\n")
		return
	var data = disk_manager.internal_read_file(src)
	if data.is_empty():
		report_exception("ОШИБКА: ИСХОДНЫЙ ФАЙЛ НЕ НАЙДЕН ИЛИ НЕДОСТУПЕН\n")
		return
	if disk_manager.write_file(dst, data):
		write_output("OK\n")
	else:
		report_exception("ОШИБКА ЗАПИСИ\n")
	write_output("\n")

func cmd_del(args: Array) -> void:
	write_output("\n")
	if args.size() < 2:
		write_output("УКАЖИТЕ ИМЯ ФАЙЛА\n")
		return
	var path = args[1]
	if not disk_manager:
		report_exception("ОШИБКА: МЕНЕДЖЕР ДИСКОВ НЕ ИНИЦИАЛИЗИРОВАН\n")
		return
	if disk_manager.delete_file(path):
		write_output("OK\n")
	else:
		report_exception("ОШИБКА УДАЛЕНИЯ\n")
	write_output("\n")

func cmd_mkdir(args: Array) -> void:
	write_output("\n")
	if args.size() < 2:
		write_output("УКАЖИТЕ ИМЯ ПАПКИ\n")
		return
	var path = args[1]
	if not disk_manager:
		report_exception("ОШИБКА: МЕНЕДЖЕР ДИСКОВ НЕ ИНИЦИАЛИЗИРОВАН\n")
		return
	if disk_manager.create_directory(path):
		write_output("OK\n")
	else:
		report_exception("ОШИБКА СОЗДАНИЯ\n")
	write_output("\n")

func cmd_rmdir(args: Array) -> void:
	write_output("\n")
	if args.size() < 2:
		write_output("УКАЖИТЕ ИМЯ ПАПКИ\n")
		return
	var path = args[1]
	if not disk_manager:
		report_exception("ОШИБКА: МЕНЕДЖЕР ДИСКОВ НЕ ИНИЦИАЛИЗИРОВАН\n")
		return
	if disk_manager.delete_directory(path):
		write_output("OK\n")
	else:
		report_exception("ОШИБКА УДАЛЕНИЯ\n")
	write_output("\n")

func cmd_ren(args: Array) -> void:
	write_output("\n")
	if args.size() < 3:
		write_output("ИСПОЛЬЗОВАНИЕ: REN <СТАРОЕ_ИМЯ> <НОВОЕ_ИМЯ>\n")
		return
	var old_path = args[1]
	var new_name = args[2]
	if not disk_manager:
		report_exception("ОШИБКА: МЕНЕДЖЕР ДИСКОВ НЕ ИНИЦИАЛИЗИРОВАН\n")
		return
	var item_type = disk_manager.get_item_type(old_path)
	match item_type:
		1:
			if disk_manager.rename_directory(old_path, new_name):
				write_output("OK\n")
			else:
				report_exception("ОШИБКА ПЕРЕИМЕНОВАНИЯ ДИРЕКТОРИИ\n")
		2, -1, -2:
			if disk_manager.rename_file(old_path, new_name):
				write_output("OK\n")
			else:
				report_exception("ОШИБКА ПЕРЕИМЕНОВАНИЯ ФАЙЛА\n")
		_:
			report_exception("ОБЪЕКТ НЕ НАЙДЕН ИЛИ НЕ ПОДДЕРЖИВАЕТСЯ\n")
	write_output("\n")

func cmd_move(args: Array) -> void:
	write_output("\n")
	if args.size() < 3:
		write_output("ИСПОЛЬЗОВАНИЕ: MOVE <ИСТОЧНИК> <НАЗНАЧЕНИЕ>\n")
		return
	var src = args[1]
	var dst = args[2]
	if not disk_manager:
		report_exception("ОШИБКА: МЕНЕДЖЕР ДИСКОВ НЕ ИНИЦИАЛИЗИРОВАН\n")
		return
	if disk_manager.move_file(src, dst):
		write_output("OK\n")
	else:
		report_exception("ОШИБКА ПЕРЕМЕЩЕНИЯ ФАЙЛА\n")
	write_output("\n")

func cmd_format(args: Array) -> void:
	write_output("\n")
	var disk_name = "" if args.size() < 2 else args[1]
	if disk_name.is_empty():
		disk_name = disk_manager.get_current_disk_name()
	write_output("ВНИМАНИЕ: ВСЕ ДАННЫЕ НА ДИСКЕ " + disk_name.to_upper() + " БУДУТ УНИЧТОЖЕНЫ!\n")
	write_output("ПОДТВЕРДИТЬ ФОРМАТИРОВАНИЕ ")
	var confirmed = await confirm(false)
	if not confirmed:
		write_output("ДЕЙСТВИЕ ОТМЕНЕНО\n")
		return
	if disk_manager.format_disk(disk_name):
		write_output("ДИСК " + disk_name.to_upper() + " ОТФОРМАТИРОВАН\n")
	else:
		report_exception("ОШИБКА ФОРМАТИРОВАНИЯ\n")
	write_output("\n")

func cmd_disk(_args: Array) -> void:
	write_output("\n")
	if not disk_manager:
		report_exception("ОШИБКА: МЕНЕДЖЕР ДИСКОВ НЕ ИНИЦИАЛИЗИРОВАН\n")
		return
	var disks = disk_manager.get_disks_info()
	if disks.is_empty():
		write_output("НЕТ ДОСТУПНЫХ ДИСКОВ\n")
		return
	var current = disk_manager.get_current_disk_name()
	write_output("ДОСТУПНЫЕ ДИСКИ:\n")
	var output_table = Table.hor([])
	for name in disks.keys():
		var marker = "[*]" if name == current else "[ ]"
		output_table.add([name.to_upper(), marker])
	write_output(output_table.prepare([Table.Anchor.LEFT, Table.Anchor.CENTER], "  "))
	write_output("\n\n")

func cmd_path(_args: Array) -> void:
	write_output("\n")
	if not disk_manager:
		report_exception("ОШИБКА: МЕНЕДЖЕР ДИСКОВ НЕ ИНИЦИАЛИЗИРОВАН\n")
		return
	var path = disk_manager.get_working_directory()
	if path.is_empty():
		path = "<НЕТ ДИСКА>"
	write_output(path.to_upper() + "\n\n")

func _get_command_info(cmd_name: String) -> Dictionary:
	var cmd_upper = cmd_name.to_upper()
	for info in COMMANDS_INFO:
		if info["name"] == cmd_upper:
			return info
		for syn in info["synonyms"]:
			if syn == cmd_upper:
				return info
	return {}

func _format_help_detail(info: Dictionary) -> String:
	var out = ""
	var table_data = []
	table_data.append(["КОМАНДА", "СИНОНИМЫ"])
	var syn_str = ", ".join(info["synonyms"])
	if syn_str.is_empty():
		syn_str = "НЕТ СИНОНИМОВ"
	table_data.append([info["name"], syn_str])
	var table = Table.hor(table_data)
	out += table.prepare([Table.Anchor.LEFT, Table.Anchor.LEFT], "  ") + "\n"
	
	out += "ОСНОВНОЙ СИНТАКСИС:\n"
	out += info["syntax"] + "\n"
	
	if not info["params"].is_empty():
		out += "ПАРАМЕТРЫ:\n"
		out += info["params"] + "\n"
	
	out += "ОБЩЕЕ ОПИСАНИЕ:\n"
	out += info["description"] + "\n"
	
	return out

func cmd_help(args: Array) -> void:
	write_output("\n")
	if args.size() >= 2:
		var cmd = args[1].to_lower()
		var info = _get_command_info(cmd)
		if info.is_empty():
			write_output("НЕТ ИНФОРМАЦИИ О КОМАНДЕ " + args[1].to_upper() + "\n")
		else:
			write_output(_format_help_detail(info))
		write_output("\n")
		return

	var rows = []
	rows.append(["КОМАНДА", "ОПИСАНИЕ", "СИНОНИМЫ"])
	rows.append(["CLS", "ОЧИСТИТЬ ЭКРАН", "CLEAR"])
	rows.append(["SET", "НАСТРОИТЬ ЦВЕТОВУЮ СХЕМУ", ""])
	rows.append(["DIR", "ПОКАЗАТЬ СОДЕРЖИМОЕ КАТАЛОГА", "DIRECTORY"])
	rows.append(["CD", "СМЕНИТЬ ТЕКУЩИЙ КАТАЛОГ", "CHDIR"])
	rows.append(["TYPE", "ВЫВЕСТИ СОДЕРЖИМОЕ ФАЙЛА", "TYP"])
	rows.append(["COPY", "КОПИРОВАТЬ ФАЙЛ", "COP"])
	rows.append(["DEL", "УДАЛИТЬ ФАЙЛ", "DELETE"])
	rows.append(["MKDIR", "СОЗДАТЬ КАТАЛОГ", ""])
	rows.append(["RMDIR", "УДАЛИТЬ ПУСТОЙ КАТАЛОГ", ""])
	rows.append(["REN", "ПЕРЕИМЕНОВАТЬ ФАЙЛ/КАТАЛОГ", "RENAME"])
	rows.append(["MOVE", "ПЕРЕМЕСТИТЬ ФАЙЛ", ""])
	rows.append(["FORMAT", "ОТФОРМАТИРОВАТЬ ДИСК", "INIT"])
	rows.append(["DISK", "ПОКАЗАТЬ СПИСОК ДИСКОВ", "SHOW"])
	rows.append(["PATH", "ПОКАЗАТЬ ТЕКУЩИЙ ПУТЬ", ""])
	rows.append(["HELP", "ЭТА СПРАВКА", ""])

	var table = Table.hor(rows)
	var anchors = [Table.Anchor.LEFT, Table.Anchor.LEFT, Table.Anchor.LEFT]
	write_output(table.prepare(anchors, " ") + "\n")
	write_output("ДЛЯ ПОЛУЧЕНИЯ ПОДРОБНОЙ ИНФОРМАЦИИ ВВЕДИТЕ:\nHELP <КОМАНДА>\n\n")
