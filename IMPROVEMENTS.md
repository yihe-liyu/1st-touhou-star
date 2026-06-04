# 东方星 STG — 架构改进规划

> 本文档描述项目当前架构的改进方向，供后续开发时参考。
> 每个改进项包含：现状分析、建议方案、预计工作量。

---

## P0 — 必须尽快修

### 1. `GameState` 缺少统一重置方法

**现状**：`reset_score()` 只重置 `current_score` 和 `graze_count`，后来新增的
`lives`、`life_fragments`、`bomb_count`、`bomb_fragments`、`memory_value`、
`power_raw` 都没有重置。Retry 关卡后状态污染。

**建议**：
```gdscript
func reset_all():
    current_score = 0
    graze_count = 0
    power_raw = 0
    memory_value = 50.0
    lives = 2
    life_fragments = 0
    bomb_count = 3
    bomb_fragments = 0
```
在 `StageManager.load_stage` 里替换掉现有的 `reset_score()` 调用。

**文件**：`scripts/autoload/game_state.gd`、`scripts/autoload/stage_manager.gd`

---

## P1 — 下一阶段开发前重构

### 2. `BulletManager` 拆分（~400 行 → 4 个文件）

**现状**：`BulletManager` 包含子弹池管理、碰撞检测分流、激光步进、死亡清弹、擦弹判定、音效触发、击中特效生成。

**建议**：拆成以下模块，`BulletManager` 只做路由：

| 新文件 | 职责 |
|--------|------|
| `scripts/autoload/bullet_pool.gd` | `shoot_bullet`、`return_bullet`、池扩容 |
| `scripts/autoload/bullet_collision.gd` | `_resolve_collisions`、`_player_bullet_vs_enemies` 等 |
| `scripts/autoload/laser_system.gd` | `fire_laser`、`_step_lasers`、`clear_all_lasers` |
| `scripts/autoload/death_clear.gd` | `start_death_clear`、`_process_death_clears`、`_cut_laser` |

`BulletManager` 保留为 autoload，持有以上模块的实例，对外提供统一 API。

**注意**：此重构不改变外部调用接口，只内部拆分。

### 3. 玩家射击脚本去重

**现状**：`cs_reimu.gd` 和 `cs_marisa.gd` 各约 60 行，但 `_on_step` 里的
`match _phase: 0: run_parallel(...); 1: sync_options + return true`
和 `_main_step`、`_option_step` 的结构几乎一样。

**建议**：在基类 `PlayerShootScript` 里抽取：
```gdscript
# 子类只需覆写这些方法
func _get_main_bullet_data() -> BulletData: ...
func _get_option_bullet_data(focused: bool) -> BulletData: ...
func _get_option_info(power: int, focused: bool) -> OptionInfo: ...

# OptionInfo 在基类定义为：
class OptionInfo:
    var offsets: Array[Vector2]
    var visual_script: Script
```

这样加第三个角色（咲夜？早苗？）只需 ~30 行。

**文件**：
- `scripts/coroutine/player/base/cs_player.gd`（重构基类）
- `scripts/coroutine/player/cs_reimu.gd`（简化为 ~30 行）
- `scripts/coroutine/player/cs_marisa.gd`（简化为 ~30 行）

---

## P2 — 开始做真关卡时

### 4. `BulletPattern` 弹幕模式组合系统

**现状**：`test_create.gd`、`test_fancy_curve.gd`、`test_laser.gd` 是手写的单次弹幕模式。做真 Boss 战时需要几十种弹幕组合。

**建议**：抽象出可复用的弹幕模式类：
```gdscript
class_name BulletPattern extends RefCounted
## 发射一次弹幕并返回下次执行的时间

func execute(api: StageAPI, origin: Node2D) -> float:
    # 返回 seconds to next fire
    return 1.0
```

子类示例：
- `CirclePattern` — 圆形弹幕（角度步进、子弹数、速度）
- `AimPattern` — 自机狙（每 N 帧发射一发）
- `WavePattern` — 波浪弹幕（角度偏移 + 三角函数）
- `LaserPattern` — 激光阵列

在 CreateScript 里组合：
```gdscript
var _phases: Array[BulletPattern] = [
    CirclePattern.new(count=32, speed=200, interval=1.5),
    AimPattern.new(interval=0.3),
    WavePattern.new(count=8, amplitude=30),
]
```

**文件**：新建 `scripts/patterns/` 目录

### 5. `GameManager` 职责拆分

**现状**：`GameManager` 兼顾状态机、场景切换、黑场过渡、菜单栈、暂停控制。

**建议**：拆成 3 个独立 autoload 或内部模块：

| 模块 | 职责 |
|------|------|
| `SceneTransition` | `change_scene`、`_fade_out/in`、`reload_current_scene` |
| `MenuStack` | `push_menu`、`pop_menu`、`push_overlay_menu` |
| `PauseControl` | `pause_game`、`resume_game`、`_cleanup_pause` |

`GameManager` 保留为顶层门面，持有以上实例。

**文件**：
- `scripts/autoload/scene_transition.gd`（新建）
- `scripts/autoload/menu_stack.gd`（新建）
- `scripts/autoload/game_manager.gd`（精简）

---

## P3 — 锦上添花

### 6. 关卡数据运行时校验

**现状**：`StageData.create_script` 是 `Script` 类型，编辑器可能拖入非协程脚本。

**建议**：在 `StageManager.load_stage` 开头：
```gdscript
assert(stage_script is StageScript, "create_script must be a StageScript")
```

对 `EnemyData.visual_scene`、`EnemyData.create_script`、`BulletData.movement_script` 同样处理。

### 7. 菜单选项注入式配置

**现状**：`PauseMenu._on_item_selected` 是硬编码的 `match index: 0: ... 1: ... 2: ...`。

**建议**：给 `BaseMenu` 加：
```gdscript
@export var item_configs: Array[Dictionary] = []
# [{text: "Resume", callback: "_on_resume"}, ...]
```
`_collect_items` 时自动创建 Label 并绑定回调。这样不用继承就能配菜单。

### 8. `AudioManager` 交叉淡入淡出

**现状**：`play_bgm` 通过 `stop → await gap → play` 切换，中间有空白。

**建议**：加 `crossfade_bgm(new_stream, duration)`，用两个 AudioStreamPlayer 做交叉淡入：
```gdscript
func crossfade_bgm(new_stream: AudioStream, duration: float = 0.5):
    var old_player = _bgm_player
    var new_player = _get_free_bgm_player()
    new_player.stream = new_stream
    new_player.volume_db = -80
    new_player.play()
    # tween old.volume_db → -80, new.volume_db → 0, 同时进行
```

### 9. `Enemy.bullet_manager` 直接引用 `get_node` 改为 `@onready`

`debug_drawer.gd` 里：
```gdscript
@onready var bullet_manager = get_node_or_null("/root/BulletManager")
```
这种写法在 `DebugDrawer` 里是合理的（可选功能）。但 `StageAPI` 里 `BulletManager.shoot_enemy_bullet` 直接引用全局——作为 autoload API 这是正确的。

不过更好的做法是用 `%BulletManager`（唯一名称访问）代替 `/root/BulletManager`（路径访问），节点改名不会断裂。

### 10. 弹幕命中特效去 Static

四个命中特效脚本 `player_bullet_hit_effect01.gd`、`player_bullet_hit_effect02.gd`、`player_main_bullet_hit_effect.gd` 各自独立实现，但 `set_tint`、`set_velocity` 的接口相同。

**建议**：提取一个 `HitEffect` 基类：
```gdscript
class_name HitEffect extends Node2D
func set_velocity(vel: Vector2): pass
func set_tint(color: Color): pass
```
三个特效脚本继承它，`_spawn_hit_effect` 里 `as HitEffect` 即可。

---

## 💡 长期方向（不紧急）

- **Replay 系统** — 记录每帧的 `RNG.seed` + 玩家输入，可回放
- **Spell Card 框架** — Boss 多阶段 + 血量条 + 动态难度
- **道具掉落系统** — Power Item、Point Item、残机碎片、Bomb 碎片
- **关卡编辑器** — 可视化编排弹幕模式的工具
- **单元测试** — 用 GDScript 的 `assert` 做协程调度器和碰撞检测的回归测试
