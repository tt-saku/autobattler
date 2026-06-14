# The Bazaar Like Game 开发路线图（Godot 4）

---

# 当前项目状态

已经完成：

* 物品数据模板
* 物品实例
* 拖拽逻辑
* 背包系统
* 背包重排逻辑

尚未完成：

* 战斗引擎
* Buff系统
* Event系统
* 技能系统
* AI系统
* 数值系统

---

# 第一阶段：搭建最小战斗循环

目标：

实现第一场能打完的战斗。

不要制作任何复杂词条。

只允许：

* 伤害
* 护盾
* 治疗
* 冷却
* 死亡

---

## Step1 角色类

创建：

Character.gd

```gdscript
class_name Character

var max_hp := 100
var hp := 100

var shield := 0

var inventory = []
```

---

## Step2 基础接口

```gdscript
func take_damage(value:int):

	if shield > 0:

		var absorbed = min(shield,value)

		shield -= absorbed
		value -= absorbed

	if value > 0:
		hp -= value

	if hp <= 0:
		die()
```

---

```gdscript
func heal(value:int):

	hp += value

	hp = min(hp,max_hp)
```

---

```gdscript
func add_shield(value:int):

	shield += value
```

---

## Step3 BattleManager

创建：

BattleManager.gd

负责：

* 更新双方物品
* 判断胜负
* 控制战斗速度

```gdscript
Player
Enemy

while battle_running:
	update_items()
	check_winner()
```

---

## Step4 CombatItem

所有战斗物品继承：

```gdscript
class_name CombatItem

var owner

var cooldown := 5.0

var current_cd := 0.0
```

---

更新：

```gdscript
func update(delta):

	current_cd += delta

	if current_cd >= cooldown:

		current_cd = 0

		activate()
```

---

## Step5 第一件武器

Sword

```gdscript
func activate():

	target.take_damage(20)
```

---

目标：

实现：

```text
武器
↓
造成伤害
↓
护盾抵挡
↓
扣血
↓
死亡
```

完成后不要继续加词条。

进入第二阶段。

---

# 第二阶段：事件系统

这是整个项目最重要的部分。

大巴扎不是：

```text
物品触发
```

而是：

```text
事件触发
```

---

建立：

BattleEventBus

---

支持事件：

```text
OnBattleStart

OnUse

OnDamage

OnHeal

OnShield

OnKill

OnDeath

OnCrit

OnBurn

OnPoison
```

---

接口：

```gdscript
BattleEventBus.emit(
	"on_damage",
	data
)
```

---

监听：

```gdscript
func on_damage(event):
	pass
```

---

以后：

```text
受到伤害时回血

暴击时获得护盾

治疗时造成伤害
```

都可以通过事件实现。

---

# 第三阶段：效果执行链

不要让物品直接修改数据。

错误：

```gdscript
target.hp -= 20
```

正确：

```gdscript
DamageEffect
```

---

建立：

```text
Effect
│
├ DamageEffect
├ HealEffect
├ ShieldEffect
├ BurnEffect
├ PoisonEffect
```

---

统一接口：

```gdscript
func execute(
	source,
	target
)
```

---

示例：

```gdscript
DamageEffect.execute(
	player,
	enemy
)
```

---

以后所有词条都通过 Effect 执行。

---

# 第四阶段：Buff系统

创建：

StatusEffect

---

统一结构：

```gdscript
class_name StatusEffect

var stacks := 1

var duration := -1
```

---

生命周期：

```gdscript
on_apply()

on_tick()

on_remove()
```

---

角色拥有：

```gdscript
var status_effects = {}
```

---

添加状态：

```gdscript
add_status(effect)
```

---

删除状态：

```gdscript
remove_status(effect)
```

---

# 第五阶段：基础词条

开发顺序：

## Damage

```text
造成伤害
```

---

## Shield

```text
获得护盾
```

---

## Heal

```text
恢复生命
```

---

## MaxHealth

```text
增加生命上限
```

---

## Regen

```text
每秒恢复生命
```

---

此时完成：

```text
坦克流
回复流
基础战斗
```

---

# 第六阶段：持续伤害系统

---

## Burn

```text
每0.5秒造成一次伤害
每一秒层数减1
对护盾伤害减半
```

例：

```text
Burn 10

10
9
8
7
...
```

---

## Poison

```text
每秒造成一次伤害
层数不减少
忽视护盾直接作用于血量
```

例：

```text
Poison 10

10
10
10
10
...
```
---

# 第七阶段：充能系统

开始接近大巴扎核心。

---

## Charge

```text
直接推进冷却进度xx秒
```

---

## Haste

```text
提高充能速度一倍xx秒
```

---

## Slow

```text
降低充能速度一倍xx秒
```

---

## Freeze

```text
暂停充能xx秒
```

---

实现：

```gdscript
if frozen:
	return
```

---

# 第八阶段：暴击系统

角色属性：

```gdscript
crit_rate

crit_multiplier
```

---

攻击时：

```gdscript
if is_crit:
	value *= crit_multiplier
```

---

支持：

```text
伤害暴击

治疗暴击

护盾暴击
```

---

# 第九阶段：弹药系统

物品新增：

```gdscript
ammo

max_ammo
```

---

触发：

```gdscript
ammo -= 1
```

---

Ammo为0：

```gdscript
停止充能
```

---

## Reload

```text
恢复弹药
```

---

# 第十阶段：高级词条

---

## Destroy

摧毁物品

```gdscript
is_destroyed = true
```

---

## Silence

沉默

禁止触发

---

## Stun

眩晕

禁止所有行动

---

## Invincible

无敌

```gdscript
伤害归零
```

---

## Reflect

反伤

```text
受到伤害时反弹
```

---

## Lifesteal

吸血

```text
造成伤害后恢复生命
```

---

# 第十一阶段：Modifier系统

这是后期核心。

---

例：

```text
获得护盾
↓
改为造成伤害
```

---

建立：

Modifier

```gdscript
modify(effect)
```

---

例：

```text
Shield → Damage

Heal → Shield

Poison → Burn
```

---

以后传奇装备都依赖它。

---

# 第十二阶段：数据驱动

不要写：

```gdscript
if sword:
```

---

改成：

items.json

```json
{
	"id":"test_sword",
	"name":"Test Sword",
	"cooldown":5,
	"effects":[
		{
			"type":"damage",
			"value":20
		}
	]
}
```

---

加载：

```gdscript
ItemFactory
```

生成：

```gdscript
CombatItem
```

---

# 第十三阶段：装备标签系统

增加：

```text
Weapon
Tool
Companion
Food
Vehicle
Magic
Gun
Ammo
```

---

实现：

```gdscript
tags = []
```

---

用于：

```text
所有Weapon获得20伤害

所有Food获得护盾
```

---

# 第十四阶段：AI系统

最简单：

```text
自动使用装备
```

即可。

---

后续：

```text
目标选择

优先治疗

优先输出

优先冻结
```

---

# 第十五阶段：数值平衡
# 这个部分先不采用
建议：

```text
普通物品
伤害 10~40

精良
30~80

史诗
80~200
```

---

# 最终架构

```text
BattleManager

Character

Inventory

CombatItem

Effect

Modifier

StatusEffect

BattleEventBus

AIController

DataLoader
```

---

# 开发完成标志

达到以下条件：

✓ 50+物品

✓ 20+状态

✓ 5+流派

✓ 数据驱动

✓ AI对战

✓ Buff系统

✓ Event系统

✓ Modifier系统

此时已经达到 The Bazaar 核心框架的80%以上。
