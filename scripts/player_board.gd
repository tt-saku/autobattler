extends HBoxContainer
class_name Board

signal item_placed(item)
signal item_removed(item)

@onready var slots: Array = []

const ITEM_SCENE = preload("res://scenes/item_instance.tscn")
const TEST_SMALL = preload("res://items/test_small.tres")
const TEST_MEDIUM = preload("res://items/test_medium.tres")
const TEST_LARGE = preload("res://items/test_large.tres")

var _drag_highlighted_slots: Array = []

# === 核心数据：有序物品列表（真相源）===
# 空格只是布局结果，不存储在数据中
var items: Array = []


func _ready():
	resized.connect(queue_redraw)


# ============================================================
# 底层放置
# ============================================================

func _place_item_at(item_instance: ItemInstance, start_slot_index: int):
	var item_size = item_instance.data.size

	item_instance.start_slot = start_slot_index

	for i in range(start_slot_index, start_slot_index + item_size):
		slots[i].occupying_item = item_instance

	if item_instance.get_parent() != self:
		if item_instance.get_parent():
			item_instance.get_parent().remove_child(item_instance)
		self.add_child(item_instance)

	item_instance.top_level = true
	item_instance._board_ref = self
	_update_item_position.call_deferred(item_instance)

	item_instance.current_face = calculate_face(item_instance)
	item_instance.refresh_visual()


func _update_item_position(it: ItemInstance):
	if it.start_slot >= 0 and it.start_slot < slots.size():
		it.global_position = slots[it.start_slot].global_position


func _draw():
	if slots.size() == 0:
		return
	var border_color = Color(1, 1, 1, 0.4)
	var border_width = 2.0
	var r = Rect2(Vector2.ZERO, size)
	draw_rect(r, border_color, false, border_width)


# ============================================================
# 初始化
# ============================================================

func initialize():
	size_flags_horizontal = 0
	custom_minimum_size = Vector2(900, 210)
	add_theme_constant_override("separation", 0)
	for child in get_children():
		child.custom_minimum_size = Vector2(90, 210)
		child.size_flags_horizontal = 0
		child.size_flags_stretch_ratio = 0
		slots.append(child)
		child.face_changed.connect(_on_slot_face_changed)
	print("Board initialized, Slot Count = ", slots.size())
	queue_redraw()


func get_items_sorted() -> Array:
	return items.duplicate()


func get_total_width() -> int:
	var total = 0
	for it in items:
		total += it.data.size
	return total


# ============================================================
# 直接放置（初始生成用，不压缩不动画）
# ============================================================

func place_item_direct(item_instance: ItemInstance, start_slot_index: int) -> bool:
	var item_size = item_instance.data.size

	if start_slot_index < 0 or start_slot_index + item_size > slots.size():
		return false

	for i in range(start_slot_index, start_slot_index + item_size):
		var occupant = slots[i].occupying_item
		if occupant != null and occupant != item_instance:
			return false

	if not items.has(item_instance):
		var insert_idx = items.size()
		for j in range(items.size()):
			if items[j].start_slot > start_slot_index:
				insert_idx = j
				break
		items.insert(insert_idx, item_instance)

	_place_item_at(item_instance, start_slot_index)
	item_placed.emit(item_instance)
	return true


func place_item(item_instance: ItemInstance, start_slot_index: int) -> bool:
	return place_item_direct(item_instance, start_slot_index)


# ============================================================
# 释放与移除
# ============================================================

func release_for_drag(item: ItemInstance):
	"""拖拽开始：从 items[] 移除，清槽位，但保留 start_slot 用于动画"""
	items.erase(item)

	for i in range(item.start_slot, item.start_slot + item.data.size):
		if i >= 0 and i < slots.size():
			slots[i].occupying_item = null

	# 保留 start_slot 不动 — rebuild_layout 用它做动画起始位置
	item._board_ref = null


func release_item(item_instance: ItemInstance):
	"""完全释放：从 items[] 和场景树移除"""
	items.erase(item_instance)

	for i in range(item_instance.start_slot, item_instance.start_slot + item_instance.data.size):
		if i >= 0 and i < slots.size():
			slots[i].occupying_item = null

	item_instance._board_ref = null

	if item_instance.get_parent():
		item_instance.get_parent().remove_child(item_instance)


func remove_item(item_instance: ItemInstance):
	print("Removing ", item_instance.data.name)
	release_item(item_instance)
	item_removed.emit(item_instance)
	item_instance.queue_free()


# ============================================================
# 智能插入（Bazaar 式）
# ============================================================

func insert_item_at_slot(item: ItemInstance, target_slot: int, hovered_slot: int = -1) -> bool:
	"""核心：确定插入位置 → 插入 items[] → 压缩重建布局 → 播放滑动动画。
	target_slot = 调整后的锚定槽位（= hovered_slot - click_offset）。
	hovered_slot = 鼠标实际落点槽位（用于判定物品顺序）。"""

	# 容量检查
	var total = get_total_width()
	if total + item.data.size > slots.size():
		print(item.data.name, " 插入失败：容量不足 (", total, " + ", item.data.size, " > ", slots.size(), ")")
		return false

	target_slot = clampi(target_slot, 0, slots.size() - 1)
	var mouse_slot = hovered_slot if hovered_slot >= 0 else target_slot

	# 确定插入索引（传入物品原始位置、大小、鼠标落点）
	var old_start = item.start_slot
	var insert_idx = _slot_to_insert_index(mouse_slot, old_start, item.data.size)

	# 插入有序列表
	if items.has(item):
		items.erase(item)
	items.insert(insert_idx, item)

	# 挂到场景树
	if item.get_parent() != self:
		if item.get_parent():
			item.get_parent().remove_child(item)
		add_child(item)
	item.top_level = true
	item._board_ref = self

	# 统一重建（传递锚定信息：物品放在松手位置）
	rebuild_layout(true, item, target_slot)
	print(item.data.name, " 智能插入 @ index=", insert_idx, " (target_slot=", target_slot, ")")
	item_placed.emit(item)
	return true


func _slot_to_insert_index(mouse_slot: int, old_start: int = -1, dragged_size: int = 1) -> int:
	"""将鼠标落点转换为 items[] 中的插入索引。"""
	if items.size() == 0:
		return 0

	for i in range(items.size()):
		var it = items[i]
		var midpoint = it.start_slot + it.data.size / 2.0
		if mouse_slot < midpoint:
			return i

	return items.size()


# ============================================================
# 布局重建（统一入口）
# ============================================================

func rebuild_layout(animate: bool = true, anchor_item: ItemInstance = null, target_slot: int = -1):
	"""
	统一布局重建。
	有锚定物品时：物品放在松手位置，只有冲突时才推移其他物品。
	无锚定物品时：从左压缩排列。
	"""
	for slot in slots:
		slot.occupying_item = null

	if items.size() == 0:
		return

	var old_positions = {}
	for it in items:
		old_positions[it] = it.start_slot

	if anchor_item != null and target_slot >= 0:
		var anchor_idx = items.find(anchor_item)
		if anchor_idx < 0:
			_compact_left()
			_apply_layout(old_positions, animate)
			return

		# === 锚定布局 ===

		# 1. 锚定物品置于目标槽位
		anchor_item.start_slot = target_slot

		# 2. 锚后物品：从锚尾向右级联
		var cursor = target_slot + anchor_item.data.size
		for i in range(anchor_idx + 1, items.size()):
			var it = items[i]
			it.start_slot = max(cursor, it.start_slot)
			cursor = it.start_slot + it.data.size

		# 3. 锚前物品：保持原位，仅因冲突向左推移；若推出界则右移锚点腾空间
		cursor = target_slot
		var anchor_push = 0
		for i in range(anchor_idx - 1, -1, -1):
			var it = items[i]
			var right_edge = it.start_slot + it.data.size
			if right_edge > cursor:
				var overlap = right_edge - cursor
				var new_start = it.start_slot - overlap
				if new_start < 0:
					anchor_push += (0 - new_start)
					new_start = 0
				it.start_slot = new_start
			cursor = it.start_slot

		# 若锚点被右推，重跑步骤2让级联自然处理（远端物品不受影响）
		if anchor_push > 0:
			anchor_item.start_slot += anchor_push
			cursor = anchor_item.start_slot + anchor_item.data.size
			for i in range(anchor_idx + 1, items.size()):
				var it = items[i]
				it.start_slot = max(cursor, it.start_slot)
				cursor = it.start_slot + it.data.size

		# 4. 右溢出修正
		var last = items[items.size() - 1]
		var overflow = (last.start_slot + last.data.size) - slots.size()
		if overflow > 0:
			for it in items:
				it.start_slot -= overflow

		# 5. 若修正后仍左溢出 → 回退到左压缩
		if items[0].start_slot < 0:
			_compact_left()
	else:
		_compact_left()

	# 最终一致性校验：确保无重叠、无越界
	if not _validate_layout():
		_compact_left()

	_apply_layout(old_positions, animate)


func _compact_left():
	var cursor = 0
	for it in items:
		it.start_slot = cursor
		cursor += it.data.size


func _validate_layout() -> bool:
	"""确保没有重叠、无越界（允许间隙）"""
	var occupied = {}
	for it in items:
		if it.start_slot < 0:
			return false
		for j in range(it.start_slot, it.start_slot + it.data.size):
			if j >= slots.size():
				return false
			if occupied.has(j):
				return false  # 重叠！
			occupied[j] = true
	return true


func _apply_layout(old_positions: Dictionary, animate: bool):
	for it in items:
		for j in range(it.start_slot, it.start_slot + it.data.size):
			if j >= 0 and j < slots.size():
				slots[j].occupying_item = it

		if it.start_slot >= 0 and it.start_slot < slots.size():
			var target_pos = slots[it.start_slot].global_position
			var old_start = old_positions.get(it, -1)

			if animate and old_start >= 0 and old_start != it.start_slot:
				_animate_item_move(it, target_pos)
			else:
				it.global_position = target_pos

		it.current_face = calculate_face(it)
		it.refresh_visual()


func _animate_item_move(item: ItemInstance, target_pos: Vector2):
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(item, "global_position", target_pos, 0.25)


# ============================================================
# 面计算（使用 start_slot 和 slots[] 替代 occupied_slots）
# ============================================================

func calculate_face(item: ItemInstance) -> String:
	var item_size = item.data.size
	var board_size = slots.size()
	var start = item.start_slot

	if start < 0 or start + item_size > slots.size():
		return "A"

	if item_size == 1:
		return slots[start].face
	elif item_size == 2:
		var left_slot = slots[start]
		var right_slot = slots[start + 1]
		var left_dist = left_slot.slot_index
		var right_dist = board_size - 1 - right_slot.slot_index
		if left_slot.slot_index + right_slot.slot_index == board_size - 1:
			return left_slot.face
		else:
			return left_slot.face if left_dist <= right_dist else right_slot.face
	elif item_size == 3:
		var outer_slot = slots[start]
		var min_dist = min(slots[start].slot_index, board_size - 1 - slots[start].slot_index)
		for i in range(start, start + item_size):
			var dist = min(slots[i].slot_index, board_size - 1 - slots[i].slot_index)
			if dist < min_dist:
				min_dist = dist
				outer_slot = slots[i]
		return outer_slot.face
	else:
		return slots[start].face


# ============================================================
# 放置预览
# ============================================================

func can_place_directly(item: ItemInstance, start_slot: int) -> bool:
	var item_size = item.data.size
	if start_slot < 0 or start_slot + item_size > slots.size():
		return false
	for i in range(start_slot, start_slot + item_size):
		var occupant = slots[i].occupying_item
		if occupant != null and occupant != item:
			return false
	return true


func preview_insertion(item: ItemInstance, target_slot: int, _click_offset: int = 0, hovered_slot: int = -1) -> Dictionary:
	"""预览插入后的槽位占用（供拖拽高亮使用，考虑锚定右移）"""
	var total = get_total_width()
	if total + item.data.size > slots.size():
		return {"level": 0, "preview_slots": []}

	var old_start = item.start_slot
	var mouse_slot = hovered_slot if hovered_slot >= 0 else target_slot
	var insert_idx = _slot_to_insert_index(mouse_slot, old_start, item.data.size)

	# 计算压缩后的起始槽位
	var compressed_start = 0
	for i in range(insert_idx):
		compressed_start += items[i].data.size

	# 计算锚定右移（与 rebuild_layout 保持一致）
	var total_width = total + item.data.size
	var available = slots.size() - total_width
	var desired_shift = target_slot - compressed_start
	var shift = clampi(desired_shift, 0, available)
	var actual_start = compressed_start + shift

	var preview_slots: Array[int] = []
	for i in range(actual_start, actual_start + item.data.size):
		preview_slots.append(i)

	return {"level": 1, "preview_slots": preview_slots}


func update_drag_highlight(item: ItemInstance, target_slot: int, click_offset: int = 0, hovered_slot: int = -1):
	clear_drag_highlight()
	var result = preview_insertion(item, target_slot, click_offset, hovered_slot)
	var can_place = result.get("level", 0) > 0
	var preview_slots: Array = result.get("preview_slots", [])

	for idx in preview_slots:
		if idx >= 0 and idx < slots.size():
			slots[idx].set_highlight(can_place)
			_drag_highlighted_slots.append(slots[idx])


func clear_drag_highlight():
	for slot in _drag_highlighted_slots:
		slot.clear_highlight()
	_drag_highlighted_slots.clear()


# ============================================================
# 批量操作
# ============================================================

func simulate_compact(item_list: Array) -> bool:
	var cursor = 0
	for it in item_list:
		if cursor + it.data.size > slots.size():
			return false
		cursor += it.data.size
	return true


func apply_compact(item_list: Array):
	items = item_list.duplicate()
	for it in items:
		if it.get_parent() != self:
			if it.get_parent():
				it.get_parent().remove_child(it)
			add_child(it)
		it.top_level = true
		it._board_ref = self
	rebuild_layout(false)


# ============================================================
# 刷新与测试
# ============================================================

func _on_slot_face_changed(slot):
	print("Slot ", slot.slot_index, " changed to ", slot.face)
	refresh_all_items()


func refresh_all_items():
	var handled: Array = []
	for slot in slots:
		var item = slot.occupying_item
		if item == null or item in handled:
			continue
		handled.append(item)
		item.current_face = calculate_face(item)
		print(item.data.name, " face=", item.current_face)
		item.refresh_visual()


func test_spawn_items():
	var small = ITEM_SCENE.instantiate()
	small.data = TEST_SMALL
	place_item_direct(small, 1)

	var medium = ITEM_SCENE.instantiate()
	medium.data = TEST_MEDIUM
	place_item_direct(medium, 3)

	var large = ITEM_SCENE.instantiate()
	large.data = TEST_LARGE
	place_item_direct(large, 6)
	remove_item(large)
