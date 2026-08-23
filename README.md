# First Gal

校园成长 Gal 的私有 Godot 工程。根目录只保留本入口；设计、叙事与技术文档各自归档在 `docs/`。

## 先读什么

- [作品企划书](docs/design/校园成长恋爱Gal_企划书_v0.2.md)：作品级主题、人物与 Demo 边界。
- [Demo 场景流程卡](docs/narrative/demo_scene_flow.md)：当前 Demo 的 Canonical 流程与不可违背约束。
- [Demo 阅读剧本](docs/script/demo_script.md)：S01–S17 的逐场文本与演出备注。
- [个人语言与互动风格画像](docs/narrative/voice/个人语言与互动风格画像.md)：海象声线、关系互动与协作写作参考。
- [显示系统](docs/architecture/display_system.md) 与 [交互系统](docs/architecture/interaction_system.md)：现有 Godot 灰盒边界。

修改优先级：作品级判断回到企划书；Demo 的流程/约束回到场景流程卡；台词与镜头落在阅读剧本；实现细节回到架构文档与代码。不要用某一份文档替代另一份的职责。

## 运行当前 Demo

当前完整流程入口是 `res://dev/scenes/demo_current_runner.tscn`：在 Godot 中打开它并按 F6。

`res://scenes/main.tscn` 是展示壳，不会自行启动 Demo。当前流程为 S01 → S17；柜子与桌子两段会暂停 Dialogic，进入各自的整理交互。

## Included tools

- Godot 4.7.1 editor: `tools/godot-4.7.1/Godot_v4.7.1-stable_win64.exe`
- Dialogic 2 Alpha 21 (vendored at commit `fd0fa22c335c72583b89b35699f9fb19dd1b4eae`): `addons/dialogic`

Dialogic is enabled only for evaluation. The game's saves and core story state will remain project-owned rather than depend on the plugin.
