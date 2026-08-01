extends RefCounted
class_name Stream

var _queue: RingQueue = RingQueue.new()

func push(value: Variant) -> void:
	_queue.push(value)

func pop() -> Variant:
	if _queue.empty():
		return null
	return _queue.pop()

func peek() -> Variant:
	if _queue.empty():
		return null
	return _queue.front()

func is_empty() -> bool:
	return _queue.empty()

func size() -> int:
	return _queue.size()

func clear() -> void:
	_queue.clear()

func pop_all() -> Array:
	var result = _queue.to_array()
	_queue.clear()
	return result
