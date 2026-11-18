# 原生 UI 作者场景

正式 Main 实例化 `game_ui.tscn`；训练/关卡场景实例化 `source_hud.tscn` 为 HUD，GameUI 接收同一个节点。它们不是与运行无关的预览副本。

- `game_ui.tscn`：标题、选人、训练选人、难度、中转、对话、结算、工程暂停等实际页面实例。单独打开对应的 `.tscn`，可直接选择 Button、Label、Panel、素材和字体；主场景中也可开启实例的“可编辑子节点”。
- `source_hud.tscn`：`Characters/CRT0`、`CRT1` 为对应角色的真实 HUD。CRT1 已保存 14 个原槽位的遮罩定义，其中替换 Z 保留屏外且默认不可见，V/受击 Z 保留原可见状态。移动 `HPLayout`、`MPLayout`、冷却遮罩、金币/无色字段、ComboLayout、榴弹信息等作者节点；纹理与字体可在 Inspector 更换。`FillState` 比率、`NumberMotion` 动画和字段文本属于实时状态，运行时会更新。它们的外层作者位置不会被重设。
- `source_menu.tscn`：组合原菜单、失败、仓库及下拉各帧。单独打开 `menu_actions.tscn`、`menu_settings.tscn`、`warehouse_2.tscn`、角色1真实武器页 `warehouse_3.tscn`、`warehouse_8.tscn` 等可直接看见实际布局。组合场景默认预览操作菜单，运行按实际页面切换显示。
- 原三态按钮是原生 BaseButton。按钮本体的 Rect 是实际点击区域，移动它会同时移动 `ArtworkLayout`。该布局层可调整视觉偏移；Inspector 的 normal/hover/pressed texture 与 pivot 是三态资源。`Artwork` 是动态状态图，不是作者位置层。
- 设置的五档音量、两个复选框纹理和帧偏移位于 `source_menu.tscn` 根节点的 `Author state textures` 分组。换图不改真实档案数值。未接入装备和 Flash 画质选项仍明确禁用。

所有页面保留节点身份。`GameUI.clear` 和 `SourceMenu._reset_owned` 只改变可见性和显示缓存，不删除作者节点；`RuntimeTransitionOffset` 是过场运行位移，`UI` 根节点本身可手调。界面仍只读 Main/Battle 快照并发送意图，没有第二份 HP、金币或存档。

角色1 `WAmmoLayout` 是原6884弹数显示。它位于原父6917的舞台坐标 `[742.15, 284.6]`；6884子偏移已在图集pivot内，不能再加一次。各关卡作者实例覆盖它的绝对HUD深度。`FrameState` 复用正式SourceSprite和生成动画资源，只读取`Battle.snapshot().crt1.w_ammo_frame`；帧2为20发、21为1发、1为空闲。`editor_frame`只供安全编辑器预览，没有独立弹数或计时。

保存 `.tscn` 后重新运行生效；Remote 检查器的临时修改不会自动落盘。普通资源导入不会修改本目录。`_bootstrap/` 保留 ACT-02 布局迁移种子和显式转换器，不参与正式运行；`--bootstrap-ui` 只创建缺失的初始页面，拒绝覆盖已有作者文件，不是日常 refresh 命令。组合场景和后续作者调整以本目录实际文件为准。

当前边界：角色0复杂技能世界对象不因 UI 迁移自动变成可编辑场景；原作图标中尚未解锁的槽不强行启用；新角色槽位需要显式添加对应作者遮罩节点。布局可编辑不代表全部原作视觉/声音已精校。

静音自动验证：`tests/test_act03_ui.gd` 检查真实 PackedScene 保存到独立 artifact、重新载入后的原生鼠标命中、动态数据、切页身份及作者文件/正式档哈希。它与编辑器人工拖动、F5/F6 和 OS 验收分别记录。

`tests/test_act03_focus.gd` 使用实际Main/Battle及隔离存档，临时关闭测试分支后投递合成焦点通知，验证菜单/仓库失焦暂停与恢复、输入清理和手动暂停保护；这不是OS切换窗口的人工验收。
