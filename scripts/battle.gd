extends Control

@onready var enemy_label = $Main_layout/Enemy_area/Label
@onready var enemy_board: Board = $Main_layout/Enemy_area/BoardCenter/Enemy_board
@onready var player_board: Board = $Main_layout/Player_area/BoardCenter/Player_board
@onready var backpack_btn = $Backpack_btn
@onready var fight_btn = $Fight_btn
@onready var log_display: RichTextLabel = $Main_layout/Battle_log/LogDisplay

var slot_scene = preload("res://scenes/slot.tscn")
var player_slots = []
var enemy_slots = []

enum EnemyView { SHOP, ENEMY, BACKPACK }
var current_enemy_view: EnemyView = EnemyView.SHOP
var _shop_stored: Array = []
var _backpack_stored: Array = []

# 战斗相关
var _player_character: Character = null
var _enemy_character: Character = null
var _battle_engine: TickScheduler = null
var _is_fighting: bool = false

# HP 状态条
var _enemy_hp_fill: ColorRect = null
var _player_hp_fill: ColorRect = null
var _enemy_hp_text: Label = null
var _player_hp_text: Label = null
var _enemy_hp_max_label: Label = null
var _player_hp_max_label: Label = null


func _ready():
	create_board(enemy_board, enemy_slots)
	create_board(player_board, player_slots)

	enemy_board.initialize()
	player_board.initialize()

	backpack_btn.pressed.connect(_on_backpack_btn_pressed)
	fight_btn.pressed.connect(_on_fight_btn_pressed)

	_create_characters()
	_subscribe_to_events()
	spawn_shop_items()


func create_board(board_container, slot_list):
	for i in range(10):
		var slot = slot_scene.instantiate()
		slot.slot_index = i

		if i == 0:
			slot.face = "B"
			slot.is_locked = true
		elif i == 9:
			slot.face = "A"
			slot.is_locked = true
		else:
			slot.face = "A"
			slot.is_locked = false

		slot_list.append(slot)
		board_container.add_child(slot)
		slot.refresh()


func spawn_shop_items():
	var ITEM_SCENE = preload("res://scenes/item_instance.tscn")
	# 总计 9 格 ≤ 10 格上限
	var templates = [
		preload("res://items/test_sword.tres"),    # 1格 damage
		preload("res://items/test_shield.tres"),    # 1格 shield
		preload("res://items/test_heal.tres"),      # 1格 heal
		preload("res://items/test_haste.tres"),     # 1格 haste
		preload("res://items/test_freeze.tres"),    # 1格 freeze
		preload("res://items/test_axe.tres"),       # 2格 damage
		preload("res://items/test_slow.tres"),      # 2格 slow
	]

	var cursor = 0
	for tmpl in templates:
		var card = ITEM_SCENE.instantiate()
		card.data = tmpl
		card.current_face = "A"
		card.current_cd_a = tmpl.cd_a
		card.current_cd_b = tmpl.cd_b
		enemy_board.place_item_direct(card, cursor)
		cursor += tmpl.size


func _on_backpack_btn_pressed():
	match current_enemy_view:
		EnemyView.SHOP:
			switch_to_backpack()
		EnemyView.BACKPACK:
			switch_to_shop()
		EnemyView.ENEMY:
			pass


func switch_to_shop():
	_backpack_stored.clear()
	for item in enemy_board.get_items_sorted():
		enemy_board.release_item(item)
		_backpack_stored.append(item)

	for item in _shop_stored:
		if is_instance_valid(item):
			enemy_board.place_item_direct(item, item.start_slot)

	current_enemy_view = EnemyView.SHOP
	enemy_label.text = "🛒 Shop"
	backpack_btn.text = "🎒 Backpack"


func switch_to_backpack():
	_shop_stored.clear()
	for item in enemy_board.get_items_sorted():
		enemy_board.release_item(item)
		_shop_stored.append(item)

	for item in _backpack_stored:
		if is_instance_valid(item):
			enemy_board.place_item_direct(item, item.start_slot)

	current_enemy_view = EnemyView.BACKPACK
	enemy_label.text = "🎒 Backpack"
	backpack_btn.text = "🛒 Shop"


# ============================================================
# 战斗系统
# ============================================================

func _create_characters():
	_player_character = Character.new()
	_player_character.character_name = "Player"
	_player_character.max_hp = 100
	add_child(_player_character)

	_enemy_character = Character.new()
	_enemy_character.character_name = "Enemy"
	_enemy_character.max_hp = 100
	add_child(_enemy_character)

	# 监听血量变化 → 更新 HP 条
	_player_character.health_changed.connect(_update_hp_bars)
	_enemy_character.health_changed.connect(_update_hp_bars)
	_player_character.shielded.connect(_update_hp_bars)
	_enemy_character.shielded.connect(_update_hp_bars)

	_create_hp_bars()
	_update_hp_bars()


func _on_fight_btn_pressed():
	if _is_fighting:
		return

	_is_fighting = true
	fight_btn.disabled = true
	_lock_inputs(true)

	# 重置角色
	_player_character.reset()
	_enemy_character.reset()

	# 从双方棋盘收集物品，创建 CombatItem
	var combat_items: Array[CombatItem] = []
	var all_instances: Array[ItemInstance] = []

	for item in enemy_board.items:
		var ci = CombatItem.new()
		ci.item_instance = item
		ci.owner_character = _enemy_character
		ci.target_character = _player_character
		item._combat_ref = ci
		item.show_combat_ui()
		add_child(ci)
		combat_items.append(ci)
		all_instances.append(item)

	for item in player_board.items:
		var ci = CombatItem.new()
		ci.item_instance = item
		ci.owner_character = _player_character
		ci.target_character = _enemy_character
		item._combat_ref = ci
		item.show_combat_ui()
		add_child(ci)
		combat_items.append(ci)
		all_instances.append(item)

	print("[Battle] 创建 %d 个 CombatItem" % combat_items.size())

	# 启动战斗引擎
	_battle_engine = TickScheduler.new()
	_battle_engine.name = "TickScheduler"
	add_child(_battle_engine)
	_battle_engine.battle_ended.connect(_on_battle_ended)
	_battle_engine.setup(_player_character, _enemy_character, combat_items)
	_battle_engine.start()


func _on_battle_ended(winner: Character):
	_is_fighting = false
	fight_btn.disabled = false
	_lock_inputs(false)

	var winner_name = winner.character_name if winner else "Draw"
	print("[Battle] 结束! 胜者: ", winner_name)

	# 隐藏所有物品的战斗 UI
	for slot in enemy_slots + player_slots:
		if is_instance_valid(slot) and slot.occupying_item:
			slot.occupying_item.hide_combat_ui()
			slot.occupying_item._combat_ref = null

	# 清理战斗对象
	if _battle_engine:
		_battle_engine.queue_free()
		_battle_engine = null

	for child in get_children():
		if child is CombatItem:
			child.queue_free()


func _lock_inputs(locked: bool):
	## 战斗期间锁定槽位点击和物品拖拽
	for slot in enemy_slots + player_slots:
		if is_instance_valid(slot):
			slot.disabled = locked
	backpack_btn.disabled = locked if not _is_fighting else true


# ============================================================
# 战斗日志
# ============================================================

func _subscribe_to_events():
	EventBus.on(EventBus.ON_BATTLE_START, _log_battle_start)
	EventBus.on(EventBus.ON_BATTLE_END, _log_battle_end)
	EventBus.on(EventBus.ON_DAMAGE, _log_damage)
	EventBus.on(EventBus.ON_HEAL, _log_heal)
	EventBus.on(EventBus.ON_SHIELD, _log_shield)
	EventBus.on(EventBus.ON_ITEM_TRIGGER, _log_item_trigger)
	EventBus.on(EventBus.ON_DEATH, _log_death)


func _log_battle_start(data: Dictionary):
	_clear_log()
	var player: Character = data.get("player", null)
	var enemy: Character = data.get("enemy", null)
	var p_hp = player.hp if player else "?"
	var e_hp = enemy.hp if enemy else "?"
	_append_log("[color=yellow]━━━ 战斗开始 ━━━[/color]")
	_append_log("Player HP: %s  |  Enemy HP: %s" % [p_hp, e_hp])


func _log_battle_end(data: Dictionary):
	var winner: Character = data.get("winner", null)
	var name = winner.character_name if winner else "Draw"
	_append_log("[color=orange]━━━ %s 获胜! ━━━[/color]" % name)


func _log_damage(data: Dictionary):
	var src = _item_name(data.get("source", null))
	var tgt = _char_name(data.get("target", null))
	var val = data.get("value", 0)
	var actual = data.get("actual", 0)
	var shield_absorbed = val - actual
	var tgt_char = data.get("target", null) as Character
	var state = _char_state(tgt_char)

	if shield_absorbed > 0:
		_append_log("[color=red]%s → %s: -%d (盾吸 %d) %s[/color]" % [src, tgt, actual, shield_absorbed, state])
	else:
		_append_log("[color=red]%s → %s: -%d %s[/color]" % [src, tgt, actual, state])


func _log_heal(data: Dictionary):
	var src = _item_name(data.get("source", null))
	var tgt = _char_name(data.get("target", null))
	var val = data.get("actual", data.get("value", 0))
	var tgt_char = data.get("target", null) as Character
	var state = _char_state(tgt_char)
	_append_log("[color=green]%s 治疗 %s +%d %s[/color]" % [src, tgt, val, state])


func _log_shield(data: Dictionary):
	var src = _item_name(data.get("source", null))
	var tgt = _char_name(data.get("target", null))
	var val = data.get("value", 0)
	var tgt_char = data.get("target", null) as Character
	var state = _char_state(tgt_char)
	_append_log("[color=cyan]%s 护盾 %s +%d %s[/color]" % [src, tgt, val, state])


func _log_item_trigger(data: Dictionary):
	var src = _item_name(data.get("source", null))
	var etype = data.get("type", "trigger")
	var val = data.get("value", 0)
	var self_buff = data.get("self", false)
	var count = data.get("target_count", 0)

	match etype:
		"haste":
			_append_log("  ⚡ %s 加速自身 ×2 (%ss)" % [src, val])
		"slow":
			_append_log("  🐌 %s 减速 %d 个敌方物品 ×0.5 (%ss)" % [src, count, val])
		"freeze":
			_append_log("  ❄️ %s 冻结 %d 个敌方物品 (%ss)" % [src, count, val])
		_:
			_append_log("  ⚡ %s 触发 %s(%s)" % [src, etype, val])


func _log_death(data: Dictionary):
	var tgt = _char_name(data.get("target", null))
	_append_log("[color=gray]💀 %s 死亡[/color]" % tgt)


func _clear_log():
	if log_display:
		log_display.clear()


func _append_log(text: String):
	if log_display:
		log_display.append_text(text + "\n")


func _item_name(source) -> String:
	if source is ItemInstance and source.data:
		return "[%s]" % source.data.name
	return "[?]"


func _char_name(target) -> String:
	if target is Character:
		return target.character_name
	return "?"


func _char_state(ch: Character) -> String:
	if not ch:
		return ""
	return "(HP: %d/%d, 盾: %d)" % [ch.hp, ch.max_hp, ch.shield]


# ============================================================
# HP 状态条
# ============================================================

func _create_hp_bars():
	# Enemy HP bar - insert between Label and Board
	var r1 = _build_hp_bar("Enemy")
	_enemy_hp_fill = r1[0]
	_enemy_hp_text = r1[1]
	_enemy_hp_max_label = r1[2]
	var enemy_area = $Main_layout/Enemy_area
	var hp_ctrl = _enemy_hp_fill.get_parent()
	enemy_area.add_child(hp_ctrl)
	enemy_area.move_child(hp_ctrl, 1)

	# Player HP bar - add to Player_area after Board
	var r2 = _build_hp_bar("Player")
	_player_hp_fill = r2[0]
	_player_hp_text = r2[1]
	_player_hp_max_label = r2[2]
	var player_area = $Main_layout/Player_area
	var hp_ctrl2 = _player_hp_fill.get_parent()
	player_area.add_child(hp_ctrl2)


func _build_hp_bar(label: String) -> Array:
	## 返回 [fill, text_label, max_label]
	var ctrl = Control.new()
	ctrl.name = label + "HPBar"
	ctrl.custom_minimum_size = Vector2(0, 38)
	ctrl.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# 背景 (深色底)
	var bg = ColorRect.new()
	bg.name = "BG"
	bg.color = Color(0.08, 0.08, 0.08, 1)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	ctrl.add_child(bg)

	# 填充条 (绿色 → 按 HP% 动态宽度)
	var fill = ColorRect.new()
	fill.name = "Fill"
	fill.color = Color(0.15, 0.75, 0.2, 1)
	fill.anchor_left = 0
	fill.anchor_top = 0
	fill.anchor_bottom = 1
	fill.anchor_right = 1  # 默认满血
	ctrl.add_child(fill)

	# 白色名字标签 (左侧)
	var name_lbl = Label.new()
	name_lbl.text = label
	name_lbl.anchor_left = 0
	name_lbl.anchor_top = 0
	name_lbl.anchor_bottom = 1
	name_lbl.offset_left = 12
	name_lbl.add_theme_font_size_override("font_size", 16)
	name_lbl.add_theme_color_override("font_color", Color.WHITE)
	name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ctrl.add_child(name_lbl)

	# 状态文本 (居中)
	var text = Label.new()
	text.name = "StatusText"
	text.set_anchors_preset(Control.PRESET_FULL_RECT)
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	text.add_theme_font_size_override("font_size", 14)
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ctrl.add_child(text)

	# 最大 HP (右侧)
	var max_lbl = Label.new()
	max_lbl.text = "100"
	max_lbl.anchor_top = 0
	max_lbl.anchor_right = 1
	max_lbl.anchor_bottom = 1
	max_lbl.offset_right = -12
	max_lbl.add_theme_font_size_override("font_size", 14)
	max_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	max_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	max_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	ctrl.add_child(max_lbl)

	return [fill, text, max_lbl]


func _update_hp_bars(_a = null, _b = null):
	## Character 的 health_changed / shielded 信号触发时调用
	if _player_character:
		_set_bar(_player_hp_fill, _player_hp_text, _player_hp_max_label, _player_character)
	if _enemy_character:
		_set_bar(_enemy_hp_fill, _enemy_hp_text, _enemy_hp_max_label, _enemy_character)


func _set_bar(fill: ColorRect, text: Label, max_lbl: Label, ch: Character):
	if not fill or not ch:
		return
	var ratio = clampf(float(ch.hp) / float(ch.max_hp), 0.0, 1.0)
	fill.anchor_right = ratio
	if ratio > 0.5:
		fill.color = Color(0.15, 0.75, 0.2, 1)
	elif ratio > 0.25:
		fill.color = Color(0.85, 0.7, 0.15, 1)
	else:
		fill.color = Color(0.8, 0.15, 0.1, 1)
	var s = "HP: " + str(ch.hp)
	if ch.shield > 0:
		s += "  Shield: " + str(ch.shield)
	text.text = s
	max_lbl.text = str(ch.max_hp)
