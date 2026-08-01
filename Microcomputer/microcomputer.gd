extends Node
class_name Microcomputer

@export var screen: Screen
@export var system: System
@export var disks: Array[VirtualDisk] = []
@export var output_resolution: Vector2 = Vector2(64, 64)

var _front_buffer: Image = null
var _back_buffer: Image = null
var _dirty: bool = false


func _ready():
	_create_buffers()
	
	if system:
		for disk in disks:
			system.add_disk(disk)
		system.boot(self)

func _create_buffers() -> void:
	var size = Vector2i(int(output_resolution.x), int(output_resolution.y))
	_front_buffer = Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	_back_buffer = Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	_front_buffer.fill(Color.BLACK)
	_back_buffer.fill(Color.BLACK)
	_dirty = false
	_update_monitor()

func _update_monitor() -> void:
	if not screen:
		return
	var screen_img = screen.image
	var offset = (Vector2(screen_img.get_width(), screen_img.get_height()) - output_resolution) / 2.0
	screen_img.blit_rect(
		_front_buffer,
		Rect2i(0, 0, int(output_resolution.x), int(output_resolution.y)),
		Vector2i(offset.x, offset.y)
	)
	screen.apply_texture()

func present() -> void:
	if not _dirty:
		return
	var tmp = _front_buffer
	_front_buffer = _back_buffer
	_back_buffer = tmp
	_dirty = false
	_update_monitor()
	
# TODO: add it to 3D version
func copy_front_to_back() -> void:
	if not _front_buffer or not _back_buffer:
		return
	_back_buffer.blit_rect(
		_front_buffer,
		Rect2i(0, 0, _front_buffer.get_width(), _front_buffer.get_height()),
		Vector2i.ZERO
	)
	_dirty = true

func clear() -> void:
	if _back_buffer:
		_back_buffer.fill(Color.BLACK)
		_dirty = true

func set_pixel(x: int, y: int, color: Color) -> void:
	if not _back_buffer:
		return
	if x < 0 or x >= output_resolution.x or y < 0 or y >= output_resolution.y:
		return
	_back_buffer.set_pixel(x, y, color)
	_dirty = true

func set_pixel_vec(to: Vector2, color: Color) -> void:
	set_pixel(int(to.x), int(to.y), color)

func draw_line(x1: int, y1: int, x2: int, y2: int, color: Color) -> void:
	if not _back_buffer:
		return
	var dx = abs(x2 - x1)
	var dy = abs(y2 - y1)
	var sx = 1 if x1 < x2 else -1
	var sy = 1 if y1 < y2 else -1
	var err = dx - dy
	var x = x1
	var y = y1
	while true:
		if x >= 0 and x < output_resolution.x and y >= 0 and y < output_resolution.y:
			_back_buffer.set_pixel(x, y, color)
		if x == x2 and y == y2:
			break
		var e2 = 2 * err
		if e2 > -dy:
			err -= dy
			x += sx
		if e2 < dx:
			err += dx
			y += sy
	_dirty = true

func draw_line_vec(from: Vector2, to: Vector2, color: Color) -> void:
	draw_line(int(from.x), int(from.y), int(to.x), int(to.y), color)

func draw_rect(x1: int, y1: int, x2: int, y2: int, color: Color) -> void:
	if not _back_buffer:
		return
	var min_x = max(min(x1, x2), 0)
	var max_x = min(max(x1, x2), int(output_resolution.x) - 1)
	var min_y = max(min(y1, y2), 0)
	var max_y = min(max(y1, y2), int(output_resolution.y) - 1)
	for x in range(min_x, max_x + 1):
		for y in range(min_y, max_y + 1):
			_back_buffer.set_pixel(x, y, color)
	_dirty = true

func draw_rect_vec(from: Vector2, to: Vector2, color: Color) -> void:
	draw_rect(int(from.x), int(from.y), int(to.x), int(to.y), color)

func get_pixel(x: int, y: int) -> Color:
	if not _front_buffer:
		return Color.BLACK
	if x < 0 or x >= output_resolution.x or y < 0 or y >= output_resolution.y:
		return Color.BLACK
	return _front_buffer.get_pixel(x, y)

func get_size() -> Vector2:
	return output_resolution

func draw_text(
	text: String,
	_position: Vector2,
	fg_color: Color = Color.WHITE,
	bg_color: Color = Color.BLACK,
	font_size: int = 0
) -> void:
	if not _back_buffer:
		return

	var text_size = FontManager.get_text_size(text, font_size)
	if text_size.x < 0:
		text_size.x = 0
	if text_size.y < 0:
		text_size.y = 0
	var text_rect = Rect2i(
		int(_position.x),
		int(_position.y),
		text_size.x,
		text_size.y
	)
	var clip_rect = text_rect.intersection(Rect2i(0, 0, int(output_resolution.x), int(output_resolution.y)))
	if clip_rect.size.x <= 0 or clip_rect.size.y <= 0:
		return

	_back_buffer.fill_rect(clip_rect, bg_color)

	FontManager.draw_text_on_image(_back_buffer, text, _position, fg_color, font_size)

	_dirty = true

func _input(event: InputEvent):
	if event is InputEventKey and system:
		system.input_key(event)

func add_disk(disk: VirtualDisk) -> void:
	if system:
		system.add_disk(disk)
	disks.append(disk)

func remove_disk(disk_id: String) -> bool:
	if system:
		return system.remove_disk(disk_id)
	return false
