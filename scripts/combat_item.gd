# combat_item.gd — 战斗物品 (CD推进 / 技能激活)
class_name CombatItem
extends Node

## 引用的 UI 物品实例
var item_instance: ItemInstance = null
## 攻击目标
var target_character: Character = null
## 所属角色
var owner_character: Character = null

## 当前 CD 进度 (0 → cooldown 时触发)
var current_cd: float = 0.0
## 当前 CD 上限 (= cd_a 或 cd_b，取决于面)
var cooldown: float = 1.0

# 状态标记 (Phase 2+ 实现)
var _is_destroyed: bool = false
var _freeze_timer: float = 0.0
var _haste_timer: float = 0.0
var _slow_timer: float = 0.0

signal activated(effect: Effect)


func _ready():
	if item_instance and item_instance.data:
		_refresh_from_face()
	# 初始随机偏移，避免所有物品同步触发
	current_cd = randf_range(0.0, cooldown * 0.5)


func _refresh_from_face():
	## 根据当前面读取 CD
	if item_instance.current_face == "A":
		cooldown = item_instance.data.cd_a
	else:
		cooldown = item_instance.data.cd_b
	cooldown = maxf(cooldown, 0.5)  # 最小 0.5s


func tick(delta: float):
	## 每帧由 TickScheduler 调用
	if _is_destroyed:
		return

	# Freeze 暂停 CD
	if _freeze_timer > 0:
		_freeze_timer -= delta
		_update_item_visual()
		return

	# 速度倍率
	var speed_mult = 1.0
	if _haste_timer > 0:
		speed_mult = 2.0
		_haste_timer -= delta
	elif _slow_timer > 0:
		speed_mult = 0.5
		_slow_timer -= delta

	current_cd += delta * speed_mult

	if current_cd >= cooldown:
		_activate()

	_update_item_visual()


func _update_item_visual():
	if item_instance and is_instance_valid(item_instance):
		item_instance.update_cd_bar(current_cd, cooldown)


func _activate():
	## CD 满 → 生成 Effect → 发射信号 → 重置 CD
	var effect = _build_effect()
	if effect:
		activated.emit(effect)
	# 保留溢出时间
	current_cd -= cooldown


func _build_effect() -> Effect:
	## 解析 effect_a / effect_b 文本 → Effect 对象
	## 格式: "type value"  如 "damage 20", "heal 10", "haste 3"
	var effect_text = item_instance.data.effect_a if item_instance.current_face == "A" else item_instance.data.effect_b
	var info = _parse_effect_text(effect_text)
	var etype: String = info["type"]
	var evalue: float = info["value"]

	if evalue <= 0:
		return null

	match etype:
		"haste":
			# 自我加速 — 不产生 Effect
			apply_haste(evalue)
			EventBus.emit(EventBus.ON_ITEM_TRIGGER, {
				"source": item_instance, "type": "haste", "value": evalue, "self": true
			})
			return null

		"heal", "shield":
			return Effect.new(etype, evalue, item_instance, owner_character)

		"slow", "freeze":
			# 敌人全体 debuff — TickScheduler 负责分发
			return Effect.new(etype, evalue, item_instance, null)

		_:
			# 默认: damage → 目标为敌方角色
			return Effect.new("damage", evalue, item_instance, target_character)


func _parse_effect_text(text: String) -> Dictionary:
	## 从效果文本提取 (type, value)。
	## 支持: "damage 20", "heal 10", "shield 15", "haste 3", "slow 2", "freeze 1.5"
	## 旧格式兼容: "a", "b", "f" → 默认 damage 10
	var trimmed = text.strip_edges()
	if trimmed.is_empty() or trimmed in ["a", "b", "f"]:
		return {"type": "damage", "value": 10.0}

	# 尝试 "type value" 格式
	var parts = trimmed.split(" ", false, 1)
	var etype = parts[0].to_lower() if parts.size() > 0 else "damage"
	var evalue = 10.0

	if parts.size() > 1:
		var regex = RegEx.new()
		regex.compile("\\d+(\\.\\d+)?")
		var m = regex.search(parts[1])
		if m:
			evalue = float(m.get_string())

	# 向后兼容: 纯数字或纯文本当 damage
	var valid_types = ["damage", "heal", "shield", "haste", "slow", "freeze"]
	if etype not in valid_types:
		# 可能是纯数字 "20" 或旧格式 "charge adjacent items 1 second"
		var regex = RegEx.new()
		regex.compile("\\d+(\\.\\d+)?")
		var m = regex.search(trimmed)
		if m:
			return {"type": "damage", "value": float(m.get_string())}
		return {"type": "damage", "value": 10.0}

	return {"type": etype, "value": evalue}


func is_frozen() -> bool:
	return _freeze_timer > 0


func apply_freeze(duration: float):
	_freeze_timer = maxf(_freeze_timer, duration)


func apply_haste(duration: float):
	_haste_timer = maxf(_haste_timer, duration)


func apply_slow(duration: float):
	_slow_timer = maxf(_slow_timer, duration)


func destroy():
	_is_destroyed = true


func get_display_name() -> String:
	if item_instance and item_instance.data:
		return item_instance.data.name
	return "Unknown"
