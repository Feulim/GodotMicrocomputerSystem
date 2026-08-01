extends RefCounted
class_name IndexedPalette

var colors: Array[Color]

func _init(p_colors: Array[Color]):
	colors = p_colors

func get_color(index: int) -> Color:
	if index >= 0 and index < colors.size():
		return colors[index]
	return colors[0]
	
