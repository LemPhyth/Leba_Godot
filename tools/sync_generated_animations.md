# 同步已有动画派生元数据

在项目外层目录执行；示例使用当前 Godot 4.6.3：

```powershell
& 'tools/Godot_v4.6.3-stable_mono_win64/Godot_v4.6.3-stable_mono_win64_console.exe' --headless --audio-driver Dummy --path godot --script res://tools/sync_generated_animations.gd -- --check
& 'tools/Godot_v4.6.3-stable_mono_win64/Godot_v4.6.3-stable_mono_win64_console.exe' --headless --audio-driver Dummy --path godot --script res://tools/sync_generated_animations.gd -- --sync-generated
```

先按原导入流程更新必要图集和 `data/asset_catalog.json`，再同步。工具仅枚举**已经存在**的 `generated/animations/*.tres`，更新当前 catalog 对应的贴图引用、帧元数据、父缩放与来源文字；不创建新动画 ID、不导入全资源、不写 `content/` 或 `scenes/`。新增动作的首次资源转换仍使用既有 bootstrap/作者流程。

全量预检通过才写入。非编辑器模式的ResourceSaver可能省略原UID，因此工具在保存后通过 `ResourceSaver.set_uid` 保留已有资源 UID（也保留原先没有 UID 的状态）；再次核验失败或中途保存失败时恢复本轮写入的派生文件。前后核对全部作者文件哈希，出现并行作者编辑时会报错，**不会回滚别人编辑的作者文件**。回滚前也检查派生文件仍是本工具刚写入的字节，保留外部后续改动。因此请在作者资源、catalog 与 generated 均稳定时运行。

`--check` 退出码：0为已同步，3为发现待同步，1为错误；`--sync-generated` 成功返回0。无参数或同时给两个模式返回2。报告默认写入 `artifacts/leba_act03_20261116/generated_sync/latest.json`，可用 `--report=res://artifacts/.../report.json` 指定独立报告。内容一致的文件完全跳过，连续执行第二次应为 `updated=0`，派生文件字节不变。

自动化写入分支测试可额外指定 `--fixture-generated=res://artifacts/.../generated/animations`。该参数只接受上述隔离目录模式，不能指向content、scenes或其他目录；仍只更新目录内已存在且catalog有对应ID的文件。正常项目同步无需此参数。测试会在隔离副本中制造旧pivot/缩放/来源值并添加UID，验证实际同步恢复catalog值、UID不变、第二遍字节不变；真实generated文件只做哈希保护。

保护验证由 `tests/test_act03_editing.gd` 的同步检查和独立同步报告记录；运行时作者编辑用隔离副本，不覆盖正式作者资源或存档。这里的自动保存/读取检查不代替原生编辑器人工拖拽验收。

2026-11-16验证：editing run04及支持绝对输出目录的run05均56/56，主日志及同步子日志ERROR/WARNING均0。隔离UID副本首次实际更新1文件、第二次0，陈旧字段恢复，UID和第二次文件字节保持；真实72份generated文件、125份content/scenes文件及正式存档未变。报告位于 `artifacts/leba_act03_20261116/editing/env_absolute/report.json`、`sync_1.json`、`sync_2.json`，扫描汇总为上级 `run05_log_scan.json`。首次run03曾因headless保存丢UID失败并自动回滚，失败证据保留；工具随后增加显式UID恢复，未降低断言。

editing测试可通过 `LEBA_TEST_ARTIFACT_DIR` 指定工程 `artifacts/` 下的绝对路径或 `res://artifacts/...`；不提供时生成唯一时间戳目录。stdout统一为 `ACT03_EDITING checks=N failures=M report=...`，供集中runner读取。同步子进程使用同目录，不需要 `--editor`。
