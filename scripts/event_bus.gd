# event_bus.gd — 战斗事件总线 (autoload 单例)
# 用法：
#   EventBus.on("on_damage", _my_callback)
#   EventBus.emit("on_damage", {"value": 20, "target": enemy})
extends Node

## 事件类型常量
const ON_BATTLE_START  = "on_battle_start"
const ON_BATTLE_END    = "on_battle_end"
const ON_DAMAGE        = "on_damage"
const ON_HEAL          = "on_heal"
const ON_SHIELD        = "on_shield"
const ON_CRIT          = "on_crit"
const ON_KILL          = "on_kill"
const ON_DEATH         = "on_death"
const ON_ITEM_TRIGGER  = "on_item_trigger"
const ON_FACE_FLIP     = "on_face_flip"

## { event_name: Array[Callable] }
var _listeners: Dictionary = {}


func on(event_name: String, callback: Callable):
	## 订阅事件
	if not _listeners.has(event_name):
		_listeners[event_name] = []
	_listeners[event_name].append(callback)


func off(event_name: String, callback: Callable):
	## 取消订阅
	if _listeners.has(event_name):
		_listeners[event_name].erase(callback)


func emit(event_name: String, data: Dictionary = {}):
	## 广播事件。data 应包含标准的 time / source / target 等字段
	if not _listeners.has(event_name):
		return
	for cb in _listeners[event_name]:
		if cb.is_valid():
			cb.call(data)


func clear():
	## 清空所有监听（用于战斗结束后重置）
	_listeners.clear()
