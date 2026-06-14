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

# 拖拽状态
var _is_dragging: bool = false
var _drag_offset: Vector2 = Vector2.ZERO
var _old_start_slot: int = -1
var _old_board: Node = null


@onready var label = $Label

const SLOT_WIDTH = 90.0
const SLOT_HEIGHT = 180.0

func _ready():
	mouse_filter = MOUSE_FILTER_PASS
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


func _notification(what):
	if what == NOTIFICATION_DRAG_END:
		_is_dragging = false
		mouse_filter = MOUSE_FILTER_PASS
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
