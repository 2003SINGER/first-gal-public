# First Gal

校园成长 Gal 的 Godot 原型。根目录只保留本入口；设计、叙事与技术文档各自归档在 `docs/`。

## 试玩灰盒 Demo

当前 Windows 试玩版只包含已经接通的基础系统与剧情灰盒：标题、S01–S17 的流程，以及两段整理交互。美术（包括 UI、音乐、音效和 CG）尚未进入这个版本；它不是最终作品的视觉呈现。

可从 [GitHub Releases](https://github.com/2003SINGER/first-gal-public/releases) 下载当前 Demo。

## 为什么做它

这个项目从一段发生在初中时、后来一直留在脑海里的个人故事长出来。它不打算靠强硬人设或狗血情节取胜；更想慢慢把人物、关系和成长写扎实，也顺便看看自己这些年走到了哪里。

现在缺的主要是实践时间与美术资源。先把能运行的叙事和交互骨架做出来，是继续打磨它的起点。

## 先读什么

- [作品企划书](docs/design/校园成长恋爱Gal_企划书_v0.2.md)：作品级主题、人物与 Demo 边界。
- [Demo 场景流程卡](docs/narrative/demo_scene_flow.md)：当前 Demo 的 Canonical 流程与不可违背约束。
- [Demo 阅读剧本](docs/script/demo_script.md)：S01–S17 的逐场文本与演出备注。
- [个人语言与互动风格画像](docs/narrative/voice/个人语言与互动风格画像.md)：海象声线、关系互动与协作写作参考。
- [显示系统](docs/architecture/display_system.md)、[交互系统](docs/architecture/interaction_system.md) 与 [基础游戏壳](docs/architecture/game_shell_system.md)：现有 Godot 灰盒与基础运行边界。

修改优先级：作品级判断回到企划书；Demo 的流程/约束回到场景流程卡；台词与镜头落在阅读剧本；实现细节回到架构文档与代码。不要用某一份文档替代另一份的职责。

## 运行当前 Demo

启动项目（F6）会先进入 `res://scenes/title/title_screen.tscn`：标题演出结束后可开始、读取、设置或退出。开始游戏会进入当前 Demo。

开发时若只想从 S01 直接检查剧情，可打开 `res://dev/scenes/demo_current_runner.tscn` 并按 F6；它会绕过标题菜单。当前流程为 S01 → S17；柜子与桌子两段会暂停 Dialogic，进入各自的整理交互。

## Included tools

- Godot 4.7.1 editor: `tools/godot-4.7.1/Godot_v4.7.1-stable_win64.exe`
- Dialogic 2 Alpha 21 (vendored at commit `fd0fa22c335c72583b89b35699f9fb19dd1b4eae`): `addons/dialogic`

Dialogic is enabled only for evaluation. The game's save files and core session boundary remain project-owned; Dialogic only provides the timeline state captured by that system.
