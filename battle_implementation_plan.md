# 战斗引擎实现计划

> 基于 `battle_engine.md` (Phase 1) + `bazaar_rules.md` (完整规则模型)
> 策略：MVP范围用完整架构骨架

---

## 架构概览

```
battle.gd (场景控制器，已有)
    │
    └── BattleEngine (Control 节点)
          ├── TickScheduler    — 统一时钟 (0.1s step)
          ├── EventBus         — 事件广播 (autoload)
          ├── Character        — 双方角色 (HP/Shield/物品列表)
          └── CombatItem       — 战斗物品 (CD/效果/所属)
```

## 核心数据流

```
Tick (0.1s) → 遍历双方物品
  → Cooldown 推进 (+0.1s)  
  → CD 满了？→ activate(item)
      → 生成 Effect {type:"damage", value:20, target:enemy}
      → EventBus.emit("on_damage", data)
      → target.take_damage(20)
          → shield 吸收 → hp 扣除 → 死亡检查
              → EventBus.emit("on_death", ...)
  → 检查胜负 → 结束或继续
```

## Tick 执行顺序（对齐 bazaar_rules §15）

```
TickScheduler._process(delta):
  1. Freeze 检查           ← 先跳过，Phase 2+
  2. Cooldown 推进         ← CombatItem.tick(delta)
  3. Item 触发             ← activate() → Effect 生成
  4. Shield 结算           ← Character.take_damage() 内部
  5. HP 结算               ← 同上
  6. 死亡检查              ← is_dead() → EventBus
  7. 胜负判定              ← BattleEngine
```

---

## 实现步骤

| Step | 内容 | 涉及文件 |
|------|------|----------|
| 1 | Character + Effect 基础层 | `scripts/character.gd`, `scripts/effect.gd` (新建) |
| 2 | CombatItem CD与激活 | `scripts/combat_item.gd` (新建), `scripts/item_instance.gd` (改) |
| 3 | EventBus 事件总线 | `scripts/event_bus.gd` (新建), autoload 注册 |
| 4 | TickScheduler + Fight按钮 | `scripts/tick_scheduler.gd` (新建), `scripts/battle.gd` (改) |
| 5 | 战斗日志 | `scripts/battle.gd` 改动 Battle_log Panel |

---

## 新建文件清单

| 文件 | 职责 |
|------|------|
| `scripts/character.gd` | HP/Shield/死亡/治疗 |
| `scripts/effect.gd` | 效果数据容器 |
| `scripts/combat_item.gd` | CD推进/技能激活 |
| `scripts/event_bus.gd` | 事件发布订阅 (autoload) |
| `scripts/tick_scheduler.gd` | 统一时间驱动 |
