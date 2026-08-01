extends RefCounted
class_name RingQueue

var _buffer: Array = []
var _head: int = 0
var _tail: int = 0
var _count: int = 0
var _capacity: int = 16

func push(value: Variant) -> void:
	if _count == _buffer.size():
		_resize()
	_buffer[_tail] = value
	_tail = (_tail + 1) % _buffer.size()
	_count += 1

func pop() -> Variant:
	if _count == 0:
		return null
	var val = _buffer[_head]
	_head = (_head + 1) % _buffer.size()
	_count -= 1
	return val

func front() -> Variant:
	if _count == 0:
		return null
	return _buffer[_head]

func back() -> Variant:
	if _count == 0:
		return null
	var idx = (_tail - 1 + _buffer.size()) % _buffer.size()
	return _buffer[idx]

func empty() -> bool:
	return _count == 0

func size() -> int:
	return _count

func clear() -> void:
	_head = 0
	_tail = 0
	_count = 0

func to_array() -> Array:
	var result = []
	if _count == 0:
		return result
	var idx = _head
	for _i in range(_count):
		result.append(_buffer[idx])
		idx = (idx + 1) % _buffer.size()
	return result

func _resize() -> void:
	var old_size = _buffer.size()
	var new_size = old_size * 2
	if old_size == 0:
		new_size = 16
	_buffer.resize(new_size)
	if _head > 0 and _count > 0:
		var temp = []
		for i in range(_count):
			temp.append(_buffer[(_head + i) % old_size])
		for i in range(_count):
			_buffer[i] = temp[i]
		_head = 0
		_tail = _count
	else:
		_tail = _count

func _init(initial_capacity: int = 16) -> void:
	_capacity = max(4, initial_capacity)
	_buffer.resize(_capacity)
	_head = 0
	_tail = 0
	_count = 0
