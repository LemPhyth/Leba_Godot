# Leba_Godot
雷巴的冒险小游戏Godot移植版托管仓库

规划资料：

- [项目概览](docs/项目概览.md)
- [逆向报告](docs/逆向报告.md)

## ACT-06：角色3核心补正与角色4接入

[ACT-06](工单/LEBA-ACT-06_角色3核心动作补正与角色4接入.md)开发侧实施、同版本回归及实际窗口复核已完成，用户整单签收待确认。已补角色3纯X完整续段、W独立剑气及条件后跳斩剑气，并接入第五个角色crt_4的27个动作、独立阵/分身/世界对象、HUD第5页与仓库第6页。F5正常标题可选角色0–4；角色5和根11后剧情尚未恢复。

启动、角色4准确键位/费用/两态分支、正常训练/冒险、原生编辑实测及测试边界集中见[ACT-06交付与验收](docs/LEBA-ACT-06_交付与验收.md)，资源/脚本矩阵见[角色4与资源依据](docs/LEBA-ACT-06_角色4与资源依据.md)。角色3默认weapon0/weaponmaster0保持原值，默认后跳斩不产生剑气；合法武器3或weaponmaster1配置方法及独立验收见报告，不擅自取消原条件。

最终34套4867项自动回归通过，两批实际GL共56case/206对图像已复核。回归使用 `python -B -X utf8 tools/run_act06_checks.py --name <新证据目录>`，自动静音、隔离档；真实试听和用户整单签收尚未完成。其他旧角色问题按用户安排后置精校，不代表已还原完美。原始资料只读保留在仓库外，未提交或推送。

### 已有ACT-05交付与核心缺口

2026-11-17：[LEBA-ACT-05](工单/LEBA-ACT-05_角色3接入与默认动作恢复.md)开发侧实施与集成验证完成。角色3的30个作者动作、11个组件、独立H/E/W/V、HUD第四页、仓库第五页及正常训练/既有冒险已接入；F5后可选择角色0/1/2/3。准确键位、编辑入口、测试证据和未验证边界见[ACT-05交付与验收](docs/LEBA-ACT-05_交付与验收.md)，逐动作音画矩阵见[角色3与资源依据](docs/LEBA-ACT-05_角色3与资源依据.md)。

原开发报告29套3126项自动回归通过，另有双向GL、接触音画、屏幕反馈及原生编辑保存重开记录；这些未覆盖纯X完整续段和上述动态剑气，不能作为核心动作完整的证明。自动运行保持静音、隔离档；听感未验证，可按需打开[集中试听页](docs/LEBA-ACT-05_音效试听.html)，没有自动播放。核心补正后的人工验收及原Flash逐tick一致性未宣称通过。回归命令：`python -B -X utf8 tools/run_act05_checks.py --name <新的证据目录名>`。

原始SWF及完整提取库保持仓库外只读；本轮仅新增95个派生输出。前三角色已有大小问题按用户决定，在全部角色复原后统一整理修正。本轮未扩展根10以后的剧情、未提交或推送，也没有改正式存档、音量或系统输出设备。

### 已有ACT-04阶段成果

2026-11-17：[LEBA-ACT-04](工单/LEBA-ACT-04_角色2接入与基础音效特效验收.md)已接入第三个角色（`crt_2`）的33个作者动作、普通/血气连段、耗血、持续状态、独立特效和R切入；训练、原HUD第三页、仓库4及既有冒险根2/4/6→7→8/9→10均可使用。角色1缺音和Q的滤镜/图标/变换已按开发报告补修。集中说明、准确键位、逐动作音画矩阵、原生编辑与验证边界见[ACT-04交付与验收](docs/LEBA-ACT-04_交付与验收.md)。用户已确认角色2可正常使用、角色1大部分音效恢复；开发侧静音，未试听，原Flash逐tick一致性与手感精校未宣称完成，残余问题按上述安排后续统一处理。

ACT-04交付时标题可选角色0/1/2。角色2的A/E/Q消耗HP，H开启后才可W/E/Q，H再次使用为独立关闭分支；R需原槽430准备。`content/actions/crt2`、`content/components/crt2`、`scenes/actors/crt2.tscn`及HUD/仓库新页可在原生编辑器保存重开使用。原始SWF/完整提取库仍在仓库外，只有按需派生资源进入工程。最终25套2608项通过；回归命令为 `python -B -X utf8 tools/run_act04_checks.py --name <新的证据目录名>`，默认静音、隔离存档，不改正式音量。未提交或推送。

2026-11-16：已按[LEBA-ACT-03](工单/LEBA-ACT-03_角色1与流程骨架_Godot原生编辑接入.md)恢复角色1默认动作/技能、原生场景/Resource编辑链，并接通根7→8→9（7437与对白）→10中转。角色0能力保留；角色1可从标题选择训练或冒险。根10后的根11/12及其后流程仍未恢复，不是全游戏通关。启动、编辑教程、实际测试和未迁移/待打磨内容集中见[ACT-03交付与编辑指南](docs/LEBA-ACT-03_交付与编辑指南.md)。

Godot4.6.3打开`project.godot`，F5正常入口；F6可直接运行`scenes/stages/root_41.tscn`。编辑场景出生点/HUD，或`content/actions/crt1/*.tres`的动作、事件和判定，保存后重开运行生效；`content/index.tres`统一注册。派生动画同步只更新`generated/`，不覆盖作者内容。用户已确认角色0可玩，音效/击飞/伤害/手感精校继续放在后期，不把本轮功能恢复冒称精确原作一致。

ACT-03集中回归：`python -B -X utf8 tools/run_act03_checks.py --name <新的证据目录名>`。执行过程静音、独立档，未提交或推送仓库。以下ACT-02及更早内容为历史阶段记录。

### 已有ACT-02阶段成果

2026-11-15：[LEBA-ACT-02](工单/LEBA-ACT-02_训练场_角色0与整体战斗场景还原.md)已接入正式训练入口、根41实例规则、角色0默认技能及其榴弹/C4/弹种/召唤依赖、原HUD与必要菜单/仓库。原根2/4/6和角色1已接能力保留。不是全职业、全装备或全剧情完成。

当前完成范围、完整键位、来源、测试及人工验收步骤见[ACT-02交付与验收](docs/LEBA-ACT-02_交付与验收.md)。16套1249项为已交付的多批次自动结果及具体原作受控样本；用户已确认当前可玩。此前工具侧独立窗口灰/黑屏观测保留在历史记录，不再直接作为主线阻塞；原作精确表现/原生Adobe Flash一致性仍单独记录，不以自动计数代替。

从本目录启动，使用明确项目路径；保持静音，不修改档案音量：

```powershell
$projectPath = (Resolve-Path .).Path
$godotPath = Join-Path (Split-Path $projectPath) 'tools/Godot_v4.6.3-stable_mono_win64/Godot_v4.6.3-stable_mono_win64_console.exe'
& $godotPath --headless --audio-driver Dummy --path $projectPath --editor --import --quit
& $godotPath --path $projectPath --audio-driver Dummy --rendering-method gl_compatibility -- --mute-audio
```

点击标题“练习模式”后选角色0或1；也可追加`--training`快速进入角色0。←/→、X、C、空中按住X、↓、Z/A/S/D/W/F/G/H/Q/T/E/R/Y/V；Q后↑/↓选择，T后方向/T控制，Y等待亮起后可再次集中。详细允许状态、消耗、库存与独立时钟见交付表。训练按钮恢复资源/技能栏，不是清场；原菜单“操作”可重试/返回，仓库目前只有已接戒指闭环，其余分类明确禁用。

静音回归：`python tools/run_act02_checks.py --name <新的证据目录名>`。旧失败日志保留；原始提取库仍在仓库外。本轮未提交或推送Git。

### 已有M1阶段成果

以下M1及工单01内容为历史阶段记录，当前实施范围以ACT-06及其交付为准；旧阶段的禁用角色、键位和完成状态不代表当前工程。

2026-11-14：按[正式工单](工单/LEBA-ACT-01_动作系统重建_M1.md)接入角色0的C跳跃、独立空中X、Down后撤、默认Z双入口和毫秒拖动，并整合既有六段X、S/D、受击、敌恢复与死亡。当前交付和逐动作验收状态见[M1交付与验收](docs/LEBA-ACT-01_M1_交付与验收.md)。代码与自动回归已接通，实际键盘只完成分项检查，M1尚未整体签收；不代表全游戏完成。

当前暂停扩展剧情，优先原作动作关系。动作使用25Hz源时钟，物理/显示独立；Z的10ms/500ms局部任务另计。工单01及以下描述是历史快照。角色1保留X首段/S/移动/受击，其余角色和动作继续按证据接入。

直接进入动作检查，不经过剧情，默认静音且不写进度：

```powershell
& '../tools/Godot_v4.6.3-stable_mono_win64/Godot_v4.6.3-stable_mono_win64.exe' --path . --audio-driver Dummy -- --action-lab
```

←/→移动，X攻击/连段/空中射击，C跳跃，↓后撤，Z/S/D技能（C/↓/Z/D仅编号0）。F1/F2切角色，F4重置，F5停帧，F6停帧时推进一个源tick和40ms局部任务；停帧后按动作键，再F6消费输入。

F7切根2单4030/根4四4030/根6单7176，F9切三难度，F8导出有限轨迹到`user://action_lab/`。也可在`--action-lab`后加`--lab-stage=root_6 --lab-difficulty=king`。入口复用正式战斗对象和输入链，禁写进度；Master总线默认静音，Dummy参数另隔离音频输出。普通启动也可追加`-- --mute-audio`静音，不更改存档音量。

无窗口、无声音的动作回归：

```powershell
& '../tools/Godot_v4.6.3-stable_mono_win64/Godot_v4.6.3-stable_mono_win64_console.exe' --headless --audio-driver Dummy --path . --script tests/test_actions.gd -- --test-mode --action-lab
& '../tools/Godot_v4.6.3-stable_mono_win64/Godot_v4.6.3-stable_mono_win64_console.exe' --headless --audio-driver Dummy --path . --script tests/test_m1_actions.gd -- --test-mode --action-lab --lab-stage=root_6 --lab-difficulty=king
& '../tools/Godot_v4.6.3-stable_mono_win64/Godot_v4.6.3-stable_mono_win64_console.exe' --headless --audio-driver Dummy --path . --script tests/test_gameplay.gd -- --test-mode
```

新增资源与原作样本见[M1资源与动作依据](docs/LEBA-ACT-01_M1_资源与动作依据.md)、[Z与敌人控制依据](docs/LEBA-ACT-01_M1_Z与敌人控制依据.md)；旧动作校准记录保留。运行轨迹比较使用`python tools/compare_m1_traces.py`，证据保存在忽略的`artifacts/`。受控Ruffle与真实OS单键输入分开，不冒称原生Flash或完整人工验收。

## 工单01：可运行粗框架

以下为工单01历史范围与命令，不作为当前能力清单；当前状态以上方ACT-06交付为准。

已接通标题、模式/角色选择、战斗、暂停、结算、两场推进、返回重进、音频与本工程存档。代表内容为原作编号0角色、X首段、D技能、4030敌人，以及根帧2/4的森林场景。其余入口明确标为待还原；这不是完整复刻版。

使用工作区 `../tools/Godot_v4.6.3-stable_mono_win64/` 的 Godot 4.6.3 打开本目录 `project.godot`，按 F5 启动主场景。项目使用GDScript，无需编译C#。

从仓库目录用 PowerShell 启动：

```powershell
& '../tools/Godot_v4.6.3-stable_mono_win64/Godot_v4.6.3-stable_mono_win64_console.exe' --path . --editor --import --quit
& '../tools/Godot_v4.6.3-stable_mono_win64/Godot_v4.6.3-stable_mono_win64.exe' --path .
```

控制：←/→移动，X普通动作首段，D技能（5MP、约5秒冷却），Esc暂停/返回，F3判定与状态调试，第一场完成后Space继续。只有编号0已接入；其他角色和模式禁用。

存档在Godot `user://profile.json`，不在仓库，也不读写原Flash档案。`-- --test-mode` 使用隔离UI测试存档；`-- --test-mode --debug-battle` 可直接进入第一场并显示调试信息。

### 验证命令

```powershell
& '../tools/Godot_v4.6.3-stable_mono_win64/Godot_v4.6.3-stable_mono_win64_console.exe' --headless --path . --script tests/test_services.gd
& '../tools/Godot_v4.6.3-stable_mono_win64/Godot_v4.6.3-stable_mono_win64_console.exe' --headless --path . --script tests/test_gameplay.gd -- --test-mode
python tools/import_runtime_assets.py --verify
python tools/verify_sources.py
```

玩法测试运行真实Main场景、按钮和战斗对象；时间由测试手动推进，不等于原Flash运行对照。测试产物在忽略的 `artifacts/`，正式说明在docs。

### 本轮交付资料

- [架构、流程及扩展方法](docs/工单01_架构与流程.md)
- [原作脚本、帧事件和场景依据](docs/工单01_原作依据.md)
- [资源来源映射和按需导入](docs/工单01_资源接入.md)
- [存档、原字段调查及音频](docs/工单01_存档与音频.md)
- [测试结果、已知偏差和后续待办](docs/工单01_测试与交付.md)
- [分阶段执行记录](docs/工单01_执行记录.md)

完整提取资料仍在仓库外的 `../res/`，原游戏在 `../leba/`。本仓库 `res://` 与那个目录不同；不应把全部提取资料拖进Godot工程。运行所需派生素材已经包含在assets，来源与哈希在data/asset_catalog.json。
