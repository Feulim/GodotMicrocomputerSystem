extends TerminalBase
class_name Terminal

var disk_manager: DiskManager
var command_executor: CommandExecutor
var input_handler: InputHandler
var render_command_stream: Stream
var output_stream: Stream
var exception_stream: Stream
var bki_stream: Stream

var input_active: bool = false
var input_start_pos: Vector2i
var pending_start_input: bool = false
var input_text: String = ""
var cursor_pos_in_input: int = 0
var saved_buffer: Dictionary = {}

var command_in_work: bool = false

var command_history: RingArray
var history_index: int = -1
var temp_text: String = ""

func _init(p_rect: Rect2i, p_total_cells: int, p_palette: IndexedPalette,
		   p_input_handler: InputHandler,
		   p_render_stream: Stream, p_output_stream: Stream,
		   p_exception_stream: Stream, p_bki_stream: Stream,
		   p_disk_manager: DiskManager,
		   p_default_bg: int = 0, p_default_fg: int = 0,
		   p_default_attrs: int = 0, cursor_blinking: bool = true,
		   command_history_capacity: int = 100) -> void:
	super(p_rect, p_total_cells, p_palette,
		   p_default_bg, p_default_fg,
		   p_default_attrs, cursor_blinking)
	disk_manager = p_disk_manager
	command_history = RingArray.new(command_history_capacity)
	input_handler = p_input_handler
	render_command_stream = p_render_stream
	output_stream = p_output_stream
	exception_stream = p_exception_stream
	bki_stream = p_bki_stream
	command_executor = OSBKCommands.new(output_stream, exception_stream)
	command_executor.set_disk_manager(disk_manager)
	command_executor.connect("user_input_requested", request_start)
	command_executor.connect("command_finished", _on_command_finished)
	input_handler.text_changed.connect(_on_text_changed)
	input_handler.cursor_moved.connect(_on_cursor_moved)
	input_handler.input_finished.connect(_on_input_finished)
	caret.position = Vector2i.ZERO
	caret.visible = false

func tick(delta: float) -> void:
	Debug.update_debug_label2(str(command_in_work))
	super.tick(delta)
	_process_bki_events()
	var has_output = false
	var output_text = ""
	if not exception_stream.is_empty():
		has_output = true
		var data = exception_stream.pop_all()
		for item in data:
			output_text += str(item)
	if not output_stream.is_empty():
		has_output = true
		var data = output_stream.pop_all()
		for item in data:
			output_text += str(item)
	if has_output:
		if input_active:
			cancel_input()
		process_output(output_text)
		if not input_active and pending_start_input:
			start_input()
			pending_start_input = false
	else:
		if pending_start_input and not input_active:
			start_input()
			pending_start_input = false
	render_to_stream(render_command_stream)

func _process_bki_events() -> void:
	while not bki_stream.is_empty():
		var event = bki_stream.pop()
		match event.type:
			InputHandler.EventType.PRESSED:
				var data = event.data
				var keycode = data.keycode
				var modifiers = data.modifiers
				_handle_key_press(keycode, modifiers)
			InputHandler.EventType.RELEASED:
				pass
			InputHandler.EventType.TEXT:
				pass

func _handle_key_press(keycode: int, modifiers: int) -> void:
	if modifiers & InputHandler.Modifier.CTRL:
		match keycode:
			KEY_DOWN:
				scroll_up_lines()
				return
			KEY_UP:
				scroll_down_lines()
				return
	match keycode:
		KEY_PAGEDOWN:
			scroll_page_up()
			return
		KEY_PAGEUP:
			scroll_page_down()
			return
	if input_active:
		match keycode:
			KEY_UP:
				navigate_history(1)
				return
			KEY_DOWN:
				navigate_history(-1)
				return

func start_input() -> void:
	if input_active:
		return
	input_handler.set_hold(false)
	input_handler.set_hold(true)
	input_active = true
	input_start_pos = caret.position
	input_text = ""
	cursor_pos_in_input = 0
	pending_start_input = false
	caret.visible = true
	saved_buffer.clear()
	_update_buffer()
	history_index = -1
	temp_text = ""

func cancel_input() -> void:
	if not input_active:
		return
	for row in saved_buffer.keys():
		buffer.set_row_data(row, saved_buffer[row])
		buffer.mark_dirty(row)
	saved_buffer.clear()
	input_active = false
	input_text = ""
	caret.position = input_start_pos
	caret.visible = false
	input_handler.set_hold(false)
	input_handler.set_hold(true)
	render_to_stream(render_command_stream)

func _update_buffer() -> void:
	if not input_active:
		return
	if not saved_buffer.is_empty():
		for row in saved_buffer.keys():
			buffer.set_row_data(row, saved_buffer[row])
			buffer.mark_dirty(row)
	var end_row = _get_end_row_for_text(input_text, input_start_pos.y, input_start_pos.x)
	for row in range(input_start_pos.y, end_row + 1):
		if row not in saved_buffer:
			saved_buffer[row] = buffer.get_row_data(row)
	_write_text_with_wrap(input_text, input_start_pos.y, input_start_pos.x)
	for row in range(input_start_pos.y, end_row + 1):
		buffer.mark_dirty(row)
	var caret_pos = _get_caret_position_from_index(cursor_pos_in_input, input_start_pos.y, input_start_pos.x)
	caret.position = caret_pos
	ensure_cursor_visible()
	render_to_stream(render_command_stream)

func _get_end_row_for_text(text: String, start_row: int, start_col: int) -> int:
	var row = start_row
	var col = start_col
	for ch in text:
		col += 1
		if col >= buffer.width:
			col = 0
			row += 1
			if row >= buffer.height:
				_scroll_up_buffer()
				row = buffer.height - 1
				if scroll_offset + visible_height >= buffer.height:
					scroll_offset = max(0, buffer.height - visible_height)
					_mark_visible_dirty()
				break
	return row

func _write_text_with_wrap(text: String, start_row: int, start_col: int) -> void:
	var row = start_row
	var col = start_col
	var idx = 0
	while idx < text.length():
		var ch = text[idx]
		buffer.update_cell(row, col, ch, buffer.current_bg_color, buffer.current_fg_color, buffer.current_attributes)
		col += 1
		if col >= buffer.width:
			col = 0
			row += 1
			if row >= buffer.height:
				_scroll_up_buffer()
				row = buffer.height - 1
				if scroll_offset + visible_height >= buffer.height:
					scroll_offset = max(0, buffer.height - visible_height)
					_mark_visible_dirty()
		idx += 1

func _get_caret_position_from_index(index: int, start_row: int, start_col: int) -> Vector2i:
	var row = start_row
	var col = start_col
	var idx = 0
	while idx < index and idx < input_text.length():
		col += 1
		if col >= buffer.width:
			col = 0
			row += 1
			if row >= buffer.height:
				_scroll_up_buffer()
				row = buffer.height - 1
				if scroll_offset + visible_height >= buffer.height:
					scroll_offset = max(0, buffer.height - visible_height)
					_mark_visible_dirty()
		idx += 1
	return Vector2i(clamp(col, 0, buffer.width - 1), clamp(row, 0, buffer.height - 1))

func _on_text_changed(new_text: String) -> void:
	if not input_active:
		return
	input_text = new_text
	cursor_pos_in_input = clamp(input_handler.get_cursor_pos(), 0, input_text.length())
	_update_buffer()

func _on_cursor_moved(new_position: int) -> void:
	if not input_active:
		return
	cursor_pos_in_input = clamp(new_position, 0, input_text.length())
	_update_buffer()

func _on_input_finished(final_text: String) -> void:
	if not input_active:
		return
	if not command_in_work:
		add_to_history(final_text)
	input_active = false
	input_text = ""
	saved_buffer.clear()
	caret.visible = false
	var row = caret.position.y
	buffer.mark_dirty(row)
	var new_pos = Vector2i(0, caret.position.y + 1)
	if new_pos.y >= buffer.height:
		_scroll_up_buffer()
		new_pos.y = buffer.height - 1
	caret.position = new_pos
	ensure_cursor_visible()
	command_executor.user_input_received.emit(final_text)
	command_in_work = command_executor.command_in_work
	render_to_stream(render_command_stream)

func start_work() -> void:
	_on_command_finished()

func _on_command_finished() -> void:
	command_in_work = command_executor.command_in_work
	var path = disk_manager.get_working_directory()
	if path and not path.is_empty():
		output_stream.push("[" + path.trim_suffix("/") + "]")
	output_stream.push("*")
	request_start()

func request_start() -> void:
	pending_start_input = true

func add_to_history(text: String) -> void:
	if text.is_empty():
		return
	if command_history.size() > 0 and command_history.get_element(-1) == text:
		return
	command_history.push_front(text)

func navigate_history(direction: int) -> void:
	if command_in_work:
		return
	if command_history.is_empty():
		return
	if history_index == -1:
		temp_text = input_text
	var new_index = history_index + direction
	if new_index < -1:
		new_index = -1
	elif new_index >= command_history.size():
		new_index = command_history.size() - 1
	history_index = new_index
	var new_text
	if history_index == -1:
		new_text = temp_text
	else:
		new_text = command_history.get_element(history_index)
	input_handler.set_text(new_text)

func shutdown() -> void:
	super.shutdown()
	if command_executor.is_connected("user_input_requested", request_start):
		command_executor.disconnect("user_input_requested", request_start)
	if command_executor.is_connected("command_finished", _on_command_finished):
		command_executor.disconnect("command_finished", _on_command_finished)
	command_executor.shutdown()
	if input_handler.is_connected("text_changed", _on_text_changed):
		input_handler.disconnect("text_changed", _on_text_changed)
	if input_handler.is_connected("cursor_moved", _on_cursor_moved):
		input_handler.disconnect("cursor_moved", _on_cursor_moved)
	if input_handler.is_connected("input_finished", _on_input_finished):
		input_handler.disconnect("input_finished", _on_input_finished)
	
	input_handler = null
	render_command_stream = null
	output_stream = null
	exception_stream = null
	bki_stream = null
	command_executor = null
