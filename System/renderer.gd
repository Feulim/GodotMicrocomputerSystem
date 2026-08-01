extends RefCounted
class_name Renderer

var microcomputer: Microcomputer = null
var command_buffer: Stream = null
var dirty: bool = false

func initialize(mc: Microcomputer, buffer: Stream) -> void:
	microcomputer = mc
	command_buffer = buffer

func process_commands() -> void:
	if command_buffer == null or microcomputer == null:
		return
	if command_buffer.is_empty():
		return

	dirty = true
	microcomputer.copy_front_to_back()

	while not command_buffer.is_empty():
		var cmd = command_buffer.pop()
		_execute_command(cmd)

	if dirty:
		microcomputer.present()
		dirty = false

func _execute_command(cmd: Dictionary) -> void:
	match cmd.type:
		"draw_text":
			microcomputer.draw_text(
				cmd.text,
				cmd.position,
				cmd.fg_color,
				cmd.bg_color,
				cmd.font_size
			)
		"draw_line":
			microcomputer.draw_line_vec(cmd.from, cmd.to, cmd.color)
		"draw_rect":
			microcomputer.draw_rect_vec(cmd.from, cmd.to, cmd.color)
		"set_pixel":
			microcomputer.set_pixel_vec(cmd.position, cmd.color)
		"clear":
			microcomputer.clear()
		_:
			push_error("Unknown render command: ", cmd.type)

func tick() -> void:
	process_commands()

func shutdown() -> void:
	command_buffer = null
	microcomputer = null
