extends Node

func update_debug_label(text: String):
	var label = get_tree().root.get_node("Test/Label")
	if label:
		label.text = text

func update_debug_label2(text: String):
	var label = get_tree().root.get_node("Test/Label2")
	if label:
		label.text = text

func update_debug_label3(text: String):
	var label = get_tree().root.get_node("Test/Label3")
	if label:
		label.text = text
