extends RefCounted
class_name TerminalBase

signal scrolled()

var buffer: Buffer
var palette: IndexedPalette
var ansi_decoder: AnsiDecoder
var caret: Caret

var rect: Rect2i
var total_cells: int
var cell_size: Vector2
var width_in_cells: int
var height_in_cells: int
var visible_height: int

var scroll_offset: int = 0:
	set(value):
		if scroll_offset != value:
			scroll_offset = value
			_mark_visible_dirty()
			scrolled.emit()
var target_scroll: int = 0
var _scroll_time: float = 0.0
var max_scroll_duration: float = 0.05

var default_fg: int = 0
var default_bg: int = 0
var default_attrs: int = 0
var current_fg: int = 0
var current_bg: int = 0
var current_attrs: int = 0

var readable_area_height: int = 0

func _init(p_rect: Rect2i, p_total_cells: int, p_palette: IndexedPalette,
		   p_default_bg: int = 0, p_default_fg: int = 0,
		   p_default_attrs: int = 0, blinking: bool = true) -> void:
	rect = p_rect
	total_cells = p_total_cells
	palette = p_palette
	default_bg = p_default_bg
	default_fg = p_default_fg
	default_attrs = p_default_attrs
	cell_size = FontManager.get_text_size("W", 0)
	ansi_decoder = AnsiDecoder.new()
	caret = Caret.new(Vector2i.ZERO, true)
	caret.should_blink = blinking
	caret.connect("blinked", mark_caret_dirty)
	caret.connect("position_changed", _update_readable_area_height)
	caret.position = Vector2i.ZERO
	_recalculate_size()

func _recalculate_size() -> void:
	width_in_cells = max(1, rect.size.x / cell_size.x)
	visible_height = max(1, rect.size.y / cell_size.y)
	height_in_cells = max(1, ceil(float(total_cells) / width_in_cells))
	buffer = Buffer.new(width_in_cells, height_in_cells,
						default_fg, default_bg, default_attrs)
	caret.position = Vector2i.ZERO
	current_fg = default_fg
	current_bg = default_bg
	current_attrs = default_attrs
	buffer.current_fg_color = current_fg
	buffer.current_bg_color = current_bg
	buffer.current_attributes = current_attrs
	scroll_offset = 0
	buffer.mark_all_dirty()

func set_rect(new_rect: Rect2i) -> void:
	rect = new_rect
	_recalculate_size()
	
func tick(delta: float) -> void:
	Debug.update_debug_label(str(scroll_offset) + "\n" + str(target_scroll))
	if scroll_offset != target_scroll:
		var diff = target_scroll - scroll_offset
		var duration = max_scroll_duration / abs(diff)
		_scroll_time += delta
		if _scroll_time >= duration:
			var step = max(1, int(_scroll_time / duration))
			scroll_offset += sign(diff) * step
			_scroll_time = 0.0
	elif _scroll_time != 0.0:
		_scroll_time = 0.0
	caret.update()

func _update_readable_area_height(position: Vector2i) -> void:
	if position.y > readable_area_height:
		readable_area_height = position.y

func mark_caret_dirty() -> void:
	buffer.mark_dirty(caret.position.y)

func set_total_cells(new_total: int) -> void:
	total_cells = new_total
	_recalculate_size()

func set_scroll_offset(new_offset: int) -> void:
	var max_offset = max(0, min(buffer.height - visible_height, readable_area_height - visible_height + 1))
	var target = clamp(new_offset, 0, max_offset)
	if target == scroll_offset:
		return
	_scroll_time = 0.0
	target_scroll = target

func _mark_visible_dirty() -> void:
	var start_row = scroll_offset
	var end_row = min(scroll_offset + visible_height, buffer.height)
	for row in range(start_row, end_row):
		buffer.mark_dirty(row)

func scroll_up_lines(amount: int = 1) -> void:
	set_scroll_offset(scroll_offset + amount)

func scroll_down_lines(amount: int = 1) -> void:
	set_scroll_offset(scroll_offset - amount)

func scroll_page_up() -> void:
	scroll_up_lines(visible_height)

func scroll_page_down() -> void:
	scroll_down_lines(visible_height)

func ensure_cursor_visible() -> void:
	var cursor_row = caret.position.y
	if cursor_row < scroll_offset:
		set_scroll_offset(cursor_row)
	elif cursor_row >= scroll_offset + visible_height:
		set_scroll_offset(cursor_row - visible_height + 1)

func process_output(text: String) -> void:
	var instructions = ansi_decoder.parse_string(text)
	for instr in instructions:
		apply_instruction(instr)

func apply_instruction(instr: Dictionary) -> void:
	var type = instr.type
	var data = instr.data
	match type:
		AnsiDecoder.InstructionType.PRINT:
			var text = data.char
			for ch in text:
				_handle_char(ch)
		AnsiDecoder.InstructionType.MOVE_ABSOLUTE:
			var x = data.get("x", -1)
			var y = data.get("y", -1)
			if x >= 0:
				x = clamp(x, 0, buffer.width - 1)
			else:
				x = caret.position.x
			if y >= 0:
				y = clamp(y, 0, buffer.height - 1)
			else:
				y = caret.position.y
			caret.position = Vector2i(x, y)
		AnsiDecoder.InstructionType.MOVE_RELATIVE:
			var dx = data.get("dx", 0)
			var dy = data.get("dy", 0)
			var reset_x = data.get("reset_x", false)
			var new_x = caret.position.x + dx
			var new_y = caret.position.y + dy
			if reset_x:
				new_x = 0
			_move_caret_relative(new_x, new_y)
		AnsiDecoder.InstructionType.SET_STYLE:
			if data.has("fg"):
				if data.fg == -1:
					current_fg = default_fg
					buffer.current_fg_color = default_fg
				else:
					buffer.current_fg_color = data.fg
			if data.has("bg"):
				if data.bg == -1:
					current_bg = default_bg
					buffer.current_bg_color = default_bg
				else:
					buffer.current_bg_color = data.bg
			var attr_int = 0
			for key in data.keys():
				if key in ["fg", "bg"]:
					continue
				if data[key]:
					match key:
						"bold": attr_int |= Buffer.ATTR_BOLD
						"italic": attr_int |= Buffer.ATTR_ITALIC
						"underline": attr_int |= Buffer.ATTR_UNDERLINE
						"blink": attr_int |= Buffer.ATTR_BLINK
						"reverse": attr_int |= Buffer.ATTR_REVERSE
						"invisible": attr_int |= Buffer.ATTR_INVISIBLE
						"strikethrough": attr_int |= Buffer.ATTR_STRIKETHROUGH
			buffer.current_attributes = attr_int
		AnsiDecoder.InstructionType.CLEAR_SCREEN:
			buffer.current_bg_color = default_bg
			buffer.current_fg_color = default_fg
			buffer.current_attributes = default_attrs
			buffer.clear()
			buffer.mark_all_dirty()
			readable_area_height = 0
			scroll_offset = 0
			target_scroll = 0
			caret.position = Vector2i.ZERO
		AnsiDecoder.InstructionType.CLEAR_LINE:
			var mode = data.mode
			var row = caret.position.y
			var col = caret.position.x
			match mode:
				0:
					for x in range(col, buffer.width):
						buffer.update_cell(row, x, " ", buffer.current_bg_color, buffer.current_fg_color, buffer.current_attributes)
				1:
					for x in range(0, col + 1):
						buffer.update_cell(row, x, " ", buffer.current_bg_color, buffer.current_fg_color, buffer.current_attributes)
				2:
					for x in range(0, buffer.width):
						buffer.update_cell(row, x, " ", buffer.current_bg_color, buffer.current_fg_color, buffer.current_attributes)
			buffer.mark_dirty(row)
		_:
			pass

func _move_caret_relative(new_x: int, new_y: int) -> void:
	while new_x < 0:
		new_x += buffer.width
		new_y -= 1
	while new_x >= buffer.width:
		new_x -= buffer.width
		new_y += 1
	while new_y < 0:
		new_y = 0
	while new_y >= buffer.height:
		_scroll_up_buffer()
		new_y -= 1
	caret.position = Vector2i(clamp(new_x, 0, buffer.width - 1), clamp(new_y, 0, buffer.height - 1))

func _scroll_up_buffer() -> void:
	buffer.scroll_up()
	if scroll_offset + visible_height >= buffer.height:
		scroll_offset = max(0, buffer.height - visible_height)
		target_scroll = scroll_offset
	_mark_visible_dirty()

func _handle_char(ch: String) -> void:
	var pos = caret.position
	buffer.update_cell(pos.y, pos.x, ch, buffer.current_bg_color, buffer.current_fg_color, buffer.current_attributes)
	buffer.mark_dirty(pos.y)
	_advance_caret()

func _advance_caret() -> void:
	caret.position.x += 1
	if caret.position.x >= buffer.width:
		caret.position.x = 0
		caret.position.y += 1
	if caret.position.y >= buffer.height:
		_scroll_up_buffer()
		caret.position.y = buffer.height - 1
	else:
		if caret.position.y >= scroll_offset + visible_height:
			scroll_offset = caret.position.y - visible_height + 1
			if scroll_offset < 0:
				scroll_offset = 0
			target_scroll = scroll_offset
			_mark_visible_dirty()

func render_to_stream(stream: Stream) -> void:
	var offset = rect.position
	var any_dirty = false
	var start_row = scroll_offset
	var end_row = min(scroll_offset + visible_height, buffer.height)
	for row in range(start_row, end_row):
		if buffer.dirty_rows[row]:
			any_dirty = true
			break
	if not any_dirty:
		return
	var mid = int(cell_size.y / 2)
	for row in range(start_row, end_row):
		if not buffer.dirty_rows[row]:
			continue
		var groups = _group_cells_in_row(row)
		for group in groups:
			var x = (group.start_col * cell_size.x) + offset.x
			var y = ((row - scroll_offset) * cell_size.y) + offset.y
			var text = group.text
			var fg_color = palette.get_color(default_bg)
			var bg_color = palette.get_color(default_bg)
			if not group.attrs & Buffer.ATTR_INVISIBLE:
				if group.attrs & Buffer.ATTR_REVERSE:
					fg_color = palette.get_color(group.bg)
					bg_color = palette.get_color(group.fg)
				else:
					fg_color = palette.get_color(group.fg)
					bg_color = palette.get_color(group.bg)
			stream.push({
				"type": "draw_text",
				"text": text,
				"position": Vector2(x, y),
				"fg_color": fg_color,
				"bg_color": bg_color,
				"font_size": 0
			})
			if group.attrs & Buffer.ATTR_UNDERLINE:
				stream.push({
				"type": "draw_line",
				"from": Vector2(x, y + cell_size.y - 1),
				"to": Vector2(x + text.length() * cell_size.x - 1, y + cell_size.y - 1),
				"color": fg_color
			})
			if group.attrs & Buffer.ATTR_STRIKETHROUGH:
				stream.push({
				"type": "draw_line",
				"from": Vector2(x, y + mid),
				"to": Vector2(x + text.length() * cell_size.x - 1, y + mid),
				"color": fg_color
			})
		buffer.dirty_rows[row] = false
	if caret.render():
		var pos = caret.position
		if pos.y >= scroll_offset and pos.y < scroll_offset + visible_height:
			var code = buffer.get_symbol(pos.y, pos.x)
			var fg = buffer.get_fg(pos.y, pos.x)
			var bg = buffer.get_bg(pos.y, pos.x)
			var attrs = buffer.get_attrs(pos.y, pos.x)
			var ch = String.chr(code) if code > 0 else " "
			if attrs & Buffer.ATTR_INVISIBLE:
				ch = " "
			var fg_color = Color()
			var bg_color = Color()
			if attrs & Buffer.ATTR_REVERSE:
				fg_color = palette.get_color(fg)
				bg_color = palette.get_color(bg)
			else:
				fg_color = palette.get_color(bg)
				bg_color = palette.get_color(fg)
			var x = pos.x * cell_size.x + offset.x
			var y = (pos.y - scroll_offset) * cell_size.y + offset.y
			stream.push({
				"type": "draw_text",
				"text": ch,
				"position": Vector2(x, y),
				"fg_color": fg_color,
				"bg_color": bg_color,
				"font_size": 0
			})
			if attrs & Buffer.ATTR_UNDERLINE and not attrs & Buffer.ATTR_INVISIBLE:
				stream.push({
				"type": "draw_line",
				"from": Vector2(x, y + cell_size.y - 1),
				"to": Vector2(x + cell_size.x - 1, y + cell_size.y - 1),
				"color": fg_color
			})
			if attrs & Buffer.ATTR_STRIKETHROUGH and not attrs & Buffer.ATTR_INVISIBLE:
				stream.push({
				"type": "draw_line",
				"from": Vector2(x, y + mid),
				"to": Vector2(x + cell_size.x - 1, y + mid),
				"color": fg_color
			})

func _group_cells_in_row(row: int) -> Array:
	var groups = []
	var current_group = null
	for col in range(buffer.width):
		var sym = buffer.get_symbol(row, col)
		var fg = buffer.get_fg(row, col)
		var bg = buffer.get_bg(row, col)
		var attr = buffer.get_attrs(row, col)
		var key = { "fg": fg, "bg": bg, "attrs": attr }
		if current_group == null or current_group.key != key:
			if current_group != null:
				groups.append(current_group)
			current_group = {
				"key": key,
				"start_col": col,
				"text": "",
				"fg": fg,
				"bg": bg,
				"attrs": attr
			}
		current_group.text += String.chr(sym) if sym > 0 else " "
	if current_group != null:
		groups.append(current_group)
	return groups

func shutdown() -> void:
	if caret.is_connected("blinked", mark_caret_dirty):
		caret.disconnect("blinked", mark_caret_dirty)
	if caret.is_connected("position_changed", _update_readable_area_height):
		caret.disconnect("position_changed", _update_readable_area_height)
