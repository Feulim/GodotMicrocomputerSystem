extends TextureRect
class_name Screen

@export var resolution: Vector2 = Vector2(64, 64)

var image: Image
var dirty: bool = false

func _ready():
	image = Image.create(int(resolution.x), int(resolution.y), false, Image.FORMAT_RGBA8)
	image.fill(Color.BLACK)
	texture = ImageTexture.create_from_image(image)
	texture_filter = TextureFilter.TEXTURE_FILTER_NEAREST
	size_flags_horizontal = Control.SIZE_EXPAND | Control.SIZE_FILL
	size_flags_vertical = Control.SIZE_EXPAND | Control.SIZE_FILL

func apply_texture() -> void:
	if texture:
		texture.update(image)
	dirty = false

func clear(color: Color = Color.BLACK) -> void:
	image.fill(color)
	dirty = true

func set_pixel(x: int, y: int, color: Color) -> void:
	if x >= 0 and x < image.get_width() and y >= 0 and y < image.get_height():
		image.set_pixel(x, y, color)
		dirty = true

func get_pixel(x: int, y: int) -> Color:
	if x >= 0 and x < image.get_width() and y >= 0 and y < image.get_height():
		return image.get_pixel(x, y)
	return Color.BLACK

func _get_size() -> Vector2:
	return resolution
