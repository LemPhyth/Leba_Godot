# LEBA-ACT-01 M1 资源与动作依据

2026-11-13。已完整阅读M1工单、根AGENTS与动作校准续报，复核当前工程增量。本文件集中记录本轮C、空中X、Down及Z最小资源，后续补充继续写入本文件。原始SWF、完整提取库均在Godot仓库之外且只读；未改Battle、Combatant、Main、ContentDb或测试。以下“确认”指AS2/XML静态事实；派生图片检查不等于原作动态或真实键盘验收。

## 1. 会影响执行方式的原作事实

### C与独立空中X

父6732的待机1、移动2的keyDown监听检查`Key.isDown(67)`，gotoAndPlay95；不是新按下C的边沿判断。父95自身stop，可见`동작`=5633，初始placement为`[7,1565]`twips，即`[.35,78.25]`px。5633实际35帧，源35回父1。没有发现默认分支给玩家根y赋跳跃重力；可见升降由5633内的子placement纵向补间形成，不套用敌人受击浮空公式。

- 5633源1..3为起跳部件；4..14的`점프중`=5627，5627源1stop，默认保持这一姿态。
- 源15重新放`점프중`=5628，实例有load/enterFrame；5628共6帧，1stop、2play、6stop。它是独立输入时钟，不能按5633外层帧数自动播射击。
- 源30移除原5628，重新放一个无name/无ClipActions的5628；源31移除它并恢复落地部件，源35再放的5628也同样无name且与返回脚本竞争。不能将源15实例的射击状态延续过源30。
- 4937是透明辅助元件，源4放入并持续到35被替换；它检查**具名점프중的子帧==1**时，先右键根x+4/朝右，再左键根x-4/朝左。两键都按时净位移0、最终朝左。源4..14默认5627停1，因此上升段也有此方向移动。

5628源15 placement的enterFrame顺序明确为：

1. 子帧!=1：根x先减`3*bug1`；再处理左键，朝右时减`9*bug1`、朝左时加`3*bug1`；最后右键，朝右时加`3*bug1`、朝左时减`9*bug1`。这里不修改朝向。即射击时不按方向会后移3；按朝向方向抵消后移；按反方向后移12。两键同时按的结果还要结合4937同tick顺序核查。
2. 子帧2或3：attach链接`대각총알`=1385到**玩家6732**，仅设置弹的`_y=220+this._y`，i++。不是加5633父offset后再创建，也不是从世界坐标自由发射。load的i初值1。
3. 轮询held X；子帧1或6时gotoAndPlay2。其keyDown处理器为空，所以空中X与地面事件监听不同。默认没有MP消耗和父stop延长；特殊zak/eun与武器条件才涉及5630计时器，不在本轮默认范围。

精确路径（均相对工作区根目录）：

- `res/scripts/DefineSprite_6732/frame_1/PlaceObject2_4544_7/CLIPACTIONRECORD onClipEvent(keyDown)_2.as`
- `res/scripts/DefineSprite_6732/frame_2/PlaceObject2_4617_7/CLIPACTIONRECORD onClipEvent(keyDown)_3.as`
- `res/scripts/DefineSprite_5633/frame_15/PlaceObject2_5628_1/CLIPACTIONRECORD onClipEvent(enterFrame).as`及同目录load。
- `res/scripts/DefineSprite_5633/frame_4/PlaceObject2_4937_93/CLIPACTIONRECORD onClipEvent(enterFrame).as`及源35同目录。
- `res/scripts/DefineSprite_5633/frame_35/DoAction.as`、`DefineSprite_5628/frame_1,2,6/DoAction.as`。

### 身体独立于可见跳跃

父95同时放名为몸빵的4745，初始偏移`[94,69]`twips。它独立推进26帧：1..6放4545，7移除，7..25**显示列表没有形状**，26重新放4545并stop。父12的몸빵=4673，偏移`[94,1449]`：1..9没有形状，10放4545（局部y=-1380twips）并stop。两者有形状时actor局部包围矩形都为`[-28.2,-67.05,65.8,141]`，不随可见身体升降。

这是XML PlaceObject/RemoveObject/ShowFrame事实，不是由PNG透明推断“无敌”。Godot应保持身体自身年龄与停帧，空白帧提供空形状；最终是否受击仍由原碰撞与状态规则决定。受控原作hitTest与各时钟相对阶段由主Agent核验。

### Down是后撤动作

父1、父2和六段X对应父7/8/9/10/16有keyDown检查Down40→父12。父12stop；`이동`=4672共12帧，placement`[-3,72.45]`px。父placement enterFrame在子帧<=11时根x减`5*bug1`；源12 DoAction再将`this._x*bug1`加到根x并回父1。默认this._x=-3，所以结束承接额外后移3；实际前段回调次数不能只由12张图乘时间决定。

4672内4671自己的纵向运动保留在图集，不变成玩家根y位移。身体使用上节4673独立时钟。其他角色进入父12有各自返回分支，本轮不将crt0规则推广给它们。

依据：`res/scripts/DefineSprite_6732/frame_12/PlaceObject2_4672_7/CLIPACTIONRECORD onClipEvent(enterFrame).as`和`res/scripts/DefineSprite_4672/frame_12/DoAction.as`。

### 斜弹1385

1..10内含542，默认541/542都停1；由逐帧完整矩阵产生向右下的轨迹，不能只复制水平弹速度。源11移除所有可见/判定子元件并stop，但不删除空父容器；源12stop后removeMovieClip。542的enterFrame另检查玩家父95/96且动作35，满足时令弹父gotoAndStop12。空容器的工程清理应与源移除机制分开记录。

默认普通身体命中设置目标重力=-3、加速度+=.1，并令空中共享marker gotoAndPlay2；没有本地固定扣HP。每颗弹分别有hita/hita2..5去重。链接名及斜向轨迹不能证明更高伤害。装备/冰/霸体分支不因此视作全部完成。

依据：`res/scripts/DefineSprite_1385_대각총알/frame_1/PlaceObject2_542_1/`中的load、enterFrame及enterFrame_2；源11/12的DoAction。

## 2. 最小导入与坐标合同

| 运行时键 | 源ID/选帧 | 图集已含父偏移px | 用途与独立处理 |
| --- | --- | --- | --- |
| crt0_jump | 5633 / 1..35 | `[.35,78.25]` | 保留起跳、上升和落地；默认5627固定源1；移除独立5628图形及其所属depth1更新 |
| crt0_jump_air | 5628 / 1..6 | `[0,0]` | 独立空中射击；按外层源帧矩阵放回 |
| crt0_down | 4672 / 1..12 | `[-3,72.45]` | 后撤身体表现；根位移由源回调承接 |
| projectile_diagonal | 1385 / 1..12 | `[0,0]` | 默认斜弹，包含11/12透明控制节点 |
| crt0_skill_z | 4622 / 1..14 | `[-3,3.25]` | 普通Z初始位置；动态child.x仅追加差值 |
| crt0_move_z | 4625 / 1..22 | `[-45,.85]` | 移动Z；根移动与body局部缓动不烘入 |

资源从原SWF在内存派生，不写回SWF；统一裁剪及pivot沿用现有导入器。完整元数据集中于`data/asset_catalog.json`：

- `source_geometry.crt0_jump.air_overlay_by_frame`记录5633源15..30与终止35的5628矩阵；`offset_px`**已合并5633父偏移**，`child_offset_px`仅为5628相对5633位置。绘制选择一种合同，不要重复叠加。源30标新实例且禁止原source15输入监听。
- `crt0_jump.body_track`与`crt0_down.body_track`逐身体源帧明确`empty/rect/shape_id`，终止帧hold；它们不是可见动作帧索引。
- `projectile_diagonal.timeline_matrices`精确保存1..10的六参数矩阵；公式`x=a*x+c*y+tx,y=b*x+d*y+ty`，再应用弹父偏移及玩家根变换。判定基础rect属于542，不用光晕/图集边缘替代。
- Z初始父偏移已含于图集pivot。普通Z的child.x按`x+=(10-x)/2`变化时，仅追加`current_child_x-initial_child_x`；不能再加一次完整父偏移。普通Z父5移除正常身体，移动Z父6身体的局部x按`x+=(180-x)/6`变化，和可见动作位置分开。此除数已直接复核`res/scripts/DefineSprite_6732/frame_6/PlaceObject2_4547_145/CLIPACTIONRECORD onClipEvent(enterFrame).as`；早先交接的/2已更正，未重渲染图片。

Z窗口及矩阵由关卡/规则调查协作者复核XML并交接：4622源6..8为1234、9移除；4625源7..10为439、11移除，两窗内判定placement矩阵不变。具体命中、毫秒拖动和双入口竞争由主Agent及规则调查整合，本资源文件不宣称那些行为已运行通过。

## 3. 音频及验证边界

全部按原StartSound登记：跳跃源2/31、Down源2/11、空中5628源2、普通Z源6的两个声音、移动Z源7。复用已导4616/4421，只增加必要4624、4620、4621；保留原in/out point和包络，无循环推定。未播放声音，未启动有声窗口。

本批派生前，旧1038源/50输出/757动画帧只读校验通过。窄范围派生与实际看图确认默认服装、空中枪口特效、后撤和Z姿态；5633底图15..30/35透明，5628独立1..6非空；Down12透明；斜弹11/12透明。由源矩阵确定锚点，没有按可见边缘重新居中。正式导入及校验结果在下方追加；本子任务不把静态图集检查写成Godot运行、原作调度或真实键盘验收。

正式导入完成：40组动画、858选帧、59个去重输出、11,391,812字节。`python godot/tools/import_runtime_assets.py --verify`退出0，1229个源哈希、59个输出哈希及858帧区域/pivot/透明隔离检查均PASS。另与导入前catalog逐项比较，旧50个输出哈希全部保持不变，原SWF记录及哈希未变。新增仅6张图集和3个声音文件。

为避免手工转写矩阵出错，再独立读取原XML，将17个5628外层放置、10个斜弹矩阵、36个独立身体帧的形状存在性、7个Z判定窗口矩阵与catalog逐项比较，共70项全部一致。该检查直接来自XML，既不由当前Godot结果反推，也不依赖PNG透明度判断身体规则。本批未运行Godot实际窗口、键盘或原生Flash；原作探针与整体动作回归由主Agent记录。

## 4. 2026-11-14 解析既有原作样本

独立只读工具`tools/analyze_m1_basic_probe.py`读取11月13日的`leba_act01_basics_20261113`及`leba_act01_native_20261113`日志，输出`artifacts/leba_act01_20261113/controlled_basics.json`。JSON保存日志快照哈希、observer哈希与provenance核对、源行号、逐tick原字段及位移差；undefined/NaN不替换为0。受控日志30..389采样完整，含结束标记，无重复记录。没有重新运行原作。

| 样本 | 已观测范围与结果 | 仍不能证明 |
| --- | --- | --- |
| C无输入，t80..114 | 父95/子1..34；t114回父1，根x不变。body1..6有宽度，7..25的原getBounds左右相等，26恢复并停；子30起具名sub为undefined | 真实C入口、方向移动、空中X |
| C另三组，t125..159、170..204、215..249 | 同样1..34后回父1；根x全不变、具名sub仅1、无斜弹记录 | 声明的held方向/X未驱动原行为，不能称输入测试通过 |
| Down朝右，t260..271 | 入场x129.35；t261..270每次-5；t271回父1再-3；总-53 | 真实Down键入口、碰撞取消 |
| Down朝左，t290..301 | 镜像位移，总+53 | 同上 |
| Z父5，t320..333 | 子1..13；child.x=-3,3.5,6.75,8.35,9.15,9.55,9.75,9.85,9.9,9.95,9.95,9.95,9.95；t333回1，根+9.9 | 直接goto未验证耗费/冷却、Z双入口竞争；9.95与9.9差异不编造固定-0.05补偿 |
| Z父6，t355..376 | 子1..6无根位移；采样子7..10各+20、11..14各+10、15..18各+6、19..21各+4；t376已回父1但仍+4，总160 | 末尾22是被执行后消失的控制节点，不能算额外完整显示帧；真实移动Z入口未验证 |
| host Z事件，t2751/2752之间→2764 | 原code90有记录；t2752已父5/子2，MP100→97.05，之后逐tick+0.05；t2764回1，根+9.9。净-2.95配合回复与原MP3脚本支持消耗3 | 没有采到子1；没有keyup/完整held快照，不能断言完全隔离输入或冷却；不是Adobe Flash |

受控mock失败的直接证据：t50..65根x只有129.35、父始终1；四次C的射击子帧仅1，斜弹记录为0。原observer尝试赋值Key.isDown，却没有回读函数或统计原clip调用；只能确认预期输入行为没有生效，不能据日志定性为某个确定的只读属性/作用域故障。

host日志完整保留了更早的65(A)、87(W)事件（t1454/1455之间）、39右键（t2201/2202之间）；90(Z)在t2751/2752之间。键日志自己没有tick，区间由前后采样夹定，不能伪造精确输入tick。日志名native表示真实主机事件，宿主仍是Ruffle且启动有fixture捷径。

另提供`tools/probes/m1_held_input.as`供主Agent注册：尝试普通`_root.Key`影子对象，保留`_global.Key`；自查询不计入原clip调用计数，输出每tick解析路径、真实调用计数、动作与斜弹对象。“自查询返回true”不能单独成为空中X通过证据。

主Agent完成编译后，已按追加授权独立运行唯一派生`leba_act01_held_20261114/observed.swf`，Ruffle0.7.1、Hidden、volume0、memory、独立run1配置/缓存及`RUST_LOG=warn,avm_trace=info`。刻意干预包括启动捷径、各例player x250/朝右、直接goto95、enemy x900以隔离接触；没有替换原脚本。t300收到SHADOW_DONE后，核对自建PID50200的可执行路径与精确启动时间，只停止该PID；launch.json记录已停止，未触及其他进程。

**替代方案没有驱动原输入。** 40..299的260条记录完整，global_unchanged始终true；方向/X窗口中visible/root自查询均可返回true，但mock_total和原clip调用记录数始终0，根x保持250、空中sub仅1、没有斜弹对象。JSON的`held_shadow_experiment.status`为`failed_to_drive_original_polling`，包含完整记录、日志哈希、干预及启动信息。此结果表明探针自身作用域中的影子对象没有被目标原clip轮询采用；精确AVM1解析机制仍未知，不再自动扩展重复试验。移动与空中X动态对照继续标未验证，不能凭原静态脚本或mock自查询补写成功。

## 5. 2026-11-14 重力身体与基础场景墙边界

4546重力身体实际1帧，内部4545偏移`[0,-1380]`twips；4547受击身体实际2帧，默认源1与4546完全相同，但源2移除图形。FFDec两者clip bounds均为`[-658,-2790,658,30]`twips。

| 6732父帧 | gravity实例depth | gravity父偏移twips | hurt身体差异 |
| --- | ---: | --- | --- |
| 1 | 143 | `[94,1449]` | 4547默认1，与gravity同几何 |
| 5 | 143 | `[94,1449]` | 正常hurt身体已移除，gravity仍在 |
| 6 | 143 | `[94,1449]` | 4547初始同位置，此后hurt局部x按/6缓动，gravity不跟随 |
| 95 | 1017 | `[94,1449]` | hurt换成4745独立空白帧时钟，gravity仍为静态4546 |

上述gravity placement都无缩放/旋转；合成actor局部矩形固定`[-28.2,-67.05,65.8,141]`，再经过玩家根缩放/翻转。因此可以确认默认矩形恰好等于地面hurt矩形，但必须独立读取，不能在跳跃、Z缺失hurt或hurt局部移动时跟着改变。已登记`source_geometry.player_gravity_body`及可重现导入器定义，没有新增图片。

墙的实际结构与“必有边界多边形”预设不符：

| 根场景 | 名wall的实例 | 已核形状 |
| --- | --- | --- |
| 2 | 实际根显示列表没有此命名placement | 无可提取polygon |
| 4 | 7131、depth1、偏移`[5378,4233]`twips=`[268.9,211.65]`px，单位矩阵，alpha0 | 7131只有SoundStreamHead2和ShowFrame，没有任何shape或嵌套placement |
| 6 | 与根4相同 | 同样为空sprite |

FFDec对7131的stroke/filter bounds均为`[0,0,0,0]`。检索完整提取AS未找到wall的动态绘图、赋值或attach代码；以上为当前提取资料覆盖结论，未做新的原宿主点测。`source_geometry.stage_wall`明确登记missing/empty状态与`polygons=[]`，**不把空元件伪造成实心矩形**。

原玩家根实例的`CLIPACTIONRECORD onClipEvent(enterFrame)_6.as`（根2`PlaceObject3_6732_909`、根4`...1652`、根6`...933`）依次对`이동.getBounds(_root).xMax/xMin`及`중력몸빵.getBounds(_root).xMax/xMin`，以玩家根y作`wall.hitTest(x,y,true)`点测；每项成立分别根x-10、+10、-10、+10。它不是35..520夹限，也不是hurt矩形重叠检测。

演员内部的额外硬夹限位于6732父14/44受击body4547附属enterFrame：x按`_width/2 .. 550-_width/2`，y也按`_width/2 .. 400-_width/2`，不能改成height或推广到所有动作。路径分别为`res/scripts/DefineSprite_6732/frame_14/PlaceObject2_4547_145`及`frame_44/PlaceObject2_4547_572`下的enterFrame与enterFrame_2。

**全AS补检找到了独立的共用根坐标边界，不能因wall为空就解释成可无限走出屏幕。** 来源为`res/scripts/frame_1/PlaceObject2_3829_4703/CLIPACTIONRECORD onClipEvent(enterFrame)_2.as`：`pren==0 || pren==1`时，玩家`일`和具名敌人`적/적2/적3/적4/적5`的根x均夹到`0..550`，不减角色宽度；else分支只有这些敌人夹到`-100..650`，玩家不在该分支夹限。XML实际显示列表确认3829实例`방도`、depth4703在根1放置后，根2/4/6均保留原实例及原clip actions；三场DoAction都初始化`pren=0`。因此本轮默认场景有明确`0..550`源规则，全局35..520是工程临时值。此根回调与演员自身回调的同tick执行先后尚未动态核验。

同时核对了6732父1共用4519/1240：4519回调只在crt5时隐藏动作元件，1240回调为空；父18的1240仅在crt4时跳父146，没有屏幕边界逻辑。完整AS检索未找到通过`Stage.width/height`实现的演员全局夹限。其他场景的3829有独立分支（如根62/64/89），不把默认2/4/6规则无条件推广到全游戏。

本次只更新`player_gravity_body`、`stage_wall`、`stage_actor_bounds`元数据及导入器来源，59个既有输出逐项哈希保持不变，无资源重渲染。导入器`--verify`核验1229个来源哈希、59个输出哈希、858帧通过；没有进行新的原宿主边界运行对照。

## 6. 2026-11-14 清除只读标记后的受控轮询对照

后续已定位到`Key.isDown`的READ_ONLY位4，新增`tools/probes/m1_held_native.as`，只清除该位并在**原Key对象**替换方法，不再放置_root.Key影子。保留真实原函数；非控制区间按原`this/arguments`委托。t300还原原函数、设置只读位4，尝试写入以验证拒写。此实验是方法级受控输入，不是自然键盘事件，也不是Adobe Flash运行。

原作派生文件`tools/swf/runtime_probe/leba_act01_held_native_20261114/observed.swf`在Ruffle0.7.1以Hidden、volume0、memory及独立run1配置运行一次。收到DONE后校验可执行路径及精确启动时间，只停止自建PID33248。完整40..299共260条记录；DONE报告1548次非探针原轮询，`this_mismatch=0`，原Key对象、原函数、只读拒写、rootKey未改均为true。与此前两次失败记录分开保存，未覆盖失败证据。

独立结果为`artifacts/leba_act01_20261114/held_native.json`，复现命令：

```powershell
python tools/analyze_m1_basic_probe.py --held-native-log ../tools/swf/runtime_probe/leba_act01_held_native_20261114/run1/log/ruffle.log
```

| 控制与样本 | 原样本事实 |
| --- | --- |
| right输入50..59；位置采样50..60 | 每tick+6，累计+60，朝右 |
| both输入60..69；位置采样60..70 | 每tick净位移0，朝左，仍父2移动 |
| left输入70..79；位置采样70..80 | 每tick-6，累计-60；释放后81父3、82父1 |
| C起点110、165、220 | 父95子1..34；下一tick离开父95 |
| 三次C持X | 源15子1、16子2、17子3并第1弹；18子4、19子5、20进入子6后轮询跳2；21/25/29各发一弹 |
| 右面向的空中反向左输入 | 源22..29每tick-12，朝向仍右；最后空中x139，返回tick199立即父2/x133/朝左 |
| 左面向的空中反向右输入 | 源22..29每tick+12，朝向仍左；最后空中x361，返回tick254立即父2/x367/朝右 |

本样本没有观察到源6的queued stop将子动画永久停在2；CALL记录能在同一源20内先看到6，再看到跳转后的2，下一采样进入3并发弹。这里是默认分支三次样本的实际序列，不能推广为所有装备固定射击周期。

探针自身的`new_shots/shot_total`存在已发现的计数缺陷：同名MovieClip被替换时，保存的引用比较仍会相等，因此总数6漏计后两次C复用名字的弹。分析器保留这个原始错误值，并以**原子元件i从1递增至5**和对应弹帧重置1相互确认每跳4发、三跳12发。空白停止在源11的弹对象跨用例保留，不能把当前对象数量当生成次数。

采样发生在后续原回调之前：例如observer t124显示父子15，但同轮CALL已显示16，因此报告同时保留CALL源帧与下一采样，不用统一±1换算掩盖阶段。首个影响当前Godot执行关系的差异是返回地面当tick的方向移动；原例t199/254已父2并±6，而先轮询输入再推进动作的实现会推迟到下一tick。此处交付原样本与静态调用链依据，实际Godot修正及对照回归由主Agent和测试交付记录负责。

## 7. 2026-11-14 普通Z默认外观选择器修正

GPU截图`render/z_07.png`的紫发来自未执行嵌套衣装脚本的导出结果。不是Z新增技能效果，不能直接删除图片里的紫色。结构核对：4622源7的depth1放置3632（sx1.6371918、sy1.6547699、twips偏移[-901,-686]），3632源1再放置3631；3632仅在pren1变色，**3631**根据crt0衣装2/3/4/5/6跳2/3/5/8/10，默认衣装1应停源1。独立depth62的3761（sx1.0378876、sy1.0497437、twips[-297,-675]）也应停透明源1，只有crt0衣装2取紫色源2、crt1衣装2取橙帽源3。

首次补外层3632和3761后，实际查看派生源7仍紫发；继续追入3631，确认外层冻结并不冻结内层衣装。最终依据各自`res/scripts/DefineSprite_ID/frame_1/DoAction.as`，补全3631、3632、3650、3659、3761、4634的默认停帧。3650/3659是有明确衣装分支的手部选择器；4634仅在zak1/eun1取2/3，默认0/0保留源1弹药表现。没有更改原脚本或擦除原效果。

结构依赖核查后只刷新三个现有动画：X首段4637、S4668、Z4622。结果X/S图集及其他输出均与修正前一致；**只有`assets/atlases/crt0_skill_z.png`改变**，58个其他运行输出哈希不变。Z的画布及统一裁剪范围变化由FFDec实际bounds计算：新canvas220×275、pivot[50.6,66.25]，未按画面中心重新猜锚点。`selector_correction/result.json`保留前后哈希与逐帧像素比较，原派生图和catalog保留为before证据。已实际查看新的Z源7，默认灰白后脑和原有动作图形正常；最终Godot GPU整图由主Agent重渲染验证。

按需再生成入口：`python tools/import_runtime_assets.py --refresh-animations player_basic crt0_skill_s crt0_skill_z`。该入口先核验已有源/输出哈希，只更新登记的选择范围，保留其他元数据及输出，继续拒绝覆盖未登记或本地改动资产。最终`--verify`：1235来源哈希、59输出、858选帧通过。完整原始库仍在Godot仓库外。
