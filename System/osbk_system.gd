extends System
class_name OSBK

var ESC = String.chr(27)

var margin: int = 1
var header_margin: int = 6
var history_pages: int = 8

var terminal_rect: Rect2i = Rect2i(0, 0, 1, 1)
var terminal_capacity: int = 1
var terminal_cell_width: int = 1

var accent_color_index: int = 15
var subaccent_color_index: int = 8
var contrast_color_index: int = 0

var buffer_key_input: Stream = Stream.new()
var buffer_key_output: Stream = Stream.new()
var buffer_key_exception: Stream = Stream.new()
var buffer_render_command: Stream = Stream.new()

var renderer: Renderer = null
var input_handler: InputHandler = null
var terminal: Terminal = null
var palette: IndexedPalette = null

var _current_lang_index: int = -1

var ansi_string = (
	ESC + "[0m" +
	"\nОбычные цвета (текст):\n" +
	ESC + "[30m" + "Черный" + ESC + "[0m " +
	ESC + "[31m" + "Красный" + ESC + "[0m " +
	ESC + "[32m" + "Зеленый" + ESC + "[0m " +
	ESC + "[33m" + "Желтый" + ESC + "[0m " +
	ESC + "[34m" + "Синий" + ESC + "[0m " +
	ESC + "[35m" + "Пурпурный" + ESC + "[0m " +
	ESC + "[36m" + "Бирюзовый" + ESC + "[0m " +
	ESC + "[37m" + "Белый" + ESC + "[0m " +
	"\nЯркие цвета (текст):\n" +
	ESC + "[90m" + "Серый" + ESC + "[0m " +
	ESC + "[91m" + "Ярко-красный" + ESC + "[0m " +
	ESC + "[92m" + "Ярко-зеленый" + ESC + "[0m " +
	ESC + "[93m" + "Ярко-желтый" + ESC + "[0m " +
	ESC + "[94m" + "Ярко-синий" + ESC + "[0m " +
	ESC + "[95m" + "Ярко-пурпурный" + ESC + "[0m " +
	ESC + "[96m" + "Ярко-бирюзовый" + ESC + "[0m " +
	ESC + "[97m" + "Ярко-белый" + ESC + "[0m " +
	"\nФоновые цвета:\n" +
	ESC + "[40m" + "Фон черный" + ESC + "[0m " +
	ESC + "[41m" + "Фон красный" + ESC + "[0m " +
	ESC + "[42m" + "Фон зеленый" + ESC + "[0m " +
	ESC + "[43m" + "Фон желтый" + ESC + "[0m " +
	ESC + "[44m" + "Фон синий" + ESC + "[0m " +
	ESC + "[45m" + "Фон пурпурный" + ESC + "[0m " +
	ESC + "[46m" + "Фон бирюзовый" + ESC + "[0m " +
	ESC + "[47m" + "Фон белый" + ESC + "[0m " +
	"\nЯркие фоны:\n" +
	ESC + "[100m" + "Фон серый" + ESC + "[0m " +
	ESC + "[101m" + "Фон ярко-красный" + ESC + "[0m " +
	ESC + "[102m" + "Фон ярко-зеленый" + ESC + "[0m " +
	ESC + "[103m" + "Фон ярко-желтый" + ESC + "[0m " +
	ESC + "[104m" + "Фон ярко-синий" + ESC + "[0m " +
	ESC + "[105m" + "Фон ярко-пурпурный" + ESC + "[0m " +
	ESC + "[106m" + "Фон ярко-бирюзовый" + ESC + "[0m " +
	ESC + "[107m" + "Фон ярко-белый" + ESC + "[0m " +
	"\nАтрибуты:\n" +
	ESC + "[4m" + "Подчеркнутый текст" + ESC + "[0m\n" +
	ESC + "[9m" + "Зачеркнутый текст" + ESC + "[0m\n" +
	ESC + "[7m" + "Инвертированный текст" + ESC + "[0m\n" +
	ESC + "[8m" + "Невидимый текст" + ESC + "[0m (после сброса видно)" +
	ESC + "[0m\n"
)

func boot(_computer: Microcomputer) -> void:
	super.boot(_computer)
	renderer = Renderer.new()
	renderer.initialize(_computer, buffer_render_command)
	
	palette = IndexedPalette.new([
		Color(0.0, 0.0, 0.0, 1.0),
		Color(0.548, 0.176, 0.091, 1.0),
		Color(0.255, 0.379, 0.145, 1.0),
		Color(0.448, 0.32, 0.113, 1.0),
		Color(0.052, 0.318, 0.628, 1.0),
		Color(0.418, 0.218, 0.56, 1.0),
		Color(0.145, 0.379, 0.323, 1.0),
		Color(0.607, 0.607, 0.607, 1.0),
		Color(0.304, 0.304, 0.304, 1.0),
		Color(1.0, 0.416, 0.43, 1.0),
		Color(0.586, 0.781, 0.348, 1.0),
		Color(0.871, 0.781, 0.325, 1.0),
		Color(0.359, 0.62, 0.769, 1.0),
		Color(0.72, 0.547, 0.908, 1.0),
		Color(0.342, 0.67, 0.554, 1.0),
		Color(1.0, 1.0, 1.0, 1.0)
	])
	
	input_handler = InputHandler.new(buffer_key_input)
	input_handler.set_hold(true)
	input_handler.finish_keycode = KEY_ENTER
	
	draw_frame()
	
	terminal = Terminal.new(
		terminal_rect,
		terminal_capacity,
		palette,
		input_handler,
		buffer_render_command,
		buffer_key_output,
		buffer_key_exception,
		buffer_key_input,
		contrast_color_index, accent_color_index, 0
	)
	terminal.connect("scrolled", draw_scrollbar)
	terminal.command_executor.connect("change_style", _update_style)
	write_output(ESC + "[2J" + ESC + "[H")
	write_output("\n")
	write_output("[00 AT  0.00\n")
	write_output(ESC + "[4m" + "ГОТОВНОСТЬ К РАБОТЕ" + ESC + "[24m" + "\n")
	#write_output(ansi_string)
	write_output("*")
	terminal.request_start()
	draw_scrollbar()

func _update_style(accent: int, subaccent: int, contrast: int) -> void:
	if accent == -1 and subaccent == -1 and contrast == -1:
		return
	if accent != -1:
		accent_color_index = clamp(accent, 0, 15)
	if subaccent != -1:
		subaccent_color_index = clamp(subaccent, 0, 15)
	if contrast != -1:
		contrast_color_index = clamp(contrast, 0, 15)
	draw_frame()
	draw_scrollbar()
	terminal.default_bg = contrast_color_index
	terminal.default_fg = accent_color_index
	write_output(ESC + "[2J" + ESC + "[H")
	redraw_lang_glyph()

func shutdown() -> void:
	if renderer: renderer.shutdown(); renderer = null
	if terminal: terminal.shutdown(); terminal = null
	if input_handler: input_handler.shutdown(); input_handler = null
	palette = null
	buffer_key_input.clear(); buffer_key_input = null
	buffer_key_output.clear(); buffer_key_output = null
	buffer_key_exception.clear(); buffer_key_exception = null
	buffer_render_command.clear(); buffer_render_command = null
	
	super.shutdown()

func input_key(event: InputEventKey) -> void:
	if input_handler:
		input_handler.process_event(event)

func _physics_process(delta: float) -> void:
	ensure_language()
	if terminal: terminal.tick(delta)
	if renderer: renderer.tick()

func draw_glyph(offset: Vector2i, glyph: String, glyph_width: int, accent_color: Color, contrast_color: Color) -> void:
	for x in range(glyph_width):
		for y in range(int(float(glyph.length()) / glyph_width)):
			if glyph[y * glyph_width + x] == '1':
				set_pixel(Vector2(offset) + Vector2(x, y), accent_color)
			else:
				set_pixel(Vector2(offset) + Vector2(x, y), contrast_color)

func redraw_lang_glyph() -> void:
	var accent_color = palette.get_color(accent_color_index)
	var contrast_color = palette.get_color(contrast_color_index)
	var size = Vector2i(computer.get_size())
	var current_lang_name = ""
	if _current_lang_index >= 0:
		current_lang_name = DisplayServer.keyboard_get_layout_language(_current_lang_index)
	var glyph = "0".repeat(OSBKConst.lang_width)
	if OSBKConst.lang_glyphs.has(current_lang_name):
		glyph = OSBKConst.lang_glyphs.get(current_lang_name)
	elif OSBKConst.lang_glyphs.has("def"):
		glyph = OSBKConst.lang_glyphs.get("def")
	draw_glyph(Vector2i(size.x - margin - OSBKConst.lang_width, margin), glyph, OSBKConst.lang_width, accent_color, contrast_color)

func draw_scrollbar() -> void:
	var accent_color = palette.get_color(accent_color_index)
	var subaccent_color = palette.get_color(subaccent_color_index)
	var contrast_color = palette.get_color(contrast_color_index)
	
	var size = Vector2i(computer.get_size())
	
	var scrollbar_height = size.y - 2 * margin - 7 - header_margin
	var scrollbar_start_point = Vector2(size.x - margin - 5, margin + header_margin + 3)
	
	draw_rect(scrollbar_start_point,
			  scrollbar_start_point + Vector2(1, scrollbar_height),
			  subaccent_color)
	if not terminal:
		return
		
	var scrollbar_filled_percent = clamp(terminal.visible_height / float(terminal.readable_area_height), 0.0, 1.0)
	var scrollbar_filled_height = max(1, int(scrollbar_height * scrollbar_filled_percent))

	var max_scroll = max(1, terminal.readable_area_height - terminal.visible_height)
	var scrollbar_offset_percent = terminal.scroll_offset / float(max_scroll)
	var scrollbar_filled_offset = int((scrollbar_height - scrollbar_filled_height) * scrollbar_offset_percent)
	scrollbar_filled_offset = clamp(scrollbar_filled_offset, 0, scrollbar_height - scrollbar_filled_height)
	
	draw_rect(scrollbar_start_point + Vector2(0, scrollbar_filled_offset - 1),
			  scrollbar_start_point + Vector2(1, scrollbar_filled_offset + 1 + scrollbar_filled_height),
			  contrast_color)
	draw_rect(scrollbar_start_point + Vector2(0, scrollbar_filled_offset),
			  scrollbar_start_point + Vector2(1, scrollbar_filled_offset + scrollbar_filled_height),
			  accent_color)

func draw_frame() -> void:
	var accent_color = palette.get_color(accent_color_index)
	var subaccent_color = palette.get_color(subaccent_color_index)
	var contrast_color = palette.get_color(contrast_color_index)
	
	var size = Vector2i(computer.get_size())
	
	draw_rect(Vector2.ZERO, size, contrast_color)
	
	draw_line(Vector2(margin, margin),
			  Vector2(margin, size.y - margin - 2),
			  accent_color)
	draw_line(Vector2(margin, size.y - margin - 1),
			  Vector2(size.x - margin - 1, size.y - margin - 1),
			  accent_color)
	draw_line(Vector2(size.x - margin - 1, margin + header_margin),
			  Vector2(size.x - margin - 1, size.y - margin - 1),
			  accent_color)
	draw_line(Vector2(margin + 1, margin + header_margin),
			  Vector2(size.x - margin - 2, margin + header_margin),
			  accent_color)
	draw_line(Vector2(size.x - margin - 8, margin + header_margin + 1),
			  Vector2(size.x - margin - 8, size.y - margin - 2),
			  accent_color)
	
	draw_glyph(Vector2i(margin + 1, margin), OSBKConst.logo, OSBKConst.logo_width, accent_color, contrast_color)
	
	draw_line(Vector2(margin + 1 + OSBKConst.logo_width, margin),
			  Vector2(size.x - margin - 2 - OSBKConst.lang_space, margin), accent_color)
	draw_line(Vector2(margin + 1 + OSBKConst.logo_width, margin + 2),
			  Vector2(size.x - margin - 3 - OSBKConst.lang_space, margin + 2), accent_color)
	draw_line(Vector2(margin + 1 + OSBKConst.logo_width, margin + 4),
			  Vector2(size.x - margin - 4 - OSBKConst.lang_space, margin + 4), accent_color)
	
	var empty_space_width = size.x - 2 * margin - 10
	var empty_space_height = size.y - 2 * margin - 5 - header_margin
	
	var font_size = Vector2i(FontManager.get_text_size("W", 0))
	
	var terminal_width = empty_space_width - empty_space_width % font_size.x
	var terminal_height = empty_space_height - empty_space_height % font_size.y
	
	var terminal_iternal_offset_x = int(float(empty_space_width - terminal_width) / 2)
	var terminal_iternal_offset_y = int(float(empty_space_height - terminal_height) / 2)
	
	var terminal_offset_point = Vector2i(margin + 1 + terminal_iternal_offset_x,
										 margin + header_margin + 2 + terminal_iternal_offset_y)
	var terminal_size_cell = Vector2i(int(terminal_width / font_size.x), int(terminal_height / font_size.y))
	
	terminal_cell_width = terminal_size_cell.x
	terminal_rect = Rect2i(terminal_offset_point, Vector2i(terminal_width, terminal_height))
	terminal_capacity = terminal_size_cell.x * terminal_size_cell.y * history_pages
	
	for x in range(terminal_size_cell.x + 1):
		set_pixel(Vector2(terminal_offset_point.x + x * font_size.x - 1, margin + header_margin + 1),
		subaccent_color)

func write_output(text: String) -> void:
	buffer_key_output.push(text)

func report_exception(message: String) -> void:
	buffer_key_exception.push(message)

func draw_text(text: String, position: Vector2,
		fg_color: Color = Color.WHITE, bg_color: Color = Color.BLACK,
		font_size: int = 0) -> void:
	buffer_render_command.push({
		"type": "draw_text",
		"text": text,
		"position": position,
		"fg_color": fg_color,
		"bg_color": bg_color,
		"font_size": font_size
	})

func draw_line(from: Vector2, to: Vector2, color: Color = Color.WHITE) -> void:
	buffer_render_command.push({
		"type": "draw_line",
		"from": from,
		"to": to,
		"color": color
	})

func draw_rect(from: Vector2, to: Vector2, color: Color = Color.WHITE) -> void:
	buffer_render_command.push({
		"type": "draw_rect",
		"from": from,
		"to": to,
		"color": color
	})

func set_pixel(position: Vector2, color: Color) -> void:
	buffer_render_command.push({
		"type": "set_pixel",
		"position": position,
		"color": color
	})

func clear_screen() -> void:
	buffer_render_command.push({
		"type": "clear"
	})

func ensure_language() -> void:
	var lang_index = DisplayServer.keyboard_get_current_layout()
	if lang_index == _current_lang_index:
		return
	_current_lang_index = lang_index
	redraw_lang_glyph()
