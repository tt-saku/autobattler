# 大巴扎式背包智能插入系统设计

## 1. 目标

实现类似《The Bazaar》的物品拖拽体验：

当玩家将物品拖入背包时，不要求目标区域必须完全空闲。

系统应自动移动周围物品，在保持物品相对顺序的前提下，为新物品腾出空间。

例如：

```
[a][o][b][o][ccc][ddd]
```

拖入一个长度为2的物品：

```
[ee]
```

并放置在 `b` 的右侧。

最终结果：

```
[a][b][ee][ccc][ddd]
```

而不是放置失败。

---

# 2. 核心思想

## 传统背包

大多数 RPG 背包采用：

```
Slot -> Item
```

模式。

放置时要求：

```
目标格子全部为空
```

否则失败。

---

## 大巴扎式背包

采用：

```
Inventory
	└ Item List
```

模式。

玩家实际上表达的是：

```
希望将物品插入到某个位置
```

而不是：

```
占用某几个格子
```

系统负责重新排列布局。

---

# 3. 数据模型

## Item

```gdscript
class ItemData

var id
var size
var start_slot
```

其中：

* id：唯一标识
* size：占用格数
* start_slot：起始槽位

---

## Inventory

```gdscript
class Inventory

var items = []
var slot_count = 10
```

items 保存物品顺序：

```gdscript
[
	item_a,
	item_b,
	item_ccc,
	item_ddd
]
```

注意：

这里不保存空格。

空格是布局结果，不是数据本身。

---

# 4. 插入规则

## Rule 1：保持相对顺序

原布局：

```
[a][b][ccc][ddd]
```

插入：

```
[ee]
```

得到：

```
[a][b][ee][ccc][ddd]
```

而不是：

```
[a][ccc][ee][b][ddd]
```

任何自动移动都不能改变原有物品顺序。

---

## Rule 2：允许整体位移

原布局：

```
[a][o][b][o][ccc][ddd]
```

插入：

```
[ee]
```

允许系统自动移动：

```
[a][b][ee][ccc][ddd]
```

只要顺序不变即可。

---

## Rule 3：优先最小移动

若存在多个合法结果：

选择总移动距离最短的方案。

例如：

原布局：

```
[a][o][b][o][o]
```

插入：

```
[ee]
```

方案A：

```
[a][b][ee][o][o]
```

方案B：

```
[a][o][b][ee][o]
```

应优先选择移动量更小的方案。

---

# 5. 推荐实现方案

## 压缩重建法

这是最容易维护的方案。

### 第一步

收集所有物品：

```
[a][o][b][o][ccc][ddd]
```

变为：

```
[a][b][ccc][ddd]
```

删除所有空洞。

---

### 第二步

根据拖拽结果确定插入位置。

例如：

```
[a][b]
	  ↑
   插入ee
```

得到：

```
[a][b][ee][ccc][ddd]
```

---

### 第三步

重新计算所有位置。

```gdscript
var cursor = 0

for item in items:
	item.start_slot = cursor
	cursor += item.size
```

---

### 第四步

重建槽位占用信息。

```gdscript
for slot in slots:
	slot.occupying_item = null

for item in items:
	occupy_slots(item)
```

---

# 6. 拖拽判定

## 不要计算格子

不要判断：

```
放到第几个slot
```

应判断：

```
插入到第几个物品之后
```

例如：

```
[a][b][ccc]
```

拖到：

```
a 和 b 中间
```

得到：

```gdscript
insert_index = 1
```

然后：

```gdscript
items.insert(insert_index, new_item)
```

最后：

```gdscript
rebuild_layout()
```

---

# 7. 布局重建

统一入口：

```gdscript
func rebuild_layout():
```

负责：

1. 清空所有占用状态
2. 重新计算起始位置
3. 更新占用格
4. 播放移动动画

---

示例：

```gdscript
func rebuild_layout():

	var cursor = 0

	for item in items:
		item.start_slot = cursor
		cursor += item.size

	clear_slots()

	for item in items:
		occupy_slots(item)
```

---

# 8. 动画系统

逻辑与显示分离。

布局更新后：

```gdscript
item.target_position
```

发生变化。

物品使用 Tween 滑动：

```gdscript
create_tween()
```

从旧位置移动到新位置。

视觉效果：

```
拖入
↓
其它物品自动滑开
↓
形成空位
↓
新物品插入
```

与《The Bazaar》体验一致。

---

# 9. 容量检查

插入前检查：

```gdscript
total_size + new_item.size <= slot_count
```

若超出容量：

```
插入失败
```

否则允许重排。

---

# 10. 最终架构

推荐结构：

```
Inventory
│
├── items[]
│
├── insert_item()
├── remove_item()
├── rebuild_layout()
│
└── slots[]
```

职责：

### Inventory

负责：

* 插入
* 删除
* 排序
* 自动重排

### Item

负责：

* 数据
* 动画

### Slot

负责：

* 显示占用状态

不负责布局逻辑。

---

# 11. 一句话总结

《The Bazaar》的背包本质上不是“格子背包”。

它更接近：

```
带长度属性的有序列表（Ordered Interval List）
```

玩家操作的是：

```
插入一个物品
```

系统负责：

```
保持顺序
→ 自动压缩
→ 重新布局
→ 播放滑动动画
```

这就是智能推挤与自动滑动系统的核心逻辑。
