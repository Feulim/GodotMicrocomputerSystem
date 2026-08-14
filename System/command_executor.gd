extends RefCounted
class_name CommandExecutor

var ESC = String.chr(27)

var command_in_work: bool = false

signal user_input_requested()
signal user_input_received(response_data: String)
signal command_finished()

var buffer_key_output: Stream
var buffer_key_exception: Stream

func _init(p_bko: Stream, p_bke: Stream) -> void:
	buffer_key_output = p_bko
	buffer_key_exception = p_bke
	self.connect("user_input_received", _on_user_input)

func _on_user_input(user_input: String) -> void:
	if command_in_work:
		pass
	else:
		command_in_work = true
		execute_command(user_input)

func execute_command(command: String) -> void:
	var args = command.split(" ")
	if args and args.size() > 0 and not args[0].is_empty():
		var callable_command = parse_command(args)
		if callable_command != null:
			await callable_command.call(args)
	finish()

func parse_command(_args: Array) -> Callable:
	return unknown_command

func unknown_command(_args: Array) -> void:
	pass

func request_user_input() -> String:
	user_input_requested.emit()
	var result = await user_input_received
	return result

func finish() -> void:
	command_finished.emit()
	command_in_work = false

func write_output(text: String) -> void:
	buffer_key_output.push(text)

func report_exception(message: String) -> void:
	buffer_key_exception.push(message)

func confirm(default_value: bool = false) -> bool:
	var prompt = "["
	if default_value: prompt += "Y/n"
	else: prompt += "y/N"
	prompt += "] "
	
	write_output(prompt)
	var input = await request_user_input()
	
	if input.is_empty():
		return default_value
	
	var first = input[0].to_lower()
	if first == "y" or first == "д":
		return true
	elif first == "n" or first == "н":
		return false
	else:
		return default_value

func shutdown() -> void:
	if self.is_connected("user_input_received", _on_user_input):
		self.disconnect("user_input_received", _on_user_input)
	buffer_key_output = null
	buffer_key_exception = null
