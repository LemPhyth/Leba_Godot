# ACT-04：CRT1 基础音效与 Q 补修依据

调查日期：2026-11-17。本文记录 T1 的源资料、真实 Resource 审计，以及补修后的自动声音消费与受控 GL 画面复核，**不代表声音听感或用户实机最终验收**。原 SWF、仓库外 `res/`、正式作者资源和用户存档没有被本调查修改。

当前结果：`crt1/run03` 273/273；`crt1/render02` 实际 GL 14 张，日志无错误或警告。62 条主声音补迁移、8 类新增独立子源、Q 三个持续组件已进入正式资源并实际消费。详细方法、历史失败和未验证范围见第 8 节；第 3～5 节保留初查基线，不能误读成当前仍漏接。

机器清单：[crt1_audio_audit.json](../artifacts/leba_act04_20261117/investigation/crt1_audio_audit.json)。其中逐事件保留 source frame、SoundID、44100Hz 起播采样点、原 SoundInfo、作者路径、初查 SHA256 和独立时钟归属。原始 [Resource 实测快照](../artifacts/leba_act04_20261117/investigation/crt1_resource_runtime.json) 保留，不随补迁移覆盖；[子实例生命周期](../artifacts/leba_act04_20261117/investigation/crt1_nested_lifetimes.json) 包含原 PlaceObject XML、父帧/深度/移除帧和控制脚本。

## 1. 已定位的两个根因

1. `convert_act03_crt1.gd::_row()` 原来用 `int(event.frame) in row.sequence` 筛选。Godot 4.6.3 实测 JSON 数组元素为 float Variant：`2 == 2.0` 为真，但 `2 in JSON.parse_string("[1,2,3]")` 为假；转成 `PackedInt32Array` 后为真。有效声音在转换阶段被丢弃，后续 `ResourceSaver` 与 `to_runtime()` 无法恢复不存在的事件。
2. Q 持续效果的源 ID 正确，但原父 4592 对 4580/4589 的 `PlaceObject3` 滤镜没有进入派生素材。4580 原始红色笔画必须经过 25×25 模糊，4589 白点必须经过橙色辉光。裸图集直接显示，造成红色人物轮廓和白点。不是应该把 Q 改接另一个技能 ID。

声音计数更正：初步查询仅接受 `animation` 或 `animation_sound_*`，曾报 61 条；遗漏了合法别名 `crt1_skill_s_charge`（4917/f2/Sound4649）。按原转换的 `begins_with(animation)`、源 sprite 和选帧共同筛选，**应补 62 条**。原 XML 在这 34 个动作的实际选帧共有 63 条 StartSound；另 1 条是已经手工接入的 move/f7/Sound4616。手工 hit/f2/`player_hit_fx` 来自独立受击 FX4689，不计入主动作 XML 63 条。初查实际 Resource 中仅有 move、hit 两个声音事件。

## 2. 如何验证，不能据此宣称什么

- 已执行 `Godot_v4.6.3-stable_mono --headless --audio-driver Dummy --script artifacts/leba_act04_20261117/investigation/audit_crt1_resources.gd`，加载 `content/characters/crt_1.tres` 及其 34 个 Action、7 个 Component，调用真实 `to_runtime()`。退出码 0，stderr 空；没有创建 Main、Battle、AudioService，没有播放音频。
- `ActionEvent.kind` 默认是 `sound`，未序列化该行仍然是声音。因此按加载后的属性和 `to_runtime().events` 审计，未按 `.tres` 中 `kind = "sound"` 的文本数量判断。
- 对原 585,998,718 字节 XML 做只读结构查询，保留相关 330 个 Sprite 的嵌套关系；结构可达不等于默认装备一定执行，下文单独排除非默认分支。
- 实际看过 ACT-03 已留存的 GL 窗口帧 `render/crt1_q_buff.png`、当前两张 Q 子图集、原 `res/sprites/DefineSprite_4592/9.png` 和裸 4580/4589 帧。没有新增 OS 操作或原 Flash 自然输入对照；原整父 PNG 仅用于辨认滤镜差异，不作为独立子时钟运行 oracle。
- 主 Agent 已将公共筛选改为整数域，并执行定向迁移报告 `audio_migration/run_1794880056_689169/report.json`，增加 62 条，随后幂等执行增加 0 条。后续 `run03` 从正式作者资源走真实动作消费链验证 `sound_played`；主事件采用明确的生产 source seek，独立子钟采用绑定按键，不能统称自然键盘逐技能验收。

## 3. 主动作接线清单

记号 `f帧:SoundID@采样点`；采样点单位是 44100Hz，运行偏移秒数为该数除以 44100。相同帧、相同 SoundID 的两个原 StartSound 仍分别列出，不能去重成一条。无主 StartSound 不代表没有子声音。以下为迁移前快照，主 Agent 的 62 条定向补迁移针对“漏接”行；动作消耗、冷却、窗口和自定义事件不应重建。

| 动作 / 作者资源 | 主源 | 原默认声音 | 迁移前实际 |
| --- | --- | --- | --- |
| [idle](../content/actions/crt1/idle.tres) | 4824 | 无主StartSound | 无声音事件 |
| [move](../content/actions/crt1/move.tres) | 4841 | f7:4616@0 | f7:move |
| [basic](../content/actions/crt1/basic.tres) | 4860 | f6:4859@600 | 无声音事件 |
| [basic2](../content/actions/crt1/basic2.tres) | 4863 | f2:4859@600 | 无声音事件 |
| [basic3](../content/actions/crt1/basic3.tres) | 4864 | f2:4859@1000 | 无声音事件 |
| [basic4](../content/actions/crt1/basic4.tres) | 4865 | f2:4859@800 | 无声音事件 |
| [basic5](../content/actions/crt1/basic5.tres) | 4875 | f5:4640@0；f7:4859@700 | 无声音事件 |
| [jump](../content/actions/crt1/jump.tres) | 5636 | f2:4624@0；f31:4616@0 | 无声音事件 |
| [down](../content/actions/crt1/down.tres) | 4919 | f2:4624@0；f11:4616@0 | 无声音事件 |
| [skill_z](../content/actions/crt1/skill_z.tres) | 6335 | f6:4620@2200；f6:4621@3300 | 无声音事件 |
| [move_z](../content/actions/crt1/move_z.tres) | 4858 | f7:4624@0 | 无声音事件 |
| [skill_a](../content/actions/crt1/skill_a.tres) | 4851 | f4:4844@200 | 无声音事件 |
| [skill_s](../content/actions/crt1/skill_s.tres) | 4917 | f2:4649@0；f7:4859@1000 | 无声音事件 |
| [skill](../content/actions/crt1/skill.tres) | 4928 | f6:4926@0；f12:4927@0 | 无声音事件 |
| [d_follow](../content/actions/crt1/d_follow.tres) | 4954 | f2:4934@0 | 无声音事件 |
| [skill_f](../content/actions/crt1/skill_f.tres) | 5073 | f5:4868@0；f7:4859@900 | 无声音事件 |
| [skill_g](../content/actions/crt1/skill_g.tres) | 5889 | f6:4868@0；f8:4859@900 | 无声音事件 |
| [skill_q](../content/actions/crt1/skill_q.tres) | 5075 | f4:5074@0 | 无声音事件 |
| [skill_h](../content/actions/crt1/skill_h.tres) | 6338 | f2:5828@0 | 无声音事件 |
| [h_forward](../content/actions/crt1/h_forward.tres) | 5114 | f3:5085@1118；f22:5086@400；f22:5086@400 | 无声音事件 |
| [h_back](../content/actions/crt1/h_back.tres) | 5116 | f21:5086@0；f21:5086@0 | 无声音事件 |
| [h_down](../content/actions/crt1/h_down.tres) | 5122 | f22:5086@600；f22:5086@600 | 无声音事件 |
| [h_up](../content/actions/crt1/h_up.tres) | 5123 | f21:5086@300；f21:5086@300 | 无声音事件 |
| [skill_w](../content/actions/crt1/skill_w.tres) | 5137 | 无主StartSound | 无声音事件 |
| [skill_e](../content/actions/crt1/skill_e.tres) | 5158 | f2:5143@0；f3:5085@1318；f8:5085@1218；f12:5085@1418；f17:5085@1218；f22:5085@1318；f27:5085@918；f32:5085@1018；f36:5085@1318 | 无声音事件 |
| [skill_r](../content/actions/crt1/skill_r.tres) | 5164 | f2:5161@0 | 无声音事件 |
| [r_catch1](../content/actions/crt1/r_catch1.tres) | 5167 | f2:5165@0；f26:5166@0 | 无声音事件 |
| [r_catch2](../content/actions/crt1/r_catch2.tres) | 5170 | f2:5168@0；f26:5169@0 | 无声音事件 |
| [revenger](../content/actions/crt1/revenger.tres) | 5177 | f2:5175@0；f12:4957@2515 | 无声音事件 |
| [skill_v](../content/actions/crt1/skill_v.tres) | 5679 | f6:4620@2400；f6:5650@0；f21:5655@12300 | 无声音事件 |
| [skill_t](../content/actions/crt1/skill_t.tres) | 5881 | f2:5827@0；f3:5828@500；f12:345@13700；f30:5828@200；f33:5868@0；f47:5828@300；f52:5868@900；f59:4621@3800；f99:5880@0 | 无声音事件 |
| [hit](../content/actions/crt1/hit.tres) | 4920 | 无主StartSound | f2:player_hit_fx |
| [dead](../content/actions/crt1/dead.tres) | 5174 | 无主StartSound | 无声音事件 |
| [knockdown](../content/actions/crt1/knockdown.tres) | 4923 | 无主StartSound | 无声音事件 |

## 4. 已存在静态调用的独立子时钟

初查时，这 9 个独立音源时间线已有 13 条 catalog 声音事件和调用位置；当时仅确认静态接线。后续 `run03` 已逐事件观测真实消费，见第 8 节。它们不应被复制成主动作第 1 帧声音。

| 独立动画 | 源 / 声音 | 正式调用位置 |
| --- | --- | --- |
| crt1_jump_air | 5635 / f2:4859@600 | `Battle._advance_crt1_air: independent air_action_frame` |
| crt1_d_air | 4935 / f2:4859@900 | `Battle._advance_crt1_air: independent air_action_frame` |
| crt1_w_shot | 5128 / f2:4859@400；f6:4859@900 | `Battle._crt1_view_frame from _advance_crt1_w: w_shot_frame` |
| crt1_q_buff_edges | 4592 / f2:3950@0 | `Battle._crt1_event: buff starts source2 once` |
| crt1_t_ground_fire | 5845 / f1:5844@300；f4:5844@0 | `Battle._crt1_view_frame from _advance_crt1_t: independent hold clock` |
| crt1_t_air_fire2 | 5876 / f1:5844@100；f3:5844@100；f5:5844@400 | `Battle._crt1_view_frame from _advance_crt1_t: independent hold clock` |
| crt1_gunhawk1 | 6772 / f2:6761@0 | `Battle._crt1_launch_gunhawk: source entry2` |
| crt1_gunhawk2 | 6764 / f2:6761@0 | `Battle._crt1_launch_gunhawk: source entry2` |
| crt1_gunhawk3 | 6753 / f2:5878@3100 | `Battle._crt1_launch_gunhawk: source entry2` |

## 5. 初查漏接的默认嵌套声音

以下 8 个源时间线在调查基线没有对应 catalog 事件，也没有独立声音消费。多数 mp3 已因其他技能被按需导入，**文件存在不等于这里已接线**；Sound5068 的 mp3 在基线也未导入。资源与核心 Agent 已按本表完成按需补接，`run03` 验证了这些实际独立声音请求。

| 默认场景 | 子源 / 声音 | 创建、独立推进与结束依据 |
| --- | --- | --- |
| H 后/下/上 | 5115/f2 → 5085，offset0，outPoint45627 | 5116/5122/5123 各在父3新建；分别到父11/12/12移除。5115/f8 stop。默认 H 前没有这个实例。 |
| E | 5156/f2 → 4859，inPoint300，outPoint22022 | 5158 在父3/8/12/17/22/27/32/36各放两份5157；每份5157拥有独立5156，f9 stop。按实例出生触发，不以主动作帧替代。 |
| E | 5069/f11 → 5068，offset0 | 同一批5157各有独立5069，f13 stop。父36创建的最后两份在默认45返回前不足11帧，不能触发。C取消时其余待触发实例也应结束。 |
| T 起跳/落地阶段 | 5840/f2 → 4616，offset0 | 5881父15/35/52各创建两份；分别父24/43/56移除；子8 stop。没有主动作首帧播放的依据。 |
| T 空中持续段 | 5879/f1 → 5878，inPoint3100 | 5881父66创建容器5879，主父在66 stop；容器只有1帧，入口声不应随每个停留 tick 重播。原导入拆出5875/5876/5877，却漏了5879自己的声音。 |
| R 第1段 | 6771/f3 → 4859，inPoint2525，outPoint19811 | 原6772的每个独立深度实例拥有4帧自然循环；f3每轮一次。沿现有各实例出生/替换/移除状态接入，不用总技能 tick 代替。 |
| R 第2段 | 6760/f3 → 4859，inPoint1721，outPoint20414 | 原6764子实例，同上；移除或被新实例替换后旧时钟停止。 |
| R 第3段 | 6752/f3 → 4859，offset0，outPoint23429 | 原6753子实例，同上。 |

原 `syncNoMultiple` / `syncStop`、envelope、outPoint 在 JSON 中保留。T1 当前要求至少正确源流、source frame、起播偏移和生命周期；envelope/outPoint 精细处理的实际支持程度须在交付中单独说明，不能把“已记录”当成“已复现”。

不加入本轮默认播放清单的分支：4900 只在 S4917/23+ 出现，默认 S17 返回；5113 在 H前5114/86，默认23返回；5136 属 W 武器9页（5137/f1检查 `레인저무기 == 9`，5141默认1..17也不到18）；F 的5073/92→5071→5070和H前/86→5113→5112虽然也包含5069，但不属于默认范围；Revenger5177/33+ 的5157同样晚于默认21返回；D后续4954/32、36、44、47、49声音在默认1..31之外。**5069、5157必须按入口分支区分，不能因其他路线非默认就全局排除它们。**

## 6. Q 画面证据与正确修补边界

原 `DefineSprite_5075/frame_11/DoAction.as` 明确 `_root.일.데바리시간.gotoAndPlay(2)`。6732中的该对象是4592。4592从2启动，在9放4580与4589，持续至400，401开始移除/结束画面；两个子分别12帧和14帧。父矩阵为 `[1.654419,0,0,1.8181763,2.75,-126.3]`。

| 子对象 | 原父9放置 | 必需滤镜 |
| --- | --- | --- |
| 4580 / depth1 | matrix `[1.1495972,0,0,0.7391205,-2.15,113.1]`；alphaMultTerm141 | BLURFILTER：blurX25、blurY25、passes1 |
| 4589 / depth4 | matrix `[0.7174988,0,0,0.6367645,-11.35,99.4]`；alpha256 | GLOWFILTER：blurX11、blurY11、passes1、strength2.296875、RGBA(255,102,0,255)、compositeSource=true、innerGlow=false、knockout=false |

初查的 `buff.tres` 记录了正确 ID、矩阵和 alpha；`SourceSprite._draw()` 只消费图集、pivot和parent_scale；`_advance_crt1_buff()` 仅给子视觉矩阵和透明度，没有上述滤镜。原图里的红色光团本来由人物形笔画模糊而成，直接导出裸子当然能得到“正确ID的错误可见效果”。已有截图清楚呈现这种差异。不能用“原PNG也有红色轮廓”反驳用户，因为裸子PNG缺少原父放置效果。

建议复用现有4689/3887的派生包装方式：克隆原4592/f9的两个 PlaceObject3，保留滤镜，独立导出12/14子帧，并把烘入的matrix/alpha写入生成元数据。运行只补偿已经烘入的因子一次，保留作者自定义的额外布局；不要同时把子矩阵画进像素又再乘一次。根Agent已接生成Resource的 `baked_placement_matrix`、`baked_alpha_mult` 补偿接口，资源Agent负责窄更新两张派生图。起段/结束仍使用4592的对应边缘帧，不应替换整个Q为静态光圈。

后续验证目标包括：Q动作起段、持续、结束和左右朝向；移动跟随；重新释放、死亡/退出、换角色、重进无残留；生成同步和运行不重写作者布局。第 8 节明确本专项实际覆盖的部分；未执行项不能由静态依据推定为通过。

补充完整显示列表核查：原4592/f9还放置 **4591/depth6**，matrix `[1,0,0,1,-2.3,3.8]`、alpha256。4591仅1帧、唯一shape4590、无自身AS/声音，是明确可见的黄色图标，不是应隐藏的碰撞框。原9..401均保留它，402移除。修滤镜后的[静态组合对照](../artifacts/leba_act04_20261117/investigation/crt1_q_filters_comparison.png)仍缺此图标。建议添加独立 `crt1_q_buff_icon` / loop1，在9..400随parts显示；401的edges图已含该图标，不再叠一次。该补充由资源Agent发现并由本调查原XML及4591/1.png独立确认。

## 7. 后续自动回归边界

新增 `tests/test_act04_crt1.gd` 应观测生产 `AudioDirector.sound_played(alias,stream,from_seconds,voice)`，该信号在真实音频池调用play后发出。覆盖正式Resource的全部62主事件及既有move/hit、13条已有子声和上述8类新增子时钟；不仅断言catalog键存在。没有实际试听时写“接线请求与有效音频流验证，听感未验证”。

迁移用隔离Resource副本验证：整数/JSON浮点序列得到同一事件集合；保留同帧自定义声音、偏移、非声音事件、消耗、冷却和判定；重复调用不新增事件；同帧两条源事件不能误合并。正式作者文件只读，保存回读只用artifact副本。源录制不替代游戏状态，测试不临时注入事件来冒充正式接线。

## 8. 整合消费与实际 GL 画面验证

- `crt1/run01`：不能算通过。stdout虽报告168项0失败，stderr有新测试自身的脚本错误：将ContentDB已转换为SourceAnimation运行格式的数据当作原catalog，访问不存在的`source_frame_sequence`，使转换/迁移测试函数提前退出。旧日志保留；已将该夹具改为和正式转换器一样读取原JSON。
- `crt1/run02`：271项，269通过、2失败，退出码1、stderr空；捕获323次正式音频池的`play()`后`signal sound_played`请求。62主声音正式Resource和全部实际事件消费、13既有独立事件、8新增子源流/偏移、E16次flash与14次tail对应父帧、E取消、T6个phase子声及单次air容器声、R三段子循环与结束停止、定向迁移幂等及保留私有作者修改/保存回读均通过；正式作者文件和正式profile哈希不变。
- 2个失败均为左右方向的**4591图标缺失**，实际parts只有4580/4589。原显示列表要求三项的有效断言保留，不能以滤镜/矩阵测试通过替代完整Q画面。声音请求测试使用Dummy，**接线与有效流已验证；听感未验证**。主动作逐事件消费使用明确的生产source seek夹具，独立子钟与Q通过正式绑定KEY；未宣称每个主技能分支都经自然OS键盘或原Flash动态对照。

对应历史记录：[run02/act04_crt1_tests.json](../artifacts/leba_act04_20261117/crt1/run02/act04_crt1_tests.json)。以上失败没有删去或放宽断言。

- 补入独立4591、正式buff第三part和生成Resource后，`crt1/run03` 为 **273/273**，stderr空；仍捕获323次实际声音请求。比run02增加的2项为第三part在左右方向的净矩阵与alpha检查。全部原音效断言及Q图标完整性、2起段→9持续→401结束→407后清除、恢复后再次释放、换角色/重进生命周期通过。正式作者资源与正式profile SHA256均未变。[完整记录](../artifacts/leba_act04_20261117/crt1/run03/act04_crt1_tests.json)。
- 新 `tests/render_act04_crt1.gd` 使用真实Main、绑定Q输入、训练场及手动25Hz推进，在 **Godot4.6.3/OpenGL3.3/NVIDIA RTX5070Ti** 下取得真实550×400帧缓冲。左右各拍施放4、buff2/8/9/21/401、结束清除，共14张。`render01`因新脚本metadata误读`battle.stage.id`产生14条脚本错误，虽然PNG落盘且计数为0失败，也不接受为通过；日志保留。修为真实`session.run.stage_id`并增加metadata完整性检查后，`render02`退出0、stdout/stderr无错误或警告，14张均逐张目视。
- [render02/report.json](../artifacts/leba_act04_20261117/crt1/render02/report.json)保存每张截图SHA、源帧、方向、位置、组件矩阵、已烘矩阵/alpha、原4592对应PNG路径与SHA。持续9的左右截图均有黄色图标、红色光雾和橙色光点；21显示独立子动画后续姿态；401只剩结束边/图标，清除帧无Q残影。源2/8/9/401 PNG已经并列查看，原整父PNG仅作显示列表/图形参照，**不作为独立子时钟或整屏像素等价的oracle**。[右向持续9](../artifacts/leba_act04_20261117/crt1/render02/right_buff009.png)、[左向持续9](../artifacts/leba_act04_20261117/crt1/render02/left_buff009.png)、[结束清除](../artifacts/leba_act04_20261117/crt1/render02/right_cleared.png)。
- GL进程使用Dummy和Master静音、唯一隔离存档；结束等待真实音频池排空。用户已有Editor进程37196仍在，起始时间未变；正式作者和profile哈希仍相同。本轮没有改作者布局、关闭用户窗口或覆盖历史产物。

本专项没有验证真实扬声器听感、自然OS键盘连续游玩、Adobe Flash动态等价，以及Q移动跟随/死亡阶段的新增专门用例；这些仍需主整合验收。原SoundInfo的envelope、outPoint、syncNoMultiple/syncStop精细重现也不能由当前正确流/起播偏移请求自动推出。

原4592/f8透明图与场景背景上黄色光环的观感不同，未据此猜测alpha错误。资源Agent补充只读核验：原8.png的SHA与catalog记录一致；atlas的82×71区域逐RGBA字节等于原PNG按union_crop裁切，原两个3949光环的23/256、72/256 alpha保留。证据为`investigation/q_edges_source8_audit.json`；背景、缩放和图像查看器的透明底显示不能当作像素丢失结论，本项没有继续改Q资源。

## 9. CRT2 默认动作的实际 GL 与声音矩阵

完整记录为 [crt2/render03/report.json](../artifacts/leba_act04_20261117/crt2/render03/report.json)：Godot 4.6.3、OpenGL、RTX 5070 Ti，真实 Main 训练选角入口、InputMap 按住状态与按键事件，经正式 `take_commands/step` 推进。**620/620 检查、56 个用例、194 张 PNG、284 次实际音频请求**；进程退出 0，stdout/stderr 无 ERROR/WARNING。正式作者、profile 和相关 Core/catalog 哈希未变。数字是本渲染检查专项，不应重复加算为主整合功能套的检查数。

33 项主动作/反应均在矩阵中登记。普通 X 三段、A 普通/追加、S 短放/蓄满、D/V 空放与接触、C/空中 X/两种空中 Z 入口、F/G/H、H 后四段连击、W 持续与释放、E/Q/R、受击 Z、击倒、死亡分别保存左右方向图。`fallen` 明确为唯一直接调用实际 Actor `set_action` 的作者预览：原父93、子5624帧1 `stop`，本轮关卡没有已确认的自然入口，不能把该图记为自然受击成功。

声音矩阵来自独立原规则表：**31 个声音源、56 组原事件，两方向均观测到正确实际流/起播偏移**。原5469帧13的三条 Sound4002 按同用例、同源 tick 的三次请求核对，没有用多次释放凑数。空中5416的事件沿正式动作调度播放，别名为空时依公开 `air_action_frame` 与独立原事件归属，避免误当父5649的帧7/18声音。三种命中刀光还实际消费独立 Sound6。使用 Dummy；**未试听**，不承诺原 SoundInfo envelope/outPoint/syncStop/noMultiple 的精细一致性。

完整194图已通过7张接触表逐图目视，D 血效、X 横/斜刀光、R 左右独立层等疑图进一步原尺寸放大。发现空中 X 初版图仅有子2和子11，另以真实 C→held X 补拍独立子5：[render05_air_child5](../artifacts/leba_act04_20261117/crt2/render05_air_child5/report.json) 为 **19/19、2 张图、6 次实际声音请求**，与完整 render03 的 Core/catalog/正式作者/renderer 哈希完全相同；两方向白色身体、剑与橙色刀弧实际可见，落地经过渲染帧后独立视觉清除。没有为两张补图重跑完整套。

集中结论和逐图 SHA、查看方式、动作/声音矩阵在 [crt2/visual_audio_review.json](../artifacts/leba_act04_20261117/crt2/visual_audio_review.json)。总计 **196 张图**已目视，但后续主审明确发现 **R 切入仍在屏外**：撤回本节此前“未发现缺图”的总体结论，不能将节点存在与空入场图当作切入画面出现。完整620项仍是当时真实自动结果，主动作、独立R三层和声音证据保留；R切入需看后续专门复验。该范围不等于原版全屏逐像素相同、连续动作体感或 OS 键盘验收。原始裸导出会停在其他衣装/武器选择页；本轮 `act04_default_source` / `act04_pren_source` 按源选择器派生，不能凭裸 PNG 的红发/不同武器猜测当前默认资源错误。

关键判定与生命周期的证据边界：

- X 刀光按原根观察器的 `가로/왼대각/오른대각` 三具名 helper 实际生成。各段使用全新场景，前段有意打空，选定源6/6/7前仅一次放置仍在地面的敌人；不强制刀光、动作或受击。原地面行动身体在敌人浮空时不再存在，不能要求浮空目标仍触发这条观察器。
- 普通 D 接触没有凭空出现出血血效；另一用例先以真实 A22..24 状态判定产生 bleed，再由同一敌人的原4001状态 helper 与 D 判定触发5289子21。两次空间夹具均有记录，没有注入出血、抓取或录制位置。
- 根9使用正式场景和7437 AI，只有一次初始站位夹具；原攻击实际触发角色父75并恢复。4030在已接关卡主要触发父74；源93暂不冒充自然关卡行为。
- F/E/Q/R结束、空中落地与后续新训练场截图无前次临时效果残留；D 的 lust 与 H 的红色状态在有效期内保留属预期，G到期、H关闭另有清除图。退出后音频池排空，场景/正式存档哈希检查通过。

历史失败均保留：`render01` 为新脚本字段、等待和归属夹具错误，不接受；`render02` 的9项为连续X已把目标打入空中却要求地面反馈（8项）及5416真实声音错归父动作（1项），按源入口修夹具后未放宽窗口；`render04_air_child5` 两条清理断言在手动源 tick 循环后未等 SceneTree `queue_free` 帧边界而误看到待删节点，补等待实际渲染帧后 render05 通过，没有改生产 Core。

本专项没有运行原 Flash 动态逐帧对照、没有实际扬声器试听，也没有把自动输入当成 OS 键盘自然长按。编辑器 Inspector、保存后 F5 和自然操作由独立整合验收记录，不能由这196张截图推定为通过。

### R 切入可见性复核更正

原5619帧4仅调用 `_root.게임오버.컷신.gotoAndPlay(66)`；6835帧97 `gotoAndStop(1)`。6835此段没有移动自身坐标的脚本，也没有父mask修正。原XML确认6917帧1给6835局部矩阵 `[-771.15,16.6]`，该局部位移已由图集pivot公式烘入；原根6917则在 `[742.15,284.6]`。初版Core错误地再次施加6835局部位移且漏根矩阵，所以整段落到屏外。此为真实产品问题，同时暴露新renderer的 `_visible_animation` 仅检查节点/alpha、未检查视口像素的不足。

正确情况下，源66/67本来就在屏外；68开始入屏，71..89可识别，90/91退出，92..96屏外，97控制清除。原71的alpha世界矩形是 `[-177.4,184.2,393,225]`，和550×400视口相交为 `[0,184.2,215.6,215.8]`。HUD切入不随玩家朝向镜像。资源Agent的 `investigation/cutin_anchor_audit.json` 保存独立原XML与逐帧交集。

主Agent修复外加矩阵后，[cutin_supplement/run01/report.json](../artifacts/leba_act04_20261117/cutin_supplement/run01/report.json) **45/45**、退出0、无 ERROR/WARNING。只补拍 R 的71/89、结束与重进，两方向共8张正常画面，另2张同帧隐藏切入的测量基线；全部单张放大查看。左下白色角色、红黑切入已清楚可见，两种玩家朝向下切入保持原固定朝向。源97删除独立切入，动作结束和新训练场均没有旧切入残影。[右向71](../artifacts/leba_act04_20261117/cutin_supplement/run01/right_r_cutin_source071_visible.png)、[左向71](../artifacts/leba_act04_20261117/cutin_supplement/run01/left_r_cutin_source071_visible.png)。

此次还在**同一冻结游戏帧**临时隐藏这一视觉，比较真实GPU帧缓冲，再立即恢复，没有改变动作/子时钟。71的实际像素贡献分别为 **34,996 / 34,991 像素**，原alpha参考覆盖34,792像素；贡献均在预期视口交集内，区外0。实际世界alpha矩形与上述源坐标一致。该验证会暴露旧“有节点但屏外”的问题，未再以节点存在充当画面证明。

修后补拍相较render03只有已列明的 `Battle`、catalog及CRT2 `visuals.tres` 三个哈希变化，不能称与旧Core相同；补拍内部哈希和正式存档稳定。其余196张历史图未重拍、未覆盖；集中review保留这次遗漏、撤回与修复记录，并加入8张修后图和2张测量基线。原620的主动作/独立层/声音结果与新的R专项应分开引用，不把补拍当作重新执行全部技能回归。
