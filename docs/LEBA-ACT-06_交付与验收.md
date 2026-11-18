# LEBA-ACT-06：角色3核心补正与角色4接入

2026-11-17。**开发侧实施、同版本回归与窗口复核完成；用户人工整单签收待确认。**先完成角色3三项P0，再接第五个角色crt_4。其他旧角色问题继续按用户安排留待集中校准。未commit/push/发布。

## 1. 工程与启动

沿用原检出main / 556d40fc6ae8e02766af9f7c9cbde93f51db9b96。大量未跟踪文件原本存在，未清理。开工679份代码/数据/作者/场景/文档备份为 `artifacts/leba_act06_20261117/baseline.zip` / `baseline.json`，并核对ACT05最终1144份冻结文件字节一致。

Godot **4.6.3.stable.mono.official.7d41c59c4** 打开project.godot，F5正常标题。“练习模式”选编号0–4，角色4进根41；“开始冒险”按角色→难度进入现有根2/4/6→7→8/9→10。角色5禁用，根11以后未恢复。恢复、操作菜单、重试、返回和仓库沿用现有入口。

从godot目录静音启动：

```powershell
& '../tools/Godot_v4.6.3-stable_mono_win64/Godot_v4.6.3-stable_mono_win64.exe' --path . --audio-driver Dummy -- --mute-audio
```

自动脚本使用Dummy音频/隔离档，原生F5观察保持Master静音；不改正式音量或系统设备，没有再次启动可听BGM。原舞台550×400、25Hz动作/事件、Godot显示更新与10ms局部任务分别处理。

## 2. 角色3三项P0

| 项目 | 根因与修复 | 独立验证及边界 |
| --- | --- | --- |
| 纯X | 旧实现把同父gotoAndPlay(106)当成重建basic，反复重播第一段。原Ruffle窄探针确认同父play保留当前子和计数，下一tick父自然107。共用Combatant.play_source_parent()现在幂等恢复父播放，取消/打断清请求，不硬编码跳下一段。 | 新有效测试在旧版81项25失败；修后87/87。正常纯X、X/S互接、新按/按住/松开、重复/断连、转向/打断有记录；双向实际GL接触combo_contact02为39/39，主三段、刀光和实际扣血可见。初始HP/位置夹具不作为原整招伤害。 |
| W剑气 | 漏掉6177源64的根级1267/1311，旧图只含166/6166。现在独立时钟/显示列表、439限7/重力−5/marker观察4、524独立推移/观察15均恢复，不用普通子弹替代。 | 双向正常W、空挥/接触、重复、提前C退出、收招后存续、死亡重进/切场；根9层级缺陷修后可见。父18stop移除主像/helpers，独立尾尘到年龄22空，惰性根保留至场景清理，不把18当原销毁。 |
| 后跳斩剑气 | 源条件weapon==3或weaponmaster==1且6156到4，旧条件生成链缺失。现在同W共用1267/1311，正式消费角色Resource的extra.source_profile。 | 武器3与weaponmaster1分别通过正常后跳X双向/重复/接触/空挥/退出；默认0/0不误生。**交付默认保持0/0，默认后跳斩没有剑气。**不删除源条件或偷偷换配置。 |

合法正式配置：原生Inspector打开 `content/characters/crt_3.tres` → extra → source_profile，将weapon设3或weaponmaster设1，保存F5，正常↓后跳再X。只是恢复合法分支消费，不宣称武器3所有外观/附加攻击/完整商店已恢复；测试后交付默认0/0字节不变。

原作证据在本轮artifact的 `investigation/crt3_combo.{json,md}`、`crt3_waves.{json,md}`、`wave_probe/`。同父play及剑气首EnterFrame/观察语义有受控Ruffle证据，不是原生Adobe Flash全招对照。T1前置集中 `p0_final02/summary.json` 6套832/0；独立窗口waves/run05为290/0，waves_window/run02为173/0，wave_layer/run05为48/0，combo_contact02为39/0。最终共享修改后的自动回归另见第7节，未把这些不同阶段记录拼成最终同版结果。

## 3. 角色4范围与操作

27份作者动作、45份组件Resource（含visuals/5417）、演员、索引、HUD第5页、仓库第6页已接通。复用Main/Battle/Combatant、SourceClock、输入、判定/伤害、AudioDirector和现有存档，不另建Runtime。精确源路径/帧/矩阵/声音/窗口见 [角色4与资源依据](LEBA-ACT-06_角色4与资源依据.md)、data/act06_crt4_rules.json、act06_crt4_world_semantics.json。

←/→移动/转向、X普攻、C跳跃、↓后撤。普通每源tick±10.5，鬼影步±12.5，双方向净0。普通X完整150→151→152复用同父play；空中heldX与独立5417 keyDown刀光分开。卡洛态有地面/空中/后撤分身，后撤子9回1允许同次后撤再次X。

| 键 | MP/无色方块 | 已接结果及关键分支 |
| --- | --- | --- |
| Z | 2/0 | 源许可/准备后交易，允许受击169；不足/不许可不误扣。 |
| A | 3/0 | 4早松→27；按住15→26，独立6418蓄力1→6；松开49，57按鬼1/2/3分58/86/114，各自收尾。 |
| S | 3/0 | 窗口再S到11、24，三段/各自结束；续段不重扣入口费用。 |
| D/F/G/H | 3/0、4/0、5/1、5/1 | 源7生316/956/818/1121，玩家X+100×朝向/Y；各自持续、范围/全局观察、冻结/伤害和墓兵978，收招后独立，不合成同一光圈。 |
| Q | 3/0 | 接触敌3951从2/出生声音3950；独立敌状态与HUD观察，保源目标编号重复/拼写差异。 |
| W | 5/0 | 6360入场/13开/18、19、20停父，6359计时跨18↔19保留/再启动重建；6346独立循环，移动身体空页/退出窗口按源。 |
| E | 7/1 | 28松开/45按住、标记/350终结，3963→3962独立16/20事件；10ms/1000ms共享句柄；按住局部6505从2到10，无目标保持空。 |
| R | 5/1 | 主7–86每3callback生1273，原随机抽取顺序/后目标覆盖；C提前退出不删已生墓碑。1023到7空stop，31终帧无永久碎屑。 |
| T初次/再次 | 8/2、8/0 | 6384源3开、12停父/6380独立计时、13清；1326/1154真实分身、1151透明碰撞、1153命中及敌三层3968/69/70独立136钟，全三层结束共同复位/可再叠。 |
| Y | 20/5 | 自然准备291，主21生944，94420中943独立942，943源65生遮罩907/906；人物31收招不结束world，90640恢复槽播放2。零/六flag、接触、背景根−16300→84。 |
| V | 5/0 | 有目标5–7→17/锚定命中/66清zab/79结束；空抓16退。入源5声音先于碰撞跳17，5/17各一次，不无条件顺播整图。 |

一般技能许可待机/普通X各父/卡洛X，A另允许S、Z另受击；精确CD/源许可见依据表，14槽读取同一状态。Y特殊准备、T二次费用、资源不足有反馈。死亡/退出/换角色/重试清world、views、flag、毫秒任务和声音；阵/分身/Y按源跨人物动作存续。

根2/4/6默认HP/MP各100，根41各130有原root脚本依据（investigation/crt4_default_maxima.json），不是临时值。原四装备家族中角色4共享웨펀，默认armor1/weapon0/weapon_master0/blaze0；没有第五独立家族。仓库6的2401到2为原项链展示，页8仍四家族戒指；Progression.equipment_family(crt_4)→crt_3。已接戒指购买/装备/卸下/保存共用同一家族，其他未实现交易明确禁用，不凭空赠属性。

## 4. 资源、作者与原生编辑

完整提取库留在仓库外../res，Godot的res://指本工程。当前654输出/382动画/8605选帧；角色4白名单58动画1188帧，37源68条StartSound另加脚本Sound5。catalog记原ID/路径/SHA/选帧/裁剪/pivot/滤镜；baked_placement_matrix和alpha只补偿一次，907→906的861遮罩保留。数量不代表全游戏。

按需入口：tools/prepare_act06_crt4.py生成有限rules/plan；tools/import_act06_assets.py的--crt4-animations <明确key…>、--crt4-ui、--crt4-geometry、--crt4-nested。只在派生副本/内存改选择器/拆层，不保存原SWF，不启动全库导入。首次converter/UI bootstrap只新建缺项，输入别名/jump30hold/world/nested均显式guard备份迁移，记录在migrations及对应日志。迁移不会重置手工费用/声音/布局。

派生同步可指定 `tools/sync_generated_animations.gd -- --sync-generated --keys=crt4_tombstone --report=res://artifacts/.../report.json`，仅已有ID/保UID/作者哈希。此前全sync碰到开工已有crt2_r_air.tres/catalog漂移，已逐字节恢复baseline并留证，不借本单修无关旧生成物。

原生编辑路径：content/characters/crt_4.tres、content/actions/crt4/*.tres、content/components/crt4/*.tres，真实AudioStream/offset/条件/判定；scenes/actors/crt4.tscn的AuthorOffset/Visual/ActionPreview；scenes/ui/source_hud.tscn的Characters/CRT4/SkillPanel、battle_hud_crt4.tscn、warehouse_6.tscn；content/index.tres统一注册。布局是作者权威，catalog不能反写。

**真实编辑器三项：** 完整隔离副本Inspector把Z.cost2→7、声音offset0→0.12、SkillPanel.x9.5→29.5，保存/完全关闭自身编辑器/重开/F5正常训练4/真实OS Z：MP130→123.05（含tick+.05恢复）、实际6510.mp3 playing/offset.12、运行布局x29.5。10张PNG+1387帧轨迹见native_editor_check/native_editor_proof.json及README。副本作者恢复原字节，正式作者未被试改覆盖，自身窗口已关。此证据属于其记录快照；后续Battle世界修正不冒称重做整套原生验收，最终审计单独比较三目标与消费合同，最终回归另测运行。

仍为schema1 Godot JSON，隔离档验证角色/进度/共享戒指/重开读取。原Flash SharedObject133槽不是此JSON，未做LSO/AMF往返证明，不读写原档，不宣称兼容迁移。

## 5. 实测中修正的必要问题

透明helper/controller不在过滤draw表时回查完整组件；固定root深度替换同步退出nested子，迭代快照跳过已退休对象，避免同tick复活/释放节点访问；Kalla三层共同复位、墓兵重复附着各自刷新时钟；V碰撞跳帧前消费原StartSound入帧声音，普通自定义事件保持顺序/可中断，旧0–3缺source_id的声音保留旧别名合同。

GL曾发现墓碑31永久黄碎屑：1023实际7空stop，父31保留放置不代表子可见；有限导出停帧合同仅重做本轮新墓碑图。Y旧图只有36–39边缘像素，不足可辨认证据；源84低于玩家801/1014确实应遮挡，改取后生侧置942源8验证，不抬前景。旧失败/撤回结论全保留。

## 6. 主要修改路径

| 路径 | 实际职责 |
| --- | --- |
| scripts/combat/combatant.gd、battle.gd、scripts/content/body_geometry.gd | 同父play、源入帧声音顺序、角色3独立剑气、角色4动作/判定/状态/世界对象与退出。 |
| scripts/content/action_preview.gd、scripts/core/progression.gd、scripts/ui/game_ui.gd | 新角色原几何预览、共享装备家族与整备显示；沿用现有状态/持久化。 |
| content/characters/crt_3.tres、crt_4.tres、actions/crt4、components/crt4、index.tres | 角色3仅增剑气组件引用；角色4作者数据/真实声音/有限源程序及注册，保旧0–3作者参数。 |
| scenes/actors/crt4.tscn、scenes/ui及content/stages | 原生演员、HUD/技能板/仓库6/选择标签、CRT4源HPMP与层级接入，旧页布局保留。 |
| data/act06_*、asset_catalog.json、assets、generated/animations | 有限依据与按需运行素材/派生动画；全库仍在仓库外。 |
| tools/import_act06_assets.py、prepare_act06_crt4.py、convert/bootstrap/migrate_act06* | 可复现选材、滤镜/拆层/停帧、首次转换和显式保护迁移；共享import_runtime_assets.py/render_act05_filtered.py仅可选扩展。 |
| tools/run_act06_checks.py、run_act06_gpu.py、tests/test_act06*及render_act06* | 冻结输入/隔离档/严格日志、实际输入链及世界/动作图像复核；旧gameplay/progression/act05_flow负例更新为尚禁用crt_5。 |

精确旧文件字节差异和新增作者见最终preservation_review.json及目录；不是只凭Git的未跟踪标记判断本轮新增，也未把所有未跟踪文件纳入本轮改动。

## 7. 最终验证与保护

同一最终运行版本（运行脚本/数据/作者/场景/generated/所引用assets全冻结）结果：

| 验证方式 | 结果 | 证据 |
| --- | --- | --- |
| 集中自动回归 | **34套4867项，0失败**；0脚本/引擎错误、0非预期警告；services七个有意音频负例警告保留，未屏蔽。旧角色/菜单/输入/存读档、T1、CRT4完整动作317/world825/正常流程155均覆盖。 | [final03/summary.json](../artifacts/leba_act06_20261117/final03/summary.json) |
| 实际GL动作 | 28case、94对显隐图，1452项/0失败，0错误/警告。含三段X、A早松/蓄力及三分支入口+61/89/117、S、Z/受击Z、Q、V成败、普通/卡洛空中与鬼影移动。 | [actions_gpu03/result.json](../artifacts/leba_act06_20261117/crt4_actions_gpu03/result.json) |
| 实际GL世界 | 28case、112对显隐图，1619项/0失败，0错误/警告。四阵、W/T/分身、R/E/Y、根9层级、独立存续/退出/实接触。 | [world_gpu04/result.json](../artifacts/leba_act06_20261117/crt4_world_gpu04/result.json) |
| 实际图像复核 | 最终206对：172可辨认、34原空阶段。192对normal+hidden双SHA与已看旧图相同明确复用，14对新/变化图重新view，另外R接触2对重看；412张最终PNG SHA全核。Root另外看R空尾、Y正常/隐藏/根9和A三个后续形态。此次关键样本无待解决视觉缺陷，不等于所有源帧都看过。 | [visual_review_final.md](../artifacts/leba_act06_20261117/crt4_visual_review/visual_review_final.md) / JSON同目录 |
| 来源/保护审计 | PASS；18,923选用来源、654输出、8,605帧验证通过。原SWF、旧561输出/99作者、CRT3默认配置/动作与正式profile/备份保持不变；282份generated前后仅定向墓碑一份变化。 | [preservation_review.json](../artifacts/leba_act06_20261117/preservation_review.json) |

三批的全部共同冻结文件逐项SHA相同（自动1407，GL额外含run_act06_gpu.py共1408），前后均无冻结字节或正式profile家族变化。最终 [final_delivery_seal.json](../artifacts/leba_act06_20261117/final_delivery_seal.json) 另外核最终实际文件、三批完成标记和文档SHA；保护审计落盘早于集中回归结束，那里忠实保留“当时仍进行中”，不改写历史。自己的测试/编辑器进程均已退出。

```powershell
python -B -X utf8 tools/run_act06_checks.py --name <新证据目录> --timeout 240
python -B -X utf8 tools/run_act06_gpu.py --name <新证据目录> --suite actions --timeout 300
python -B -X utf8 tools/run_act06_gpu.py --name <新证据目录> --suite world --timeout 300
python -B -X utf8 tools/import_runtime_assets.py --verify
```

自动检查包括真实Main按钮/输入/Battle推进；GL为实际550×400 Compatibility/NVIDIA RTX5070Ti framebuffer，经InputEventKey/InputMap/take_commands，非OS键盘人工签收。显隐对照同一源tick和毫秒，记ID/子帧/矩阵/atlas SHA/差分并实际看图。声音查交付Resource/offset/请求/池/退出生命周期，**Dummy静音、未试听**。原SOUNDINFO的OutPoint、LoopCount、包络和同步标志已保留为来源元数据；现有共享播放器尚未逐项复现其完整混音语义，不把源表登记说成已精确消费全部字段。

保留final01旧禁用断言/声音别名失败：只把新增已开放crt_4负例改仍禁用crt_5，其他有效链不删；final02揭示自定义声音不能先于中断事件，现仅原SOUNDINFO来源声提前，原中断测试未改，ordered_events_fix03两套403/0。world_gpu02虽0断言失败但64脚本错误，明确失败，修复退休对象复活后重跑；world_gpu03原R尾判断撤回/Y取样不足另补，不以计数掩盖图像问题。

保护范围：旧561输出、99份角色0–2作者字节不变；角色3全部30动作不变，character仅加剑气引用，source_profile默认不变。原SWF SHA afef4c43153780e9140eca7234b5af26c4a751596efefeb071d35428435a909d。外库内容191733文件/2,982,789,466字节按原manifest逐路径/大小核对；原_meta另46文件/177,377,480字节，全目录191779文件，不能混用口径。catalog全部选用来源和输出另做SHA，不宣称全191733文件新做内容hash。

## 8. 未完成与验收边界

**还需逆向/运行校准：** 原生Adobe Flash全招逐tick/跨对象callback、复杂多目标marker重复观察相位、10ms宿主调度、角色5完整行为和根11后推进、全装备特殊分支/交易、133槽真实Flash映射/样档往返。Ruffle仅上述有限探针，不证明整招总伤害/击飞/滤镜像素/全宿主精确一致。

**规则已明确但未实现：** 来源表已定位的作弊thereisnospoon准备分支、SOUNDINFO高级播放字段的完整消费、当前禁用分类中已确认的展示/导航及额外装备局部分支。角色5、根11后剧情、全装备系统仍未接入，不能因此推定这些范围的规则均已全部查明。旧0–3其他问题按原安排在全角色恢复后集中整理，不杜撰用户未反馈的具体缺陷，也不宣称旧角色完美。

**未验证：** 声音听感、用户人工整单签收。原生三项实测与最终自动/GL分开。建议一轮正常练习验角色3纯X/W及按第2节配置的后跳斩，再选4试全默认键/两态/四阵/E/R/Y、重试/整备/存读档，按需试听；开发侧应完成的核心链不以人工验收延期实现。
