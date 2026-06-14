项目名称：autobattler_TheBazaar_mod
开发引擎：Godot 4.6.3
开发语言：GDScript
分辨率：1920×1080

已完成：
✅ 拖拽系统（三级智能放置：直接放→压缩滑动→拒绝）
✅ 拖拽源 (ItemInstance._get_drag_data)
✅ 拖放目标 (Slot._can_drop_data / _drop_data)
✅ 拖拽高亮预览（绿色有效/红色无效）
✅ 智能压缩滑动（物品>空隙时自动左滑腾空间）
✅ 物品动态尺寸（小90×130, 中180×130, 大270×130）
✅ 槽位紧密排列（间距0, 外框边框）
✅ 商店/背包视图切换
✅ 双向拖拽（商店↔玩家棋盘）
✅ 物品A/B面颜色反馈（蓝色A面/红色B面）
✅ 战斗引擎（TickScheduler / EventBus / Character / CombatItem）
✅ CD系统（进度条横杠从底升顶 / Haste×2 / Slow×0.5 / Freeze暂停）
✅ 效果系统（damage / heal / shield / haste / slow / freeze 六种）
✅ 战斗日志（可滚动RichTextLabel，BBCode彩色事件记录）
✅ HP状态条（绿→黄→红填充，38px高，实时HP/护盾/最大HP显示）
✅ 物品悬浮提示框（跟鼠标、黑底蓝灰边框、屏幕内钳制）
✅ CD进度条（3px亮蓝横杠从卡底升到卡顶）
✅ 9个测试物品（覆盖小中大 + 六种效果类型）
✅ 1080p分辨率 + 棋盘居中 + 按钮右置

当前尚未完成：
翻面系统
燃烧/剧毒/生命再生状态系统
弹药系统
摧毁/修复系统
商店购买系统
AI对手
