# effect.gd — 战斗效果数据容器
class_name Effect
extends RefCounted

# 效果类型: damage / heal / shield
var type: String = ""
# 效果数值
var value: float = 0.0
# 来源（ItemInstance / Character）
var source: Object = null
# 目标 Character
var target: Object = null


func _init(p_type: String = "", p_value: float = 0.0,
		p_source: Object = null, p_target: Object = null):
	type = p_type
	value = p_value
	source = p_source
	target = p_target


func describe() -> String:
	var src_name = "?"
	if source and source.has_method("get_display_name"):
		src_name = source.get_display_name()
	elif source and source is ItemInstance and source.data:
		src_name = source.data.name

	var tgt_name = "?"
	if target and target is Character:
		tgt_name = target.character_name

	match type:
		"damage":
			return "%s 造成 %d 伤害 → %s" % [src_name, int(value), tgt_name]
		"heal":
			return "%s 恢复 %d 生命 → %s" % [src_name, int(value), tgt_name]
		"shield":
			return "%s 获得 %d 护盾 → %s" % [src_name, int(value), tgt_name]
		_:
			return "%s: %s(%d) → %s" % [src_name, type, int(value), tgt_name]
