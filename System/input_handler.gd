extends RefCounted
class_name InputHandler

enum EventType {
	PRESSED,
	RELEASED,
	TEXT
}

enum Modifier {
	SHIFT = 1 << 0,
	CTRL  = 1 << 1,
	ALT   = 1 << 2,
	META  = 1 << 3
}

class KeyData:
	var keycode: int
	var modifiers: int
	func _init(p_keycode: int, p_modifiers: int):
		keycode = p_keycode
		modifiers = p_modifiers

signal text_changed(new_text: String)
signal cursor_moved(new_position: int)
signal insert_mode_changed(insert_mode: bool)
signal input_finished(final_text: String)

var bki: Stream
var hold: bool = false
var finish_keycode: int = KEY_ENTER

var _buffer_text: String = ""
var _cursor_pos: int = 0
var _insert_mode: bool = true

func _init(p_bki: Stream):
	bki = p_bki

func set_hold(enabled: bool) -> void:
	if hold == enabled:
		return
	hold = enabled
	if not hold:
		_buffer_text = ""
		_cursor_pos = 0
		_insert_mode = true

func process_event(event: InputEventKey) -> void:
	var key_data = KeyData.new(event.keycode, _get_modifiers(event))
	if event.pressed:
		bki.push({ "type": EventType.PRESSED, "data": key_data })
	else:
		bki.push({ "type": EventType.RELEASED, "data": key_data })
		return
	if hold:
		_handle_hold_mode(event)
	else:
		var unicode = event.unicode
		if unicode > 0:
			bki.push({ "type": EventType.TEXT, "text": char(unicode) })

func _handle_hold_mode(event: InputEventKey) -> void:
	var keycode = event.keycode
	var unicode = event.unicode
	if keycode == finish_keycode:
		bki.push({ "type": EventType.TEXT, "text": _buffer_text })
		input_finished.emit(_buffer_text)
		_buffer_text = ""
		_cursor_pos = 0
		_insert_mode = true
		text_changed.emit("")
		cursor_moved.emit(0)
		return
	match keycode:
		KEY_LEFT:
			if _cursor_pos > 0:
				_cursor_pos -= 1
				cursor_moved.emit(_cursor_pos)
		KEY_RIGHT:
			if _cursor_pos < _buffer_text.length():
				_cursor_pos += 1
				cursor_moved.emit(_cursor_pos)
		KEY_HOME:
			if _cursor_pos != 0:
				_cursor_pos = 0
				cursor_moved.emit(_cursor_pos)
		KEY_END:
			var new_pos = _buffer_text.length()
			if _cursor_pos != new_pos:
				_cursor_pos = new_pos
				cursor_moved.emit(_cursor_pos)
		KEY_BACKSPACE:
			if _cursor_pos > 0:
				_buffer_text = _buffer_text.left(_cursor_pos - 1) + _buffer_text.substr(_cursor_pos)
				_cursor_pos -= 1
				text_changed.emit(_buffer_text)
				cursor_moved.emit(_cursor_pos)
		KEY_DELETE:
			if _cursor_pos < _buffer_text.length():
				_buffer_text = _buffer_text.left(_cursor_pos) + _buffer_text.substr(_cursor_pos + 1)
				text_changed.emit(_buffer_text)
		KEY_INSERT:
			_insert_mode = not _insert_mode
			insert_mode_changed.emit(_insert_mode)
		_:
			if unicode > 0:
				var char_str = char(unicode)
				if _insert_mode:
					_buffer_text = _buffer_text.left(_cursor_pos) + char_str + _buffer_text.substr(_cursor_pos)
				else:
					if _cursor_pos < _buffer_text.length():
						_buffer_text = _buffer_text.left(_cursor_pos) + char_str + _buffer_text.substr(_cursor_pos + 1)
					else:
						_buffer_text += char_str
				_cursor_pos += 1
				text_changed.emit(_buffer_text)
				cursor_moved.emit(_cursor_pos)

func _get_modifiers(event: InputEventKey) -> int:
	var mods = 0
	if event.shift_pressed: mods |= Modifier.SHIFT
	if event.ctrl_pressed:  mods |= Modifier.CTRL
	if event.alt_pressed:   mods |= Modifier.ALT
	if event.meta_pressed:  mods |= Modifier.META
	return mods

func get_buffer_text() -> String:
	return _buffer_text

func get_cursor_pos() -> int:
	return _cursor_pos

func get_insert_mode() -> bool:
	return _insert_mode

func set_text(new_text: String, cursor_pos: int = -1) -> void:
	_buffer_text = new_text
	if cursor_pos < 0:
		_cursor_pos = _buffer_text.length()
	else:
		_cursor_pos = min(cursor_pos, _buffer_text.length())
	text_changed.emit(_buffer_text)
	cursor_moved.emit(_cursor_pos)

func reset() -> void:
	_buffer_text = ""
	_cursor_pos = 0
	_insert_mode = true
	text_changed.emit("")
	cursor_moved.emit(0)

func shutdown() -> void:
	bki = null
