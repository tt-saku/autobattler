# item_instance.gd
extends Control
class_name ItemInstance

# 引用模板
@export var data: ItemData

# 运行时状态
var start_slot: int = -1   # 当前起始槽位（-1 = 未放置）

var current_face: String = "A"
var current_tags: Array = []
var current_cd_a: float = 0.0
var current_cd_b: float = 0.0
var current_critchance: float = 0.0
var enchantments: Array = []
var is_destroyed: bool = false
var is_flying: bool = false
var _board_ref: Node = null
var _combat_ref: CombatItem = null  # 战斗中关联的 CombatItem

# 悬浮提示
var _tooltip: Control = null
var _tooltip_visible: bool = false
var _tooltip_vbox: VBoxContainer = null

# CD 进度条
var _cd_line: ColorRect = null
var _combat_ui_visible: bool = false

# 拖拽状态
var _is_dragging: bool = false
var _drag_offset: Vector2 = Vector2.ZERO
var _old_start_slot: int = -1
var _old_board: Node = null


@onready var label = $Label

const SLOT_WIDTH = 90.0
const SLOT_HEIGHT = 180.0

func _ready():
	mouse_filter = MOUSE_FILTER_STOP
	label = get_node_or_null("Label")
	if label:
		label.mouse_filter = MOUSE_FILTER_IGNORE
	else:
		label = Label.new()
		label.name = "Label"
		add_child(label)
		label.mouse_filter = MOUSE_FILTER_IGNORE
	var panel = get_node_or_null("Panel")
	if panel:
		panel.mouse_filter = MOUSE_FILTER_IGNORE

	_create_tooltip()
	_create_cd_bar()

func refresh_visual():
	if data == null:
		return

	label.text = data.name + "\n" + current_face

	var item_width = SLOT_WIDTH * data.size

	anchor_left = 0
	anchor_top = 0
	anchor_right = 0
	anchor_bottom = 0
	offset_right = offset_left + item_width
	offset_bottom = offset_top + SLOT_HEIGHT
	custom_minimum_size = Vector2(item_width, SLOT_HEIGHT)

	label.anchor_left = 0
	label.anchor_top = 0
	label.anchor_right = 1
	label.anchor_bottom = 1
	label.offset_left = 4
	label.offset_top = 4
	label.offset_right = -4
	label.offset_bottom = -4
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	var panel = get_node_or_null("Panel")
	if panel:
		panel.anchor_left = 0
		panel.anchor_top = 0
		panel.anchor_right = 1
		panel.anchor_bottom = 1
		panel.offset_left = 0
		panel.offset_top = 0
		panel.offset_right = 0
		panel.offset_bottom = 0
		if current_face == "A":
			panel.self_modulate = Color(0.2, 0.4, 0.8, 1.0)
		else:
			panel.self_modulate = Color(0.8, 0.2, 0.2, 1.0)

	queue_redraw()


func _draw():
	var border_color = Color(1, 1, 1, 0.6)
	var border_width = 2.0
	var r = Rect2(Vector2.ZERO, size)
	draw_rect(r, border_color, false, border_width)


func _get_drag_data(at_position):
	if data == null:
		return null

	_drag_offset = at_position

	# 保存旧位置信息用于恢复
	_old_start_slot = start_slot
	_old_board = _board_ref

	# 从棋盘释放（不压缩，保留空位供预览）
	if _board_ref and _board_ref.has_method("release_for_drag"):
		_board_ref.release_for_drag(self)

	_is_dragging = true
	mouse_filter = MOUSE_FILTER_IGNORE
	set_process(true)

	var click_slot_offset = int(at_position.x / SLOT_WIDTH)

	modulate = Color(1, 1, 1, 0.7)

	return {
		"item_instance": self,
		"source_board": _old_board,
		"old_start_slot": _old_start_slot,
		"click_slot_offset": click_slot_offset,
	}


func _process(_delta):
	if _is_dragging:
		global_position = get_global_mouse_position() - _drag_offset
	elif _tooltip_visible and _tooltip:
		var mouse = get_global_mouse_position()
		var pos = mouse + Vector2(16, 16)
		# 屏幕钳制 — 确保完整可见
		var vp_rect = get_viewport().get_visible_rect()
		var ts = _tooltip.size
		if pos.x + ts.x > vp_rect.end.x:
			pos.x = mouse.x - ts.x - 4
		if pos.y + ts.y > vp_rect.end.y:
			pos.y = mouse.y - ts.y - 4
		pos.x = clampf(pos.x, 0, vp_rect.end.x - ts.x)
		pos.y = clampf(pos.y, 0, vp_rect.end.y - ts.y)
		_tooltip.global_position = pos
		_tooltip.queue_redraw()


func _notification(what):
	if what == NOTIFICATION_MOUSE_ENTER:
		_show_tooltip()
	elif what == NOTIFICATION_MOUSE_EXIT:
		_hide_tooltip()
	elif what == NOTIFICATION_DRAG_END:
		_is_dragging = false
		mouse_filter = MOUSE_FILTER_STOP
		set_process(false)
		modulate = Color.WHITE

		# 清除所有棋盘的高亮（跨棋盘拖拽时旧棋盘可能残留）
		if _old_board and _old_board.has_method("clear_drag_highlight"):
			_old_board.clear_drag_highlight()
		if _board_ref and _board_ref.has_method("clear_drag_highlight"):
			_board_ref.clear_drag_highlight()

		# 如果未被放置到任何棋盘（_board_ref 仍为空），恢复到旧位置
		if _board_ref == null and _old_board and _old_start_slot >= 0:
			_restore_to_old_position()


func _restore_to_old_position():
	if _old_board and _old_board.has_method("insert_item_at_slot"):
		_old_board.insert_item_at_slot(self, _old_start_slot)
	_old_board = null
	_old_start_slot = -1


# ============================================================
# 悬浮提示框
# ============================================================

func _create_tooltip():
	_tooltip = ColorRect.new()
	_tooltip.name = "Tooltip"
	_tooltip.visible = false
	_tooltip.top_level = true
	_tooltip.z_index = 100
	_tooltip.mouse_filter = MOUSE_FILTER_IGNORE
	_tooltip.color = Color(0.04, 0.04, 0.08, 1.0)
	_tooltip.draw.connect(_draw_tooltip_border)
	add_child(_tooltip)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 10)
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	_tooltip.add_child(margin)

	_tooltip_vbox = VBoxContainer.new()
	_tooltip_vbox.name = "Content"
	_tooltip_vbox.add_theme_constant_override("separation", 2)
	_tooltip_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_child(_tooltip_vbox)


func _draw_tooltip_border():
	if not _tooltip or _tooltip.size == Vector2.ZERO:
		return
	_tooltip.draw_rect(Rect2(Vector2.ZERO, _tooltip.size), Color(0.45, 0.50, 0.70, 1.0), false, 2.0)


func _show_tooltip():
	if _is_dragging or data == null:
		return
	_build_tooltip_content()
	_tooltip.visible = true
	_tooltip_visible = true
	set_process(true)


func _hide_tooltip():
	if _tooltip:
		_tooltip.visible = false
	_tooltip_visible = false
	if not _is_dragging:
		set_process(false)


func _build_tooltip_content():
	if not _tooltip_vbox or data == null:
		return

	# 先彻底清空旧的（等一帧让 queue_free 生效）
	for child in _tooltip_vbox.get_children():
		child.queue_free()
	await get_tree().process_frame

	# 现在安全添加新标签
	var size_text = "Small (1格)" if data.size == 1 else ("Medium (2格)" if data.size == 2 else "Large (3格)")
	var face_color = "#4a9eff" if current_face == "A" else "#ff4a4a"
	var cd_val = data.cd_a if current_face == "A" else data.cd_b
	var effect_val = data.effect_a if current_face == "A" else data.effect_b

	_add_tip_label(data.name, 16, Color.WHITE)
	_add_tip_label(size_text, 11, Color(0.55, 0.55, 0.55))
	_add_tip_label("", 2, Color.WHITE)
	_add_tip_label("[color=%s]▶ %s 面[/color]" % [face_color, current_face], 13, Color.WHITE)
	_add_tip_label("CD: %.1fs" % cd_val, 11, Color(0.75, 0.75, 0.75))
	_add_tip_label("效果: %s" % effect_val, 11, Color(0.85, 0.85, 0.5))
	_add_tip_label("翻面: %s" % data.flip_effect, 11, Color(0.55, 0.45, 0.75))
	_add_tip_label("", 2, Color.WHITE)
	if data.tags.size() > 0:
		_add_tip_label("Tag: " + ", ".join(data.tags), 10, Color(0.45, 0.65, 0.45))
	_add_tip_label("Rarity: %s  |  Hero: %s" % [data.rarity, data.heroes], 10, Color(0.45, 0.45, 0.45))

	# 等新标签布局完成 → 手动测量
	await get_tree().process_frame
	var content_w = 0.0
	var content_h = 0.0
	for child in _tooltip_vbox.get_children():
		var s = child.get_minimum_size()
		content_w = max(content_w, s.x)
		content_h += s.y
	content_h += max(0, _tooltip_vbox.get_child_count() - 1) * 2  # separation
	var w = max(content_w, 190) + 28
	var h = content_h + 20
	_tooltip.custom_minimum_size = Vector2(w, h)
	_tooltip.size = Vector2(w, h)
	_tooltip.queue_redraw()


func _add_tip_label(text: String, font_size: int, color: Color):
	var lbl = Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", color)
	lbl.mouse_filter = MOUSE_FILTER_IGNORE
	_tooltip_vbox.add_child(lbl)


# ============================================================
# CD 进度条 & 战斗 UI
# ============================================================

func _create_cd_bar():
	_cd_line = ColorRect.new()
	_cd_line.name = "CDLine"
	_cd_line.color = Color(0.3, 0.9, 1.0, 0.9)
	_cd_line.visible = false
	_cd_line.mouse_filter = MOUSE_FILTER_IGNORE
	_cd_line.anchor_left = 0
	_cd_line.anchor_right = 1
	_cd_line.anchor_top = 0
	_cd_line.offset_top = SLOT_HEIGHT - 3
	_cd_line.offset_bottom = SLOT_HEIGHT
	add_child(_cd_line)


func show_combat_ui():
	_combat_ui_visible = true
	if _cd_line:
		_cd_line.visible = true
	update_cd_bar(0, 1)


func hide_combat_ui():
	_combat_ui_visible = false
	if _cd_line:
		_cd_line.visible = false


func update_cd_bar(current: float, maximum: float):
	if not _combat_ui_visible or not _cd_line:
		return
	# 横杠从卡底 (CD=0) 升到卡顶 (CD=满) —— 读秒效果
	var ratio = clampf(1.0 - current / maxf(maximum, 0.1), 0.0, 1.0)
	var line_h = 3.0
	var travel = SLOT_HEIGHT - line_h
	_cd_line.offset_top = travel * ratio
	_cd_line.offset_bottom = _cd_line.offset_top + line_h
