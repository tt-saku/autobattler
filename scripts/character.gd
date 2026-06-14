# character.gd — 战斗角色 (HP / Shield / 死亡判定)
class_name Character
extends Node

signal damaged(actual_damage: int, source)
signal healed(amount: int)
signal shielded(amount: int)
signal died()
signal health_changed(current_hp: int, max_hp: int)

@export var max_hp: int = 100
@export var character_name: String = ""

var hp: int = 100
var shield: int = 0


func _ready():
	hp = max_hp


func take_damage(value: int) -> int:
	## 返回实际扣除的 HP 量。
	## 伤害先作用 Shield → 再作用 HP
	var remaining = value

	# Shield 吸收
	if shield > 0:
		var absorbed = mini(shield, remaining)
		shield -= absorbed
		remaining -= absorbed

	# HP 扣除
	var actual = 0
	if remaining > 0:
		actual = remaining
		hp -= actual

	damaged.emit(actual, null)
	health_changed.emit(hp, max_hp)

	if hp <= 0:
		hp = 0
		died.emit()

	return actual


func heal(value: int) -> int:
	## 回复 HP（不超上限），返回实际回复量
	var old = hp
	hp = mini(hp + value, max_hp)
	var actual = hp - old

	if actual > 0:
		healed.emit(actual)
		health_changed.emit(hp, max_hp)

	return actual


func add_shield(value: int) -> int:
	## 叠加护盾，返回当前护盾量
	shield += value
	shielded.emit(value)
	return shield


func is_dead() -> bool:
	return hp <= 0


func reset():
	hp = max_hp
	shield = 0
