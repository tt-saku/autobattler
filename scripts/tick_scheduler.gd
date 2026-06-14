# tick_scheduler.gd — 战斗循环驱动器
class_name TickScheduler
extends Node

var _combat_items: Array[CombatItem] = []
var _player_items: Array[CombatItem] = []
var _enemy_items: Array[CombatItem] = []
var _player_char: Character = null
var _enemy_char: Character = null
var _running: bool = false
var _elapsed: float = 0.0

signal battle_started()
signal battle_ended(winner: Character)


func setup(player_char: Character, enemy_char: Character, combat_items: Array[CombatItem]):
	_player_char = player_char
	_enemy_char = enemy_char
	_combat_items = combat_items

	# 按所属分组
	_player_items.clear()
	_enemy_items.clear()
	for ci in _combat_items:
		if is_instance_valid(ci):
			ci.activated.connect(_on_item_activated.bind(ci))
			if ci.owner_character == _player_char:
				_player_items.append(ci)
			else:
				_enemy_items.append(ci)

	# 监听角色死亡
	if _player_char:
		_player_char.died.connect(_on_character_died)
	if _enemy_char:
		_enemy_char.died.connect(_on_character_died)


func start():
	_running = true
	_elapsed = 0.0
	print("[Battle] 开始! 玩家 HP=", _player_char.hp, " 敌人 HP=", _enemy_char.hp)
	EventBus.emit(EventBus.ON_BATTLE_START, {
		"player": _player_char,
		"enemy": _enemy_char,
		"time": _elapsed
	})
	battle_started.emit()


func stop():
	_running = false


func _process(delta: float):
	if not _running:
		return

	_elapsed += delta

	# 1. Tick 所有战斗物品
	for ci in _combat_items:
		if is_instance_valid(ci) and ci.item_instance and is_instance_valid(ci.item_instance):
			ci.tick(delta)


func _on_item_activated(effect: Effect, source_ci: CombatItem):
	## 收到 CombatItem.activated → 执行 Effect
	if not _running:
		return

	if not effect:
		return  # 自我 buff（haste 等），无需处理

	var target: Character = effect.target

	match effect.type:
		"damage":
			if not target:
				return
			var actual = target.take_damage(int(effect.value))
			EventBus.emit(EventBus.ON_DAMAGE, {
				"value": int(effect.value),
				"actual": actual,
				"source": effect.source,
				"target": target,
				"time": _elapsed
			})
		"heal":
			if not target:
				return
			var actual = target.heal(int(effect.value))
			EventBus.emit(EventBus.ON_HEAL, {
				"value": int(effect.value),
				"actual": actual,
				"source": effect.source,
				"target": target,
				"time": _elapsed
			})
		"shield":
			if not target:
				return
			target.add_shield(int(effect.value))
			EventBus.emit(EventBus.ON_SHIELD, {
				"value": int(effect.value),
				"source": effect.source,
				"target": target,
				"time": _elapsed
			})
		"slow":
			# 对敌人全体物品减速
			var enemy_items = _get_enemy_items(source_ci)
			for ci in enemy_items:
				if is_instance_valid(ci):
					ci.apply_slow(effect.value)
			EventBus.emit(EventBus.ON_ITEM_TRIGGER, {
				"source": effect.source,
				"type": "slow",
				"value": effect.value,
				"target_count": enemy_items.size(),
				"time": _elapsed
			})
		"freeze":
			# 冻结敌人全体物品
			var enemy_items = _get_enemy_items(source_ci)
			for ci in enemy_items:
				if is_instance_valid(ci):
					ci.apply_freeze(effect.value)
			EventBus.emit(EventBus.ON_ITEM_TRIGGER, {
				"source": effect.source,
				"type": "freeze",
				"value": effect.value,
				"target_count": enemy_items.size(),
				"time": _elapsed
			})


func _get_enemy_items(source_ci: CombatItem) -> Array[CombatItem]:
	## 返回来源物品的对立阵营 CombatItem 列表
	if source_ci.owner_character == _player_char:
		return _enemy_items
	else:
		return _player_items


func _on_character_died():
	## 任意一方死亡 → 判定胜负
	if not _running:
		return

	_running = false

	var winner: Character = null
	if _player_char and _player_char.is_dead():
		winner = _enemy_char
	elif _enemy_char and _enemy_char.is_dead():
		winner = _player_char

	EventBus.emit(EventBus.ON_BATTLE_END, {
		"winner": winner,
		"time": _elapsed
	})
	battle_ended.emit(winner)
	print("[Battle] 结束! 胜者=", winner.character_name if winner else "无")
