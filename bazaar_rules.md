# bazaar_rules.md（完整统一战斗规则基准 / Godot实现向）

> 本文档定义类 The Bazaar 自动战斗系统的完整规则模型  
> 核心：Tick驱动 + 状态系统 + Effect管线 + 资源对抗 + 构筑驱动（build-driven）

---

# 0. 核心设计原则
## 0.1 时间系统（关键）
系统不是固定 Tick，而是**高精度模拟 + 语义Tick**
Simulation Step：0.05 ~ 0.1s（推荐实现）
语义Tick：0.5s / 1s（用于DoT/规则表达）
## 0.2 执行管线（核心架构）
Item Trigger
→ Effect生成
→ Modifier修正
→ Crit判定
→ 数值结算
→ 状态更新
→ Event广播
## 0.3 设计目标
所有效果必须可组合
所有数值必须可追溯来源
所有状态必须可叠加
所有系统必须基于统一时间推进
禁止玩家全局属性主导战斗

# 1. 伤害系统（Damage）
## 1.1 基础规则
Damage → 先作用 Shield → 再作用 HP
Shield不会完全阻挡一次伤害。比如：10 HP + 2 Shield 受到 3 伤害 会变成 9 HP
## 1.2 暴击系统（Crit）
Crit = 数值 × crit_multiplier（默认2.0）
以下词条可造成暴击：
Damage
Heal
Shield
Burn
Poison
Regen
以下词条不参与暴击：
Freeze
Slow
Haste
Charge等不在白名单的词条
## 1.3 暴击来源
暴击率就像物品的价值、词条等，是物品的属性，也可以成长。
不是 Player 的属性
举例：某物品的主动效果是：cd3.0s，使得相邻物品暴击率+5%。

# 2. 护盾系统（Shield）
Shield = 优先吸收所有非穿透伤害
护盾受到火焰伤害减半
Shield不会完全阻挡一次伤害。比如：10 HP + 2 Shield 受到 3 伤害 会变成 9 HP

# 3. 火焰 Burn（递减型DoT）
## 3.1 Tick
约 0.5 秒触发一次
## 3.2 规则
每 Tick：
- 造成 Burn 当前值伤害
- Burn -1
## 3.3 Shield交互
若目标有 Shield：Burn伤害 × 0.5
## 3.4 Heal交互
每次 Heal：移除 Burn = Heal × 10%
## 3.5 特性
Burn = 高频递减DoT + 护盾减半 + 会被对面的治疗所净化

# 4. 剧毒 Poison（稳定型DoT）
## 4.1 Tick
每 1 秒触发一次
## 4.2 规则
Poison伤害 = 当前层数
不衰减
## 4.3 Shield规则
Poison 无视 Shield
## 4.4 Heal交互
每次 Heal：移除 Poison = Heal × 10%
## 4.5 特性
Poison = 稳定持续伤害 + 无视护盾 + 会被对面的治疗所净化

# 5. 生命再生 Regen
## 5.1 Tick
每 1 秒恢复一次
## 5.2 规则
Regen = 直接回血
不会超过最大生命值
不影响护盾
## 5.3 与 Poison
同Tick系统 → 相互抵消趋势
## 5.4 与 Burn
只能抵消整数秒的火焰（因为火焰每0.5s伤害一次，生命再生每1s回复一次）

# 6. 治疗 Heal（核心系统）
## 6.1 基础效果
立即恢复 HP
不会超过最大生命值，超额回复的时候可以触发“过量回复”
不影响护盾
## 6.2 净化机制
Heal = 同时净化：
Burn = Heal × 10%
Poison = Heal × 10%
## 6.3 系统定位
Heal = 恢复 + 状态清除入口

# 7. 冷却系统（Cooldown）
## 7.1 基础模型
Cooldown随时间推进（高频更新），体现在进度条（每一张卡面从下到上的光效）
## 7.2 Haste
进度条速度×2
## 7.3 Slow
进度条速度×0.5
## 7.4 Freeze（关键控制）
冻结期间：
- 冷却停止（不走进度条）
- 物品无法触发（即使进度条满了也不能触发，类似有子弹槽的物品在没子弹以后）
- 被冻结的物品可以被充能（Charge）

# 8. 充能系统（Charge）
Charge = 直接推进Cooldown进度（进度条突跃）

# 9. 飞行 Flying
Flying = 控制效果减半（Freeze / Slow 的影响时间 × 0.5）
起降系统：物品可以被起飞（进入飞行状态），可以被降落（回到未飞行状态）

# 10. 弹药系统（Ammo）
没有弹药槽的物品默认不消耗弹药
有弹药槽的物品，每触发一次消耗一格弹药，没有弹药可以消耗则不会被触发（但是进度条会读满卡在最上面）
Ammo = 使用次数限制
装填（Reload）可以恢复Ammo，默认装填只回复一发弹药

# 11. 摧毁 Destroy
摧毁（Destroy）：使其在本场战斗永久失效
效果：停止触发、被动失效、占用槽位
修复（Repair）：修复被摧毁的物品

# 12. 状态系统（Status System）
## 12.1 标准结构
StatusEffect:
- stacks
- duration
- tick()
- on_apply()
- on_remove()
## 12.2 状态类型
人物血量条的状态：当前HP、最大生命值、护盾、Burn、Poison、Regen
物品的状态：Freeze、Slow、Haste、Destroy

# 13. 事件系统（Event Bus）
## 13.1 事件类型
OnDamage
OnHeal
OnShield
OnBurn
OnPoison
OnCrit
OnKill
OnDeath
## 13.2 作用
用于：
物品之间的间接触发与联动

# 14. 暴击系统（Crit）
## 14.1 本质
Crit = Effect修正节点
## 14.2 模型
if rand < crit_chance:
	value *= crit_multiplier
## 14.3 来源
Item
Buff
状态
装备词条

# 15. Tick执行顺序（核心）
Freeze检查
Cooldown推进
Item触发
Effect生成
Modifier修正
Crit判定
Shield结算
HP结算
DoT结算（Burn/Poison）
Regen结算
状态更新
Event广播

# 16. 核心机制关系图
Burn → Shield减半 → Heal净化
Poison → 无视Shield → Heal净化
Regen → 对抗Poison
Freeze → 控制Cooldown
Charge → 推进Cooldown
Haste/Slow → 改变时间效率
Crit → 修正所有数值类Effect

# 17. 架构建议（Godot实现）
BattleManager
├── TickScheduler
├── EventBus
├── CooldownSystem
├── EffectSystem
├── ModifierSystem
├── CritSystem
├── StatusSystem
│   ├── Burn
│   ├── Poison
│   ├── Regen
│   ├── Freeze
│   └── Slow
├── ShieldSystem
├── ItemSystem
└── DamageSystem

# 18. 设计禁区（非常重要）
Burn ≠ 普通DoT
Poison ≠ 护盾伤害
Regen ≠ DoT反转
Heal ≠ 单纯回血
Crit ≠ 玩家属性
不允许多时间系统混乱实现

# 19. 最终核心总结
The Bazaar 风格战斗系统本质：
Tick驱动（高频模拟）
+ 状态叠加系统
+ Effect修正管线
+ 资源对抗模型
+ 构筑驱动（build-driven）
