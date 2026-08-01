class_name RingArray
extends RefCounted

var _data: Array
var _start: int = 0
var _size: int = 0
var _capacity: int = 0

func _init(p_capacity: int = 0) -> void:
	assert(p_capacity >= 0, "Capacity must be non-negative")
	_capacity = p_capacity
	_data = []
	_data.resize(_capacity)
	for i in _capacity:
		_data[i] = null
	_start = 0
	_size = 0

func push_back(value) -> void:
	if _capacity == 0:
		return
	if _size < _capacity:
		var idx = (_start + _size) % _capacity
		_data[idx] = value
		_size += 1
	else:
		var idx = (_start + _size) % _capacity
		_data[idx] = value
		_start = (_start + 1) % _capacity

func push_front(value) -> void:
	if _capacity == 0:
		return
	if _size < _capacity:
		_start = (_start - 1 + _capacity) % _capacity
		_data[_start] = value
		_size += 1
	else:
		_start = (_start - 1 + _capacity) % _capacity
		_data[_start] = value

func pop_back() -> void:
	if _size == 0:
		return
	_size -= 1
	var idx = (_start + _size) % _capacity
	_data[idx] = null

func pop_front() -> void:
	if _size == 0:
		return
	_data[_start] = null
	_start = (_start + 1) % _capacity
	_size -= 1

func get_element(index: int) -> Variant:
	assert(index < _size, "Index out of bounds")
	return _data[(_start + index) % _capacity]

func set_element(index: int, value) -> void:
	assert(index < _size, "Index out of bounds")
	_data[(_start + index) % _capacity] = value

func size() -> int:
	return _size

func capacity() -> int:
	return _capacity

func is_empty() -> bool:
	return _size == 0

func front() -> Variant:
	assert(_size > 0, "RingArray is empty")
	return get_element(0)

func back() -> Variant:
	assert(_size > 0, "RingArray is empty")
	return get_element(_size - 1)

func alloc(new_capacity: int) -> void:
	assert(new_capacity >= 0, "New capacity must be non-negative")
	if new_capacity == _capacity:
		return

	var new_data = []
	new_data.resize(new_capacity)
	for i in new_capacity:
		new_data[i] = null

	var copy_count = mini(_size, new_capacity)
	for i in copy_count:
		new_data[i] = get(i)

	_data = new_data
	_capacity = new_capacity
	_start = 0
	_size = copy_count

func clear() -> void:
	for i in _capacity:
		_data[i] = null
	_start = 0
	_size = 0

func to_array() -> Array:
	var result = []
	result.resize(_size)
	for i in _size:
		result[i] = get_element(i)
	return result
