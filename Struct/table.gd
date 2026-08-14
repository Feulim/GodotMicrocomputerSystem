class_name Table
extends RefCounted

enum Anchor {
	LEFT,
	RIGHT,
	CENTER
}

var _rows: Array = []
var _mode: String = ""
var _anchors: Array = []

static func ver(lists: Array) -> Table:
	var t = Table.new()
	t._mode = "ver"
	if lists.is_empty():
		return t
	
	for item in lists:
		if not (item is Array):
			return t
	
	var max_len = 0
	for col in lists:
		if col.size() > max_len:
			max_len = col.size()
	
	var cols = []
	for col in lists:
		var c = col.duplicate()
		while c.size() < max_len:
			c.append(null)
		cols.append(c)
	
	t._rows = []
	for i in range(max_len):
		var row = []
		for col in cols:
			row.append(col[i])
		t._rows.append(row)
	
	return t

static func hor(lists: Array) -> Table:
	var t = Table.new()
	t._mode = "hor"
	if lists.is_empty():
		return t
	
	for item in lists:
		if not (item is Array):
			return t
	
	var max_len = 0
	for row in lists:
		if row.size() > max_len:
			max_len = row.size()
	
	t._rows = []
	for row in lists:
		var r = row.duplicate()
		while r.size() < max_len:
			r.append(null)
		t._rows.append(r)
	
	return t


func add(list: Array) -> void:
	if _mode == "ver":
		_add_column(list)
	elif _mode == "hor":
		_add_row(list)
	else:
		push_warning("Table.add: mode not set (call ver or hor first)")

func _add_column(list: Array) -> void:
	var current_rows = _rows.size()
	
	if current_rows == 0:
		for val in list:
			_rows.append([val])
		return
	
	var current_cols = _rows[0].size()
	var target_rows = max(current_rows, list.size())
	
	if target_rows > current_rows:
		for i in range(current_rows, target_rows):
			var new_row = []
			for _j in range(current_cols):
				new_row.append(null)
			_rows.append(new_row)
	
	var col_data = list.duplicate()
	while col_data.size() < target_rows:
		col_data.append(null)
	
	for i in range(target_rows):
		_rows[i].append(col_data[i])
	
	if list.size() != current_rows:
		push_warning("Table: added column size (%d) does not match row count (%d), adjusted with nulls" % [list.size(), current_rows])

func _add_row(list: Array) -> void:
	var current_rows = _rows.size()
	
	if current_rows == 0:
		_rows = [list.duplicate()]
		return
	
	var current_cols = _rows[0].size()
	var target_cols = max(current_cols, list.size())

	if target_cols > current_cols:
		for i in range(current_rows):
			while _rows[i].size() < target_cols:
				_rows[i].append(null)
	
	var row_data = list.duplicate()
	while row_data.size() < target_cols:
		row_data.append(null)
	
	_rows.append(row_data)
	
	if list.size() != current_cols:
		push_warning("Table: added row size (%d) does not match column count (%d), adjusted with nulls" % [list.size(), current_cols])


func prepare(args: Array = [], end: String = " ") -> String:
	var num_cols = _rows[0].size() if not _rows.is_empty() else 0
	
	if args.is_empty():
		_anchors = []
	else:
		var anchors = args.duplicate()
		if anchors.size() < num_cols:
			while anchors.size() < num_cols:
				anchors.append(Anchor.LEFT)
		elif anchors.size() > num_cols:
			anchors = anchors.slice(0, num_cols)
			push_warning("Table.prepare: too many anchors provided, extra ignored")
		_anchors = anchors
	
	return _format(end)

func _to_string() -> String:
	return _format()

func _format(end: String = " ") -> String:
	if _rows.is_empty():
		return ""
	
	if end.length() == 0:
		end = " "
	var space_width = end.length()
	if end.length() > 1:
		end = end[0]
	
	var num_cols = _rows[0].size()
	
	var max_widths = []
	for j in range(num_cols):
		var max_len = 0
		for row in _rows:
			var val = row[j] if row[j] != null else end
			var s = str(val)
			if s.length() > max_len:
				max_len = s.length()
		max_widths.append(max_len)
	
	var lines = []
	for row in _rows:
		var cells = []
		for j in range(num_cols):
			var val = row[j] if row[j] != null else end
			var s = str(val)
			var width = max_widths[j]
			var anchor = _anchors[j] if j < _anchors.size() else Anchor.LEFT
			
			match anchor:
				Anchor.LEFT:
					s = s + end.repeat(width - s.length())
				Anchor.RIGHT:
					s = end.repeat(width - s.length()) + s
				Anchor.CENTER:
					var left = (width - s.length()) / 2
					var right = width - s.length() - left
					s = end.repeat(left) + s + end.repeat(right)
			cells.append(s)
		lines.append(end.repeat(space_width).join(cells))
	
	return "\n".join(lines)

func get_anchors() -> Array:
	return _anchors.duplicate()

func get_size() -> Dictionary:
	if _rows.is_empty():
		return {"rows": 0, "cols": 0}
	return {"rows": _rows.size(), "cols": _rows[0].size()}
