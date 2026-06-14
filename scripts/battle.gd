extends Control

@onready var enemy_label = $Main_layout/Enemy_area/Label
@onready var enemy_board: Board = $Main_layout/Enemy_area/Enemy_board
@onready var player_board: Board = $Main_layout/Player_area/Player_board
@onready var backpack_btn = $Backpack_btn

var slot_scene = preload("res://scenes/slot.tscn")
var player_slots = []
var enemy_slots = []

enum EnemyView { SHOP, ENEMY, BACKPACK }
var current_enemy_view: EnemyView = EnemyView.SHOP
var _shop_stored: Array = []
var _backpack_stored: Array = []


func _ready():
	create_board(enemy_board, enemy_slots)
	create_board(player_board, player_slots)

	enemy_board.initialize()
	player_board.initialize()

	backpack_btn.pressed.connect(_on_backpack_btn_pressed)

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
	var templates = [
		preload("res://items/test_small.tres"),
		preload("res://items/test_medium.tres"),
		preload("res://items/test_large.tres"),
		preload("res://items/dooley/capacitor_bronze.tres"),
		preload("res://items/karnok/flying_squirrel.tres"),
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
			enemy_board.insert_item_at_slot(item, 99)

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
			enemy_board.insert_item_at_slot(item, 99)

	current_enemy_view = EnemyView.BACKPACK
	enemy_label.text = "🎒 Backpack"
	backpack_btn.text = "🛒 Shop"
