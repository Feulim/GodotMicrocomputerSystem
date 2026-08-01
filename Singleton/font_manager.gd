extends Node

@warning_ignore_start("integer_division")

#region Exports
@export var font_path: String = "res://10.BKF"
#endregion

#region Private Variables
var _font: FontFile = null
var _font_size: int = 0
var _atlas_image: Image = null
var _glyph_map: Dictionary = {}

const DEFAULT_CHARS = (
	' !"#¤%&\'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]¬_`' +
	'abcdefghijklmnopqrstuvwxyz{|}¯█π┴♥┐╡├└═╤♠┌┬╨↓┼║┤←╬↑♣─╫│♦┘╪╥╧╞→▒' +
	'юабцдефгхийклмнопярстужвьызшэщчъЮАБЦДЕФГХИЙКЛМНОПЯРСТУЖВЬЫЗШЭЩЧЪ'
)
#endregion

#region Initialization
func _ready():
	load_font(font_path)
#endregion

#region Font Loading
func load_font(path: String) -> bool:
	if not FileAccess.file_exists(path):
		push_error("Font file not found: ", path)
		return false

	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Failed to open font: ", path)
		return false

	var signature = file.get_buffer(4)
	var glyphs = []

	if signature == "BKF2".to_utf8_buffer():
		var count = file.get_16()
		var common_height = file.get_8()
		var codes = []
		for i in range(count):
			codes.append(file.get_16())
		for code in codes:
			var width = file.get_8()
			var bitmap_size = (width * common_height + 7) / 8
			var bitmap = file.get_buffer(bitmap_size)
			glyphs.append({
				"code": code,
				"width": width,
				"height": common_height,
				"bitmap": bitmap
			})
	else:
		file.seek(0)
		var data = file.get_buffer(file.get_length())
		if data.size() % 10 != 0:
			push_error("Old BKF file size is not multiple of 10")
			return false
		var num_chars = data.size() / 10
		for i in range(num_chars):
			var raw = data.slice(i * 10, i * 10 + 10)
			var reversed_bytes = PackedByteArray()
			for b in raw:
				reversed_bytes.append(_reverse_byte(b))
			var code = 0
			if i < DEFAULT_CHARS.length():
				code = ord(DEFAULT_CHARS[i])
			else:
				push_warning("Glyph index ", i, " exceeds DEFAULT_CHARS length, code set to 0")
			glyphs.append({
				"code": code,
				"width": 8,
				"height": 10,
				"bitmap": reversed_bytes
			})

	file.close()

	if glyphs.is_empty():
		push_error("No glyphs loaded")
		return false

	var result = _create_font_from_glyphs(glyphs)
	_font = result[0]
	_font_size = result[1]
	_atlas_image = result[2]
	_glyph_map = result[3]
	return _font != null
#endregion

#region Glyph Helpers
func _reverse_byte(b: int) -> int:
	b = ((b >> 1) & 0x55) | ((b & 0x55) << 1)
	b = ((b >> 2) & 0x33) | ((b & 0x33) << 2)
	b = ((b >> 4) & 0x0F) | ((b & 0x0F) << 4)
	return b

func _unpack_bitmap_to_bytes(bitmap: PackedByteArray, width: int, height: int) -> PackedByteArray:
	var result = PackedByteArray()
	result.resize(width * height)
	var bytes_per_row = (width + 7) / 8
	for y in range(height):
		for x in range(width):
			var byte_idx = y * bytes_per_row + x / 8
			var bit_idx = 7 - (x % 8)
			var bit = (bitmap[byte_idx] >> bit_idx) & 1
			result[y * width + x] = 255 if bit == 1 else 0
	return result

func _create_font_from_glyphs(glyphs: Array) -> Array:
	var atlas_size = 512
	var atlas_image = Image.create(atlas_size, atlas_size, false, Image.FORMAT_L8)
	atlas_image.fill(0)

	var current_x = 0
	var current_y = 0
	var row_height = 0
	var font_size = 0
	for glyph in glyphs:
		font_size = max(font_size, glyph["height"])

	var glyph_infos = []

	for glyph in glyphs:
		var w = glyph["width"]
		var h = glyph["height"]
		var bmp = glyph["bitmap"]

		if current_x + w > atlas_size:
			current_x = 0
			current_y += row_height
			row_height = 0
		row_height = max(row_height, h)

		var pixel_data = _unpack_bitmap_to_bytes(bmp, w, h)
		var glyph_image = Image.create_from_data(w, h, false, Image.FORMAT_L8, pixel_data)
		atlas_image.blit_rect(glyph_image, Rect2i(0, 0, w, h), Vector2i(current_x, current_y))

		glyph_infos.append({
			"code": glyph["code"],
			"x": current_x,
			"y": current_y,
			"width": w,
			"height": h,
			"advance": w
		})

		current_x += w

	var font = FontFile.new()
	font.antialiasing = false

	font.set_texture_image(0, Vector2i(font_size, font_size), 0, atlas_image)

	var cache_index = 0
	var size_vec = Vector2i(font_size, font_size)
	var size_int = font_size

	var glyph_map = {}
	for info in glyph_infos:
		var code = info["code"]
		var x = info["x"]
		var y = info["y"]
		var w = info["width"]
		var h = info["height"]
		var advance = info["advance"]

		var uv_rect = Rect2(
			float(x) / atlas_size,
			float(y) / atlas_size,
			float(w) / atlas_size,
			float(h) / atlas_size
		)

		font.set_glyph_size(cache_index, size_vec, code, Vector2(w, h))
		font.set_glyph_uv_rect(cache_index, size_vec, code, uv_rect)
		font.set_glyph_offset(cache_index, size_vec, code, Vector2(0, 0))
		font.set_glyph_advance(cache_index, size_int, code, Vector2(advance, 0))

		glyph_map[code] = {
			"x": x,
			"y": y,
			"width": w,
			"height": h,
			"advance": advance
		}

	return [font, font_size, atlas_image, glyph_map]
#endregion

#region Accessors
func get_font() -> FontFile:
	return _font
#endregion

#region Text Utilities
func get_text_size(text: String, spacing: int = 1) -> Vector2:
	if _glyph_map.is_empty():
		return Vector2.ZERO
	var total_width = 0
	var max_height = 0
	for ch in text:
		var code = ord(ch)
		if _glyph_map.has(code):
			var info = _glyph_map[code]
			total_width += info["width"] + spacing
			max_height = max(max_height, info["height"])
		else:
			total_width += spacing
	if total_width > 0:
		total_width -= spacing
	return Vector2(total_width, max_height)

func draw_text_on_image(image: Image, text: String, pos: Vector2, color: Color, spacing: int = 1) -> void:
	if _atlas_image == null or _glyph_map.is_empty():
		return

	var x = pos.x
	var y = pos.y

	for ch in text:
		var code = ord(ch)
		if _glyph_map.has(code):
			var info = _glyph_map[code]
			var gw = info["width"]
			var gh = info["height"]
			var gx = info["x"]
			var gy = info["y"]

			for row in range(gh):
				for col in range(gw):
					var atlas_pixel = _atlas_image.get_pixel(gx + col, gy + row).r
					if atlas_pixel > 0.5:
						var px = int(x + col)
						var py = int(y + row)
						if px >= 0 and px < image.get_width() and py >= 0 and py < image.get_height():
							image.set_pixel(px, py, color)

			x += info["width"] + spacing
		else:
			x += spacing
#endregion
