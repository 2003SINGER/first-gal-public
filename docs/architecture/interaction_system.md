# Interaction System — S04–S06 graybox

## LockerCleanup 职责

`res://scenes/interaction/locker_cleanup.tscn` +
`res://scripts/interaction/locker_cleanup.gd` 是一次独立、一次性的柜子整理交互。

它只负责：

- 展示 5 个灰盒物品并查看说明；
- 对每件物品做 `keep` / `discard`；
- 在最终保留数量超过上限时进入“腾个位置”；
- 发出 `finished(result)`。

LockerCleanup 不知道 S05，不启动 Dialogic，也不跳转下一段 Timeline。

## Dialogic 如何启动 Gameplay

`NarrativeBridge` 继续接收 Dialogic Alpha20 的标准 Signal Event。当前新增语义命令：

```text
interaction:locker_cleanup
```

Bridge 把它转给 `InteractionController.start_interaction("locker_cleanup")`。
InteractionController 实例化 LockerCleanup，并设置 `Dialogic.paused = true`。

## Gameplay 如何结束

LockerCleanup 发出 `finished(result)` 后，InteractionController：

1. 保存结果；
2. 关闭并释放 LockerCleanup；
3. 发出 `interaction_finished`；
4. 设置 `Dialogic.paused = false`。

Dialogic Alpha20 的 `handle_event()` 在暂停期间会等待 `dialogic_resumed`，所以 Signal Event 后面的对白不会在柜子界面打开时提前运行。

## result 数据结构

```gdscript
{
    "kept": PackedStringArray,
    "discarded_initially": PackedStringArray,
    "discarded_later": PackedStringArray,
    "returned": PackedStringArray,            # e.g. ye_xiao_pen 还给叶晓
    "overpacked_once": bool,                  # 包是否曾溢出（仅 S05 即时分支用）
}
```

当前 shell 生命周期内，结果还会保存在：

```text
InteractionController.last_locker_result
InteractionController.locker_items_kept
InteractionController.locker_items_discarded_initially
InteractionController.locker_items_discarded_later
InteractionController.locker_items_returned
```

这不是存档，也不是完整 GameState。`overpacked_once` / `locker_overpacked` 仅用于 S05 结束时的即时分支，是演出状态，不长期保存。

## 当前物品与容量规则

当前 5 件灰盒物品：

- `sports_day_bib`：运动会号码布
- `old_workbook`：旧练习册（红笔“别睡了”）
- `ye_xiao_pen`：叶晓的笔（去向可能是“还给她”，走 `returned` 而非 `discarded`）
- `freshman_map`：入学报到折页（替换原 `keychain_piece`）
- `broken_ruler`：断尺（替换原 `used_paper`）

最终最多保留 3 件。不显示 `3/5`、重量、格子或稀有度。

如果全部决定后保留数超过 3：

```text
……装不下了。腾个位置。
```

玩家只能从已保留物中重新舍弃；该物品记录为 `discarded_later`。第一次直接舍弃的物品记录为 `discarded_initially`。`ye_xiao_pen` 无论初次还是二次，只要选“还给她”都记录为 `returned` / `returned_late`，绝不混入 `discarded_initially`。

## 当前 Timeline 组织

- `01_return_to_school.dtl`：S01–S04
- `02_locker_and_future.dtl`：S05–S06
- `03_lunch_and_afternoon.dtl`：S07–S12

S04 完成后跳转到 `02_locker_and_future`；S06 完成后跳转到
`03_lunch_and_afternoon`；S12 再跳转到 `04_memory_and_ending`。S05 和 S11 都通过交互命令暂停并等待，各自使用不同规则。
S13–S17 不增加交互系统，直接使用世界场景、Dialogic 和现有 PhotoViewer。

## S11 DeskCleanup

`res://scenes/interaction/desk_cleanup.tscn` +
`res://scripts/interaction/desk_cleanup.gd` 只处理 2 个桌面/桌洞物品：点击查看即算“已看”，没有“标记处理完成”按钮，也没有 `[已处理]` 标签。全部看过后“收拾好了”才可点。

它复用了 `res://scripts/interaction/item_inspect_panel.gd` 这个小组件；LockerCleanup 的 InspectPanel 也使用同一个组件来展示名称和短描述。
DeskCleanup 没有 keep/discard、容量或二次舍弃规则；真正清空桌洞的演出留在该段 Timeline 里。

## 跨 Timeline 客观状态（延迟实现）

当前 `Dialogic.VAR.var_storage` 直接承载 `locker_overpacked` 等未注册 key（灰盒阶段可行）。
正式解法 `scripts/state/demo_state.gd` 本轮**不实现**，触发条件已定死：

> 当出现第 2 个需要跨 Timeline 读取的 gameplay result 时，再建 `demo_state.gd`，
> 把跨 Timeline 使用的客观状态统一注册或包一层状态接口，
> 避免直接读写 `var_storage` 在存档 / 变量编辑器 / 插件升级时出问题。

在此之前，仅 `locker_overpacked` 一个跨 Timeline 信号，继续走 `var_storage` 即可。

## 运行方式

打开：

```text
res://dev/scenes/demo_current_runner.tscn
```

按 F6，流程为：S01 → S02 → S03 → S04 → S05 LockerCleanup → S06 → S07 → S08 → S09 → S10 → S11 DeskCleanup → S12 → S13 → S14 → S15 → S16 → S17 → Demo End。
`res://scenes/main.tscn` 仍然是 blank shell，不会自动启动 Demo。

## 当前没有实现

没有实现正式 Inventory、存档、正式 GameState、Hotspot 通用框架、手机 UI、正式 MemoryManager、CG、AudioManager、标题、Settings、正式 Ending UI、Credits、成熟度或关系数值，也没有修改 `res://addons/dialogic/`。
