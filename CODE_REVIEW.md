# 🔍 东方星 STG 项目全面审查报告
## 审查日期：2026-06-12
## 审查范围：全部 .gd 脚本、架构、性能、安全性、可维护性

---

## ⚠️ 严重问题（必须修复）

### 1. Player.miss() 中使用 `await` 会泄露/崩溃
**文件：** `scripts/player/player.gd:146`
```gdscript
is_invincible = true
await get_tree().create_timer(3.0).timeout
is_invincible = false
```
- 如果玩家在 3 秒无敌期间死亡（lives=0），`miss()` 第二次被调用时上一个 `await` 还没返回，is_invincible 会被置为 true 第二次，然后第一个 await 返回时置 false，**无敌时间被吞掉**。
- 更严重：如果场景切换或玩家 `queue_free()`，await 的 timer 还在跑。
- **建议：** 改为 `Tween` 或 `SceneTreeTimer` + 回调，并在 `_exit_tree` 中取消。

### 2. EnemyVisual 速度检测阈值为 30px/s，但 Patrol 巡逻端点速度降为 0
**文件：** `scripts/enemy/enemy_visual.gd`
- 巡逻用 SINE EASE_IN_OUT，端点处 `speed < 30` 触发 IDLE，但下一秒方向翻转又 >30 触发 RIGHTING。
- 如果 patrol `period=1.5, range=100`，峰值速度约 105px/s，threshold=30 意味着端点附近约 30% 时间是 IDLE。动画在 IDLE ↔ RIGHTING ↔ RIGHT 快速切换会**抖动闪烁**。
- **建议：** 加一个延迟退出 timer（speed<30 持续 0.2s 才切 IDLE），或使用 `hysteresis`（进入阈值 ≠ 退出阈值）。

### 3. StageManager.stop_stage() 不停止背景协程
**文件：** `scripts/autoload/stage_manager.gd:48`
```gdscript
func stop_stage():
    current_background = null
    if _stage_script and is_instance_valid(_stage_script):
        _stage_script.stop()
        _stage_script.queue_free()
```
- `StageManager.start_background()` 播过的 `BackgroundScript` 子协程没被停止！虽然 `current_background` 设为 null，但 `BackgroundScript` 挂在 `current_background` 节点上——如果 StageBackground 没被 free，协程继续跑。
- **建议：** 停止所有 `BackgroundScript` 子节点。

### 4. 场景切换时 BulletManager 仍在处理碰撞
**文件：** `scripts/autoload/bullet_manager.gd`
- `scene_transition.gd` 先 `change_scene_to_file()` 然后 `BulletManager.clear_all()`。但 `_physics_process` 在 change_scene 后仍在运行（autoload），新场景可能还没准备好。
- 更严重：`_physics_process` 中的 `_pool.active_bullets[i]` 可能在迭代中被 `return_bullet()` 移除（如碰撞回收），导致 `is_offscreen` 检查到无效引用。
- **建议：** 加一个 `_paused` flag，场景切换期间跳过 `_physics_process`。

### 5. `active_bullets.is_offscreen` 循环越界风险
**文件：** `scripts/autoload/bullet_manager.gd:58`
```gdscript
for i in range(_pool.active_bullets.size() - 1, -1, -1):
    if _pool.is_offscreen(_pool.active_bullets[i].global_position):
        _pool.return_bullet(_pool.active_bullets[i])
```
- `return_bullet()` 调用 `active_bullets.erase(bullet)`，使数组缩短。反向遍历 `i` 仍在有效范围，但 `active_bullets[i]` 的索引可能已变——因为 `erase` 改变了数组。应该从 `i` 位置重新读取。
- **实际上没有 bug**（erase 后 i 索引不变，下一个迭代 i-1 仍有效），但代码意图不够清晰。

---

## ⚡ 性能问题

### 6. GameState._process 每帧跑，即使不在游戏中
**文件：** `scripts/autoload/game_state.gd:93`
```gdscript
func _process(delta: float) -> void:
    memory_value = clampf(memory_value + MEMORY_REGEN * delta, 0.0, 100.0)
```
- `memory_value` 每帧增长 0.05/s，但只在游戏中需要。主菜单/暂停时也在跑，浪费。
- **建议：** 只在 `AppState.PLAYING` 时执行，或者把 `set_process(false)` 放到非游戏状态。

### 7. EnemyVisual._process 每帧找 parent
**文件：** `scripts/enemy/enemy_visual.gd`
```gdscript
func _process(delta: float) -> void:
    var parent := get_parent() as Node2D
    if not parent: return
```
- 每个敌人每帧都做 `get_parent()` + `as` 转型。如果 30 个敌人同时存在，就有 30 次 `get_parent()`。
- **建议：** 在 `_ready()` 缓存 parent 引用。

### 8. BulletPool.shoot() 动态扩容无上限
**文件：** `scripts/autoload/bullet/bullet_pool.gd:42`
```gdscript
if bullet_pool.is_empty():
    bullet = bullet_scene.instantiate()
    _parent.add_child(bullet)
```
- POOL_SIZE=4000 但 shoot 时如果池空了会动态创建，**没有上限**。理论上可以创建无限多子弹（比如无限弹幕 bug）。
- **建议：** 加一个 max 上限，超限时复用最早的 active bullet。

### 9. StageBackground `_process_events` O(n) 扫描
**文件：** `scripts/background/stage_background.gd`
```gdscript
func _process_events():
    for time in _events:
        if _elapsed >= time:
```
- 每帧遍历所有已调度事件。事件多时（100+）浪费。
- **建议：** 改用排序列表，只检查最早的到期时间。或使用 `Array` 排序 + 移除已过期的。

---

## 🏗️ 架构问题

### 10. StageAPI 通过 RefCounted 传递，但 runner 是 Node
**文件：** `scripts/coroutine/base/stage_api.gd`
- `StageAPI` extends `RefCounted`，包含一个 `runner: CoroutineRunner`（extends Node）。如果 runner 被释放了，StageAPI 上 `active()` 返回 false，但其他的引用（如 lambda 中捕获的 api）会导致 RefCounted 不释放。
- 实际上这不是问题（runner 被释放 → RefCounted 引用 → GC 释放），但**语义混乱**——runner 是 Node，本不该被 RefCounted 持有。
- **建议：** StageAPI 持 `WeakRef(runner)` 更安全。

### 11. Enemy.create_script 和 move_script 的职责分工模糊
**文件：** `scripts/enemy/enemy.gd`
- CreateScript 负责"创建弹幕"——但实际上弹幕发射是在 `_on_step` 协程里持续运行的。MoveScript 负责"移动"——但 CreateScript 也能改 target 的位置。
- 两者都继承 `CoroutineRunner`，都能调用 `api.spawn_enemy()` 和 `api.shoot_spread()`。**谁该发射弹幕？** 都在 create_script 里？还是移动脚本里的回调？设计不清晰。
- **建议：** 明确约定：CreateScript 仅一次性初始化，MoveScript 负责弹幕发射（类似 Touhou 的 ECL）。

### 12. BulletManager 作为 Autoload Node2D，但子弹挂在 World 下
**文件：** `scripts/autoload/stage_manager.gd:79`
```gdscript
func _add_enemy_to_scene(enemy: Enemy):
    var parent = get_tree().current_scene
    if parent:
        var world = parent.get_node_or_null("World")
        if world:
            parent = world
    parent.add_child(enemy)
```
- 子弹通过 BulletManager.add_child 挂（pool setup），但敌人通过 StageManager 挂到 World 下。**不一致**。
- BulletManager 是 Autoload Node2D，它的坐标系是根节点的，子弹发到它的子节点里，而不是 World 下。如果 World 有摄像机偏移，子弹位置会错。
- **建议：** 统一挂载点——全部挂 `World` 下，或全部挂 BulletManager 下。

### 13. BackgroundScript._on_init 与 start_background 时序混乱
**文件：** `scripts/autoload/stage_manager.gd:36`
```gdscript
# _on_init 先被叫（via StageBackground._on_setup）
# start_background 后被叫（via StageManager.load_stage → start_background）
```
- `stage_background.gd._on_setup()` 在 `_ready()` 中调 `_on_init(api)`。
- `StageManager.load_stage()` 中调 `start_background(api)`，运行协程。
- **但 `_on_init` 时的 api 是一个临时 StageAPI**，没有运行协程的能力。如果 `_on_init` 里写了 `api.seconds(1)`（虽然在 `_on_init` 里不应该用），会静默失败。
- **建议：** 文档化 `_on_init` 只做同步设置；或者 `_on_init` 时也 mark 一下 "这一帧不能用协程 API"。

### 14. GameScene 中 `_blur_rect` 生命周期不匹配
**文件：** `scripts/scenes/game/game_scene.gd:61`
```gdscript
func _add_blur() -> void:
    if _blur_rect: return
    ...
    var blur_layer := CanvasLayer.new()
    blur_layer.layer = 15
    blur_layer.add_child(_blur_rect)
    add_child(blur_layer)
```
- `_blur_rect` 引用了一个 ColorRect，但它的父节点是 `blur_layer`。当 `_remove_blur()` 调用 `_blur_rect.queue_free()` 后，`_blur_rect = null`，但 `blur_layer` 自己也被 `queue_free()`。如果 GameScene 在 blur_layer 被释放后还在访问 `_blur_rect`，没问题（_blur_rect = null）。但如果暂停→恢复→快速暂停，`_add_blur` 中 `_blur_rect` 仍是 null，没问题。
- 实际上没问题，但 `_blur_rect` 既不是 `@onready` 也不在树中，**命名和语义不匹配**。

### 15. GameUI 中 `_entry_queue` 追加 16 个碎片图标，但没设 modulate.a
**文件：** `scripts/scenes/ui/game_ui.gd:146`
- `_fragment_init` 创建 16 个 Sprite2D 加到 `_entry_queue`，但它们已经 `modulate.a = 0.0`。
- 入场动画中 `is_memory` 检查不匹配这些碎片（它们不是 memory 节点），走"其他元素"分支：`position.x += 30`——**但碎片的位置是绝对坐标，不该 +30**！
- **Bug：** 16 个碎片图标的 X 坐标被入场动画多加了 30 像素，位置错位。

### 16. `range` 变量名与 `GDScript built-in range()` 冲突
**文件：** `scripts/coroutine/stages/move_patrol.gd` 和 `move_stage1_enemy1.gd`
```
WARNING: The variable "range" has the same name as a built-in function.
```
- 使用 `@export var range: float`，遮蔽了 GDScript 的 `range()`。在脚本内调用 `range(10)` 会失败。
- **建议：** 改名为 `patrol_range` 或 `amplitude`。

---

## 🐛 潜在 Bug

### 17. Enemy.die() 调用 GameEvents.enemy_killed → GameState._on_enemy_killed → add_score —— 但 enemy 还未 free
- 在 `die()` 里，`GameState.active_enemies.erase(self)` 先于 `GameEvents.enemy_killed.emit()`。如果 `enemy_killed` 的回调中又调了 `all_defeated()`，敌人数已准确。
- 但如果 `enemy_killed` 回调里调了 `queue_free` 的其他操作（如 `death_effect` 播放），HitEffectPool 依赖 enemy 还在——没问题，`queue_free` 是延迟的。

### 18. AudioManager.play_bgm gap timer 使用 `await` 在 autoload 中
**文件：** `scripts/autoload/audio_manager.gd:59`
```gdscript
if gap > 0.0:
    await get_tree().create_timer(gap, false).timeout
```
- 如果 `play_bgm` 被快速调用两次，第二个 await 还在等待时，第一个 timer 到期 → 播放 BGM1 → `bgm_player.stop()` → 第二个 await 到期 → 播放 BGM2。没问题。
- 但如果有第三次调用，可能同时有多个异步流程在跑，导致状态错乱——虽然 `cancel_crossfade` / `stop` 被调了。

### 19. Bullet.bind() 不重置 `fog` 状态
- 复用子弹时，`bind()` 清除 `coroutine_movement`、重置 `extra`、重置 `_grazed`。但如果子弹上一轮有 fog 在播放，下一轮 `spawn_fog=false` → `fog.visible = false`。没问题。
- 但如果 `spawn_fog=true` 时 `fog.fog_finished` 信号连接了 `_on_fog_ready`，`bind()` 里 disconnect 了旧连接——但连接是 `CONNECT_ONE_SHOT`，不 disconnect 也行。

### 20. HitEffectPool._pools 从不清理
**文件：** `scripts/autoload/hit_effect_pool.gd`
- `_pools` 只增不减。如果 100 个不同的 `PackedScene` 各创建 8 个实例，就永远有 800 个节点。
- **建议：** 用 LRU 或计数限制每种效果的最大实例数。

### 21. SceneTransition._fade_out 和 _fade_in 使用 TWEEN_PAUSE_PROCESS
- `set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)`：暂停时 tween 继续跑。但场景切换时树被 paused，这意味着过渡动画在暂停中继续——这是**预期行为**（保证动画不冻）。
- 但如果 TWEEN_PAUSE_PROCESS 指的是"暂停时处理"，那它就会在 `get_tree().paused = true` 中继续跑。OK。

---

## 🧹 代码质量/风格

### 22. 大量 `print()` 遗留
- `MovePatrol` 中可能有遗留 debug print（不确认，但开发中常见）。
- 没有任何统一的日志系统——`push_error()` / `push_warning()` 和 `print()` 混用。

### 23. `@export` 变量缺文档注释
- 几乎所有脚本的 `@export` 变量都没有注释，依赖变量名自描述。但像 `range`、`period` 这种在多次复用中含义不同，应该写注释。

### 24. static 函数不标 `static`
- `BulletPool.is_offscreen`、`StageAPI._make_straight_curve` 等不使用 `self` 的方法未标 `static`。

### 25. 不一致的命名约定
- 私有变量：`_pool`、`_physics`（下划线前缀） vs `active_bullets`（无前缀 public）
- 类名：`MovePatrol` (PascalCase) vs `move_entrance` (snake_case 文件名)
- 信号回调：`_on_player_death` vs `_on_game_state_changed` 混用

### 26. CoroutineRunner._tasks 类型注解缺失
```gdscript
var _tasks: Array[Task] = []
```
- Godot 4 不支持 `Array[Task]` 类型注解，实际是无类型 Array。可以改 `Array`。

---

## 🎯 功能缺失

### 27. 没有关卡 BGM
- 主菜单有 BGM，但 Stage 加载后不播放任何 BGM。StageData 中没有 `bgm` 字段，StageManager 不启动 BGM。

### 28. 残机碎片/Bomb 碎片无拾取逻辑
- `GameState.collect_life_fragment()` 和 `collect_bomb_fragment()` 存在，但没有实际调用入口。没有 Item 系统。

### 29. 没有 Spell Card / Boss 系统
- 只有 StageData 和 EnemyData，没有 Boss 相关数据结构或脚本。

### 30. 没有 Replay 系统
- 对于一个 STG 项目，这是**架构级缺失**。所有输入/随机/时间都必须可录可回放。目前随机数直接调 `randf()`，没有用 RNG autoload。

### 31. 没有暂停菜单的"返回标题"功能
- 暂停菜单只有"继续"和"重开"（推测），没有返回标题或退出。

### 32. 关卡结束后没有结算/返回流程
- `StageManager.stage_cleared` 信号发出后，没有对应的 UI 响应。

---

## 📋 优先级建议

| 优先级 | 编号 | 问题 |
|--------|------|------|
| 🔴 P0 | 1 | Player.miss await 泄露 |
| 🔴 P0 | 4 | 场景切换时 bullet 碰撞不安全 |
| 🔴 P0 | 2 | EnemyVisual 动画抖闪 |
| 🟠 P1 | 15 | GameUI 碎片坐标错位 |
| 🟠 P1 | 3 | StageManager 不清背景协程 |
| 🟠 P1 | 27 | 没有关卡 BGM |
| 🟡 P2 | 6 | GameState 非游戏状态跑 _process |
| 🟡 P2 | 7 | EnemyVisual 每帧 get_parent |
| 🟡 P2 | 8 | BulletPool 无限扩容 |
| 🟡 P2 | 10 | StageAPI 持 runner 强引用 |
| 🟡 P2 | 16 | `range` 变量名冲突 |
| 🟢 P3 | 12 | 子弹/敌人挂载点不一致 |
| 🟢 P3 | 14 | _blur_rect 语义混乱 |
| 🟢 P3 | 20 | HitEffectPool 不清理 |
| 🟢 P3 | 22-26 | 代码风格 |
| 🔵 Feature | 28-32 | 缺失功能 |

---

## 💡 推荐改进方向

1. **引入统一的 Game Loop 状态机**：`LOADING → READY → PLAYING → PAUSED → ENDING`，每个状态明确哪些系统该跑/不该跑。
2. **所有随机数走 RNG autoload**：为 replay 铺路。
3. **StageData 加 bgm 字段**：`@export var bgm: AudioStream`，StageManager.load_stage 时播放。
4. **EnemyVisual 加 hysteresis**：切 IDLE 前确认 speed<30 持续 0.2s，避免闪烁。
5. **统一挂载策略**：所有动态生成的对象都挂到 `World` 下（或 `BulletManager` 下），通过 `StageManager` 查找。
6. **引入 Item 系统**：自动回收 + 拾取判定 + 碎片/完整道具。
