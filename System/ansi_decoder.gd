extends RefCounted
class_name AnsiDecoder

enum ParserState {
	NORMAL,
	ESC,
	CSI,
}

enum InstructionType {
	PRINT,
	MOVE_ABSOLUTE,
	MOVE_RELATIVE,
	SET_STYLE,
	CLEAR_SCREEN,
	CLEAR_LINE,
}

var _state := ParserState.NORMAL
var _parameters := []
var _current_parameter := 0
var _parameter_has_value := false

var _foreground: int = -1
var _background: int = -1
var _is_bold: bool = false
var _is_italic: bool = false
var _is_underline: bool = false
var _is_invisible: bool = false
var _is_reverse: bool = false
var _is_strikethrough: bool = false

var _instructions := []

func parse_string(text: String) -> Array:
	_instructions.clear()
	for ch in text:
		_parse_char(ch)
	return _instructions.duplicate()

func _parse_char(ch: String) -> void:
	match _state:
		ParserState.NORMAL:
			if ch == String.chr(27):
				_state = ParserState.ESC
			else:
				_process_normal_char(ch)

		ParserState.ESC:
			if ch == "[":
				_state = ParserState.CSI
				_parameters.clear()
				_current_parameter = 0
				_parameter_has_value = false
			else:
				_state = ParserState.NORMAL

		ParserState.CSI:
			if ch >= "0" and ch <= "9":
				_current_parameter = _current_parameter * 10 + ch.to_int()
				_parameter_has_value = true
			elif ch == ";":
				_parameters.append(_current_parameter if _parameter_has_value else 0)
				_current_parameter = 0
				_parameter_has_value = false
			else:
				if _parameter_has_value:
					_parameters.append(_current_parameter)
				_process_csi_command(ch)
				_state = ParserState.NORMAL

func _process_normal_char(ch: String) -> void:
	match ch:
		"\n":
			_add_instruction(InstructionType.MOVE_RELATIVE, {"dx": 0, "dy": 1, "reset_x": true})
		"\r":
			_add_instruction(InstructionType.MOVE_ABSOLUTE, {"x": 0, "y": -1})
		"\t":
			_add_instruction(InstructionType.PRINT, {"char": "    "})
		_:
			_add_instruction(InstructionType.PRINT, {"char": ch})

func _process_csi_command(cmd: String) -> void:
	var p := _parameters.duplicate()
	if p.is_empty():
		match cmd:
			"m": p = [0]
			"A", "B", "C", "D", "E", "F", "G", "H", "f", "J", "K":
				p = [1]
			_:
				p = [0]

	match cmd:
		"m":
			_process_sgr(p)

		"A":
			var n = p[0] if p.size() > 0 else 1
			_add_instruction(InstructionType.MOVE_RELATIVE, {"dx": 0, "dy": -n})
		"B":
			var n = p[0] if p.size() > 0 else 1
			_add_instruction(InstructionType.MOVE_RELATIVE, {"dx": 0, "dy": n})
		"C":
			var n = p[0] if p.size() > 0 else 1
			_add_instruction(InstructionType.MOVE_RELATIVE, {"dx": n, "dy": 0})
		"D":
			var n = p[0] if p.size() > 0 else 1
			_add_instruction(InstructionType.MOVE_RELATIVE, {"dx": -n, "dy": 0})
		"E":
			var n = p[0] if p.size() > 0 else 1
			_add_instruction(InstructionType.MOVE_RELATIVE, {"dx": -1000, "dy": n, "reset_x": true})
		"F":
			var n = p[0] if p.size() > 0 else 1
			_add_instruction(InstructionType.MOVE_RELATIVE, {"dx": -1000, "dy": -n, "reset_x": true})
		"G":
			var col = p[0] if p.size() > 0 else 1
			_add_instruction(InstructionType.MOVE_ABSOLUTE, {"x": col - 1, "y": -1})
		"H", "f":
			var row = p[0] if p.size() > 0 else 1
			var col = p[1] if p.size() > 1 else 1
			_add_instruction(InstructionType.MOVE_ABSOLUTE, {"x": col - 1, "y": row - 1})
		"J":
			var mode = p[0] if p.size() > 0 else 0
			_add_instruction(InstructionType.CLEAR_SCREEN, {"mode": mode})
		"K":
			var mode = p[0] if p.size() > 0 else 0
			_add_instruction(InstructionType.CLEAR_LINE, {"mode": mode})
		_:
			pass

func _process_sgr(params: Array) -> void:
	for code in params:
		match code:
			0:
				_foreground = -1
				_background = -1
				_is_bold = false
				_is_italic = false
				_is_underline = false
				_is_reverse = false
				_is_invisible = false
				_is_strikethrough = false
			1:   _is_bold = true
			3:   _is_italic = true
			4:   _is_underline = true
			7:   _is_reverse = true
			8:   _is_invisible = true
			9:   _is_strikethrough = true
			22:  _is_bold = false
			23:  _is_italic = false
			24:  _is_underline = false
			27:  _is_reverse = false
			28:  _is_invisible = false
			29:  _is_strikethrough = false
			30, 31, 32, 33, 34, 35, 36, 37:
				_foreground = code - 30
			90, 91, 92, 93, 94, 95, 96, 97:
				_foreground = code - 90 + 8
			40, 41, 42, 43, 44, 45, 46, 47:
				_background = code - 40
			100, 101, 102, 103, 104, 105, 106, 107:
				_background = code - 100 + 8
			_:
				pass

	var style := {
		"fg": _foreground,
		"bg": _background,
		"bold": _is_bold,
		"italic": _is_italic,
		"underline": _is_underline,
		"reverse": _is_reverse,
		"invisible": _is_invisible,
		"strikethrough": _is_strikethrough
	}
	_add_instruction(InstructionType.SET_STYLE, style)

func _add_instruction(type: int, data: Dictionary) -> void:
	_instructions.append({
		"type": type,
		"data": data,
	})
