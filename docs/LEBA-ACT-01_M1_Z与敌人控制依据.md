# LEBA-ACT-01 M1：默认Z与敌人控制依据

2026-11-13。已读M1总工单、AGENTS和现有角色/受击依据；Godot仓库仍为main，README及大量未跟踪成果保留。本分工只读原脚本/XML并记录本文，不改Runtime、导入器、catalog、资产或探针构建器。根Agent负责动态探针和统一执行链；本报告不表示Z已接入或动态验收完成。剧情不扩展。

路径以工作区`C:/Users/24782/Desktop/leba_project`为基准；`res/`是仓库外提取库。父帧指6732；动作子帧指4622/4625等；twips除20才是局部像素。声明和实际ShowFrame均核对，未以PNG数量推断时间轴。

## 1. Z有两个入口，竞争顺序必须实测

| 入口 | 原路径（相对res/scripts） | 明确条件和效果 |
| --- | --- | --- |
| 技能栏 | `DefineSprite_4064/frame_1/PlaceObject2_4051_1/CLIPACTIONRECORD onClipEvent(keyDown).as` | keyDown事件发生时Key.isDown(90)；父帧<5，或7..10，或14，或16；MP>=3扣3，父gotoAndPlay5；thereisnospoon!=1时技能栏잭스파이크 gotoAndPlay2；MP不足则游戏界面부족 gotoAndPlay2 |
| 移动动作 | `DefineSprite_6732/frame_2/PlaceObject2_4617_7/CLIPACTIONRECORD onClipEvent(keyDown)_2.as` | keyDown时Key.isDown(90)便父gotoAndPlay6；此脚本没有MP、技能栏冷却、敌人或动作子帧检查 |

两者均不是“仅Z的刚按下事件”：源检查按住状态，不检查事件keycode。X或其它键事件与Z同时按住时也可能参与竞争。父14受击允许技能栏Z取消；父5/6不在技能栏Z许可集合内。

4064实际66帧：f1 stop并放4051输入节点；f2移除该节点、改放无输入4063；f66改4031；无末帧stop/显式返回，时间轴自然绕回f1。静态不可输入段为2..66，共65帧；25FPS名义2.6秒，实际首尾事件阶段需探针对齐。冷却阶段只移除技能栏监听，不会自动移除移动4617的独立Z入口。原4391 f1 depth124放4064，名잭스파이크。

同一移动Z事件的静态候选：技能栏先且移动监听随子销毁失效→父5/扣3；移动监听先→父6，技能栏见6拒绝/不扣；若已排队的移动监听在销毁后仍执行→父6/扣3。**这是待排除候选，不是三种已实测规则。** MP不足或技能栏冷却时移动监听是否继续触发也必须覆盖。

## 2. 普通Z：父5、4622、动态偏移、身体

父5脚本stop；placement为4622，名동작，depth7，初始(-60,65)twips即(-3,3.25)px。`DefineSprite_6732/frame_5/PlaceObject2_4622_7/…enterFrame.as`每次执行：

```as
this._x += (10 - this._x) / 2;
```

这是动作子实例局部x的缓动，不是每tick给玩家根加10。4622实际14帧，`frame_14/DoAction.as`：

```as
_root.일._x += this._x * _root.bug1;
_root.일.gotoAndPlay(1);
```

正常结束才把当前子x直接乘bug1加到玩家根；源码没有额外乘角色缩放。中断进入其它父状态时不能补做已被跳过的f14承接。

XML父5明确Remove depth145的몸빵=4547；depth143的중력몸빵=4546仍保留，位置(94,1449)twips。当前4030/7176普通攻击以몸빵为目标，因此父5不能继续使用常驻通用hurt矩形。重力/敌近距触发另读중력몸빵，不能一并删掉。这里只说明命名身体存在性，不推广成所有攻击的通用无敌。

S4066与D4068的默认状态许可也排除父5/6；不能给Z随意增加S/D取消。父5因当前普通攻击所读身体缺失，强制goto受击fixture只算干预，不是自然受击许可。

## 3. 普通Z的判定与计时器：完整原码

4622 f6放1234于depth30，f9移除，故存在于f6..8。1234自身两帧均stop：默认f1显示shape1232；冰冻/霸体交互才请求f2 shape1233。以下是`DefineSprite_4622/frame_6/PlaceObject2_1234_30/CLIPACTIONRECORD onClipEvent(enterFrame).as`的全部原码：

```as
onClipEvent(enterFrame){
   function Flying()
   {
      if(_root.적.중력가속도 > 0)
      {
         _root.적._x += 3 * _root.일face;
      }
      if(_root.적2.중력가속도 > 0)
      {
         _root.적2._x += 3 * _root.일face;
      }
      if(_root.적3.중력가속도 > 0)
      {
         _root.적3._x += 3 * _root.일face;
      }
      if(_root.적4.중력가속도 > 0)
      {
         _root.적4._x += 3 * _root.일face;
      }
      if(_root.적5.중력가속도 > 0)
      {
         _root.적5._x += 3 * _root.일face;
      }
   }
   function clearFly()
   {
      clearInterval(_root.flyInt);
   }
   if(_root.적.속.행동몸빵.hitTest(this))
   {
      _root.적.중력 = -15;
      _root.적.중력가속도 += 0.1;
   }
   if(_root.적2.속.행동몸빵.hitTest(this))
   {
      _root.적2.중력 = -15;
      _root.적2.중력가속도 += 0.1;
   }
   if(_root.적3.속.행동몸빵.hitTest(this))
   {
      _root.적3.중력 = -15;
      _root.적3.중력가속도 += 0.1;
   }
   if(_root.적4.속.행동몸빵.hitTest(this))
   {
      _root.적4.중력 = -15;
      _root.적4.중력가속도 += 0.1;
   }
   if(_root.적5.속.행동몸빵.hitTest(this))
   {
      _root.적5.중력 = -15;
      _root.적5.중력가속도 += 0.1;
   }
   _root.일face = _root.bug1;
   clearInterval(_root.flyInt);
   _root.flyInt = setInterval(Flying,10);
   clearInt = setTimeout(clearFly,500);
}
```

可执行事实：

- 每次enterFrame分别检查根命名敌적、적2..5的`속.행동몸빵.hitTest(this)`；是对象包围盒hitTest，没有shapeFlag点测。
- 每次相交只设重力-15、加速度+=.1；无每敌命中次数标志，不直接扣HP，不显式seek敌受击标记。
- 计时器语句位于五个if之外；**无命中也会执行**。同一个1234在存续期间每次enterFrame清当前全局interval并新建10ms interval，同时新建500ms timeout。
- Flying每次遍历五个命名敌，只看加速度>0就横移`3 * _root.일face`；没有HP门槛，没有本次被Z命中过的集合，也不要求仍与Z相交。
- `_root.일face`每次该enterFrame写为当前bug1；它是运行时共享值，不是每个回调的固定捕获朝向。
- clearFly读取执行时的`_root.flyInt`，清除的是当时最新interval；旧timeout可能清掉更新的interval。每次覆盖局部clearInt变量但没有clearTimeout，因此不能实现成仅“最后一次刷新后的500ms”。
- 全提取AS中flyInt/clearFly还出现在3962、6335、6594，后两者与此结构相同；本轮默认角色0不扩展这些装备/角色分支，但不能把全局ID关系误记为原作每动作独立ID。
- 当前查到的Z脚本没有unload时主动clear，也没有玩家受击/父返回时clear；销毁1234后宿主是否继续调用函数、实际10ms粒度/过期合并须运行确认。Battle退出清理属于本轮生命周期要求，需与原作观测分开说明。

新增局部毫秒队列应保留：创建时刻、下一次interval到期、独立timeout列表、当前全局interval引用、共享方向；不是把10ms四舍五入成源tick，也不是对每个受击敌创建新计时器。暂停冻结和场景退出清空按本轮要求处理，不能称为已确认原Flash暂停行为。

### 默认判定几何

| 项 | 1234普通Z | 439移动Z |
| --- | --- | --- |
| 出现/移除 | 4622 f6 / f9 | 4625 f7 / f11 |
| 默认形状 | 1232 | 299（439 f1内） |
| 形状bounds twips | xmin-925 xmax925 ymin-966 ymax965 | xmin-2048 xmax1918 ymin-1144 ymax3209 |
| 判定placement | sx1.2986298 sy1.7942505 tx1141 ty-765 | sx.4582672 sy.35092163 tx3168 ty563 |
| 子动作内Rect2(x,y,w,h) px | [-3.01162825,-124.91229915,120.1232565,173.234885775] | [111.47343872,8.077282764,90.87438576,76.3780927695] |

表中矩形仅包含判定placement，尚须叠加动作子实例局部offset，再应用玩家根缩放/翻转和位置。普通Z的动作x持续变化，不能只取初始-3。移动Z父偏移(-45,.85)可另存。1234非默认f2形状bounds为xmin-1372 xmax1479 ymin-1608 ymax1324；本轮没有把冰冻/霸体支线实现成默认伤害。

### 不能把“仅物理赋值”误解成“整个Z必为零伤害”

首次地面上挑会通过敌重力观察器切外层2，创建4028/7175的空中层；两者f1均放唯一타격=3889，f2移除。3889 f1没有stop，f2有组合计数脚本。敌根4030 `_24.as`与7176 `_39.as`观察该标记f2扣5；crt0还受既有3835常驻10影响。

因此首次新建空中层可能产生自然标记伤害，而已在空中的Z再挑没有源码显式重启标记。**不能给每次Z相交直接固定15或0，也不能无差别调用会seek2的通用_start_marker。** 需对照首次地面与既有空中marker≥3两种样本，区分物理更新、组件创建和标记seek。

## 4. 移动Z：父6、4625、滑行与身体位置

父6 stop；名이동的4625放于depth7，(-900,17)twips=(-45,.85)px，实际22帧。父placement的`…enterFrame_2.as`按子帧对玩家根直接移动：

| 子帧条件 | 每次enterFrame根x变化 |
| --- | ---: |
| 7..10 | +20×bug1 |
| 11..14 | +10×bug1 |
| 15..18 | +6×bug1 |
| 19..22 | +4×bug1 |

f22 DoAction令玩家gotoAndPlay1；f22回根与父enterFrame移动哪个先发生仍需探针，不能把4×(20+10+6+4)=160直接当已测总位移。f7的另一个父观察器按bug1attach 먼지1/먼지2，i由placement load设1。

父6重放몸빵=4547于depth145、(94,1449)twips，即初始localx4.7；该节点每enterFrame执行`this._x += (180 - this._x) / 6`。身体本身相对玩家向前移动，不能用静态idle身体代替。중력몸빵仍保留原位置。

4625 f7..10的439针对적、적2..5的行动身体分别设置重力-5、加速度+=.1；无HP写入、无伤害标记seek、无本次命中标志。f11移除。原路径`DefineSprite_4625/frame_7/PlaceObject2_439_30/…enterFrame.as`及`_2.._5.as`；`_6.._15`是冰冻/霸体特殊分支，默认本轮不推广。

## 5. 4030/7176父控制与Z交互的边界

| 敌地面父控制 | 源确认的返回 |
| --- | --- |
| 3898（4030）f1 | stop，并重置combo |
| 3898 f4 | gotoAndPlay1 |
| 3898 f50（近攻末控制） | gotoAndPlay2 |
| 3898 f62（受击末控制） | gotoAndPlay1 |
| 7170（7176）f1 | stop，并重置combo |
| 7170 f4 | gotoAndStop1 |
| 7170 f45（近攻末）、109（受击末）、130（远攻末） | gotoAndPlay2 |
| 7170 f91 | gotoAndPlay113，不能当作整个远攻结束 |
| 7168（evade子）f80 | root敌속 gotoAndPlay2 |
| 7168 f2 / 7178 f200 | 前者重启根timer到1；后者stop并令敌속 gotoAndStop111 |

路径均为对应`DefineSprite_ID/frame_N/DoAction.as`。返回2表示恢复到带父控制阶段的移动段，再由父4回1；不能统一把非loop动画结束直接idle。3898/7170的移动与近距触发区由父1放置，父4移除，绘图子3873/7158帧号不能代替它们的寿命。

根2 4030 `_5`/根6 7176 `_5`均以玩家중력몸빵与敌속.이동히트相交触发移动，分别每tick2/3；`_6`请求속 gotoAndPlay2并把重力设1e-9。方向调整4030 `_7`、7176 `_9`只在속父1或敌外层2许可，不是整个move状态随时翻转；mobsp在已取得默认样本仍undefined，不能凭该变量添加全程追踪速度。

**7176 evade确有根位移**：`frame_6/PlaceObject3_7176_458/…enterFrame_24.as`在玩家x>=敌x且속帧111时令敌x-=6；`_25.as`在玩家x<=敌x且同帧111时令敌x+=6。两条独立if含等号；同x及前一条改变后一条件的情况不可简化成未经核对的sign(0)。之前“未确认退避位移”的旧报告需由此更新。

Z抛空使地面层被替换，不能继续上述地面攻击/恢复窗口；空中独立行动身体仍存在，可再次被Z碰撞。恢复地面应重新经历原外层/父控制，不把Z计时器拖动当成敌AI移动。Flying只读gacc>0，故致命浮空也不应仅凭HP0提前过滤其横移；落地gacc归0才自然停止该条件。

## 6. 提给主Agent的最小受控取证方案

1. **双入口顺序**：真实keyDown或能触发原clip listener的事件入口，分别覆盖parent1、2、14，MP100/2，4064帧1/冷却帧2。原监听前后记录getTimer、parent、동작/이동子ID/帧、MP、4064帧及监听来源；不要依次手工调用两个复制函数冒称源调度。Key.isDown可由受控键状态驱动，但必须标干预。
2. **毫秒任务无命中**：先把一个不与Z相交的敌设gacc>0，触发普通Z；在原Flying/clearFly及创建处增加只读trace，记录getTimer、全局ID、父/子存在性、敌x/gacc/HP。覆盖f6..8、f9移除、正常f14返回，直到最晚timeout后；验证是否无接触也拖动、每段实际回调数、旧timeout清新ID。
3. **首次入空和空中重挑**：同位置的地面敌与已有空中marker≥3敌分别运行4622/4625。记录物理赋值、外层2创建、marker1/2/3、HP和观察器来源，区分新建标记与显式seek。
4. **打断与场景退出**：f6前/后强制父跳转作为受控组件销毁，不冒称自然可受击；记录回调是否继续。正常游戏内返回场景的清理另测。Godot必须确保退出后不再访问上场对象。
5. **父6末帧**：记录根x、子4625帧、body.localx、enterFrame和f22 DoAction次序；确认每段实际移动次数、终帧承接。与自然移动+Z竞争结果分开。

截至本节静态调查时的未知包括原生Flash与Ruffle计时精度及卸载函数寿命、同tick keyDown监听顺序、重复timeout的执行顺序、判定实际执行次数、多敌和跨招式共享全局interval。后续受控样本及匹配版本源码结论见第8、9节；仍未声称自然输入、原生Flash或Godot验收通过。


## 7. 本次新增的独立计时探针脚本

已按主Agent分配新增`godot/tools/probes/m1_z_timers.as`；没有改`build_runtime_probe.py`。根Agent负责加载并编译，调查Agent运行独立的静音实例；2026-11-13已取得完整样本，2026-11-14完成分析，结果见第8节。

脚本在t30切root2/crt0/nan0，t40跳过对话至9。t60将玩家x40、敌x330/y220/g-20/gacc.1并置原空中层，然后请求parent5，检查无碰撞也拖动已有空中敌及正常结束；t95布置玩家x200/地面敌x240，t100请求parent5检查正常接触；t120重新布置远距空中敌并请求Z，t129先parent1再5保证销毁重建，t137强制parent14移除第二次动作；t180恢复计时函数包装并输出DONE。

干预边界：控制根场景、玩家父帧、双方位置、玩家朝向、敌重力/加速度/外层姿态；绕过技能栏MP和冷却。没有直接设置HP，没有替换Z原判定、Flying或clearFly函数体。t129强制重复/t137强制受击都不是自然合法输入证据。t95/120会重置敌物理，不用于测连续自然轨迹。

包装`_global.setInterval/setTimeout/clearInterval`时保存原生函数；调用时保持参数个数、顺序、引用并通过`native.apply(this,args)`转交。函数型回调用包装增加前后trace后，仍`originalCallback.apply(this,arguments)`；其它签名不改参数直接交给原生。t180只恢复全局包装器，不人为清原Z的interval。日志前缀`LEBA_M1_Z_TIMER`带event、getTimer毫秒、source tick、phase、创建/回调ID、当前全局ID、父子帧、子x、根x、敌x/y/HP/g/gacc/空中标记、方向。

这层包装保留了原函数引用、this和参数，但增加trace与函数调用成本；结果属于有观测开销的Ruffle样本。构建或宿主不支持native.apply时应报告失败并改用独立只读采样，不吞错误后宣称计时器运行成功。判断旧timeout取消最新interval时应直接比较`timeout_before`、`interval_clear`中的ID与后续callback，不能只看flyInt数值还留在root就判断interval仍活着。

## 8. 计时探针结果（运行2026-11-13，整理2026-11-14）

本节为**受控原作脚本运行**，不是自然键盘、原生Flash或Godot实机验收。当前CLI版本为`Ruffle 0.7.1-stable (89a7049965f3090e706265670df309a5128233ac 2026-10-07)`。使用`--volume 0 --storage memory`及独立config/cache；只管理本次PID 46976，在DONE后停止，未操作其他播放器。2026-11-14只读取已有日志，没有重开桌面窗口。

可复查文件（相对工作区根目录）：

- 派生SWF、构建来源：`tools/swf/runtime_probe/leba_act01_z_timers_20261113/observed.swf`及`provenance.json`。SWF SHA256为`8E07F6EC17C0B28D7682FFEDDB1376FE7C52CB524C779EE92F587502A51C892E`。
- 独立运行记录：同目录`run1/launch.json`，状态`done_stopped_own_pid`；原始日志`run1/log/ruffle.log`。
- 分析器：`godot/tools/analyze_m1_z_probe.py`；输出`godot/artifacts/leba_act01_20261113/z_timer_probe.json`。输出保留原日志行号、原事件顺序、getTimer、请求delay和每次回调前后数据，并记录原日志哈希。

复查命令：

```powershell
python -X utf8 godot/tools/analyze_m1_z_probe.py --log tools/swf/runtime_probe/leba_act01_z_timers_20261113/run1/log/ruffle.log --output godot/artifacts/leba_act01_20261113/z_timer_probe.json
```

分析器退出0，DONE和包装恢复均存在；8次interval创建、8次timeout创建与执行、147对Flying前后事件均完整。日志没有ERROR，存在9条WARN（字体、trapallkeys、MP3解码、cacheAsBitmap等），不能称零警告。下列均使用实际事件顺序；`t`是观察器最近一次tick，回调可能在它下一次自增前发生，不能只按t推断Flash所有事件阶段。

### 8.1 10 ms / 500 ms 与组件生命周期

| 已观察事实 | 原日志/JSON支持的结论 |
| --- | --- |
| interval请求delay全部10，timeout请求delay全部500 | 两者是毫秒任务，不能直接翻译成25 Hz逐帧调用 |
| 同ID相邻回调139个间隔，min0/median10/max16 ms；初次ms3494有连续3次回调 | 当前Ruffle会出现同毫秒追赶，不保证每回调落在独立显示帧 |
| 8个timeout的getTimer差为469/491/466/496/469/490/489/491 ms | 这是本宿主时钟/调用阶段和观测开销下的结果；原请求仍500，不应把466或469硬编码成玩法值 |
| 远距已有空中敌分组49次Flying，各次只改变敌x+3、HP不变；parent返回1后仍有19次 | Flying不以本次Z接触为条件，也不与4622/1234组件销毁一起自动取消 |
| 正常接触分组同样49次Flying，parent返回1后18次 | 本次每个Z观察到两次创建（child7/8），不能因判定存在f6..8就机械执行三次 |
| 强制parent14后，ID15于ms6337..6353仍调用3次、各+3 | 强制销毁动作不会终止该函数型interval；这不是自然可受击条件的证明 |

“远距未接触”由双方距离、源判定矩阵与gacc保持.1交叉判断；未在原hitTest内部加布尔日志，故不宣称直接测得overlap=false。t60人为创建空中层已自然产生一次标记扣血，不能把此时200→185误算为远距Z命中。

旧timeout清新ID的直接序列：ms5893创建interval9/timeout10；ms5932重建interval11/timeout12；fixture t129再次请求Z，随后ms6254和6292分别创建interval13/timeout14、interval15/timeout16；t137强制移除动作。**ms6362 timeout10执行时，当前global flyInt=15，它调用clearInterval(15)**；后面的timeout12/14/16仍分别于6422/6743/6783清15。不是清创建timeout10时的9。局部调度应保留每次timeout任务及其读取“当前全局ID”的语义；Godot退出场景后统一清任务是生命周期适配，不能冒称已经测过原Flash场景退出。

匹配二进制的Ruffle源码解释：`timer.rs`37..67按宿主dt累积并追赶到期任务，195..196将interval截止点累加请求间隔；214/217分别限制最小10 ms及单次update最多10次。246..265以当前计时器时钟加delay建截止点。74..97的Avm1Function直接调用函数；98..141的Avm1Method才检查接收clip是否移除。Z使用函数型`setInterval(Flying,10)`，样本中组件消失后继续回调与此一致。[当前版本timer.rs](https://github.com/ruffle-rs/ruffle/blob/89a7049965f3090e706265670df309a5128233ac/core/src/timer.rs#L37)

### 8.2 首次自然入空标记

fixture t95仅布置地面敌及位置，t100直接请求parent5，不写HP、不seek伤害标记；所以本段的接触、空中组件创建和标记推进来自原脚本。

| tick sample | 玩家4622子帧 | 敌outer / marker | 敌gacc | 敌HP |
| --- | --- | --- | --- | --- |
| 105 | 6 | 1 / 未创建空中标记 | 0 | 185 |
| 106 | 7 | 2 / 1 | .1 | 185 |
| 107 | 8 | 2 / 2 | .2 | 180 |
| 108 | 9 | 2 / 3 | .2 | 170 |

这里首度入空后总计-15（先-5后-10），与第3节的空中f1创建3889及观察器链一致。Z判定本身仍只写物理，不应给每次碰撞固定伤害15；Flying前后各次HP差均0。既有空中marker≥3再次真正相交、7176首次入空、多敌、相反朝向及跨招式共享interval尚未在这套样本验证。

## 9. Z及M1键盘监听顺序（2026-11-14，源码推导）

此结论来自**原XML/AS与匹配当前二进制的Ruffle源码**，可作为M1当前宿主的默认监听顺序；不标为自然键盘实测，也不推广到原生Flash。源码只读快照及各文件URL/哈希存于`godot/artifacts/leba_act01_20261113/ruffle_source/provenance.json`；采用精确commit `89a7049965f3090e706265670df309a5128233ac`，不以可变分支或标签行号替代。

### 9.1 显示树与执行队列依据

| 根场景 | 4391 스킬창 depth / XML行 | 6732 일 depth / XML行 |
| --- | --- | --- |
| 2 | 472 / 2489937 | 909 / 3641483 |
| 4 | 474 / 3685877 | 1652 / 3686506 |
| 6 | 227 / 3687366 | 933 / 3690041 |

XML文件为`res/structure/game.xml`。三个场景技能栏都低于玩家深度。已检索原脚本的swapDepths调用，只有其他效果及6177内部部件，未发现修改本表技能栏/玩家根深度的代码。这里只覆盖当前默认crt0分支，不把未知外部动态代码当作已排除。

1. Ruffle真实KeyDown先调用舞台ClipEvent传播，再排入Key对象监听通知，两者是不同入口（`player.rs`1247..1249、1311..1328）。[真实键盘事件入口](https://github.com/ruffle-rs/ruffle/blob/89a7049965f3090e706265670df309a5128233ac/core/src/player.rs#L1245)
2. `interactive.rs`233..258对键盘采用render list正序；548..569先对子递归，再处理自身；原AVM1放置由`container.rs`811..858按深度插入render list。因此先完整处理较低深度的技能栏子树，再到玩家子树。[递归传播](https://github.com/ruffle-rs/ruffle/blob/89a7049965f3090e706265670df309a5128233ac/core/src/display_object/interactive.rs#L233)、[深度插入](https://github.com/ruffle-rs/ruffle/blob/89a7049965f3090e706265670df309a5128233ac/core/src/display_object/container.rs#L811)
3. `movie_clip.rs`2934..2962按clipAction原记录顺序排入Normal动作，KeyDown不使用KeyPress的消费分支；`context.rs`538..559在对应优先级FIFO进出，Normal属于Default（692..698）。[ClipAction排队](https://github.com/ruffle-rs/ruffle/blob/89a7049965f3090e706265670df309a5128233ac/core/src/display_object/movie_clip.rs#L2934)、[动作队列](https://github.com/ruffle-rs/ruffle/blob/89a7049965f3090e706265670df309a5128233ac/core/src/context.rs#L538)
4. AVM1 goto即时调用run_goto（`movie_clip.rs`896..940）；前进跨过RemoveObject时当场移除旧child（2177..2215）。原6732父5在XML3637663移除depth7的旧4617，再放4622。队列执行时`player.rs`2205..2213跳过已经removed/pending-removal的旧clip动作。故不能把同次输入捕获的所有callback无条件跑完。[即时跳帧与移除](https://github.com/ruffle-rs/ruffle/blob/89a7049965f3090e706265670df309a5128233ac/core/src/display_object/movie_clip.rs#L2177)、[执行前检查旧clip](https://github.com/ruffle-rs/ruffle/blob/89a7049965f3090e706265670df309a5128233ac/core/src/player.rs#L2205)

### 9.2 M1默认监听表

4391 f1的DoAction为`gotoAndStop(_root.crt + 1)`，crt0使用本帧。下列源路径均以`res/scripts/`为前缀。所有键盘记录是在每个keyDown事件中检查`Key.isDown`的**当前持有集合**，不是只检查新按下键码。

| 执行顺序 | 来源 / 深度 / XML记录 | 条件与目标 |
| --- | --- | --- |
| 技能Z | 4391 f1 →4064 depth124（XML2489333）→4051 depth1；Z记录2381154 | 许可父<5、7..10、14、16且MP≥3：扣3→父5；否则MP不足提示或条件不成立 |
| 技能S | →4066 depth129（2489339）→4051 depth1；S记录2381357 | 许可父<5、7..10、16且MP≥3：扣3→父11；父14不许可 |
| 技能D | →4068 depth131（2489342）→4051 depth1；D记录2381582 | 许可父<5、7..10、14、16且MP≥5：扣5→父13 |
| idle当前子 | 6732 f1 →4544 depth7；keyDown记录XML3637581/84/87 | X→父7；C→父95；Down→父12，无本子Z记录 |
| move当前子 | 6732 f2 →4617 depth7；记录XML3637640/43/46/49 | X→父7；Z→父6；C→父95；Down→父12 |

技能文件分别为`DefineSprite_4064/4066/4068/frame_1/PlaceObject2_4051_1/CLIPACTIONRECORD onClipEvent(keyDown).as`；玩家idle为`DefineSprite_6732/frame_1/PlaceObject2_4544_7/…keyDown.as`及`_2/_3`，move为`frame_2/PlaceObject2_4617_7/…keyDown.as`及`_2/_3/_4`。4544原完整clipAction数组前四条是空enterFrame，筛选KeyDown后才是表中三条，不能按目录名称排序推断原顺序。

正常技能ready+MP足够时，移动中Z先走技能栏，扣3并跳父5，旧4617随后失效，不再覆盖成父6。Z冷却期间4051已经移除，或MP不足只播放不足反馈而没有跳父，4617的Z仍可到父6、不扣MP。默认idle没有这一备用Z入口。多个M1技能同持时按Z/S/D评估**各自执行时的父帧**；Z成功后父5使后续S/D条件不成立，S成功后父11使D条件不成立。技能失败未跳转时可以继续评估下个监听，不可固定“先D后S后X”或一见Z就整次事件返回。

玩家子内同理：X成功跳父7后旧4544/4617被销毁，该旧实例后续C/Down/Z记录不能继续生效。建议捕获事件开始时实际存在的监听及其源实例身份，执行前确认该身份仍活着；新动作中新建的监听不补入同一次既有队列。这个建议仅适配本轮覆盖的源监听，不要求创建通用Flash虚拟机。抽取的放置证据另存`godot/artifacts/leba_act01_20261113/z_listener_source_evidence.json`。

### 9.3 排除Key.broadcastMessage伪取证

`as_broadcaster.rs`131..170仅遍历对象的`_listeners`并调用同名方法；Key对象在`key.rs`31..39初始化此broadcaster。它没有触发显示树ClipAction KeyDown的代码，不能用`Key.broadcastMessage("onKeyDown")`冒充本节原clip listener调度，更不能手动调用两段复制函数再声称证明原顺序。[广播器实际实现](https://github.com/ruffle-rs/ruffle/blob/89a7049965f3090e706265670df309a5128233ac/core/src/avm1/globals/as_broadcaster.rs#L131)

剩余验证边界：自然OS键盘下的移动Z/MP不足/冷却/多键组合、帧边界输入与同一显示帧多事件、原生Flash对应顺序仍需实机采样；原作帧动画计时与宿主interval的关系仍按源时钟和毫秒任务分开。未修改runtime、导入器、catalog、资产或原始资料。

## 10. AVM1帧阶段与受控held输入补核（2026-11-14，源码调查及后续受控实测）

本节仍使用第9节匹配二进制的精确commit；新增源文件同样保存到`ruffle_source`及provenance。**键盘事件的显示树顺序与每帧执行顺序不是同一种排序**：后者采用实例创建的全局执行链，不可把第9节的低深度键盘顺序直接套入enterFrame。

状态更新：10.1至10.3保留首次只读调查、普通覆写失效的根因及当时待确认项。2026-11-14主Agent随后完成`held_native`原clip轮询探针和Godot同条件轨迹对照，成功结果见10.4；不得再把已取到的默认held样本概括成“尚未运行”，也不得升级为自然键盘或原生Flash验收。

### 10.1 enterFrame排队后，先推进再执行回调

1. `player.rs`2072..2084在`self.update`闭包里调用`Avm1::run_frame`；`update`2424..2433在整个闭包返回后调用`run_actions`。[帧入口](https://github.com/ruffle-rs/ruffle/blob/89a7049965f3090e706265670df309a5128233ac/core/src/player.rs#L2072)、[更新后清空执行队列](https://github.com/ruffle-rs/ruffle/blob/89a7049965f3090e706265670df309a5128233ac/core/src/player.rs#L2424)
2. `avm1/runtime.rs`518..544遍历全局clip执行链；561..565在新实例创建时从链头插入。每个存活clip调用`run_frame_avm1`，不是为每个clip即时清空AS执行队列。[AVM1帧遍历](https://github.com/ruffle-rs/ruffle/blob/89a7049965f3090e706265670df309a5128233ac/core/src/avm1/runtime.rs#L518)
3. `movie_clip.rs`448..462先调用event_dispatch排Load或EnterFrame，再在playing时run_frame_internal；1388..1420在当前调用中推进帧号、处理放置/移除。event_dispatch的Normal动作仍等待全局队列执行，所以回调读到推进后的帧。新放置child在1566..1575只运行初始化首帧，走Load分支，不立即执行首次EnterFrame。[每实例帧更新](https://github.com/ruffle-rs/ruffle/blob/89a7049965f3090e706265670df309a5128233ac/core/src/display_object/movie_clip.rs#L448)、[显示列表即时更新](https://github.com/ruffle-rs/ruffle/blob/89a7049965f3090e706265670df309a5128233ac/core/src/display_object/movie_clip.rs#L1388)

这能解释普通Z判定1234在4622 f6放置，下一轮该helper首次EnterFrame真正执行时父4622已经到7；f8仍可执行，父进f9移除helper后其已排动作被跳过。第8节两次interval创建的运行样本与此阶段解释一致，但不是证明所有宿主都采用同一阶段的依据。

### 10.2 空中5628默认held X应先推进再轮询

原脚本`res/scripts/DefineSprite_5633/frame_15/PlaceObject2_5628_1/CLIPACTIONRECORD onClipEvent(enterFrame).as`的顺序是：当前帧非1时横移 → 当前帧2/3时attach斜向弹 → 最后检查held X，当前1/6则gotoAndPlay2。`DefineSprite_5628/frame_1/DoAction.as`为stop，f2为play，f6为stop。

以默认装备、没有其他跳转为前提，当前Ruffle源码推导：停在1时该轮前面的发弹条件不成立，最后held请求2；下一轮先推进3，回调在3发一颗；之后4、5无弹；推进6的回调最后又请求2。**不能在goto2后倒回执行本轮前面的2/3检查，也不能把配置中“2或3”直接等同默认每轮两发。** 默认连续轮询路径只有在3命中发弹条件；人为seek2并stop等不同入口仍可能让2条件成立，源条件本身应保留。

末帧还有必须保留的队列关系：推进到6时先排EnterFrame，再排f6的stop；EnterFrame中goto2又追加目标f2的play。`movie_clip.rs`4288..4308将DoAction排为Normal，goto在1880..1885处理目标帧脚本；同实例仍存活，因此依次执行旧f6 stop、目标f2 play，最后继续播放，而不是卡在2。目标f2 play不是多余脚本。[DoAction排队](https://github.com/ruffle-rs/ruffle/blob/89a7049965f3090e706265670df309a5128233ac/core/src/display_object/movie_clip.rs#L4288)、[goto目标帧](https://github.com/ruffle-rs/ruffle/blob/89a7049965f3090e706265670df309a5128233ac/core/src/display_object/movie_clip.rs#L1869)

以上在首次调查时是源码推导，当时待受控原clip轮询日志确认；默认分支现已取得10.4的运行支持。特殊武器条件会stop父5633、增加空中子弹并触发父timer，仍不在此默认分支结论内；本调查分工没有修改Godot。

### 10.3 Key.isDown覆写为何失败，以及可验证的探针入口

`avm1/globals/key.rs`30将isDown声明为DONT_ENUM | DONT_DELETE | READ_ONLY；45..56的原生函数读取宿主InputManager。`avm1/property.rs`101..109与136..137拒绝向READ_ONLY属性写数据。因此普通`Key.isDown = function(...)`不能替换此内建函数。`_global.Key`本身在`avm1/globals.rs`693只有DONT_ENUM，这与其isDown成员的只读属性不同；不能把两个层次混为一谈。[Key属性与原生取值](https://github.com/ruffle-rs/ruffle/blob/89a7049965f3090e706265670df309a5128233ac/core/src/avm1/globals/key.rs#L28)、[只读属性赋值](https://github.com/ruffle-rs/ruffle/blob/89a7049965f3090e706265670df309a5128233ac/core/src/avm1/property.rs#L101)

当前实现允许`ASSetPropFlags(Key,"isDown",0,4)`清READ_ONLY位：`globals/object.rs`294..344接受setFlags/clearFlags并定位属性；`object/script_object.rs`683..712执行`(旧属性 - clear) | set`，不因属性原先只读而拒绝；READ_ONLY在property.rs16等于4。[ASSetPropFlags实现](https://github.com/ruffle-rs/ruffle/blob/89a7049965f3090e706265670df309a5128233ac/core/src/avm1/globals/object.rs#L294)、[属性标记修改](https://github.com/ruffle-rs/ruffle/blob/89a7049965f3090e706265670df309a5128233ac/core/src/avm1/object/script_object.rs#L683)

首次调查提出的独立派生SWF方案：保留原Key对象和原isDown函数引用，只清isDown的4位，覆写为受控held查询；结束时先还原函数，再`ASSetPropFlags(originalKey,"isDown",4,0)`恢复只读位，原1/2位全程保留。必须记录赋值后函数身份及受控键查询是否实际生效；这只是原clip enterFrame轮询的受控输入，不会凭空生成真正KeyDown ClipAction，更不证明自然输入顺序。该取证不触碰OS键盘设置、原SWF或用户存档。本分工当时只核源码，未实施或运行新probe；主Agent后续执行和验证结果如下。

### 10.4 held_native成功样本与Godot对照（2026-11-14补记）

依据为`godot/artifacts/leba_act01_20261114/held_native.json`（SHA256 `11f0defc2e963602da11052d7132f724528ba39fc17f24efb9df1fa6592ee56d`）和同目录`regression/source_comparison.json`。前者状态为`verified_original_clip_polling`，轨迹完整，无缺失/重复tick；原日志位于`tools/swf/runtime_probe/leba_act01_held_native_20261114/run1/log/ruffle.log`，日志SHA256 `7d89a039f804d951908d33c3ad9ba75999a12b846f7610745549c63edd363796`。播放器仍为Ruffle 0.7.1，静音、memory存档及独立配置运行，DONE后只停止本次PID 33248。

干预记录：只在派生SWF根帧1增加DoAction，未替换原clip脚本；清原Key对象isDown的READ_ONLY位并提供受控held状态，同时设置场景、玩家父帧、位置和朝向。安装记录确认原Key对象不变、方法已成为mock、原函数已保存、root.Key未改。共记录1028次非探针自身查询（172次返回true）；全样本函数身份和this通过，this_mismatch=0。t300确认原函数及READ_ONLY均恢复。这次成功不覆盖或改写此前普通覆写/shadow未能证明原clip消费输入的失败记录。

| 受控运行观察 | 结论范围 |
| --- | --- |
| 地面右持10tick各+6、左持各-6；左右同持10tick位移均0、最终朝左 | 默认crt0/root2/nan0地面原轮询确实消费受控键，不能把左右同持只实现成无方向的axis=0 |
| 三个跳跃用例均在父5633源17/21/25/29、5628子帧3各生成一颗 | 每次默认跳跃4颗；支持“1/6最后seek2、下一轮先advance3再发弹”，没有永久停在2 |
| 子帧采样为1→2→3→4→5→2→3…；源计数sub_i在每次子3加1，并有对应弹体frame1 | 运行确认默认每轮一发；旧f6 stop/目标f2 play的内部队列次序仍由10.2源码解释，而非声称此探针逐条记录了DoAction |
| 无方向空中X至末个空中样本dx=-39；反向左/右用例分别-111/+111 | 方向干预影响原轮询位移；带方向落地返回的采样已为父2并同轮移动6，无方向返回父1 |

原fixture的`shot_total=6`因MovieClip同名替换的引用比较而漏数，保留原值；不能把6写成真实三次总发弹数。分析采用原`sub_i`增量与弹体frame1交叉确认每次4颗、合计12颗。观察器snapshot先于剩余原回调，须按回调child/sub和后续snapshot归属事件，不能把所有原tick统一平移一格。该日志记录20条WARN，未将警告隐藏为零。

后续`source_comparison.json`记录Godot同条件捕获对照：三个held跳跃用例各35个样本、246个字段比较，均`passed=true`、`first_difference=null`；连同已有受控C/Down/Z用例共10例、1708个字段比较、差异0。坐标容差1e-4 px仅覆盖浮点表示，身体bbox宽允许0.05 px；帧/tick没有宽容。`held_native.json`中的`godot_comparison`仍保留分析当时“仅静态审查、落地轮询可能晚一tick”的候选问题；实际回归结论以这份后续比较文件为准，不把旧候选写成已实测失败。

边界保持明确：这是原对象受控held输入驱动原clip enterFrame，并非自然OS键盘、原生Adobe Flash或真实KeyDown事件。直接goto95绕过C入口条件，未验证地面X触发和第9节Z/S/D双入口竞争；仅默认装备、crt0、nan0、root2，敌x900为避碰干预，未断言命中结果或特殊装备发弹周期。毫秒Z任务使用独立计时套件对照，多敌/打断仍各自标为fixture；本次文档补记没有重新运行探针或改变这些验证范围。
