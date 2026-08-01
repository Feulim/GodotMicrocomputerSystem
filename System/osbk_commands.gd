extends CommandExecutor
class_name OSBKCommands

signal change_style(accent: int, subaccent: int, contrast: int)

func parse_command(args: Array) -> Callable:
	if not args or args.size() < 1:
		return unknown_command
	if args[0] == "rnd":
		return random_test_command
	if args[0] == "cls":
		return clear
	if args[0] == "SET":
		return cmd_set
	return unknown_command

func unknown_command(args: Array) -> void:
	if args.size() == 0 or args.get(0) == "":
		return
	write_output("ВВЕДЕННАЯ ПОСЛЕДОВАТЕЛЬНОСТЬ ")
	write_output(ESC + "[4m" + "\"" + args[0] + "\"" + ESC + "[24m")
	write_output(" НЕ ЯВЛ. ИСПОЛНЯЕМЫМ КОДОМ ИЛИ ПРОГРАММОЙ\n")

func random_test_command(_args: Array) -> void:
	write_output("RANDOM TEST COMMAND")
	var user_input = await request_user_input()
	if user_input == "1":
		write_output(":)\n")

func clear(_args: Array) -> void:
	write_output(ESC + "[2J" + ESC + "[H")

func cmd_set(args: Array) -> void:
	if args.size() < 2:
		return
	if args[1] != "TV":
		return
	
	var accent = -1
	var subaccent = -1
	var contrast = -1
	
	var i = 2
	while i < args.size() - 1:
		var key = args[i]
		if key in ["ACC", "SUB", "CON"]:
			var value_str = args[i + 1]
			if value_str.is_valid_int():
				var value = clamp(int(value_str), 0, 15)
				match key:
					"ACC":
						accent = value
					"SUB":
						subaccent = value
					"CON":
						contrast = value
		i += 1
	write_output("СМЕНА ВНЕШНЕГО ВИДА ПОВЛЕЧЕТ ЗА СОБОЙ ОЧИСТКУ\n")
	write_output("ТЕРМИНЛА. ПОДТВЕРДИТЬ ДЕЙСТВИЕ ")
	var success = await confirm()
	if success:
		change_style.emit(accent, subaccent, contrast)
	else:
		write_output("ДЕЙСТВИЕ ОТМЕНЕНО\n")
