# 📐 东方星 STG 引擎 — 系统规格书
## 版本 1.1 · 2026-06-12
## 基于项目现状逆向提炼 + 规范化约定

---

## 1. 总体架构

```
┌─────────────────────────────────────────┐
│               Autoload 层               │
│  GameManager → GameState → GameEvents   │
│  StageManager → BulletManager           │
│  AudioManager  RNG  HitEffectPool       │
│  MissEffectManager                      │
├─────────────────────────────────────────┤
│               Scene 层                   │
│  MainMenu → DifficultyScreen            │
│          → CharacterScreen              │
│          → GameScene                    │
├─────────────────────────────────────────┤
│             协程（业务逻辑）             │
│  StageScript  CreateScript  MoveScript  │
│  BackgroundScript  PlayerShootScript    │
│  ← 全部通过 StageAPI 访问系统           │
├─────────────────────────────────────────┤
│             实体层                       │
│  Player  Enemy  Bullet  CurvedLaser     │
│  Item  ItemPool                        │
│  BackgroundPlane/Cylinder/Object        │
│  HitEffect                              │
├─────────────────────────────────────────┤
│             数据层                       │
│  StageData  EnemyData  BulletData       │
│  PlayerData  CurvedLaserData            │
│  BulletOverride                         │
└─────────────────────────────────────────┘
```

### 数据流向规则
```
协程 → StageAPI → 系统 → 实体
  │                   │
  └─ 只读 GameState ──┘
  
实体 → 系统（碰撞/回收）→ GameState（改状态）
						→ GameEvents（通知 UI）
```

---

## 2. 系统清单

### 2.1 GameManager
| 项目 | 内容 |
|------|------|
| **职责** | 应用级状态机 + 子模块门面 |
| **状态** | `MENU → PLAYING → PAUSED → TRANSITIONING` |
| **子模块** | SceneTransition, MenuStack, PauseControl |
| **暴露** | `change_scene(path)`, `push_menu()`, `pause/resume` |
| **输入** | `_input()` 拦截（菜单/暂停时吃掉输入）|
| **禁止** | 任何系统不得直接写 AppState（走 `_set_state`）|

### 2.2 GameState
| 项目 | 内容 |
|------|------|
| **职责** | 全局游戏数据 **唯一真源** |
| **拥有** | score, lives, bombs, power, max_point, memory, graze, difficulty, character |
| **读写规则** | 系统通过方法读写（`add_score()`, `add_power()`, `add_max_point()`, `collect_life_fragment()`），不直接改属性 |
| **禁止** | 任何协程/实体不直接改 `GameState.current_score` |
| **reset_all()** | 关卡开始时调用，清零所有运行时数据 |
| **enable** | 只在 `PLAYING` 时启用 `_process` |

### 2.3 StageManager
| 项目 | 内容 |
|------|------|
| **职责** | 关卡生命周期 |
| **流程** | `load_stage(data)` → 创建 StageScript → start_stage(api) → `_on_step` 循环 |
| **背景** | `current_background` 在 add_child 前设置，`_on_init` 可用 |
| **停止** | `stop_stage()` 停 StageScript + 所有 BackgroundScript + 清敌 + 清弹 |
| **敌人** | `spawn_enemy(data, pos)` → 挂到 `World` 下 |
| **禁止** | 不要在协程外直接调 `spawn_enemy` |

### 2.4 BulletManager
| 项目 | 内容 |
|------|------|
| **职责** | 子弹/激光门面 |
| **子模块** | BulletPool, BulletPhysics, LaserSystem, DeathClear |
| **每帧** | `_physics_process`: 清弹圈 → 激光步进 → 碰撞 → 出屏回收 |
| **暂停** | 场景切换时跳过 `_physics_process` |
| **禁止** | 直接访问 `_pool.active_bullets`（用 API 方法）|

### 2.5 AudioManager
| 项目 | 内容 |
|------|------|
| **职责** | BGM 双路 + SFX 8路池 |
| **BGM** | `play_bgm(stream)`, `stop_bgm()`, `crossfade_bgm(stream, dur)` |
| **SFX** | `play_sfx(stream, vol_db)` → 同帧同流不重复 |
| **暂停** | 自动 stream_paused = true/false |
| **禁止** | BGM 不要在 `PLAYING` 外播放 |

### 2.6 RNG
| 项目 | 内容 |
|------|------|
| **职责** | 可复现随机数（replay 基础）|
| **所有随机数必须走 RNG** | `RNG.randf()`, `RNG.randi()`, `RNG.randf_range()` |
| **禁止** | 全局 `randf()` `randi()` — 直接用会破坏 replay |

### 2.7 HitEffectPool
| 项目 | 内容 |
|------|------|
| **职责** | 命中特效对象池 |
| **play()** | 池化复用，自动 reparent 到 World |
| **spawn()** | 直接实例化（不用池），简单效果用 |
| **上限** | 每种 PackedScene 最多 16 个实例 |

### 2.8 Item 系统

#### Item
| 项目 | 内容 |
|------|------|
| **类型** | `POWER / POINT / LIFE_FRAG / BOMB_FRAG / LIFE_FULL / BOMB_FULL` |
| **节点** | `Area2D`（碰撞层 128, 掩码 1=Player）|
| **运动** | 上抛 ↑180 → 重力 ↓240/s² → 终端 ↓180 |
| **收集** | 碰撞 Player / 靠近 128px / 玩家 y<256 → 飞向玩家 800px/s |
| **focus** | 吸附范围 ×1.5 |
| **_dead** | 收集/回收前设 true, 所有回调入口检查 |

#### ItemPool
| 项目 | 内容 |
|------|------|
| **池容量** | 64 个 |
| **模式** | 常驻 tree, `spawn()/recycle()` 无 queue_free |
| **查找** | `StageAPI._find_item_pool()` → World/ItemPool |

#### 掉落配置 (EnemyData)
| 项目 | 内容 |
|------|------|
| `item_power/point/life/bomb` | 各掉几个 |
| `item_life_full/bomb_full` | 完整残机/Bomb 个数 |
| `item_scatter` | 生成位置随机散布 |

#### 得分逻辑
| 项目 | 内容 |
|------|------|
| **Point** | `GameState.add_max_point()`: +max_point 分, max_point+=10 |
| **Power** | `GameState.add_power(1)` → power_raw+1 |
| **碎片** | `collect_*_fragment()`: 5碎片→1命/Bomb |
| **Full** | `collect_*_full()`: 内部调 5×fragment |
| **上限** | 命≤8, Bomb≤8, power_raw≤300 |

### 2.9 CoroutineRunner（基类）
| 项目 | 内容 |
|------|------|
| **机制** | `run(callable)` → `_physics_process` 每帧调 callable |
| **返回值** | `> 0` 等待秒数 / `true` 下帧 / `false/null` 结束 |
| **stop()** | 清全部任务，发 `cancelled` 信号 |
| **注意** | `run()` 内部调 `stop()` — 子类覆写 `stop()` 时注意初始态不被意外触发 |

### 2.10 StageAPI
| 项目 | 内容 |
|------|------|
| **职责** | 协程与系统的唯一桥梁 |
| **持有** | WeakRef(runner) |
| **active()** | runner 存在且 is_running |
| **方法** | `seconds()`, `frames()`, `shoot_spread()`, `spawn_enemy()`, `get_player()`, `fire_*_laser()`, `spawn_decor()`, `all_defeated()` |
| **安全** | 所有方法开头检查 `active()` |

---

## 3. 生命周期

### 3.1 应用级
```
Boot
  └→ MainMenu（MENU 状态，播标题 BGM）
	   ├→ [Start] → DifficultyScreen
	   │               └→ CharacterScreen
	   │                    └→ stop_bgm() → change_scene("game_scene")
	   └→ [Quit]
```

### 3.2 关卡级（GameScene）
```
GameScene._ready()
  ├ 1. GameManager._set_state(PLAYING)     ← 尽早允许暂停
  ├ 2. _load_background()                  ← current_background 在此设置
  │      StageBackground._ready()
  │        ├ _find_camera()
  │        ├ _find_world_environment()
  │        └ _on_setup() → 遍历子 BackgroundScript → _on_init(api)
  ├ 3. 连接 GameEvents + GameManager 信号
  ├ 4. _setup_player()
  ├ 5. await UI.entry_finished
  └ 6. StageManager.load_stage(stage_data)
	   ├ StageScript.new() → add_child → start_stage(api)
	   ├ 遍历 current_background 子 BackgroundScript → start_background(api)
	   └ stage_started.emit()

关卡运行中:
  StageScript._on_step(api) 协程循环
	├ spawn_enemy / shoot_spread / fire_laser
	├ return api.seconds(delay) / true / false
	└ api.all_defeated() → return false

暂停:
  Input.is_action_just_pressed("ui_pause")
  → GameManager.pause_game()
	→ _set_state(PAUSED)
	→ AudioManager._on_game_state_changed → stream_paused=true
	→ CoroutineRunner 冻结（_physics_process 不跑）
	→ Background._process 不跑
	→ Tween 默认暂停（除非 TWEEN_PAUSE_PROCESS）
	→ UI 加 blur layer

恢复:
  → _set_state(PLAYING)
  → stream_paused=false
  → 正常帧恢复

Miss:
  Player → BulletManager.start_death_clear(pos, 2048, 3.0)
		→ MissEffectManager 特效
		→ GameState.lives -= 1
		→ is_invincible = true（3 秒）
		→ lives == 0 → GameEvents.player_death → GameOverMenu

场景切换:
  GameManager.change_scene(path)
	→ _set_state(TRANSITIONING)
	→ 清 MenuStack + PauseControl
	→ SceneTransition:
		 pause tree → fade_out → clear_all → change_scene_to_file
		 → process_frame → fade_in → unpause
	→ _set_state(target_state)

GameScene._exit_tree():
  → _background_instance.queue_free()
  → StageManager.stop_stage() (停协程 + 清敌 + 清弹)
```

### 3.3 协程任务生命周期
```
CoroutineRunner
  ┌ run(callable) → stop() (清旧) → 新任务
  │ run_parallel(callable) → 追加（不停止已有）
  │
  ├ _physics_process(delta):
  │   _clock += delta
  │   for task in _tasks (倒序):
  │     if wake_time > _clock: skip
  │     result = task.callable.call()
  │     if result is float/int > 0: wake_time = _clock + result
  │     elif result == true: pass（下帧再调）
  │     else: 移除任务
  │
  └ 所有任务结束 → finished.emit()
```

### 3.4 敌人生命周期
```
StageScript → api.spawn_enemy(data, pos)
  → StageManager.spawn_enemy → ENEMY_SCENE.instantiate()
  → Enemy._ready()
	   ├ GameState.active_enemies.append(self)
	   └ _apply_enemy_data(data)
			├ visual_scene.instantiate() → add_child
			├ CreateScript.new() → add_child → start_creating(api)
			└ MoveScript.new() → add_child → start_moving(api, self)

Enemy 运行:
  EnemyVisual._process 检测 speed → 切动画
  CreateScript+MoveScript 协程运行中
  碰撞检测 → take_damage → hp <= 0 → die()

Enemy.die():
  ├ active_enemies.erase(self)
  ├ HitEffectPool.play(death_effect)
  ├ enemy_killed.emit(score, pos)
  ├ _drop_item() → ItemPool.spawn (从 EnemyData 配置)
  ├ stop create + move 协程
  └ queue_free()
```

### 3.5 Item 生命周期
```
ItemPool.spawn(pos, type)
  → _pool.pop_back() 或 instantiate (capped)
  → Item.setup(type, pos)
	   ├ _dead=false, _auto_collect=false
	   ├ _velocity=(0,-180) 上抛
	   └ 设贴图
  → visible=true, physics_process=true

Item._physics_process(delta):
  if _dead: return
  ├ 玩家 y<256 或距离<prox → _auto_collect=true
  ├ auto_collect: 飞向玩家 800px/s
  ├ else: 重力加速 → _velocity.y=min(vy+240*dt, 180)
  └ y>960 → _dead, _recycle()

Item collect (area_entered → Player):
  → collect(): _dead=true, visible=false, physics=false
  → 计分/加命 → _recycle()

ItemPool.recycle(item):
  → 已在池中跳过 → visible=false, physics=false → 入池
```

### 3.6 子弹生命周期
```
发射:
  BulletPool.shoot(data, pos, dir)
	├ 池中有 → pop
	├ 池空 → instantiate (扩容, 有上限)
	├ bind(data, dir, override)
	│   ├ 恢复 sprite 可见性
	│   ├ 如果 spawn_fog → fog.play()
	│   │    fog tween → fog_finished signal → _on_fog_ready → is_ready=true
	│   ├ 否则 → is_ready = true
	│   └ movement_script → 启动协程
	├ 加入 active_bullets
	└ _physics_process: position += velocity / physics_ticks

回收:
  ┌ 碰撞命中 → return_bullet
  ├ 出屏 → return_bullet
  ├ DeathClear 圈内 → return_bullet
  ├ 消弹（记忆值概率）→ return_bullet
  └ clear_all → 全部 return_bullet

return_bullet:
  ├ 停协程 + free
  ├ visible=false, process_mode=DISABLED
  ├ 从 active_bullets 移除
  └ 放回池（或 free 如果池满）
```

---

## 4. 数据所有权

| 数据 | 所有者 | 写入者 | 读取者 |
|------|--------|--------|--------|
| score | GameState | GameState.add_score() | GameUI |
| lives | GameState | Player.miss() | GameUI |
| power | GameState | GameState.add_power() | Player shoot calc |
| memory | GameState | bullet_physics, Player.miss() | bullet tint, memory shader |
| graze | GameState | bullet_physics.on_graze() | GameUI |
| max_point | GameState | GameState.add_max_point() | Item, GameUI |
| difficulty | GameState | DifficultyScreen | 各处 |
| character | GameState | CharacterScreen | GameScene |
| active_enemies | GameState | Enemy._ready/_exit/die | StageScript.all_defeated() |
| active_bullets | BulletPool | BulletPool.shoot/return_bullet | BulletPhysics, BulletMultiMesh |
| active_lasers | LaserSystem | LaserSystem.fire/clear | LaserSystem.step |
| item_pool | World/ItemPool | ItemPool.spawn/recycle | Enemy._drop_item, StageAPI |
| current_stage | StageManager | StageManager.load/stop_stage | 各处只读 |
| current_background | StageManager | GameScene._load_background | StageAPI.spawn_decor |

---

## 5. API 契约

### 5.1 StageAPI — 协程唯一入口
```
✅ 可以做的:
  api.seconds(2.0)           — 等待 2 秒后再次调用
  api.frames(5)              — 等待 5 物理帧
  api.shoot_spread(data, count, angle, dir, pos)
  api.spawn_enemy(data, pos)
  api.get_player()           — 返回 Player 或 null
  api.get_field_rect()       — 游戏区域 Rect2
  api.all_defeated()         — active_enemies 为空
  api.fire_*_laser(...)      — 各种激光
  api.spawn_decor(scene, pos3d, follow_plane)
  api.spawn_item(type, pos)
  api.active()               — 协程是否还在跑

❌ 禁止的:
  api.seconds(0) 或负数     — 用 return true（下帧立即调）
  协程内 await               — 会撕裂调度器
  直接写 GameState 属性      — 用方法
  直接调 BulletManager 方法  — 走 api
```

### 5.2 CoroutineRunner 子类约定
```
CreateScript:
  start_creating(api) → run(_on_step)
  职责: 敌人弹幕模式（持续发射）

MoveScript:
  start_moving(api, target) → run(_on_step)
  职责: 目标位置控制（Tween/直接）
  target: Node2D 引用
  覆写 stop() 时: if not is_running: return（防 run() 误触）

StageScript:
  start_stage(api) → run(_on_step)
  职责: 关卡脚本（出生波次、BGM、Boss 触发）
  finished 信号挂 StageManager._on_stage_finished

BackgroundScript:
  start_background(api) → run(_on_step)
  职责: 背景装饰物生成、相机动画
  _on_init(api) → 同步初始化（设置初始参数）
  注意: _on_init 时协程未启动，不要 await/seconds/frames

PlayerShootScript:
  start_shooting(api) → run(_on_step)
  职责: 自机射击弹幕
```

### 5.3 实体 API
```
Enemy:
  take_damage(int)  → 扣血, hp<=0 自动 die
  die()             → 清状态 + 特效 + emit + queue_free
  ⚠️ 不在外部调 die()（take_damage 自动处理）

Bullet:
  bind(data, dir, override)  → 池复用初始化
  ⚠️ 不在外部调 -- 池管理

Player:
  miss()            → 被弹处理
  ⚠️ miss() 不能 await（由碰撞回调同步调用）
  ⚠️ miss() 内无敌计时用信号/Tween

Item:
  setup(type, pos)  → 池复用初始化
  collect()         → 收集逻辑（内部调用，不外部触发）
  ⚠️ Item 不外部实例化，走 ItemPool.spawn()

ItemPool:
  spawn(pos, type)  → 生成 item (池复用优先)
  recycle(item)     → 回收入池（内部调用，不外部触发）
  ⚠️ 不 queue_free，常驻 tree
```

### 5.4 禁止操作清单
```
❌ 任何脚本直接用 global randf() / randi()
❌ 任何脚本直接写 GameState.current_score / lives / power_raw
❌ 协程内使用 await
❌ 碰撞回调/物理回调内 await
❌ StageAPI.active()==false 时调用 StageAPI 方法
❌ 直接 instantiate 子弹（走 BulletManager/BulletPool）
❌ Enemy.die() 外部调用
❌ 场景切换期间读 current_scene 子节点
❌ BackgroundScript._on_init 里用 api.seconds/frames
❌ MoveScript.stop() 中做业务逻辑（run() 内部会调 stop()）
```

---

## 6. 状态机

### 6.1 GameManager.AppState
```
MENU ──→ PLAYING ──→ PAUSED
  ↑        │  ↑         │
  └────────┘  └─────────┘
	  (ESC/返回)  (ESC 暂停/恢复)

TRANSITIONING = 短暂态, 场景切换时
```

### 6.2 代码中检查状态
```gdscript
# 只在游戏中跑的代码
if GameManager.current_state != GameManager.AppState.PLAYING:
	return
```

### 6.3 EnemyVisual 动画状态
```
IDLE ──speed>=30──→ RIGHTING ──播放完毕──→ RIGHT
  ↑                    │                      │
  └──speed<30持续0.2s──┘──────────────────────┘
```

### 6.4 Player 动画状态
```
IDLE ──press L/R──→ LEFTING/RIGHTING ──播完──→ LEFT/RIGHT
  ↑                      │                        │
  └──release─────────────┘────────────────────────┘
```

### 6.5 CurvedLaser 状态
```
ALIVE ──出屏/超时/全洞──→ FADE ──0.3s──→ DEAD
```

---

## 7. 命名 & 文件公约

| 类别 | 约定 | 例 |
|------|------|-----|
| 类名 | PascalCase | `MoveStage1Enemy1` |
| 文件名 | snake_case | `move_stage1_enemy1.gd` |
| 私有成员 | `_prefix` | `_pool`, `_tween` |
| 公共成员 | no prefix | `active_bullets` |
| 信号 | snake_case | `stage_cleared` |
| 信号回调 | `_on_` + 信号名 | `_on_enemy_killed` |
| @export 变量 | snake_case, 写注释 | `@export var patrol_range: float ## 摆幅` |
| 常量 | UPPER_SNAKE | `POOL_SIZE`, `FACTION_ENEMY` |
| 枚举 | PascalCase | `Phase.ENTRANCE` |

### 变量名避讳
```
❌ range    → ✅ patrol_range / amplitude  (遮蔽内置 range())
❌ dir      → ✅ direction
```

---

## 8. 检查清单（新功能/修改前）

```
□ 随机数走了 RNG 吗？
□ GameState 修改走了方法吗？
□ 碰撞/物理回调里没有 await 吗？
□ 协程里没有 await 吗？
□ 新 node 挂到了正确的父节点吗（World / BulletManager / current_background）？
□ 新 StageAPI 方法检查了 active() 吗？
□ MoveScript.stop() 里加了 `if not is_running: return` 吗？
□ 新 @export 写了注释吗？
□ 新功能需要考虑暂停时的行为吗？
□ 释放资源了吗（tween, timer, signal disconnect）？
```

---

## 9. 你可以做什么

拿着这份 spec，你可以：

1. **逐条修 P0 问题** — 对着 `CODE_REVIEW.md` 的 5 个致命问题按 spec 边界修
2. **先修 #1 (player.miss 去 await)** — 影响面最大，修一个解决 #5 和 #37
3. **代码审查时对照检查清单** — 每次 PR / commit 前跑一遍 §8
4. **写新系统前查 §2 系统清单** — 确认你的系统跟谁交互、禁止做什么
5. **维护这份 spec** — 系统变了就更新对应段落
6. **要求我严格按照 spec 写代码** — 给我 spec 引用，我会遵循 §5 API 契约和 §7 命名
7. **要求我在改动前先更新 spec** — "先把 §X.Y 改了再写代码"

💡 建议从 **P0 #1 (player.miss 去 await)** 开始~ ♥️
