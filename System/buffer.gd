extends RefCounted
class_name Buffer

const MODE_OVERWRITE = 0
const MODE_INSERT = 1

const ATTR_BOLD          = 1 << 0
const ATTR_ITALIC        = 1 << 1
const ATTR_UNDERLINE     = 1 << 2
const ATTR_BLINK         = 1 << 3
const ATTR_REVERSE       = 1 << 4
const ATTR_INVISIBLE     = 1 << 5
const ATTR_STRIKETHROUGH = 1 << 6

var width: int
var height: int

var symbols: PackedInt32Array
var fg_colors: PackedInt32Array
var bg_colors: PackedInt32Array
var attrs: PackedInt32Array

var dirty_rows: Array[bool]

var current_fg_color: int
var current_bg_color: int
var current_attributes: int

var _row_offset: int = 0

func _init(p_width: int, p_height: int,
		   p_fg_color: int = 0,
		   p_bg_color: int = 0,
		   p_attributes: int = 0) -> void:
	width = p_width
	height = p_height
	current_fg_color = p_fg_color
	current_bg_color = p_bg_color
	current_attributes = p_attributes

	var total = width * height
	symbols.resize(total)
	fg_colors.resize(total)
	bg_colors.resize(total)
	attrs.resize(total)
	for i in range(total):
		symbols[i] = 32
		fg_colors[i] = current_fg_color
		bg_colors[i] = current_bg_color
		attrs[i] = current_attributes

	dirty_rows.resize(height)
	mark_all_dirty()

func _get_physical_index(row: int, col: int) -> int:
	var phys_row = (row + _row_offset) % height
	return phys_row * width + col

func get_symbol(row: int, col: int) -> int:
	var idx = _get_physical_index(row, col)
	if idx < 0 or idx >= symbols.size():
		return 32
	return symbols[idx]

func get_fg(row: int, col: int) -> int:
	var idx = _get_physical_index(row, col)
	if idx < 0 or idx >= symbols.size():
		return 0
	return fg_colors[idx]

func get_bg(row: int, col: int) -> int:
	var idx = _get_physical_index(row, col)
	if idx < 0 or idx >= symbols.size():
		return 0
	return bg_colors[idx]

func get_attrs(row: int, col: int) -> int:
	var idx = _get_physical_index(row, col)
	if idx < 0 or idx >= symbols.size():
		return 0
	return attrs[idx]

func set_cell(row: int, col: int, symbol: int, fg: int, bg: int, attr: int) -> void:
	var idx = _get_physical_index(row, col)
	if idx < 0 or idx >= symbols.size():
		return
	symbols[idx] = symbol
	fg_colors[idx] = fg
	bg_colors[idx] = bg
	attrs[idx] = attr
	mark_dirty(row)

func update_cell(row: int, col: int, _char: String, bg_color: int, fg_color: int, attr: Variant = 0) -> void:
	var code = _char.unicode_at(0) if _char.length() > 0 else 32
	var attr_int = _to_attr_int(attr)
	set_cell(row, col, code, fg_color, bg_color, attr_int)

func clear() -> void:
	for i in range(symbols.size()):
		symbols[i] = 32
		fg_colors[i] = current_fg_color
		bg_colors[i] = current_bg_color
		attrs[i] = current_attributes
	mark_all_dirty()

func restore_from_data(data: Dictionary) -> void:
	if data.has("symbols") and data.symbols.size() == symbols.size():
		symbols = data.symbols.duplicate()
		fg_colors = data.fg.duplicate()
		bg_colors = data.bg.duplicate()
		attrs = data.attrs.duplicate()
		_row_offset = 0
		mark_all_dirty()
	else:
		push_warning("Buffer.restore_from_data: The data size does not match the current buffer.")

func write(text: String, row: int, col: int, mode: int = MODE_OVERWRITE) -> void:
	var r = row
	var c = col
	var touched_rows = []
	for ch in text:
		if ch == '\n':
			r += 1
			c = 0
			continue
		if c >= width:
			r += 1
			c = 0
		if r >= height:
			break
		var idx = _get_physical_index(r, c)
		if mode == MODE_OVERWRITE:
			symbols[idx] = ch.unicode_at(0)
			fg_colors[idx] = current_fg_color
			bg_colors[idx] = current_bg_color
			attrs[idx] = current_attributes
		else:
			symbols[idx] = ch.unicode_at(0)
			fg_colors[idx] = current_fg_color
			bg_colors[idx] = current_bg_color
			attrs[idx] = current_attributes
		if r not in touched_rows:
			touched_rows.append(r)
		c += 1
	for row_index in touched_rows:
		mark_dirty(row_index)

func delete(row: int, col: int, _mode: int = MODE_OVERWRITE) -> void:
	var idx = _get_physical_index(row, col)
	if idx < 0 or idx >= symbols.size():
		return
	symbols[idx] = 32
	fg_colors[idx] = current_fg_color
	bg_colors[idx] = current_bg_color
	attrs[idx] = current_attributes
	mark_dirty(row)

func get_line(row: int) -> String:
	var start = _get_physical_index(row, 0)
	var end = start + width
	if start >= symbols.size():
		return ""
	if end > symbols.size():
		end = symbols.size()
	var chars = []
	for i in range(start, end):
		chars.append(String.chr(symbols[i]))
	return "".join(chars)

func get_text() -> String:
	var lines = []
	var total_rows = ceil(symbols.size() / float(width))
	for r in range(total_rows):
		lines.append(get_line(r))
	return "\n".join(lines)

func get_row_data(row: int) -> Dictionary:
	var start = _get_physical_index(row, 0)
	var end = start + width
	return {
		"symbols": symbols.slice(start, end),
		"fg": fg_colors.slice(start, end),
		"bg": bg_colors.slice(start, end),
		"attrs": attrs.slice(start, end)
	}

func set_row_data(row: int, data: Dictionary) -> void:
	var start = _get_physical_index(row, 0)
	for i in range(data.symbols.size()):
		symbols[start + i] = data.symbols[i]
		fg_colors[start + i] = data.fg[i]
		bg_colors[start + i] = data.bg[i]
		attrs[start + i] = data.attrs[i]
	mark_dirty(row)

func mark_dirty(row: int) -> void:
	if row >= 0 and row < dirty_rows.size():
		dirty_rows[row] = true

func mark_all_dirty() -> void:
	for i in range(dirty_rows.size()):
		dirty_rows[i] = true

func reset_dirty() -> void:
	for i in range(dirty_rows.size()):
		dirty_rows[i] = false

func scroll_up() -> void:
	_row_offset = (_row_offset + 1) % height
	
	var last_phys_row = (_row_offset + height - 1) % height
	var start = last_phys_row * width
	var end = start + width
	for i in range(start, end):
		symbols[i] = 32
		fg_colors[i] = current_fg_color
		bg_colors[i] = current_bg_color
		attrs[i] = current_attributes
		
	mark_dirty(height - 1)

func _to_attr_int(attr: Variant) -> int:
	if typeof(attr) == TYPE_INT:
		return attr
	elif typeof(attr) == TYPE_DICTIONARY:
		var res = 0
		if attr.get("bold", false):    res |= ATTR_BOLD
		if attr.get("italic", false):  res |= ATTR_ITALIC
		if attr.get("underline", false): res |= ATTR_UNDERLINE
		if attr.get("blink", false):   res |= ATTR_BLINK
		if attr.get("reverse", false): res |= ATTR_REVERSE
		if attr.get("invisible", false): res |= ATTR_INVISIBLE
		if attr.get("strikethrough", false): res |= ATTR_STRIKETHROUGH
		return res
	return 0
