# 🛠️ 东方星 STG 引擎 — 内容制作流程

> 版本：2026-07-18 · v2.0 对齐 CoroutineScript 统一架构

---

## 一、总体流程

```
创建资源文件 (.tres)          编写协程脚本 (.gd)
        ↓                            ↓
  PhaseData ─→ BossData        CoroutineScript（统一脚本）
                  ↓                    ↓
             StageData  ←──────────────┘
                  ↓
          StageManager.load_stage()
                  ↓
             自动运行
```

> ⚠️ **v2.0 重要变更**：不再有 StageScript / CreateScript / MoveScript 之分，全部统一为 `CoroutineScript`。
> 用 `auto_stop` 控制行为（true=播完即止，false=持续运行），用 `target` 指定控制目标。

---

## 二、资源文件清单

| 步骤 | 文件类型 | 位置 | 说明 |
|------|----------|------|------|
| 1 | `PhaseData` | `data/phase_data/` | 单个 phase 的配置（符卡/非符） |
| 2 | `BossData` | `data/boss_data/` | 一个 Boss 的所有 phase 列表 |
| 3 | `StageData` | `data/stages/` | 一个关卡（含难度），绑定背景+Boss+脚本 |
| 4 | `StageScript` | `scripts/coroutine/` | 关卡脚本（敌人波次/BGM 等）— **也是 CoroutineScript** |
| 5 | 弹幕脚本 | `scripts/coroutine/` | 敌机弹幕逻辑 — **CoroutineScript, auto_stop=true** |
| 6 | 移动脚本 | `scripts/coroutine/` | 敌机/Boss 移动路径 — **CoroutineScript, auto_stop=true** |

---

## 三、PhaseData（符卡/非符配置）

**文件**：`scripts/data/phase_data.gd`

| 字段 | 类型 | 说明 |
|------|------|------|
| `name` | String | 符卡名（空串=非符，不显示） |
| `uid` | int | **全局唯一编号**，0=非符不记入符卡簿 |
| `hp` | int | 血量 |
| `time_limit` | float | 时限（秒） |
| `bonus` | int | 击破奖励分 |
| `move_script` | Script | 移动脚本（继承 CoroutineScript） |
| `shoot_script` | Script | 弹幕脚本（继承 CoroutineScript） |
| `item_power` | int | 击破掉落 P 点 |
| `item_point` | int | 击破掉落蓝点 |
| `item_life` / `item_bomb` | int | 碎片掉率 |
| `item_life_full` / `item_bomb_full` | int | 整残/Bomb 掉率 |

### 示例

创建 `data/phase_data/stage1_spell01.tres`：
```
PhaseData
name = "梦幻「幻想风穴」"
uid = 101
hp = 3000
time_limit = 60.0
bonus = 5000000
shoot_script = preload("res://scripts/coroutine/boss_ex_shoot.gd")
move_script = preload("res://scripts/coroutine/move_patrol.gd")
```

**uid 规则**：正数=真符卡，全局唯一。不同难度的同名符卡用不同 uid。非符 uid=0。

---

## 四、BossData（Boss 定义）

**文件**：`scripts/data/boss_data.gd`

| 字段 | 类型 | 说明 |
|------|------|------|
| `boss_name` | String | Boss 名称 |
| `visual` | PackedScene | Boss 视觉场景 |
| `phases` | Array[PhaseData] | Phase 列表（**顺序即战斗顺序**） |

### 示例

创建 `data/boss_data/stage1_boss.tres`：
```
BossData
boss_name = "琪露诺"
visual = preload("res://scenes/enemy_visual_test.tscn")
phases = [
  preload("res://data/phase_data/stage1_non01.tres"),   # 非符1
  preload("res://data/phase_data/stage1_spell01.tres"),  # 符卡1
  preload("res://data/phase_data/stage1_non02.tres"),   # 非符2
]
```

**注意**：phases 数组里的顺序决定战斗顺序，也决定符卡练习里的排列。

---

## 五、StageData（关卡定义）

**文件**：`scripts/data/stage_data.gd`

| 字段 | 类型 | 说明 |
|------|------|------|
| `stage_id` | int | 关卡编号（1=1面, 2=2面...） |
| `difficulty` | Difficulty | `EASY / NORMAL / HARD / LUNATIC / EXTRA` |
| `create_script` | Script | 关卡脚本（继承 StageScript） |
| `background_scene` | PackedScene | 背景场景（`.tscn`） |
| `bosses` | Array[BossData] | 本关卡所有 Boss（中 boss + 关底） |

### 命名建议

```
data/stages/
  stage1_easy.tres      ← stage_id=1, difficulty=EASY
  stage1_normal.tres    ← stage_id=1, difficulty=NORMAL
  stage1_hard.tres      ← stage_id=1, difficulty=HARD
  stage1_lunatic.tres   ← stage_id=1, difficulty=LUNATIC
  stage2_easy.tres      ← stage_id=2, difficulty=EASY
  ...
```

**每个难度一个文件**，不同难度可以有不同 boss_data、不同弹幕。

### 示例

```
StageData
stage_id = 1
difficulty = NORMAL
create_script = preload("res://scripts/coroutine/examples/test_wave.gd")
background_scene = preload("res://scenes/background/stage01_background.tscn")
bosses = [
  preload("res://data/boss_data/stage1_midboss.tres"),
  preload("res://data/boss_data/stage1_boss.tres"),
]
```

---

## 六、难度差分（Phase 编排 + UID 管理）

### 核心理念

不同难度的 Boss 战可能有**完全不同**的符卡编排，每张符卡有独立 UID：

```
Easy:    非符1
Normal:  非符1 → 符卡「？？？」(uid=101)
Hard:    非符1 → 符卡「更深」(uid=102)
Lunatic: 非符1 → 符卡「更深」(uid=102) → 符卡「最终」(uid=103)
```

关卡脚本里用 `diff_pick` 选择难度对应的 Phase 数组，`.tres` 文件跨难度复用：

```gdscript
// stage01.gd — 关卡脚本里
extends CoroutineScript

const PHASES = [
    [  # Easy
        preload("res://data/stages/stage01/phase/E_01.tres"),
    ],
    [  # Normal
        preload("res://data/stages/stage01/phase/E_01.tres"),
        preload("res://data/stages/stage01/phase/E_spell_01.tres"),   // uid=101
    ],
    [  # Hard
        preload("res://data/stages/stage01/phase/E_01.tres"),
        preload("res://data/stages/stage01/phase/E_spell_02.tres"),   // uid=102
    ],
    [  # Lunatic
        preload("res://data/stages/stage01/phase/E_01.tres"),
        preload("res://data/stages/stage01/phase/E_spell_02.tres"),   // uid=102
        preload("res://data/stages/stage01/phase/E_spell_03.tres"),   // uid=103
    ],
]

func start(p_ctx: StageContext, p_target: Node2D = null):
    ctx = p_ctx
    var kamorui = BossData.new().name("卡摩瑞").look(BOSS_POINT)
    for p in diff_pick(PHASES):
        kamorui.phase(p)
    
    var tl := start_timeline()
    tl.at(35).spawn_boss(kamorui, Vector2(448, 250))
    super.start(ctx, target)
```

### PhaseData 文件结构

```
data/stages/stage01/phase/
├── E_01.tres              ← 非符1，各难度共用
├── E_spell_01.tres         ← uid=101，Normal 专属
├── E_spell_02.tres         ← uid=102，Hard + Lunatic 共用
└── E_spell_03.tres         ← uid=103，Lunatic 专属
```

### UID 规则

| 规则 | 说明 |
|------|------|
| 全局唯一 | 同一张符卡在不同难度出现时 UID 相同 |
| 非符 = 0 | uid=0 不记入符卡簿 |
| 号段预留 | 建议 1 面 100-199, 2 面 200-299... |
| 角色无关 | 灵梦和魔理沙共用同一 UID，SpellRecordBook 主键自动区分 |

### diff_pick 的三种用途

| 用途 | 示例 |
|------|------|
| 选弹幕数量 | `diff_pick([10, 14, 20, 20])` — 子弹发数 |
| 选弹幕脚本 | `diff_pick(SCRIPTS)` — 完全不同逻辑时用 |
| **选 Phase 列表** | `diff_pick(PHASES)` — 不同符卡编排 |

三种可以混用！一个 Boss 的不同 Phase 之间互不影响。

### Boss 出场特效

```gdscript
// Timeline 中：defer=true 让 Boss 生成但不开始战斗
tl.at(34).do(func():
    MissEffectManager.add_circle(Vector2(448, 250), 2.0, 600, 60.0)
)
tl.at(35).do(func():
    var boss = StageManager.spawn_boss(kamorui, Vector2(448, -100), true, ctx)
    var tw := create_tween()
    tw.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
    tw.tween_property(boss, "global_position:y", 250, 2.0)
    tw.tween_callback(boss.begin_battle)  // 降落完毕 → 开战
)
```

> ⚠️ `defer=true` 时 Boss 无碰撞、无血条、子弹穿过、诱导不追踪。`begin_battle()` 后一切激活。

---

## 七、协程脚本（CoroutineScript 统一架构）

> ⭐ 所有协程脚本统一继承 `CoroutineScript`（`scripts/coroutine/base/coroutine_script.gd`）

### 核心概念

| 属性 | 类型 | 默认 | 说明 |
|------|------|------|------|
| `auto_stop` | bool | false | true=Timeline 播完自动结束；false=持续运行 |
| `target` | Node2D | null | 要控制的节点（敌人/Boss） |
| `_tl` | Timeline | null | 声明式时间线（start_timeline() 创建） |

### 返回值约定
```gdscript
return ctx.clock.wait(2.0)  # 等待 2 秒后再次调用
return true                  # 下物理帧立即再次调用
return false                 # 结束协程
```

### 7.1 关卡脚本

**职责**：控制关卡流程 — 生成敌人波次、播放 BGM、触发 Boss。

```gdscript
extends CoroutineScript

func _tick(ctx: StageContext):
    if not _tl: _tl = start_timeline()
    return _tl.tick(get_physics_process_delta_time())
```

**核心 API**（通过 `StageContext` 调用）：

```gdscript
ctx.clock.wait(2.0)                              # 等待
ctx.bullets.shoot_spread(data, count, spread, dir, pos)  # 扇形弹幕
ctx.player.get_position()                         # 自机位置
ctx.audio.play_bgm(stream)                        # 播放 BGM
ctx.play_dialogue(lines)                          # 对话
```

### 7.2 弹幕脚本

**职责**：定义弹幕模式。在 PhaseData 的 `shoot_script` 里引用。

```gdscript
extends CoroutineScript

func _tick(ctx: StageContext):
    ctx.bullets.shoot_spread(bullet, 3, 0.3, Vector2.DOWN, target.global_position)
    return ctx.clock.wait(0.5)
```

### 7.3 移动脚本

**职责**：控制敌机/Boss 的移动路径。

```gdscript
extends CoroutineScript

var target_y: float = 300

func _tick(ctx: StageContext):
    target.global_position.y = move_toward(target.global_position.y, target_y, 100 * get_physics_process_delta_time())
    return abs(target.global_position.y - target_y) < 1
```

### 7.4 使用 Timeline

```gdscript
func _tick(ctx: StageContext):
    if not _tl:
        _tl = start_timeline()
        _tl.at(0.0).do(func(): ctx.audio.play_bgm(bgm))
        _tl.at(1.0).every(0.5).times(6).spawn_wave(bullet, 3, 0.3, Vector2.DOWN, pos)
        _tl.at(10.0).spawn_boss(boss_data, pos)
    return _tl.tick(get_physics_process_delta_time())
```

---

## 八、挂到游戏

关卡通过 `StageManager.load_stage(data)` 加载。流程：

1. MainMenu → Start → 选难度 → 选角色 → `GameManager.change_scene("game_scene")`
2. `GameScene._ready()` → `_resolve_stage_data()` → `StageManager.load_stage(data)`
3. 练习模式：从 CardDef 构建单 phase Boss，走 `_start_practice_game()`

---

## 九、符卡练习

### 自动生成记录

1. 确保所有 StageData 文件已创建并填好 `bosses`
2. 进游戏 → Spell Practice 自动从 StageRegistry 加载

### 符卡记录规则

| 角色 | 存储 |
|------|------|
| 共用符卡 | 同一 uid，两个角色各存一条，独立统计 |
| 专属符卡 | 不同 uid，自然分开 |
| 非符 | uid=0，**不记入符卡簿**，仅练习模式可用 |

**运行时记录**：`boss.gd` 调用 `GameState.record_spell()` / `unlock_spell()`。非符（uid=0）自动跳过。

---

## 十、菜单页面

### 基类体系

```
BasePage          — 生命周期 + 遮罩淡入淡出 + 内容滑入
  └── NavPage     — 垂直选项列表 + 脉冲高亮 + 导航
        ├── MainMenu
        ├── PauseMenu / GameOverMenu
        ├── DifficultyScreen（水平滑动，自定义着色器）
        └── CharacterScreen
```

### 可复用方法（BasePage 提供）

| 方法 | 说明 |
|------|------|
| `_on_enter()` | 入场（首次被 push） |
| `_on_leave()` | 退场（被 pop），播放退场动画后 queue_free |
| `_fade_overlay_in(dur)` | 暗色遮罩淡入 |
| `_fade_overlay_out(dur)` | 暗色遮罩淡出（返回 Tween 可接 callback） |
| `_fade_content_in(ctrl, dur, slide)` | 内容从右侧滑入 + 淡入 |
| `_fade_all_out(ctrl, dur)` | 内容 + 遮罩一起淡出 |
| `go_back()` | 触发 back 信号（返回上一页） |
| `done(result)` | 触发 finished 信号（确认选择） |

### 添加新页面

1. 场景根节点 `type="Control"`，设置 `anchors_preset = 15`
2. 子节点：`Overlay`（ColorRect, 50%黑）+ `TitleTexture`（TextureRect）
3. 脚本继承 `BasePage` 或 `NavPage`
4. 在主菜单 `_on_item_selected` 里加 `_open_page("res://scenes/ui/xxx.tscn")`

### 自定义视觉的菜单

如果菜单布局和 NavPage 默认行为差异很大（如水平滑动、shader 着色），可以直接继承 `BasePage`，自己管理选项列表和动画。参考 `DifficultyScreen`。

> 🔮 **未来改进**：考虑抽 `MenuLogic`（纯导航逻辑）与视觉呈现分离，让 `NavPage` 和 `DifficultyScreen` 等自定义菜单共享同一套选项管理逻辑。详见 `ARCHITECTURE_ROADMAP.md`。

---

## 十一、对话系统

### 对话数据

- `CharacterProfile`：角色名 + 立绘
- `DialogueLine`：包含多个 `DialogueBubble`
- `DialogueBubble`：说话者 + 文字 + 立绘位置 + 表情

### 在关卡中使用

```gdscript
# Timeline 中
ctx.play_dialogue(data.lines)

# 或协程中
ctx.dialogue_show("灵梦", "这是测试文本", Vector2(100, 200))
```

### 自定义气泡样式

气泡渲染由独立的 `BubblePanel`（`scripts/scenes/bubble_panel.gd`）负责。支持：
- `[shake=N]` — 气泡抖动 N 秒
- BBCode 颜色 — `[color=red]文字[/color]`

扩展气泡效果（逐字打印、尾巴三角形等）只需修改 `bubble_panel.gd`，不影响对话流程。

---

## 十二、常见问题

| 问题 | 解决 |
|------|------|
| 符卡练习显示"No records" | 确保 StageRegistry 已加载，StageData 有 `bosses` |
| uid 冲突 | 真符卡保证 uid 全局唯一（建议按关卡预留号段：1面 100-199, 2面 200-299...） |
| 非符在符卡练习里排列不对 | 排列跟随 `phases` 数组顺序，不依赖 uid 数字 |
| 不同难度符卡不同 | 各难度用不同 StageData 文件，各自引用不同 BossData |
| 对话气泡想加新效果 | 改 `scripts/scenes/bubble_panel.gd`，不要动 `dialogue_box.gd` |
| 菜单加新页面怎么写动画 | 继承 BasePage/NavPage，用 `_fade_overlay_in/out` 等现成方法 |

## 自机子弹击中特效（数据驱动，零代码）

所有自机击中特效共用**一个脚本** `scripts/effect/player_bullet_hit_effect.gd`。
新增特效只需做资源，不用写代码：

**步骤**（以新增"灵梦新星爆"为例）：
1. 复制 `scenes/effect/hit_effect_reimu_option02.tscn` → 改名
2. 改贴图 / AtlasTexture region（或换成你的动画 SpriteFrames）
3. 在 Inspector 里调参数：
   - `speed`   飞散速度（px/s，默认 300）
   - `fade_time` 淡出时长（秒，默认 0.3）
   - `jitter`  飞散方向随机抖动（弧度，默认 0）
4. 保存即生效！（节点结构自动识别：有 `AnimatedSprite2D` = 动画版，有 `Sprite2D` = 单帧淡出版）

**贴图位置参考**：`assets/Textures/player/pl01.png`（命中特效区在 y≈143~224 行）。

**接线**：在射击脚本里 `b.hit_effect = preload("res://scenes/effect/你的特效.tscn")`。
