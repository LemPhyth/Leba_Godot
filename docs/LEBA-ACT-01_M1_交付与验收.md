# LEBA-ACT-01 M1 动作系统交付与验收

更新：2026-11-14。对应正式工单`工单/LEBA-ACT-01_动作系统重建_M1.md`。本轮以动作系统为主，不继续扩展剧情。**代码和自动回归已接通；实际键盘范围见下表，M1尚未标为整体验收通过。** 本文是当前交付记录，工单01/02旧报告保留为历史。

## 1. 版本、范围与入口

实际Git仓库是`godot/`，分支main，HEAD `556d40fc6ae8e02766af9f7c9cbde93f51db9b96`。开始时README有修改，主要工程已经存在但尚未跟踪；均已保留，没有重置、删除、提交或推送。修改前的文件清单及备份在`artifacts/leba_act01_20261113/baseline.zip`和`artifacts/leba_act01_20261114/baseline.zip`。当前项目继续用GDScript、唯一Main/Battle/Combatant/SourceClock/SourceSprite，不新增战斗Runtime或Flash解释器。

本轮接通角色编号0默认分支的移动/释放、C、空中X、Down、默认Z双入口及与六段X、S/D、受击/返回的整合；4030/7176用于交互，角色1既有X/S/移动/受击做兼容回归。职业名、未接技能、特殊装备和其余角色没有借此宣称完成。

在`godot/`目录静音启动，不经剧情、不写正式进度：

```powershell
& '../tools/Godot_v4.6.3-stable_mono_win64/Godot_v4.6.3-stable_mono_win64.exe' --path . --audio-driver Dummy -- --action-lab
```

可加`--lab-stage=root_2|root_4|root_6`和`--lab-difficulty=expert|master|king`，每项只选一个值。默认root_2/expert/角色0；root_2一个4030、root_4四个4030、root_6一个7176，全部沿用正式放置和战斗对象。

| 操作 | 含义 |
| --- | --- |
| ←/→、X、C、Down、Z、S、D | 移动、地面/空中X、跳跃、后撤分支、默认Z、S、D；D仅编号0 |
| F1 / F2 | 重建当前场景并切编号0 / 编号1 |
| F3 / F4 | 判定显示 / 重建当前场景 |
| F5 / F6 | 连续运行与停帧切换 / 停帧时推进源tick及40ms局部任务 |
| F7 / F9 | 在根2/4/6间重建 / Expert、Master、King间重建 |
| F8 | 导出本场有限诊断到`user://action_lab/trace_*.json` |
| 界面“菜单” / Esc | 暂停；菜单可继续或返回，窗口关闭正常释放音频 |

动作检查入口默认Master总线静音，且`save_progress()`不写存档；`--audio-driver Dummy`再隔离输出设备。它仍使用正式音频解码/播放节点。没有覆盖原Flash SharedObject。常规流程启动时可加`-- --mute-audio`。

## 2. 本轮控制关系与证据

动作仍以25Hz源tick运行，Godot物理60Hz、显示刷新率独立。局部Z的10ms interval和500ms timeout按毫秒队列推进，与源tick交错，不四舍五入成25Hz任务。暂停冻结两条时间线，退出/结束清理本场任务。F6每次同时推进40ms，仅是诊断单步，不代表毫秒回调也变为40ms一次。

| 动作/转换 | 已实现的来源关系 | 来源与边界 |
| --- | --- | --- |
| 待机→移动→释放 | crt0父1→2，释放经过3再回1；crt1为30→31→32→30。右if后左if，双持净0且朝左 | 6732与根实例AS；受控held原片段验证。未找到默认分支独立跑动入口，不新增双击跑动 |
| 地面事件输入 | keyDown时保存held快照，按源监听顺序处理；非所有动作统一just_pressed；重复事件和释放保留 | 原ClipActions及匹配Ruffle版本显示树/FIFO/移除语义；多键顺序不是全宿主已验证事实 |
| C进入/返回 | 父95→5633，源35返回；根y不套敌浮空。返回当tick处理仍按住的地面方向 | AS/XML及35采样；修正旧实现返回方向晚一tick |
| 跳跃身体 | 独立4745时钟：1..6有身体、7..25无形状、26恢复并hold；gravity身体仍在 | XML与原body宽度采样，不能用人物可见高度替代受击身体 |
| 空中X | 源15创建独立5628；先推进/读帧、后held轮询；默认连续X在外层17/21/25/29各发1弹；30替换不继承输入实例 | 三组受控原片段/CALL记录。普通覆写和影子Key两次失败均保留，不当成功证据 |
| 空中方向/落地 | 射击后撤每tick3，反向输入为12且不随意翻面；未射击4937的首次有效方向回调为源5；落地同tick可继续移动6 | 独立原受控held样本，非Godot输出反推 |
| 斜向弹 | 1385源1..10完整矩阵、owner-relative坐标，g=-3；每颗弹各自目标去重，重启敌共享marker；真实走碰撞链 | XML/AS，逐帧比较创建时机及parent_y；源11空容器在工程释放，源12移除竞争未完全动态校准 |
| Down进入/返回 | 父12→4672；源2..11各后移5，源12承接-3，总后撤53（镜像反向）；4673身体1..9空、10hold | 正反两组原采样。不是静止蹲伏；根位移不乘演员缩放 |
| 六段X | 保留父7/8/9/9/16/10及各段控制跳转、末帧窗口、近距判定/投射物，不重写已校准机制 | 旧原作探针+本轮129动作回归；未重新取得每段自然键盘原版轨迹 |
| S/D与受击取消 | 继续各自许可状态与冷却；D可从hit取消，移除旧helper后旧动作事件不越界；活动helper按当前状态读，不按弹身份伪造固定伤害 | 原AS/既有受控探针，本轮交叉/取消fixture；D marker2基础5+活动helper70与后续marker3的10分开，不将75推广成全部伤害 |
| 默认技能栏Z | parent5/4622、MP3、冷却65tick；允许源码所列父状态含14受击；普通hurt身体不存在，gravity保留 | 4064/6732 AS；原OS Z有限样本支持MP3，双入口竞争结合匹配Ruffle源码，不称原生Flash自然输入已确认 |
| 默认移动Z fallback | barZ成功先到5并销毁旧移动监听；MP不足/冷却时移动监听仍可到父6/4625，不扣MP；待机无fallback | 原监听/层级/队列依据；两种fallback原直接goto轨迹比对，根移动总160，身体localx按/6缓动 |
| 普通Z结束/判定 | child.x缓动并以twips精度写回，正常返回加当前child.x；原x129.35 fixture根+9.9；helper放置6、首次EnterFrame读7，再8，9移除 | 原采样与XML/Ruffle阶段。不能将9.9硬编码成任意起点的常数，也不能以“6..8三张图”当三个命中tick |
| Z抛空与伤害 | 判定每次写g/gacc，无固定扣HP；首次新空中层自然marker产生5再10，已空中Z不自动seek marker | 原地面首次入空样本；多敌/既有空中/跨招式主要静态链+顺序fixture，未伪称全部原动态对齐 |
| Z毫秒拖动 | 对所有gacc>0具名敌拖3，不以本次命中或HP过滤；每次重启interval，独立旧timeout清当前全局interval；动作返回/强制打断后仍可继续，结束/退出清理 | 原8次创建、8 timeout、147次Flying样本。请求10/500ms；宿主实际有抖动与提前容差，工程执行名义请求值，不硬编码观测469ms |
| 4030/7176 | gravity-body触发；4030移动2、7176为3有源依据，恢复经过父2/3/4；转向、近/远攻、7176独立timer、浮空换层及落地/死亡分开 | 根实例AS+既有原探针/本轮fixture；7176受控动作不称自然通关 |
| 死亡/清理 | 保留根4内部死敌监听与独立Expert监听，致命浮空继续运动至落地结算；计数/奖励一次、退出无残余演员/弹/marker/ms任务 | 既有来源+玩法/受击/M1回归；并非全敌人库已还原 |
| 边界 | 根2/4/6保留3829且pren0，根x夹0..550；hurt14/44单独_width/2夹限；wall缺失/空不伪造多边形 | 全AS/XML，夹限间同tick顺序尚无原动态边界样本；替换旧临时35..520 |

详细源ID、脚本路径、矩阵、干预和失败记录见[资源与动作依据](LEBA-ACT-01_M1_资源与动作依据.md)、[Z与敌人控制依据](LEBA-ACT-01_M1_Z与敌人控制依据.md)。历史首段/受击链见[动作校准续报](工单02_动作校准续报.md)、[受击链校准](工单02_受击链校准.md)。

## 3. 分项验收状态

“自动通过”包括真实Main/Battle对象、合成输入、源数据预期及竞争fixture，不等于OS键盘。受控原作仅Ruffle0.7.1（commit `89a7049965f3090e706265670df309a5128233ac`）；部分用直接goto/固定位置，部分方法级替换原Key.isDown并保留原clip轮询。所有直接干预均在派生SWF，原SWF不变。原生Adobe Flash本轮无可用运行环境，整列未验证。

| 动作/边界 | 代码接入 | 自动检查 | 受控原作比较 | 实际键盘（Godot） | 原生Flash |
| --- | --- | --- | --- | --- | --- |
| 待机/移动/双方向/释放恢复 | 完成 | 通过 | held样本对齐 | 待机已见；方向短按未跨源tick，不算移动通过 | 未验证 |
| 地面六段X/末帧连段 | 保留并回归 | 通过 | 历史控制节点样本；非全段新对照 | X首段输入/发弹/返回通过；连续六段未验证 | 未验证 |
| C无攻击/完整返回/身体空窗 | 完成 | 通过 | 35帧对齐 | C进入、根坐标保持、完整返回和再入/单步通过 | 未验证 |
| 空中持续X/四发/反向/落地继续 | 完成 | 通过 | 三组held轨迹对齐 | 未验证OS持续按住 | 未验证 |
| Down正反后撤/返回 | 完成 | 通过 | 两组12帧对齐 | 朝右后撤53/返回通过；反向未验证 | 未验证 |
| S/D合法入口/禁止取消/受击取消D | 保留并整合 | 通过 | 部分历史样本；新增竞争静态/fixture | 闲置S/D输入/消耗/结束通过；取消竞争未验证 | 未验证 |
| Z技能栏闲置/移动/受击入口 | 完成 | 通过 | 有限原OS Z+静态/Ruffle调度；自然移动竞争未测 | 闲置Z/扣3/冷却/返回通过；移动/受击未验证 | 未验证 |
| 移动Z低MP/冷却fallback | 完成 | 通过 | 两组原直接goto位移；原自然输入未测 | 待验证 | 未验证 |
| Z正常/打断/重启/旧timeout | 完成 | 通过 | 普通Z与计时原样本；多敌静态/fixture | 正常结束/任务归零已见；重启/竞争未验证 | 未验证 |
| 斜弹命中/多目标/重复接触 | 完成 | 通过 | 发弹时机对齐，碰撞全竞争原样本未齐 | 待验证 | 未验证 |
| 4030/7176恢复/浮空/死亡 | 整合并回归 | 通过 | 原旧样本+静态；非7176自然通关 | 已见四4030攻击及7176近远攻/受击；完整浮空/敌死亡链未验证 | 未验证 |
| 角色1 X/S/移动/受击 | 保留并回归 | 通过 | 历史样本，本轮未新取原自然输入 | X/S、受击和四敌致死/重试通过；移动未验证 | 未验证 |
| 暂停/重置/退出重进/失焦 | 完成 | 通过 | 工程适配，不冒称原规则 | F4/F5/F6、菜单暂停/继续/返回、F1重进、焦点移出自动暂停、Alt+F4退出通过 | 未验证 |
| 根2/4流程、失败/奖励/进度 | 保留并回归 | 通过 | 沿用既有源码证据，不扩剧情 | 根4自然失败/重试通过；完整通关/保存仍仅自动验证 | 未验证 |

## 4. 本轮执行的验证

环境：Windows，Godot4.6.3 mono stable `7d41c59c4`；GDScript；GPU为NVIDIA RTX5070Ti、OpenGL3.3 Compatibility。自动回归用`--headless --audio-driver Dummy`，GPU另起Hidden实际GL窗口并用Dummy音频；未做扬声器听测。

| 本轮重跑 | 检查数 | 结果 |
| --- | ---: | --- |
| test_actions.gd | 129 | exit0，失败0，错误0 |
| test_gameplay.gd | 102 | exit0，根2/4合法输入、失败恢复、退出重进等通过 |
| test_hit_timeline.gd | 78 | exit0，两角色/三难度/根2/4/6等通过 |
| test_m1_actions.gd | 168 | exit0，C/空X/Down/Z、多敌、时基、输入/诊断与存档保护；另含窗口关闭竞争与重试回归 |
| test_services.gd | 72 | exit0，7条明确的异常输入WARNING符合预期；新声音实际PCM解码/节点释放通过 |
| test_progression.gd | 28 | exit0，既有隔离进度/交易规则未退化 |
| Godot导入 | — | exit0，无错误 |
| render_m1_actions.gd | 21幅 | 实际GL渲染exit0、stderr空；检查跳跃枪口、落地、后撤、Z默认外观、双角色/多敌/7176 |
| 原作轨迹比较 | 10组/257采样/1708字段 | 差异0，首差异null；比较器1twip负向夹具能拒绝 |
| 资源及原库完整性 | 1235源/59输出；191733文件 | 校验通过；完整库2,982,789,466字节，原SWF哈希不变 |

六套最新合计577项，不能代替右表未验证事项。初批569项明细在`artifacts/leba_act01_20261114/regression/summary.json`；实机发现窗口关闭竞争后新增8项，重跑M1/玩法并复用本轮前批其余四套（未变的相关模块），最新汇总/文件哈希在`artifacts/leba_act01_20261114/window_regression/summary.json`，已分列重跑与复用。正式`user://profile.json`在本轮前后均不存在，未创建正式档。

原作比较来自独立`controlled_basics.json`、`held_native.json`和Godot `m1_actions_tests.json`。比较器使用根/child坐标1e-4px、原body包围盒0.05px误差，帧不设模糊容差；移动Z用进入时相对位移，其余用相同fixture绝对位置。不能把“差异0”扩大到没比较的伤害竞争或自然键盘行为。修正前发现的实际差异包括：落地恢复方向晚一tick、空中射击错误每周期两发、4937和普通Zhelper新放置当tick误执行、twips写回受Godot float32影响，以及Z嵌套默认衣装外观。

### 实际窗口/OS键盘分项记录

使用Sky向实际Godot窗口发送OS按键和点击，不是`Input.parse_input_event`，也不是用户亲手操作。工具接口只提供短按组合，没有可跨调用保持的按键，因此没有把长按空中X、原生键盘重复和六段连续操作写为通过。

第一次窗口不带`--test-mode`，动作实验仍禁写正式档。F4重置后，导出轨迹`keyboard/trace_1794652727_154709910.json`记录：C在219进入父95，253返回；Down548进入，559回父1，根129.35→76.35；Z676进入父5并扣3，689返回；X1471进入父7并发弹/返回；S1675、D1958分别扣3/5并恢复。这个Z起点为76.35，实际加9.95而非原129.35 fixture的9.9，属于浮点加法后twips截断的起点差异；没有硬编码补偿，同起点原动态样本尚未新取。F5停于2571，按C仍2571，F6恰推进到2572/父95子1，验证单步消费。

F7根4、F2角色1；自然多敌受击后306tick结算失败，界面重试恢复100HP和四敌。F7到7176，F9将HP400切600；角色1的S在155进入父42，随后被命中取消，X在370进入父37；已观测真实敌攻击、受击与输入响应。菜单暂停/继续/返回角色界面后F1重新进入同场，Alt+F4关闭。首轮日志发现Alt+F4误触发F4重置，在音频drain时尝试新音乐；已修复Main修饰键与closing守卫。重试恢复debug/hint、选人编号1错误键位、F8过长提示也一并修正。

最终窗口使用隔离`--test-mode --action-lab --lab-stage=root_4`再验自然失败→点击重试，父1/100HP/四敌/调试提示恢复，F8提示仅文件名、不遮住状态文字，Alt+F4正常退出。`keyboard_final_godot.log`无ERROR/WARNING，PID45728已退出；第一次PID39176也已退出，未关闭用户进程。日志、启动身份和5份app导出轨迹保存在`artifacts/leba_act01_20261114/keyboard*`；初轮诊断解析在`keyboard/summary.json`，保留发现问题的原始日志。

复跑（在godot目录，每条独立执行）：

```powershell
$gd = '../tools/Godot_v4.6.3-stable_mono_win64/Godot_v4.6.3-stable_mono_win64_console.exe'
& $gd --headless --audio-driver Dummy --path . --editor --import --quit
& $gd --headless --audio-driver Dummy --path . --script tests/test_actions.gd -- --test-mode --action-lab
& $gd --headless --audio-driver Dummy --path . --script tests/test_gameplay.gd -- --test-mode
& $gd --headless --audio-driver Dummy --path . --script tests/test_hit_timeline.gd -- --test-mode
& $gd --headless --audio-driver Dummy --path . --script tests/test_m1_actions.gd -- --test-mode --action-lab --lab-stage=root_6 --lab-difficulty=king
& $gd --headless --audio-driver Dummy --path . --script tests/test_services.gd
& $gd --headless --audio-driver Dummy --path . --script tests/test_progression.gd -- --test-mode
python tools/compare_m1_traces.py
python tools/import_runtime_assets.py --verify
python tools/verify_sources.py
```

GPU脚本必须用实际显示后端运行，不能把headless导出的空图当验收：`--audio-driver Dummy --script tests/render_m1_actions.gd -- --action-lab --test-mode`；本轮以隐藏窗口执行，图片在`artifacts/leba_act01_20261114/render/`。

## 5. 资源与修改范围

原始游戏`../leba/雷巴的冒险EX.swf`的SHA256为`afef4c43153780e9140eca7234b5af26c4a751596efefeb071d35428435a909d`，完整库仍在仓库外`../res/`。这些目录与Godot工程`res://`是不同位置。新增6张必要图集：5633、5628、4672、1385、4622、4625；只新增4624/4620/4621三个必要声音文件，其他音效复用。工程当前总计40组动画/858选帧/59个去重输出。

统一导入器保留源路径/ID/选帧、默认选择器、源哈希、输出哈希、尺寸、pivot、矩阵、body空帧和声音参数。完整映射在`data/asset_catalog.json`。普通Z发现嵌套服装未停帧后补6个有原AS依据的默认选择器，只重渲染登记范围；最终只有Z图集变化，另58输出哈希不变，来源见资源依据第7节。`--refresh-animations player_basic crt0_skill_s crt0_skill_z`先校验已有文件，不覆盖用户改动资产；全导入仍按原工具约定。

| 修改文件/范围 | 目的 |
| --- | --- |
| scripts/combat/battle.gd | 输入监听顺序、落地返回、跳跃/空X/Down/Z事件、矩阵碰撞、局部毫秒任务、敌恢复/边界、有限轨迹 |
| scripts/combat/combatant.gd | 父/子/独立身体时钟、late-entry消费、Z偏移、twips精度；沿用动作serial和seek保护 |
| scripts/core/content_db.gd | 注册本轮动作/来源父帧、敌恢复/返回与必要资源约束 |
| scripts/main.gd、scripts/ui/game_ui.gd | C/Down/Z、最小场景/难度切换/导出、HUD读真实状态、诊断文字避让、Alt+F4关闭竞争与重试观察恢复 |
| tools/import_runtime_assets.py、data/asset_catalog.json、assets/必要派生文件 | 统一按需导入，保留锚点/矩阵/独立身体/默认选择器 |
| tools/build_runtime_probe.py、tools/probes/m1_*.as、三个analyze/compare工具 | 独立派生原作取证、保留失败、可追溯比较；不改原资料 |
| tests/test_m1_actions.gd、tests/render_m1_actions.gd、既有动作/玩法测试局部预期 | 实际输入链/生命周期/时基竞争回归与独立源预期；不锁定旧临时通关tick |
| README、工单状态、本报告与两份M1依据 | 当前入口、操作步骤、证据和验收边界 |
| .gitignore、artifacts/.gdignore | Git只保留诊断目录标记；Godot跳过诊断截图/日志扫描，FileAccess仍可输出证据 |

SourceSprite、SourceClock、音频/存档/进度服务继续复用，本轮没有另建平行系统。`artifacts/`只存忽略的证据与备份，`.gdignore`防止把这些诊断图当运行资源导入；最后重新执行Godot导入和21幅GPU输出均exit0。Godot导入生成的UID/import元数据不属于原资料。

## 6. 实际操作步骤与后续缺口

1. 按第1节静音启动。向右、向左、同时按住，再松开；观察根坐标变化、最终朝向与恢复，不应额外补发动作。
2. 按C完整落地，重复。再次C后在空中持X，分别不按方向、同向、反向；观察独立枪口、四发窗口和落地继续移动。F5停帧后先按C，再F6逐步，可复查父95与子帧，但此方式不替代连续手感。
3. 面朝两侧各按Down，检查完整后撤53及返回；停止后不应持续漂移。用F4避免屏幕夹限影响测量。
4. 在单4030场用X多次按键走六段连段，分别S/D；待MP恢复后Z。普通Z应消耗3MP，出现冷却；立即移动中再按Z，应走不扣MP的parent6 fallback。用F4重置后，测试Z与其他技能同时按、受击后D/Z及禁止状态请求；这些自然键盘组合需单独记录，不由fixture推定。
5. F7到四4030，再到7176；检查重复命中、浮空、恢复与死亡计数，F9切三难度。F2只核验编号1已有X/S/移动/受击，不将C/Z缺失当新实现。
6. 菜单暂停/继续、F5/F6、F4重置、返回后重进及窗口关闭。运行中切走应用再回来应自动暂停（使用不带--test-mode的上述入口）；正式存档不应改变。F8留本场轨迹，默认最多5000帧/30000事件，正常运行不无限积累。

**规则已有依据但尚未实现：** 角色0其余技能、角色1完整默认动作和其他角色；本轮以外的装备/特殊分支、更多敌人、商店/剧情扩展保留到后续，未建立假入口。斜弹源11空容器采用工程释放，视觉/判定终止已经接入，原12清理竞争尚未完整复现。

**还需继续逆向或取证：** 原作自然键盘下的Z移动/低MP/冷却/多键监听竞争、同帧多事件与末帧边界；Z既有空中/多敌/7176与跨招式timer竞争的完整原动态样本；墙/全局夹限与演员回调同tick顺序；特殊装备跳跃计时与弹规则。原生Flash与Ruffle差异、原Flash133槽存档兼容仍未验证，不承诺兼容。

**验收未覆盖：** OS键盘长按/宿主重复、扬声器播放/听感及所有承诺转换的人工连续操作；当前OS短按分项已按实际轨迹更新上表。没有用截图、提取数量或577项自动通过替代它们。活动Z期间致死的清理链完成静态核查，活动Z暂停/退出和死亡/胜利分别有自动测试，组合致死仍缺独立原动态样本。
