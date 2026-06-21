# 📐 东方星 STG 引擎 — 系统规格书
## 版本 1.2 · 2026-06-21
## 基于源码逆向提炼 + 架构路线图 v3 对齐

---

## 1. 总体架构

```
┌─────────────────────────────────────────┐
│            Autoload 层                  │
│  GameManager  GameState  GameEvents     │
│  StageManager  AudioManager  RNG       │
│  BulletManager                          │
│  HitEffectPool  MissEffectManager      │
│  AssetRegistry  LayerConfig            │
├─────────────────────────────────────────┤
│             协程（业务逻辑）             │
│  StageScript  CreateScript  MoveScript  │
│  BackgroundScript  PlayerShootScript   │
│  ← 全部通过 StageContext 访问系统       │
├─────────────────────────────────────────┤
│               Scene 层                  │
│  MainMenu → DifficultyScreen           │
│          → CharacterScreen             │
│          → GameScene                   │
├─────────────────────────────────────────┤
│             实体层                       │
│  Player  Enemy  Boss  Bullet           │
│  Laser  Item  ItemPool                │
│  EnemyVisual  HitEffect                │
│  BackgroundPlane/Cylinder/Object       │
├─────────────────────────────────────────┤
│             数据层                       │
│  StageData  PhaseData  BossData        │
│  EnemyData  BulletData  PlayerData     │
│  StageRegistry                         │
│  SpellRecord, SpellRecordBook          │
│  CardDef, CardRegistry                 │
└─────────────────────────────────────────┘
```

### 数据流向规则
```
协程 → StageContext → 系统 → 实体
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
| **职责** | 应用级状态机 + 模块门面 |
| **状态** | `MENU → PLAYING → PAUSED → TRANSITIONING` |
| **子模块** | SceneTransition, MenuNav（替代旧的 MenuHost/MenuStack/PauseControl） |
| **暴露** | `change_scene(path)`, `push_page(path)`, `pop_page()`, `push_overlay_menu(menu)`, `pop_overlay_menu(menu)` |
| **输入** | `_process` 拦截 ui_pause 推暂停覆盖层；覆盖层开着时不处理 |
| **禁止** | 任何系统不得直接写 AppState（走 `_set_state`）|
| **场景切换** | `change_scene()` → TRANSITIONING → await SceneTransition → 更新 `current_scene_path` → PLAYING |
| **菜单导航** | 所有页面 push/pop 统一走 MenuNav（普通页面 + 覆盖层两层栈） |
| **页面契约** | 页面必须有 `finished(result: Dictionary)` 信号；推荐继承 `BasePage` / `NavPage` |

### 2.2 GameState
| 项目 | 内容 |
|------|------|
| **职责** | 全局游戏数据 **唯一真源** |
| **拥有** | score, lives, bomb_count, power_raw, max_point, memory_value, graze_count, difficulty, character |
| **附加** | active_enemies（引用列表）, player（弱引用）, spell_book, stage_registry, high_scores |
| **练习模式** | `is_practice_mode`, `is_stage_practice`, `practice_boss_data`, `practice_phase_index` |
| **读写规则** | 系统通过方法读写（`add_score()`, `add_power()`, `add_memory()`, `collect_life_fragment()`），不直接改属性 |
| **禁止** | 协程/实体直接改 `GameState.current_score` |
| **reset_all()** | 关卡开始时调用，清零运行时数据；`reset_practice()` 设置满P/0命 |
| **memory** | 运行在 `_process`（仅在 PLAYING 时启用），每秒恢复 `MEMORY_REGEN=0.05`；影响自机弹伤害倍率（0~50时最多1.15x）和擦弹消弹概率（50~100时0.05~0.30） |

### 2.3 StageManager
| 项目 | 内容 |
|------|------|
| **职责** | 关卡生命周期 + 敌人生成门面 |
| **流程** | `load_stage(data)` → reset_all → 创建 StageScript → start_stage(ctx) → 自动启动 BackgroundScript |
| **背景** | `current_background` 由 GameScene 设置 `StageManager.current_background = instance` |
| **停止** | `stop_stage()` 清敌人、清弹幕、清 BackgroundScript |
| **敌人** | `spawn_enemy(data, pos)` → 挂到 `World` 下；`spawn_boss(data, pos)` → 走 Boss 类 |
| **禁止** | 不要在协程外直接调用 spawn_enemy |

### 2.4 BulletManager
| 项目 | 内容 |
|------|------|
| **职责** | 子弹/激光门面，挂载为 Node2D 实体 |
| **子模块** | BulletPool, BulletPhysics, LaserSystem, DeathClear |
| **每帧** | `_physics_process`: 死亡清弹 → 激光步进+碰撞 → 子弹碰撞 → 出屏回收 |
| **暂停** | 场景切换或 `processing_paused` 时跳过 `_physics_process` |
| **多网格** | 可选 `use_multi_mesh`，通过 BulletMultiMesh 批量渲染 |
| **禁止** | 直接访问 `_pool.active_bullets`（用 API 方法）|

#### 2.4.1 BulletPool
- 池大小 `POOL_SIZE=4000`，硬上限 `MAX_TOTAL=5000`
- `shoot(data, pos, dir)` → 从池取 → bind → 加入 `active_bullets`
- `return_bullet(bullet)` → 停协程+队列清理 → 入池（或 free 如果池满）
- `_return_to_pool` 清理雾 + 协程 + 信号连接
- `is_offscreen()` 使用 90px 边距扩展判定

#### 2.4.2 BulletPhysics
- 每帧遍历 `active_bullets`，按 faction 分流：
  - PLAYER → 对敌伤害（记忆值<50时伤害倍率 1.05~1.15）
  - ENEMY → 玩家碰撞（miss）/ 擦弹（记忆>50时有消弹概率 0.05~0.30）
  - BOMB → 对敌伤害
- 命中检测：圆形（半径和） / 矩形（OBB 最近点）
- 擦弹：`on_graze()` → graze+1, score+10, memory+0.15

#### 2.4.3 LaserSystem
- 池大小 32，`fire_*()` 返回 Laser 引用
- 每帧 `step()`：激光更新 → 玩家碰撞检测 + 擦弹
- `clear()` 让所有激光立即淡出

#### 2.4.4 DeathClear
- 每帧膨胀圈内消除敌弹
- 消弹圈碰到的激光直接淡出（不再切割打孔）
- Miss 时 `start_death_clear(pos, 2048, 3.0)`

### 2.5 AudioManager
| 项目 | 内容 |
|------|------|
| **职责** | BGM 双路（A/B 交叉渐出预留） + SFX 8 路池 |
| **BGM** | `play_bgm(stream, gap=0.3)` — 同流不重复 |
| **SFX** | `play_sfx(stream, vol_db)` → 同帧同流不重复（_played_this_frame 过滤） |
| **音量** | `master_volume`, `bgm_volume`, `sfx_volume`（线性值 → db 转换） |
| **暂停** | 自动 stream_paused = true/false |
| **禁止** | BGM 不要在 `PLAYING` 外播放 |

### 2.6 RNG
| 项目 | 内容 |
|------|------|
| **职责** | 可复现随机数（replay 基础）|
| **所有随机数必须走 RNG** | `RNG.randf()`, `RNG.randi()`, `RNG.randf_range()`, `RNG.randfn()` |
| **禁止** | 全局 `randf()` `randi()` — 直接用会破坏 replay |

### 2.7 HitEffectPool
| 项目 | 内容 |
|------|------|
| **职责** | 命中特效对象池，按 PackedScene 分池（每场景 8 实例上限）|
| **play()** | 从池取 → reparent 到 World → 激活+旋转 |
| **_recycle()** | 实例用完自动调用（`return_method`）→ visible=false |
| **clear_all_pool()** | 清空所有池实例 |

### 2.8 MissEffectManager
| 项目 | 内容 |
|------|------|
| **职责** | 全屏圆形 Miss 特效（CanvasLayer, ShaderMaterial）|
| **add_circle()** | 最多 8 圈同时；支持延迟、起始半径 |
| **每帧** | `_process` 更新 shader uniform（位置/半径/alpha）→ 过期移除 |

### 2.9 Item 系统

#### Item
| 项目 | 内容 |
|------|------|
| **类型** | `POWER / POINT / LIFE_FRAGMENT / BOMB_FRAGMENT / LIFE_FULL / BOMB_FULL` |
| **节点** | `Area2D`（碰撞层 32, 掩码=Player）|
| **运动** | 上抛 ↑180 → 重力 ↓240/s² → 终端 ↓180 |
| **收集** | 碰撞 Player / 靠近 128px（focus×1.5） / 玩家 y<256 → 飞向玩家 800px/s |
| **_dead** | 收集/回收前设 true，回调入口检查 |

#### ItemPool
| 项目 | 内容 |
|------|------|
| **池容量** | 64 个 |
| **模式** | 常驻 tree（World/ItemPool），`spawn()/recycle()` 无 queue_free |
| **recycle()** | 已在池中跳过，`_pool` 满时 queue_free |

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
| **碎片** | `collect_life_fragment()` / `collect_bomb_fragment()`: 5碎片→1完整 |
| **完整** | `collect_life_full()` / `collect_bomb_full()`: 内部调 5×fragment |
| **上限** | lives≤8, bomb_count≤8, power_raw≤300（对应火力 1.00~4.00）|

### 2.10 CoroutineRunner（基类）
| 项目 | 内容 |
|------|------|
| **机制** | `run(callable)` → `_physics_process` 每帧调 callable |
| **返回值** | `> 0` 等待秒数 / `true` 下帧 / `false/null` 结束 |
| **stop()** | 清全部任务，发 `cancelled` 信号 |
| **注意** | `run()` 内部调 `stop()` — 子类覆写 `stop()` 时注意初始态不被意外触发 |
| **run_parallel()** | 追加并行任务，不停止已有 |

### 2.11 StageContext
| 项目 | 内容 |
|------|------|
| **职责** | 协程与系统的唯一桥梁（替代旧的 StageAPI 类）|
| **持有** | WeakRef + `runner` 引用 |
| **子服务** | `clock`, `bullets`, `enemies`, `player`, `dialogue`, `items`, `decor` |
| **active()** | runner 存在且 is_running |
| **方法** | `clock.wait(seconds)`, `bullets.shoot_spread()`, `bullets.fire_*_laser()`, `enemies.spawn()`, `enemies.spawn_boss()`, `player.get_player()`, `play_dialogue()`, `spawn_item()`, `get_decor()`, `get_field_rect()` |
| **安全** | 所有方法开头检查 `active()` |

### 2.12 AssetRegistry
| 项目 | 内容 |
|------|------|
| **职责** | 全项目资源注册表，一处改全局生效 |
| **拥有** | `enemy_visuals`, `bullet_configs`, `sounds`, `ui_textures`, `enemies` 字典 |
| **子弹配置** | `bullet_configs` 包含贴图 + 判定盒信息；构造链通过 `BulletData.tex(key)` 查找 |
| **敌人脚本** | `enemies` 字典存 EnemyScript 类引用 |

### 2.13 LayerConfig
| 项目 | 内容 |
|------|------|
| **职责** | 全局 z_index 常量 |
| **值** | `PLAYER_BULLET=-10`, `ITEM=-5`, `PLAYER=0`, `ENEMY=5`, `ENEMY_BULLET=10`, `BOSS=15`, `BOSS_HP_RING=20`, `BOMB=100`, `GAME_UI=1000`, `OVERLAY=2000`, `DEBUG=9999` |

---

## 3. 生命周期

### 3.1 应用级
```
Boot
  └→ MainMenu（MENU 状态，播标题 BGM）
       ├→ [Start] → DifficultyScreen
       │              └→ CharacterScreen
       │                   └→ stop_bgm() → change_scene("game_scene")
       ├→ [Stage Practice] → StagePracticeMenu
       │              └→ (直接跳 GameScene, is_stage_practice=true)
       ├→ [Spell Practice] → SpellPracticeMenu
       │              └→ (直接跳 GameScene, is_practice_mode=true)
       ├→ [Replay / Player Data / Music Room / Option / Manual]
       └→ [Quit]
```

### 3.2 关卡级（GameScene）
```
GameScene._ready()
  ├ 1. GameManager._set_state(PLAYING)     ← 尽早允许暂停
  ├ 2. ItemPool 创建并挂到 World
  ├ 3. 根据 is_practice_mode 分流:
  │     普通: 解析 StageData → _load_background → StageManager.load_stage(data)
  │     练习: _load_background(缓存的 practice_background) → 直接 spawn_boss(单 phase)
  ├ 4. _setup_player() (引入角色数据 + 射击脚本)
  ├ 5. 连接 GameEvents + GameManager 信号
  └ 6. 自动开始（StageScript → start_stage → Timeline 驱动）

关卡运行中:
  GameUI HUD 每帧更新（score/power/max_point/graze/memory/碎片）
  StageScript._on_step() → Timeline.tick() 驱动波次

暂停:
  Input.is_action_just_pressed("ui_pause")
  → GameManager.pause_game()
    → MenuNav.push_overlay("pause_menu")
      → _set_state(PAUSED)
      → tree.paused = true（AudioManager 自动 stream_paused）
      → CoroutineRunner 冻结（_physics_process 不跑）
      → Background._process 不跑
      → Tween 默认暂停
      → _add_blur()（SubViewport 区域着色器模糊）

恢复:
  MenuNav.pop_overlay() → tree.paused = false
  → _set_state(PLAYING)
  → 移除 blur

Miss:
  Player → BulletManager.start_death_clear(pos, 2048, 3.0)
    → DeathClear 圈膨胀 + 激光淡出
    → MissEffectManager 6 个 CircleShader 圈
    → GameState.add_memory(25.0)
    → GameState.lives -= 1
    → is_invincible = true（3 秒倒计时，_physics_process 自动倒数）
    → lives == 0 → GameEvents.player_death.emit()
      → await 2 秒 → game_over_menu 覆盖层

关卡通关:
  stage_cleared → 非练习: current_stage_id += 1, reload_current_scene
  → 关卡练习: 跳回主菜单

场景切换:
  GameManager.change_scene(path)
    → _set_state(TRANSITIONING)
    → 清 MenuStack + 覆盖层
    → SceneTransition:
        pause tree → fade_out → clear_all → change_scene_to_file
        → process_frame → fade_in → unpause
    → _set_state(target_state)

GameScene._exit_tree():
  BulletManager.clear_all()
  → HitEffectPool.clear_all_pool()
  → 清理 background_instance（queue_free）
  → 清理 practice_runner
  → StageManager.stop_stage()
  → GameState.end_practice()
```

### 3.3 协程任务生命周期
```
CoroutineRunner
  ├ run(callable) → stop() (清旧) → 新任务
  ├ run_parallel(callable) → 追加（不停止已有）
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

### 3.4 Timeline（声明式替代状态机）
```
tl := Timeline.new(ctx)
tl.at(0.0).do(cb)              — 单次定时
tl.at(2.0).every(1.5).times(4).do(cb)  — 重复定时
tl.at(5.0).spawn_enemy(data, pos)      — 快捷方法
tl.at(10.0).spawn_boss(data, pos)
tl.at(12.0).play_bgm(path)
tl.loop()                      — 循环模式

tick(delta) → bool (还有未触发事件)
```

### 3.5 敌人生命周期
```
StageScript → ctx.enemies.spawn_enemy(data, pos)
  → StageManager.spawn_enemy → ENEMY_SCENE.instantiate()
  → Enemy._ready()
    ├ GameState.active_enemies.append(self)
    └ _apply_enemy_data(data)
        ├ visual_scene.instantiate() → add_child
        ├ CreateScript.new() → add_child → start_creating(ctx)
        └ MoveScript.new() → add_child → start_moving(ctx, self)
  → start() 启动协程

Enemy 运行:
  EnemyVisual._process 检测 speed → 切动画（IDLE ↔ RIGHTING ↔ RIGHT，含防抖 0.2s）
  CreateScript+MoveScript 协程运行中
  碰撞检测 → take_damage → hp <= 0 → die()

Enemy.die():
  ├ active_enemies.erase(self)
  ├ AudioManager.play_sfx(enemy_die)
  ├ _drop_item() → ItemPool.spawn（从 EnemyData 配置）
  ├ HitEffectPool.play(death_effect)
  ├ GameEvents.enemy_killed.emit(score, pos)
  ├ stop create + move 协程
  └ queue_free()
```

### 3.6 Boss 生命周期
```
Boss.setup(data, ctx) → 环形血条 + 碰撞形状 + 信号连接
Boss.start_boss() → active_enemies 注册 + 发射 boss_spawned 信号

NextPhase:
  ├ phase_index++
  ├ HP 从 0 → phase.hp (1 秒 Tween)
  ├ unlock_spell() → 符卡簿记录（见到即记）
  ├ 如果是符卡 → GameEvents.phase_start
  ├ _begin_phase() → 启动 move/shoot 协程
  ├ 非 is_timeout_only → invincible=false

每帧:
  ├ _elapsed += delta
  ├ bonus 递减 tick（max(1, bonus / time_limit * delta)）
  └ 超时 → _on_phase_clear(!is_timeout_only)

PhaseClear:
  ├ 停 move/shoot 协程
  ├ 记录 attempt（普通模式）/ practice（练习模式）
  ├ score += bonus（如果收取）
  ├ _drop_items()（练习不掉落）
  ├ 2 秒 gap → _next_phase（或 _die_boss）

DieBoss:
  ├ active_enemies.erase
  ├ boss_defeated.emit
  └ queue_free
```

### 3.7 子弹生命周期
```
发射:
  BulletPool.shoot(data, pos, dir)
    ├ 池中有 → pop
    ├ 池空 → instantiate（有上限）
    └ bind(data, dir)
        ├ sprite.texture = data.texture
        ├ faction = data.faction
        ├ velocity = dir.normalized() × data.velocity.length()
        ├ 如果 spawn_fog → 雾播放 → _on_fog_ready → is_ready=true
        ├ 否则 is_ready=true
        └ 如果 movement_script → 启动协程

每帧:
  ├ 没有协程的：position += velocity / physics_ticks_per_second
  └ 有协程的：由 MoveScript 协程控制

回收:
  ├ 碰撞命中 → return_bullet
  ├ 出屏 → return_bullet
  ├ DeathClear 圈内 → return_bullet
  └ clear_all → 全部 return_bullet

return_bullet:
  ├ 停协程（bullet.coroutine_movement + 子 MoveScript）+ queue_free
  ├ fog.visible=false, texture=null, 断信号
  ├ visible=false, process_mode=DISABLED
  ├ 从 active_bullets 移除
  └ 入池（或 free 如果池满 4000）
```

### 3.8 Item 生命周期
```
ItemPool.spawn(pos, type)
  → _pool.pop_back() 或 instantiate（无上限）
  → Item.setup(type, pos)
    ├ _dead=false, _auto_collect=false
    ├ _velocity=(0,-180) 上抛
    └ 设贴图（power / point / life 等）

Item._physics_process(delta):
  if _dead: return
  ├ 玩家 y<256 或距离<128px（focus×1.5）→ _auto_collect=true
  ├ auto_collect: 飞向玩家 800px/s
  ├ else: 重力加速 → vy=min(vy+240*dt, 180)
  └ y>960 → _recycle()

Item collect (area_entered → Player):
  → collect(): _dead=true, visible=false, physics=false
  → AudioManager.play_sfx(item)
  → 计分/加碎片/加命
  → _recycle()

ItemPool.recycle(item):
  → 已在池中跳过 → visible=false, physics=false → 入池
```

---

## 4. 数据所有权

| 数据 | 所有者 | 写入者 | 读取者 |
|------|--------|--------|--------|
| score | GameState | GameState.add_score(), add_max_point() | GameUI |
| lives | GameState | Player.miss(), collect_life_*() | GameUI |
| bomb_count | GameState | collect_bomb_*() | GameUI, Player |
| power_raw | GameState | GameState.add_power(), on_miss_power_penalty() | Player shoot calc, GameUI |
| memory_value | GameState | GameState._process(regen), add_memory(), reduce_memory() | bullet tint, bullet_physics damage |
| graze_count | GameState | bullet_physics.on_graze() | GameUI |
| max_point | GameState | GameState.add_max_point() | Item, GameUI |
| difficulty | GameState | DifficultyScreen | 各处 |
| character | GameState | CharacterScreen | GameScene._setup_player() |
| active_enemies | GameState | Enemy._ready/_exit, Boss, BulletPhysics | StageContext, all_defeated() |
| active_bullets | BulletPool | BulletPool.shoot/return_bullet | BulletPhysics, BulletMultiMesh |
| active_lasers | LaserSystem | LaserSystem.fire_*/clear | LaserSystem.step |
| item_pool | World/ItemPool | ItemPool.spawn/recycle | Enemy._drop_item, Boss._drop_items |
| current_stage | StageManager | StageManager.load/stop_stage | 各处只读 |
| current_background | StageManager | GameScene._load_background | StageContext.spawn_decor |
| spell_book | GameState | record_spell/record_practice | SpellPracticeMenu |
| player | GameState | GameScene._setup_player() | PlayerService, Item |

---

## 5. 协程脚本体系

### 5.1 StageScript（关卡脚本）
> 继承 `CoroutineRunner`

| 项目 | 内容 |
|------|------|
| **入口** | `start_stage(ctx)` → `run(_on_step.bind(ctx))` |
| **主循环** | `_on_step(ctx)` → `Timeline.tick(delta)` |
| **便捷方法** | `start_timeline()`, `diff_pick(arr)`, `diff_get(dict, key, default)` |
| **数据** | `ctx: StageContext`, `_tl: Timeline` |

### 5.2 CreateScript（弹幕脚本）
> 继承 `CoroutineRunner`

| 项目 | 内容 |
|------|------|
| **入口** | `start_creating(ctx)` → `run(_on_step.bind(ctx))` |
| **主循环** | `_on_step(ctx)` → `Timeline.tick(delta)` |
| **便捷方法** | `start_timeline()`, `diff_pick(arr)` |

### 5.3 MoveScript（移动脚本）
> 继承 `CoroutineRunner`

| 项目 | 内容 |
|------|------|
| **入口** | `start_moving(ctx, target)` → `run(_on_step.bind(ctx))` |
| **主循环** | `_on_step(ctx)` → `Timeline.tick(delta)` |
| **target** | Node2D 引用（Enemy 或 Bullet 自身）|
| **便捷方法** | `start_timeline()`, `diff_pick(arr)` |

### 5.4 BackgroundScript（背景协程）
> 继承 `CoroutineRunner`

| 项目 | 内容 |
|------|------|
| **入口** | `start_background(ctx)` → `run(_on_step.bind(ctx))` |
| **初始化** | `_on_init(ctx)` — 场景加载后立即调用，协程未启动 |
| **禁止** | `_on_init` 里用 `api.seconds/frames`（协程未启动）|
| **便捷方法** | `start_timeline()`, `diff_pick(arr)` |

### 5.5 PlayerShootScript / CSPlayer（自机射击脚本）
> 继承 `CoroutineRunner`

| 项目 | 内容 |
|------|------|
| **入口** | `start_shooting(ctx)` → `run(_on_step.bind(ctx))` |
| **实例** | `cs_reimu.gd`, `cs_marisa.gd` 分别在角色 PlayerData 中指定 |

### 5.6 EnemyScript（一体化敌人脚本）
> 继承 `CoroutineRunner`

| 项目 | 内容 |
|------|------|
| **入口** | `setup(enemy, ctx)` → `start()` → `run(_on_step.bind(ctx))` |
| **职责** | 一文件 = 外观 + 移动 + 弹幕（通过 Timeline 组织）|
| **使用** | `AssetRegistry.enemies["red_soldier"]` — 被 EnemyService.spawn(key) 调用 |

---

## 6. 数据类

### 6.1 BulletData
| 项目 | 内容 |
|------|------|
| **类型** | Resource, class_name BulletData |
| **关键字段** | texture, tint, damage, velocity, hit_effect, faction, can_be_canceled, hitbox_shape/radius/size, spawn_fog, fog_texture, movement_script |
| **构造链** | `.tex(key).speed(v).dir(x,y).color(c).enemy().player().blend(b)` |
| **判定** | `HitboxShape.CIRCLE` / `RECTANGLE` |
| **tint_mode** | `MULTIPLY`（默认）/ `BLEND`（白色保持不变）|

### 6.2 EnemyData
| 项目 | 内容 |
|------|------|
| **类型** | Resource, class_name EnemyData |
| **关键字段** | visual_scene, max_hp, hitbox_radius, score_value, death_effect, create_script, move_script, boss_data |
| **掉落** | item_power, item_point, item_life, item_bomb, item_life_full, item_bomb_full, item_scatter |

### 6.3 PhaseData
| 项目 | 内容 |
|------|------|
| **类型** | Resource, class_name PhaseData |
| **关键字段** | name, uid, bonus, time_limit, hp, is_timeout_only, move_script, shoot_script, background |
| **uid 规则** | 正数=真符卡全局唯一，0=非符不记入符卡簿 |
| **掉落** | 同上 item_* |

### 6.4 BossData
| 项目 | 内容 |
|------|------|
| **类型** | Resource, class_name BossData |
| **关键字段** | boss_name, visual(PackedScene), phases(Array[PhaseData]), score_value |

### 6.5 StageData
| 项目 | 内容 |
|------|------|
| **类型** | Resource, class_name StageData |
| **关键字段** | stage_id, difficulty(EASY~EXTRA), create_script, background_scene |
| **注意** | 已经不挂 boss 数组，通过 StageScript 内部 Timeline 管理 |

### 6.6 Laser（激光实体）
| 项目 | 内容 |
|------|------|
| **类型** | Node2D, class_name Laser |
| **模式** | `LINE`（两点直线）、`GROWING`（曲线生长）、`FIXED_PATH`（曲线瞬间全开）|
| **关键字段** | laser_color, mid_width, end_width, hitbox_width, glow_intensity, max_lifetime, grow_speed, tail_distance |
| **碰撞** | 沿曲线采样 20 点做线段最近点距离检测，阈值 = hitbox_width + 5px |

### 6.7 PlayerData
| 项目 | 内容 |
|------|------|
| **类型** | Resource, class_name PlayerData |
| **关键字段** | focus_speed, normal_speed, animation(SpriteFrames), shoot_script(Script) |

### 6.8 StageRegistry
| 项目 | 内容 |
|------|------|
| **类型** | Resource, class_name StageRegistry |
| **字段** | stages(Array[StageData]) |
| **方法** | `find(stage_id, difficulty)`, `get_by_stage(stage_id)` |

### 6.9 SpellRecord / SpellRecordBook
| 项目 | 内容 |
|------|------|
| **SpellRecord** | uid, character, stage, phase_type, phase_number, difficulty, spell_name, attempts, captures, practice_attempts, practice_captures, best_score, best_time |
| **SpellRecordBook** | 主键 (uid, character, difficulty) |
| **uid 生成** | `SpellRecord.get_phase_uid(boss, phase_idx, stage_id)` — 真 uid 或 合成非符 uid |
| **非符 uid** | `make_non_uid(stage, phase_idx)` → `-(stage*100 + phase_idx + 1)` |

---

## 7. StageContext — 协程唯一入口

### 7.1 子服务

**ClockService**
| 项目 | 内容 |
|------|------|
| `wait(seconds)` | 返回 seconds，CoroutineRunner 自动等待后再次调用 |
| `wait_frames(count)` | 返回帧等效秒数 |

**BulletService**
| 项目 | 内容 |
|------|------|
| `shoot_spread(data, count, spread_angle, base_dir, at, sfx)` | 扇形散弹 |
| `fire_growing_laser(curve, color, speed, tail, lifetime)` | 曲线生长激光 |
| `fire_line_laser(a, b, color, lifetime)` | 两点间直线激光 |
| `fire_fixed_laser(curve, color, lifetime)` | 固定路径瞬间全开 |
| `fire_homing_laser(origin, player_pos, color, bend, length, lifetime)` | 自机导向激光 |
| `clear_all_lasers()` | 清除所有激光 |

**EnemyService**
| 项目 | 内容 |
|------|------|
| `spawn_enemy(data, pos)` | 通过 StageManager 生成普通敌人 |
| `spawn(key, pos, params)` | 通过 AssetRegistry 查找 EnemyScript 生成 |
| `spawn_boss(data, pos)` | 生成 Boss |
| `all_defeated()` | active_enemies 为空 |

**PlayerService**
| 项目 | 内容 |
|------|------|
| `get_player()` | 返回 Player 或 null |
| `get_position()` | 返回玩家位置 Vector2 |

**DialogueService**
| 项目 | 内容 |
|------|------|
| `play(lines)` | 播放对话（暂停协程，等完成后继续）|
| `show(char_name, text, pos, portrait)` | 快捷单句对话 |

**ItemService**
| 项目 | 内容 |
|------|------|
| `spawn(type, position)` | 生成道具 |

**DecorManager**
| 项目 | 内容 |
|------|------|
| `add_layer(layer)` | 添加一个装饰层（DECOR_LAYER + MultiMesh）|
| `spawn(layer_name, pos, tex_scale, follow, lifetime)` | 生成单个装饰 |
| `batch_spawn(layer_name, count, x_range, z_range, follow, lifetime)` | 批量生成 |
| `clear_layer(layer_name)` | 清空该层 |
| `fade_out_layer(layer_name, duration)` | 淡出并清空 |

### 7.2 使用模式
```
var bullet := BulletData.new().tex("小玉").color(Color.RED).enemy()
bullet.velocity = Vector2(0, 400)

var move_cfg := { type: "move_down", target_y: 300, duration: 1.5 }

# 在 Timeline 中使用
tl.at(1.0).every(0.5).times(3).do(func():
    ctx.enemies.spawn("red_soldier", Vector2(randf_range(200, 700), 0))
)

---

## 8. API 契约

### 8.1 StageContext — 协程唯一入口
```
✅ 可以做的:
  ctx.clock.wait(2.0)          — 等待 2 秒后再次调用（返回 >0 秒数）
  ctx.clock.wait_frames(5)     — 等待 5 物理帧
  ctx.bullets.shoot_spread(data, count, spread, dir, pos)
  ctx.bullets.fire_straight_laser(data, origin, dir, len)
  ctx.bullets.fire_homing_laser(data, origin, bend, len, player_pos)
  ctx.enemies.spawn_enemy(data, pos)
  ctx.enemies.spawn(key, pos, params)     — 通过 AssetRegistry 按名称生成
  ctx.enemies.spawn_boss(data, pos)
  ctx.enemies.all_defeated()
  ctx.player.get_player()      — 返回 Player 或 null
  ctx.player.get_position()    — 返回 Vector2
  ctx.spawn_item(type, pos)
  ctx.play_dialogue(lines)
  ctx.dialogue_show(char, text, pos, portrait)
  ctx.get_decor()              — 获取 DecorManager
  ctx.get_field_rect()         — 游戏区域 Rect2
  ctx.active()                 — 协程是否还在跑

❌ 禁止的:
  ctx.clock.wait(0) 或负数    — 用 return true（下帧立即调）
  协程内 await                — 会撕裂调度器
  直接写 GameState 属性        — 用方法
  直接调 BulletManager 方法   — 走 ctx
```

### 8.2 CoroutineRunner 子类约定
```
CreateScript:
  start_creating(ctx) → run(_on_step)
  职责: 敌人弹幕模式（持续发射）

MoveScript:
  start_moving(ctx, target) → run(_on_step)
  职责: 目标位置控制（Tween/直接）
  target: Node2D 引用
  覆写 stop() 时: if not is_running: return（防 run() 误触）

StageScript:
  start_stage(ctx) → run(_on_step)
  职责: 关卡脚本（出生波次、BGM、Boss 触发）
  finished 信号挂 StageManager._on_stage_finished

BackgroundScript:
  start_background(ctx) → run(_on_step)
  职责: 背景装饰物生成、相机动画
  _on_init(ctx) → 同步初始化（设置初始参数）
  注意: _on_init 时协程未启动，不要 await/clock.wait/clock.wait_frames

PlayerShootScript (CSPlayer):
  start_shooting(ctx) → run(_on_step)
  职责: 自机射击弹幕

EnemyScript:
  setup(enemy, ctx) → start() → run(_on_step)
  职责: 一文件包含外观、移动、弹幕
```

### 8.3 实体 API
```
Enemy:
  take_damage(int)  → 扣血, hp<=0 自动 die
  die()             → 清状态 + 特效 + emit + queue_free
  ⚠️ 不在外部调 die()（take_damage 自动处理）

Boss:
  take_damage(int)  → 扣血（invincible 时跳过）, hp<=0 自动清 phase
  current_phase()   → 返回当前 PhaseData
  current_bonus()   → 返回当前剩余奖励分
  begin_battle()    → 手动开始战斗
  start_boss(defer) → 注册并开始

Bullet:
  bind(data, dir, override)  → 池复用初始化
  ⚠️ 不在外部调 -- 池管理

Player:
  miss()            → 被弹处理
  ⚠️ miss() 不能 await（由碰撞回调同步调用）
  ⚠️ miss() 内无敌计时用 _invincible_timer 倒计时（_physics_process 自动减）

Item:
  setup(type, pos)  → 池复用初始化
  collect()         → 收集逻辑（内部调用，不外部触发）
  ⚠️ Item 不外部实例化，走 ItemPool.spawn()

ItemPool:
  spawn(pos, type)  → 生成 item（池复用优先，不限上限）
  recycle(item)     → 回收入池（内部调用，不外部触发）
  ⚠️ 不 queue_free，常驻 tree
```

### 8.4 禁止操作清单
```
❌ 任何脚本直接用 global randf() / randi()
❌ 任何脚本直接写 GameState.current_score / lives / power_raw
❌ 协程内使用 await
❌ 碰撞回调/物理回调内 await
❌ ctx.active()==false 时调用 StageContext 方法
❌ 直接 instantiate 子弹（走 BulletManager/BulletPool）
❌ Enemy/Boss.die() 外部调用
❌ 场景切换期间读 current_scene 子节点
❌ BackgroundScript._on_init 里用 clock.wait/clock.wait_frames
❌ MoveScript.stop() 中做业务逻辑（run() 内部会调 stop()）
❌ 直接修改 missing 子文件/资源的 .uid 文件（由 Godot 维护）
```

---

## 9. 状态机

### 9.1 GameManager.AppState
```
MENU ──→ PLAYING ──→ PAUSED
  ↑        │  ↑         │
  └────────┘  └─────────┘
      (ESC/返回)  (ESC 暂停/恢复)

TRANSITIONING = 短暂态, 场景切换时
```

### 9.2 代码中检查状态
```gdscript
# 只在游戏中跑的代码
if GameManager.current_state != GameManager.AppState.PLAYING:
    return
```

### 9.3 EnemyVisual 动画状态
```
IDLE ──speed>=30──────→ RIGHTING ──播完──→ RIGHT
  ↑                        │               │
  └──speed<30 持续 0.2s────┘───────────────┘
```

### 9.4 Player 动画状态
```
IDLE ──press L/R──→ LEFTING/RIGHTING ──播完──→ LEFT/RIGHT
  ↑                      │                        │
  └──release─────────────┘────────────────────────┘
```

### 9.5 Laser 状态
```
ALIVE ──出屏/超时──→ FADE ──0.15s──→ DEAD
```

### 9.6 敌人脚本（EnemyScript）一体化模式
EnemyScript 将外观 + 移动 + 弹幕放在一个文件里，通过 Timeline 组织。
```
extends EnemyScript
## 红杂鱼:向下减速 + 自机狙散射

var target_y: float = 300
var bullet_speed: int = 400
var bullet_count: int = 3
var bullet_spread: float = 0.2

func setup(_enemy: Enemy, _ctx: StageContext) -> void:
    super(_enemy, _ctx)
    # 外观
    enemy.add_child(AssetRegistry.enemy_visuals["s_red"].instantiate())
    # 移动
    enemy.create_tween().tween_property(enemy, "global_position",
        Vector2(enemy.global_position.x, target_y), 1.5)
    # 弹幕
    var bullet := BulletData.new().tex("小玉").color(Color.RED).enemy()
    bullet.velocity = Vector2(0, bullet_speed)

    var tl := start_timeline()
    tl.at(0.0).every(shoot_interval).do(func():
        var p := ctx.player.get_player()
        if not p: return
        var dir := (p.global_position - enemy.global_position).normalized()
        ctx.bullets.shoot_spread(bullet, bullet_count, bullet_spread, dir,
            enemy.global_position)
    )
    start()
```

---

## 10. 命名 & 文件公约

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

### 文件路径结构
```
scripts/
├── autoload/              # Autoload 层（GameState, AudioManager, ...）
│   ├── bullet/            # 子弹子模块（BulletPool, BulletPhysics, LaserSystem, DeathClear）
│   └── game/              # 游戏模块（SceneTransition, MenuNav）
├── background/            # 背景系统
├── bullet/                # 子弹实体（Bullet, CurvedLaser, BulletFog, BulletMultiMesh）
├── components/            # 组件（NumberSprite, UISeparator, RectOutline）
├── coroutine/             # 协程系统
│   ├── base/              # 基础类（CoroutineRunner, StageContext, Timeline, 各 Service）
│   └── player/            # 自机脚本（CSPlayer, CSReimu, CSMarisa, OptionFollow, ...）
├── data/                  # 数据 Resource 类
├── debug/                 # 调试工具
├── effect/                # 特效脚本
├── enemy/                 # 敌人实体
├── item/                  # Item 实体
├── player/                # Player 实体
└── scenes/                # 场景 UI 脚本

data/
├── dialogue/              # 对话资源
├── enemies/               # EnemyScript 脚本 + 基类
├── enemy_visual/          # 敌人视觉场景
├── laser_data/            # 激光配置 .tres
├── phase_data/            # PhaseData .tres
├── player_data/           # 角色数据 .tres
├── stages/                # 关卡资源
│   └── stage01/           # 第一面
│       ├── background/    # 背景场景+脚本
│       └── stage_data/    # StageData .tres（各难度）
│       └── stage_script/  # StageScript .gd
├── spell_records.tres     # 符卡记录持久化
├── stage_registry.tres    # 关卡注册表
└── spell_regidtry.tres    # (旧) 符卡注册表
```

---

## 11. 检查清单（新功能/修改前）

```
□ 随机数走了 RNG 吗？
□ GameState 修改走了方法吗？
□ 碰撞/物理回调里没有 await 吗？
□ 协程里没有 await 吗？
□ 新 node 挂到了正确的父节点吗（World / BulletManager / current_background）？
□ 新 StageContext 方法检查了 active() 吗？
□ MoveScript.stop() 里加了 `if not is_running: return` 吗？
□ 新 @export 写了注释吗？
□ 新功能需要考虑暂停时的行为吗？
□ 释放资源了吗（tween, timer, signal disconnect）？
□ Bullet fog 的信号连接在回收时正确断开吗？
□ Item 的 _dead 标志在所有回调入口检查了吗？
□ Boss phase 切换时 move/shoot 协程正确 stop+queue_free 了吗？
```

---

## 12. 差异对照：SPEC v1.1 → v1.2

| 项目 | v1.1 (旧) | v1.2 (新) |
|------|-----------|-----------|
| **入口** | StageAPI（独立类） | StageContext（含子 Service）+ Timeline |
| **敌人脚本** | CreateScript + MoveScript 分离 | EnemyScript 一体化（可选） |
| **子弹构造** | .tres 预加载 | BulletData 构造链 `.tex().speed().enemy()` |
| **菜单导航** | MenuStack + SubPageStack + PauseControl | MenuNav 统一栈（页面 + 覆盖层） |
| **Boss 数据** | StageData 挂 boss 数组 | Boss 由 StageScript Timeline 手动 spawn |
| **子弹池** | 简单池 | POOL_SIZE=4000, MAX_TOTAL=5000, 雾信号清理 |
| **CurvedLaser** | 简单激光 | 孔洞切割 + MultiSegment + 擦弹分域 |
| **练习模式** | 无 | is_practice_mode + is_stage_practice + 单 phase |
| **Miss 特效** | 无 | MissEffectManager（Shader 圆圈） |
| **Memory 系统** | 无 | 记忆值影响自机弹伤害倍率 + 擦弹消弹概率 |
| **Timeline** | 无 | 声明式替代 state machine |
| **Boss 练习掉落** | 练习也掉落 | 练习模式不掉落 |
| **SpellRecord** | 简单记录 | 含 practice 统计 + 多角色/多难度 |