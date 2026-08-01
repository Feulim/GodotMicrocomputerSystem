extends RefCounted
class_name Caret

var _blink: bool = true
var _blink_timer: int = 0

var blink_time: int = 40:
	set(value):
		if blink_time != value:
			blink_time = value

var should_blink: bool = true:
	set(value):
		if should_blink != value:
			should_blink = value

var position: Vector2i = Vector2i.ZERO:
	set(value):
		if position != value:
			position = value
			position_changed.emit(position)

var saved_position: Vector2i = Vector2i.ZERO

var visible: bool = true:
	set(value):
		if visible != value:
			visible = value
			visibility_changed.emit(visible)

signal position_changed(new_position: Vector2i)
signal visibility_changed(new_visible: bool)
signal blinked()

func _init(initial_position: Vector2i = Vector2i.ZERO, initial_visible: bool = true) -> void:
	position = initial_position
	saved_position = initial_position
	visible = initial_visible

func update():
	if not should_blink:
		return
	if _blink_timer >= blink_time:
		_blink = not _blink
		_blink_timer = 0
		blinked.emit()
	_blink_timer += 1

func set_position(new_pos: Vector2i) -> void:
	position = new_pos

func get_position() -> Vector2i:
	return position

func save_position() -> void:
	saved_position = position

func restore_position() -> void:
	position = saved_position

func show() -> void:
	visible = true

func hide() -> void:
	visible = false

func toggle_visibility() -> void:
	visible = not visible

func move_by(delta: Vector2i) -> void:
	position += delta

func set_and_save(new_pos: Vector2i) -> void:
	set_position(new_pos)
	save_position()

func render() -> bool:
	if should_blink:
		return visible and _blink
	else:
		return visible
