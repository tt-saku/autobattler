extends Button

signal face_changed(slot)

@export var slot_index = 0
@export var face = "A"
@export var is_locked = false

var occupying_item = null
var item_text = ""
var _highlight_rect: ColorRect

func _ready():
	update_display()
	pressed.connect(_on_pressed)

	_highlight_rect = ColorRect.new()
	_highlight_rect.name = "DragHighlight"
	_highlight_rect.color = Color.TRANSPARENT
	_highlight_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_highlight_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_highlight_rect)

	# 底部面标识
	var face_label = Label.new()
	face_label.name = "FaceLabel"
	face_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	face_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	face_label.add_theme_font_size_override("font_size", 12)
	face_label.add_theme_color_override("font_color", Color.WHITE)
	face_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	face_label.anchor_left = 0
	face_label.anchor_right = 1
	face_label.anchor_top = 1
	face_label.anchor_bottom = 1
	face_label.offset_top = -28
	face_label.offset_bottom = 0
	add_child(face_label)

func update_display():
	var face_label = get_node_or_null("FaceLabel")
	if face_label:
		face_label.text = "[" + face + "]"
		if face == "A":
			face_label.add_theme_color_override("font_color", Color.CORNFLOWER_BLUE)
		else:
			face_label.add_theme_color_override("font_color", Color.INDIAN_RED)
	var display_text = str(slot_index)
	if item_text != "":
		display_text += "\n" + item_text
	if is_locked:
		display_text += "\nL"
	
	text = display_text
	
	if face == "A":
		modulate = Color.CORNFLOWER_BLUE
	else:
		modulate = Color.INDIAN_RED

func _on_pressed():
	
	if is_locked:
		return
	
	if face == "A":
		face = "B"
	else:
		face = "A"
		
	update_display()
	face_changed.emit(self)

func refresh():
	update_display()

func _can_drop_data(_position, data):
	if data == null or not data is Dictionary:
		return false
	if not data.has("item_instance"):
		return false
	var item = data["item_instance"]
	if not item is ItemInstance or item.data == null:
		return false

	var board = get_parent()
	if not board.has_method("preview_insertion"):
		return false

	var click_offset = data.get("click_slot_offset", 0)
	var adjusted_slot = slot_index - click_offset
	var result = board.preview_insertion(item, adjusted_slot, click_offset, slot_index)
	var can_place = result.get("level", 0) > 0
	board.update_drag_highlight(item, adjusted_slot, click_offset, slot_index)
	return can_place

func _drop_data(_position, data):
	var item = data["item_instance"]
	# 停止跟手动画
	item._is_dragging = false
	item.mouse_filter = Control.MOUSE_FILTER_PASS
	item.set_process(false)
	item.modulate = Color.WHITE

	var board = get_parent()
	board.clear_drag_highlight()
	if board.has_method("insert_item_at_slot"):
		var click_offset = data.get("click_slot_offset", 0)
		var adjusted_slot = slot_index - click_offset
		var success = board.insert_item_at_slot(item, adjusted_slot, slot_index)
		if not success:
			item._restore_to_old_position()

func set_highlight(valid: bool):
	if valid:
		_highlight_rect.color = Color(0, 1, 0, 0.25)
	else:
		_highlight_rect.color = Color(1, 0, 0, 0.25)

func clear_highlight():
	_highlight_rect.color = Color.TRANSPARENT
