# 东方星 STG — 架构改进规划

> 本文档描述项目当前架构的改进方向，供后续开发时参考。
> 已完成项标记 ✅，新发现问题会追加。

---

## ✅ 已完成

### 1. ~~`GameState` 缺少统一重置方法~~ ✅

在 `game_state.gd` 添加了 `reset_all()`，在 `StageManager.load_stage` 中调用，
替代旧的 `reset_score()`。重置项：score / graze / power / lives / life_fragments /
bomb_count / bomb_fragments / memory。

**提交**：cb2df44

### 2. ~~协程暂停后跳帧~~ ✅

`CoroutineRunner` 从 `Time.get_ticks_usec()` 绝对时间改为 `_clock += delta` 累积时间。
暂停时 `_physics_process` 不跑，`_clock` 不递增；恢复后从上次处继续，不追帧。

**提交**：cb2df44

### 3. ~~暂停期间 BGM 偷跑~~ ✅

`play_bgm` 的 `create_timer` 参数改为 `(gap, false)`，暂停时 timer 不走。
`AudioManager._on_game_state_changed` 用 `stream_paused` 代替 `stop()`。

**提交**：cb2df44

### 4. ~~UI 入场动画期间暂停冲突~~ ✅

`GameUI` 添加 `entry_finished` 信号，入场 tween 完毕后发射。
`GameScene._ready` 第一行 `_set_state(PLAYING)`，入场期间即可暂停。
暂停时 tween 自然冻结（`TWEEN_PAUSE_BOUND`），恢复后继续。

**提交**：cb2df44

### 5. ~~敌人外观硬编码~~ ✅

`EnemyData` 去掉了 `sprite_frames`，改为 `visual_scene: PackedScene`。
新增 `EnemyVisual` 脚本（idle/righting/right 状态机，flip_h 翻转）。
旧测试敌人已迁移。

**提交**：cb2df44

### 6. ~~子弹染色系统~~ ✅

`BulletData` 新增 `tint: Color` 字段，`bullet.bind()` 时 `sprite.modulate = data.tint`。
弹雾跟弹幕同色（`fog.modulate = data.tint`）。
记忆值 < 50% 时自机子弹自动变红（`remap(memory, 0,50, 1,0)`）。
击中特效通过 `set_tint(color)` 传递颜色。

**提交**：cb2df44

### 7. ~~音效同帧去重~~ ✅

`AudioManager.play_sfx` 检查 `_played_this_frame` 数组，同帧相同流只播一次。
`_process` 每帧清空记录（只在有播放时启用）。

**提交**：cb2df44

### 8. ~~AudioManager 热重载后丢失 Player~~ ✅

`_init_players()` 在 `_ready` 和 `play_bgm`/`play_sfx` 中双重调用（懒 init），
热重载后首次调用自动重建播放器。

**提交**：cb2df44

---

## P1 — 下一阶段开发前重构

### 9. `BulletManager` 拆分（~400 行 → 5 个文件） ✅

**现状**：`BulletManager` 包含子弹池管理、碰撞检测分流、激光步进、死亡清弹、擦弹判定、音效触发、击中特效生成。

**建议**：拆成以下模块，`BulletManager` 只做路由：

| 新文件 | 职责 |
|--------|------|
| `scripts/autoload/bullet_pool.gd` | `shoot_bullet`、`return_bullet`、池扩容 |
| `scripts/autoload/bullet_collision.gd` | `_resolve_collisions`、`_player_bullet_vs_enemies` 等 |
| `scripts/autoload/laser_system.gd` | `fire_laser`、`_step_lasers`、`clear_all_lasers` |
| `scripts/autoload/death_clear.gd` | `start_death_clear`、`_process_death_clears`、`_cut_laser` |

**注意**：此重构不改变外部调用接口，只内部拆分。

### 10. 玩家射击脚本去重 ✅

**现状**：`cs_reimu.gd` 和 `cs_marisa.gd` 各约 60 行，但 `_on_step` 里的
`match _phase: 0: run_parallel(...); 1: sync_options + return true`
和 `_main_step`、`_option_step` 的结构几乎一样。

**建议**：在基类 `PlayerShootScript` 里抽取：
```gdscript
# 子类只需覆写这些方法
func _get_main_bullet_data() -> BulletData: ...
func _get_option_bullet_data(focused: bool) -> BulletData: ...
func _get_option_info(power: int, focused: bool) -> OptionInfo: ...

class OptionInfo:
    var offsets: Array[Vector2]
    var visual_script: Script
```

加第三个角色（咲夜？早苗？）只需 ~30 行。

**文件**：
- `scripts/coroutine/player/base/cs_player.gd`（重构基类）
- `scripts/coroutine/player/cs_reimu.gd`（简化为 ~30 行）
- `scripts/coroutine/player/cs_marisa.gd`（简化为 ~30 行）

---

## P2 — 开始做真关卡时

### 11. ~~`BulletPattern` 弹幕模式组合系统~~（搁置）

用户决定暂时不做通用弹幕模式系统，直接在 CreateScript 里手写组合。

### 12. `GameManager` 职责拆分 ✅

**现状**：`GameManager` 兼顾状态机、场景切换、黑场过渡、菜单栈、暂停控制。

**建议**：拆成 3 个模块：

| 模块 | 职责 |
|------|------|
| `SceneTransition` | `change_scene`、`_fade_out/in`、`reload_current_scene` |
| `MenuStack` | `push_menu`、`pop_menu`、`push_overlay_menu` |
| `PauseControl` | `pause_game`、`resume_game`、`_cleanup_pause` |

**文件**：`scripts/autoload/scene_transition.gd`、`scripts/autoload/menu_stack.gd`（新建）

---

## P3 — 锦上添花

### 13. 关卡数据运行时校验 ✅

**建议**：`StageManager.load_stage` 断言 `stage_script is StageScript`。
`EnemyData.visual_scene`、`BulletData.movement_script` 同样处理。

### 14. 菜单选项注入式配置 ⬜

**建议**：`BaseMenu` 加 `@export var item_configs: Array[Dictionary]`，
`_collect_items` 时自动创建 Label 并绑定回调。

### 15. ~~`AudioManager` 交叉淡入淡出~~ ✅

**提交**：ffd7e92

`crossfade_bgm(stream, duration)` 双播放器交叉淡入，旧渐弱→新渐强。
暂停时两个播放器一起 `stream_paused`，音量调整同步。

### 16. ~~命中特效基类~~ ✅

**提交**：065ea8e

提取 `HitEffect` 基类：`velocity`、`_physics_process`、超时 `queue_free` 统一处理。
三个子类（Effect01/Effect02/MainEffect）各覆写 `_get_speed`/`_setup`/`_on_velocity_set`/`_process_extra`。

### 17. 敌弹消弹特效对象池化 ⬜

**现状**：`HitEffectPool.spawn()` 每帧 `instantiate` + `add_child(World)` + `activate`。
0.35s 后 `_finish` 设 `visible=false`，节点留在树里不回收。高频消弹时产生大量悬挂节点。

**建议**：`spawn()` 内部接池：
- `_acquire()` 优先从 `_pools[scene]` 取 `not visible` 实例
- `_finish` 回调 (`_on_finish`) 把实例标记为不可见 → 回池
- 池大小不设硬上限，按需扩容

### 18. 道具掉落系统 ⬜

**建议**：
- 消灭敌人掉落 Power Item / Point Item / 残机碎片 / Bomb 碎片
- 自动回收线（屏幕底部吸附）、POC（道具回收线）
- 满火力后 Power Item 变 Point Item

### 19. Spell Card 框架 ⬜

**建议**：
- Boss 多阶段 + 血量条 HUD
- Spell Card Bonus（收卡时不 Bomb/不 Miss）
- 动态难度（Rank 系统）

### 20. Replay 系统 ⬜

**建议**：每帧记录 RNG 种子 + 玩家输入 → 可完整回放

### 21. 关卡编辑器 ⬜

**建议**：可视化编排弹幕模式时间轴

### 22. 单元测试 ⬜

**建议**：GDScript `assert` 协程调度和碰撞检测回归测试
