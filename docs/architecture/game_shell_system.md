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
      ├─ Continue Game (only when `autosave.json` exists)
      ├─ Load Game
      ├─ Settings
      ├─ Extras（鉴赏／回忆）
      └─ Quit
```

`AnimationPlayer` 在 6.5 秒内将 `Camera2D` 从人物附近的 `zoom = 2.45` 拉到完整天台视角的 `zoom = 1.0`；动画结束才显示菜单。以后替换 `World` 下的背景与人物，或只调整两个轨道的起止值即可，不需要改游戏会话或剧情代码。

标题页在 `autosave.json` 存在时显示“继续游戏”，直接读取项目自己的自动存档；“开始新游戏”始终保留。两者都由 `GameSession` 换入 `res://scenes/main.tscn`。`main.gd` 仍只负责把既有场景、展示、交互桥接起来，并将运行时节点交给会话层；它不保存存档，也不包含菜单或剧情分支。

## 运行时 UI

`res://scenes/system/system_ui.tscn` 实例为 `main.tscn` 的 `UIRoot`。它包含一个全屏 `Root` 包装节点，用来统一遮罩和输入拦截：

```text
UIRoot (CanvasLayer)
├─ Root
│  ├─ Menu
│  ├─ SaveLoad
│  ├─ Settings
│  └─ SystemMessage
└─ AdvBar                 # AUTO / SKIP / LOG / HIDE
```

- `Esc` 打开／关闭 Menu；Menu 可继续、保存、读取、打开设置或返回标题。
- 保存／读取列表都固定显示 10 个槽位。
- `F5` 快速保存到 01 槽；`F7` 打开读取列表。
- 菜单打开时 `GameSession` 暂停 Dialogic；关闭后恢复。

物理按键只在 `scripts/system/input_manager.gd` 登记。Timeline 不引用这些按键。`AdvController` 是唯一的 ADV 控制薄层：`A` 切换 AUTO、按住 `Ctrl` 临时 SKIP、`PageUp` 打开 Dialogic 官方 History、`H` 隐藏／显示文本框；右上角 AdvBar 使用同一 API。它不重写 History，也不修改 Dialogic。SKIP 在未读文本处停止。

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

## 鉴赏与回忆

`ExtrasProgress` 是槽位无关、项目拥有的永久解锁记录，持久化于
`user://extras_progress.cfg`。它不参与剧情分支，也不属于尚未建立的
GameState：它只回答“玩家是否已经看过此条目”。因此删除存档、读取旧档或
重新开始都不会反锁鉴赏内容。

- 标题页“鉴赏”目前收录可重放的标题动画。
- S17 的 `system:demo_end` 第一次到达时解锁“毕业日 Demo 回忆”。
- 回忆入口由 `GameSession.begin_recollection()` 启动同一套 Dialogic Timeline，
  但回忆会话不写自动存档、也不覆盖正常游戏进度。
- Dialogic Alpha20 没有 Gallery／CG 解锁 UI 或章节标题模块；它在这里仅继续
  负责 Timeline 播放。将来若加入分段回忆，使用 Dialogic Label／Jump 定位，
  UI 和解锁仍留在项目侧。

## 职责边界

```text
TitleScreen ──进入──> GameSession ──挂接──> main / UIRoot / SceneController
                                  │
                                  ├── SaveService  (JSON 槽位)
                                  └── GameSettings (ConfigFile)

Dialogic Timeline ──语义信号──> NarrativeBridge ──> SceneController / PhotoViewer / TransitionOverlay / ChapterTitleOverlay / AudioBridge / InteractionController / DemoEndCard
```

- `GameSession`：当前是否在游戏内、菜单暂停、场景改变后的自动存档、读取恢复次序。
- `SaveService`：序列化和槽位文件；不知道 UI、场景节点或剧情。
- `GameSettings`：设置与平台效果；不进入游戏存档。
- `SystemUI`／`TitleScreen`：按钮和显示；不直接读写 Dialogic 状态文件。
- `Dialogic`：文本、选择、Timeline 顺序、官方 History、音频频道与自身完整状态；不管理项目存档。
- `ExtrasProgress`：只保存跨档鉴赏解锁；不持有角色、关系或剧情运行状态。

本层明确不实现 Inventory、Relationship、Growth、Memory System、手机、通用 Hotspot 或 CG Manager。

## 演出、音频与 Demo End

- `TransitionOverlay` 是最小演出层，只支持 `transition:fade_out`、`transition:fade_in`、`transition:flash_white`；效果播放时暂停 Timeline，完成后恢复。它不接管场景、照片或剧情状态。
- `PhotoViewer` 保留即时 `photo:<id>`／`photo:hide`，另有 `photo:fade_in:<id>`／`photo:fade_out` 的短淡入淡出供后续场景使用。
- `AudioBridge` 保留既有 `audio:<sfx_id>`，并定义 `audio:music:<id>|stop`、`audio:amb:<id>|stop`、`audio:sfx:<id>`。资源 ID 在桥接层映射，实际播放由 `Dialogic.Audio.update_audio()` 完成；`music`、`amb` 共用 BGM 总线，空频道为一次性 SFX，Voice 等有素材后再接。
- S17 用唯一的 `system:demo_end` 调用 `DemoEndCard`，黑场后提供“重新开始”与“返回标题”。它不监听泛化的 `timeline_ended`。
- `ChapterTitleOverlay` 接收 `chapter:<id>`，在左上短暂显示作品级场景标题；当前
  Demo 的“再见之前”从 S01 开始、覆盖 S01–S13，标题仅在 S01 出场一次；S14 是
  断开的蒙太奇，S15 回到现在时显示并进入“结束之后”。

## Debug 入口

`res://dev/scenes/dev_chapter_launcher.tscn` 只在 debug build 工作，启动真实的 `main.tscn` 并可跳至 S01／S05／S11／S14／S17，显示当前 scene、Timeline、event index 与交互状态。它用 Dialogic 支持的事件索引入口；维护 Timeline 结构后可运行 `res://dev/scenes/timeline_event_probe.tscn` 更新索引表。现有柜子与桌子交互的 debug skip 保持各自脚本内，不进入 release UI。

## 验证入口

`res://dev/scenes/system_smoke_test.tscn` 会无界面验证：运行时挂接、Timeline 启动、10 槽保存 UI、单 JSON 存档、场景变更自动存档、Dialogic 变量与 Timeline 恢复、ConfigFile 设置持久化、统一输入动作，以及标题镜头结束后菜单与读取槽位列表的出现。
