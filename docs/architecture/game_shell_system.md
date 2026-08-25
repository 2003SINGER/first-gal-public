# 基础游戏壳 — 技术架构

> 范围：把当前 S01–S17 灰盒包装成一个可启动、可保存、可读取、可设置的 Galgame 工程。
> 本文不定义剧情，不定义好感／背包／成长等作品玩法状态。

## 入口与场景

项目启动入口是 `res://scenes/title/title_screen.tscn`。它是独立的标题／主菜单场景，不依赖 `main.gd`：

```text
TitleScreen (Node2D)
├─ World
│  ├─ Sky / Rooftop / Railing              # 当前占位构图
│  └─ CharacterPlaceholder                 # 当前占位人物
├─ Camera2D
├─ AnimationPlayer
└─ CanvasLayer
   └─ MenuUI
      ├─ Start Game
      ├─ Load Game
      ├─ Settings
      └─ Quit
```

`AnimationPlayer` 在 6.5 秒内将 `Camera2D` 从人物附近的 `zoom = 2.45` 拉到完整天台视角的 `zoom = 1.0`；动画结束才显示菜单。以后替换 `World` 下的背景与人物，或只调整两个轨道的起止值即可，不需要改游戏会话或剧情代码。

开始游戏与读取游戏都由 `GameSession` 换入 `res://scenes/main.tscn`。`main.gd` 仍只负责把既有场景、展示、交互桥接起来，并将运行时节点交给会话层；它不保存存档，也不包含菜单或剧情分支。

## 运行时 UI

`res://scenes/system/system_ui.tscn` 实例为 `main.tscn` 的 `UIRoot`。它包含一个全屏 `Root` 包装节点，用来统一遮罩和输入拦截：

```text
UIRoot (CanvasLayer)
└─ Root
   ├─ Menu
   ├─ SaveLoad
   ├─ Settings
   └─ SystemMessage
```

- `Esc` 打开／关闭 Menu；Menu 可继续、保存、读取、打开设置或返回标题。
- 保存／读取列表都固定显示 10 个槽位。
- `F5` 快速保存到 01 槽；`F7` 打开读取列表。
- 菜单打开时 `GameSession` 暂停 Dialogic；关闭后恢复。

物理按键只在 `scripts/system/input_manager.gd` 登记为 `confirm`、`cancel`、`menu`、`save`、`load`。Timeline 不引用这些按键。

## 存档

`SaveService` 是项目自己的存档边界；Dialogic Timeline 和 `addons/dialogic/` 均不直接访问文件。

```text
user://saves/
├─ autosave.json
├─ save_01.json
├─ ...
└─ save_10.json
```

每个槽位是单一 JSON 文件，含：

- `saved_at`、`scene`、`timeline`、`event_index`；
- 可直接阅读的 `variables`；
- `dialogic_state`：Timeline、事件位置和完整 Dialogic 子系统状态。

Dialogic 子系统可能携带 `Vector2`、`PackedStringArray` 等不是 JSON 原生的 Godot 值。为不丢失它们，`subsystems_variant` 将其写成 Godot Variant 文本，再作为 JSON 的字符串字段保存；整个槽位仍然只有一个 `.json` 文件。读取时 `SaveService` 重建 `DialogicSaveState`，`GameSession` 先恢复世界场景，再 `await Dialogic.load_full_state(...)` 恢复变量与 Timeline。

自动存档覆盖 `autosave.json`，触发于新游戏 Timeline 已启动后，以及 `SceneController.scene_changed` 后。当前柜子／桌子整理交互仍在进行时，保存会明确拒绝：这些未完成的局部交互状态尚不属于基础存档契约，不能伪造为可恢复状态。

## 设置

`GameSettings` 是槽位无关的设置服务，持久化于 `user://settings.cfg`：

- BGM 音量（`BGM` 总线）；
- SE 音量（`SFX` 总线）；
- 文本速度（即时同步到 Dialogic `text_speed`）；
- 全屏／窗口模式。

`GameSettings` 在运行时保证 BGM、SFX 总线存在，因而当前没有正式音乐资源也可先使用这套接口。

## 职责边界

```text
TitleScreen ──进入──> GameSession ──挂接──> main / UIRoot / SceneController
                                  │
                                  ├── SaveService  (JSON 槽位)
                                  └── GameSettings (ConfigFile)

Dialogic Timeline ──语义信号──> NarrativeBridge ──> SceneController / InteractionController
```

- `GameSession`：当前是否在游戏内、菜单暂停、场景改变后的自动存档、读取恢复次序。
- `SaveService`：序列化和槽位文件；不知道 UI、场景节点或剧情。
- `GameSettings`：设置与平台效果；不进入游戏存档。
- `SystemUI`／`TitleScreen`：按钮和显示；不直接读写 Dialogic 状态文件。
- `Dialogic`：文本、选择、Timeline 顺序和自身完整状态；不管理项目存档。

本层明确不实现 Photo System、Inventory、Relationship、Growth 或 Memory System。

## 验证入口

`res://dev/scenes/system_smoke_test.tscn` 会无界面验证：运行时挂接、Timeline 启动、10 槽保存 UI、单 JSON 存档、场景变更自动存档、Dialogic 变量与 Timeline 恢复、ConfigFile 设置持久化、统一输入动作，以及标题镜头结束后菜单与读取槽位列表的出现。

