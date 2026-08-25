# Interaction System — S04–S06 graybox

## LockerCleanup 职责

`res://scenes/interaction/locker_cleanup.tscn` +
`res://scripts/interaction/locker_cleanup.gd` 是一次独立、一次性的柜子整理交互。

它只负责：

- 展示 5 个普通灰盒物品与 1 个特殊“照片袋”并查看说明；
- 对每件普通物品做 `keep` / `discard`；
- 在第一次保留数量超过上限时发出 `overflow_requested(result)`，暂停自身并临时隐藏；
- 通过 `resume_overflow()` 恢复同一个实例，进入二次取舍；
- 二次取舍完成后发出 `finished(result)`。

LockerCleanup 不知道 S05，不启动 Dialogic，也不跳转下一段 Timeline。

## Dialogic 如何启动 Gameplay

`NarrativeBridge` 继续接收 Dialogic Alpha20 的标准 Signal Event。当前新增语义命令：

```text
interaction:locker_cleanup
interaction:locker_cleanup_resume
```

Bridge 把它们转给 `InteractionController.start_interaction()`：

- `locker_cleanup`：创建 LockerCleanup 实例，并设置 `Dialogic.paused = true`；
- `locker_cleanup_resume`：不创建新实例，恢复仍然存活的原 LockerCleanup，并设置 `Dialogic.paused = true`。

第一次 overflow 时，InteractionController 收到 `overflow_requested`，写入 transient 的 `locker_overpacked = 1`，隐藏的交互实例保持存活，并恢复 Dialogic，让 Timeline 先播放“包塞不下”的演出。

## Gameplay 如何结束

LockerCleanup 有两个阶段：

```text
Phase A：第一次物品去向决定。
若 kept <= 3，直接 finished。
若 kept > 3，发 overflow_requested，临时隐藏 UI，并恢复 Timeline。

Timeline 播放“包塞不下”演出后发送：
interaction:locker_cleanup_resume

Phase B：恢复原 LockerCleanup 实例，只允许对第一次 kept 的普通物品进行二次处理。
完成后才发 finished。
```

只有最终 `finished(result)` 后，InteractionController 才会：

1. 保存最终结果到 `last_locker_result` 与四组 `locker_items_*`；
2. 关闭并释放 LockerCleanup；
3. 发出 `interaction_finished`；
4. 设置 `Dialogic.paused = false`。

中途 `overflow_requested` 只是 transient session，不当作最终状态。

Dialogic Alpha20 的 `handle_event()` 在暂停期间会等待 `dialogic_resumed`，所以 Signal Event 后面的对白不会在交互界面打开时提前运行。

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

基础存档系统已实现，但在 LockerCleanup 或 DeskCleanup 仍处于打开／等待恢复的局部状态时会拒绝保存。这样不会把无法完整恢复的交互面板伪装为正常存档；最终 `finished(result)` 后，Dialogic 变量会随基础存档保存。

## 当前物品与容量规则

当前 5 件普通灰盒物品，外加 1 件特殊“照片袋”：

- `sports_day_bib`：运动会号码布（B 档高中时间痕迹）
- `dead_refill`：没水的笔芯（对应 S05 开场"一截笔芯滚出来……没水"；A 档真垃圾 / 普通残留代表，替换原 `old_workbook`）
- `ye_xiao_pen`：叶晓的笔（去向是“还给她”，走 `returned` 而非 `discarded`；C 档未来回填槽位）
- `freshman_map`：入学报到折页（替换原 `keychain_piece`）
- `broken_ruler`：断尺（替换原 `used_paper`）
- `photo_pack`：一袋照片（特殊项，`is_photo_set: true`；不计入容量、无 keep/discard，但必须至少检视一次；玩家主动点击或第一次点击“整理完毕”时自动打开，检视时在柜子面板内显示 `first_day_classroom` 照片）

每件物品都带完整分支文本：`inspect_text` / `keep_text` / `discard_text` / `late_discard_text`，以及 `returned` 物品的 `late_return_text`（二次取舍时读取 `late_return_text` 而非 `late_discard_text`），不做成“一处描述用到底”。

最终最多保留 3 件（仅计普通物品，照片袋不占名额）。不显示 `3/5`、重量、格子或稀有度。

照片袋不占容量，也不显示“还缺一个任务”的 checklist；如果玩家一直没有主动点击，第一次点击“整理完毕”时会自动切换到 `photo_pack`，玩家看完后再次点击“整理完毕”才继续判断容量。

如果全部决定后保留数超过 3：

```text
Phase A：overflow_requested → 隐藏 UI → Timeline 播放“包塞不下”。
Phase B：locker_cleanup_resume → 恢复同一实例 → 仅从已保留物中重新舍弃。
```

该物品记录为 `discarded_later`。第一次直接舍弃的物品记录为 `discarded_initially`。`ye_xiao_pen` 无论初次还是二次，只要选“还给她”都记录为 `returned` / `returned_late`，绝不混入 `discarded_initially`。

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
项目启动会先经过 TitleScreen；开发 runner 仍可绕过标题，直接检查 Demo。

## 当前没有实现

没有实现正式 Inventory、正式 GameState、Hotspot 通用框架、手机 UI、正式 MemoryManager、CG、正式 AudioManager、正式 Ending UI、Credits、成熟度或关系数值，也没有修改 `res://addons/dialogic/`。基础 TitleScreen、存档、设置和系统 UI 已由 `game_shell_system.md` 说明。
