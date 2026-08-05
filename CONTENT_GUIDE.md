# 🛠️ 东方星 STG 引擎 — 内容制作流程

> 版本：2026-08 · 协程代码版（关卡/Boss/弹幕全在 Godot 里写代码；工作台只做预览/调试）

---

## 0. 快速上手（加一个弹幕波次 / 一张符卡）

1. 在 Godot 编辑器里打开 `data/stages/stage01/stage_script/stage01.gd`（Timeline 编排）
2. 加 `tl.at(时刻).do(func(): EnemyData.new().with_script(...).pos(...).spawn(ctx))`
   或给 Boss 加阶段（`BossData.new().phase(...)` + `tl.phase(...)` 阶段链）
3. F6 运行工作台 → 命中框/固定种子/逐帧看效果；改完代码**重启工作台**生效
4. 弹幕脚本（`data/boss_scripts/`）改完同样重启工作台看

> 工作台**不是编辑器**：不写数据、不热重载，是「跑真实代码看效果」的预览沙盒。
> 数据（关卡/Boss/阶段）全部以代码 + .tres 形式存在，由 AI/人直接写。

---

## 一、总体架构

```
① 关卡编排：stage01.gd（Timeline API，代码声明节奏/Boss/阶段）
② 行为层：  协程脚本 .gd（敌人行为 + Boss 移动/弹幕/入场/退场）
③ 数据层：  .tres 资源（BossData/PhaseData/敌人预设/CardDef）
④ 预览层：  工作台 = 真实运行时沙盒（幽灵玩家 + 命中框 + 固定种子 + 书签）
```

数据关卡（wave_stage/StageTimeline/波次表）与脚本页/编排页已**移除**（2026-08 决策）：
弹幕的核心是逻辑不是数据，代码直写 + 工作台预览是当前唯一流程。

---

## 二、关卡编排（stage01.gd，Timeline API）

位置：`data/stages/stage01/stage_script/stage01.gd`（`extends CoroutineScript`）

```gdscript
const ENEMY01 = preload("res://data/stages/stage01/coroutine_script/enemy01.gd")
const NON_01  = preload("res://data/stages/stage01/phase/non_01.tres")
const TEST_01 = preload("res://data/stages/stage01/phase/test_01.tres")

func start(p_ctx: StageContext, p_target: Node2D = null):
	ctx = p_ctx
	var tl := start_timeline()
	tl.at(0.0).play_bgm(...)
	tl.at(1.0).do(func(): EnemyData.new().with_script(ENEMY01)...
		.pos(Vector2(...)).red_little_fairy().param("target_y", 200).spawn(ctx))
	# Boss + 阶段链（phase 击破后 Timeline 冻结 → 击破继续 → 激活下一个 wait 事件）
	tl.at(35.0).do(func(): boss_holder[0] = StageManager.spawn_boss(kamorui, ...))
	tl.at(38.0).phase(func(): return boss_holder[0], NON_01)
	tl.wait(1.0).phase(func(): return boss_holder[0], TEST_01)   # 非符1 击破后 1s 进测试
	tl.wait(2.0).do(func(): 退场)
	super.start(ctx, target)
```

Timeline 链式 API：`at(t)` 绝对时刻 · `wait(n)` 相对上一 blocking 结束 · `do(cb)` 任意逻辑 ·
`phase(getter, PhaseData)` 起阶段并冻结直到击破 · `every(times)` 重复 · `play_bgm/spawn_enemy/spawn_boss` 快捷。

> ⚠️ phase 链注意：`wait()` 后接 `phase()` 必须直接链（`tl.wait(1.0).phase(...)`），
> 中间插 `do(pass)` 会破坏 wait 偏移继承（阶段会立即触发）。

---

## 三、敌人

### 敌人数据（构造链硬编码）

`EnemyData` 提供构造链：`red_little_fairy() / blue_middle_fairy() / red_middle_fairy() / ...`
（外观/血量/判定/掉落直接写死，`enemy_presets/*.tres` 已移除——数据即代码）。

### 行为脚本

位置：`data/stages/stage01/coroutine_script/`（enemy01/02、fly_away 等）。
**直接引用**：关卡脚本 `preload()` 敌人行为，`EnemyData.new().with_script(ENEMY01)...` 构建——
无注册表、无中间层（EnemyTemplateRegistry/BossScriptRegistry 已随编辑器移除，2026-08）。

---

## 四、Boss（阶段数据 + 脚本目录）

### BossData / PhaseData（.tres）

- `BossData`（`data/stages/stage01/phase/` 参照）：`boss_name` / `visual` / `phases`（Normal 组）/ `phases_easy/hard/lunatic` / `enter_script` / `exit_script` / `score_value`
- `PhaseData`：`name`（空串 = 非符）、`uid`（0 = 非符不记）、`hp` / `time_limit` / `bonus`、`is_timeout_only`、`move_script` / `shoot_script`、掉落 item 系列、`params`

阶段示例（`data/stages/stage01/phase/test_01.tres`）：
```gdscript
[gd_resource type="Resource" script_class="PhaseData" format=3]
...
name = "测试"
uid = 105
time_limit = 90.0
hp = 3001
move_script = ExtResource("...test_move.gd")
shoot_script = ExtResource("...orbit_spiral.gd")
```

### Boss 脚本（目录自动发现）

```
data/boss_scripts/move/   移动脚本（test_move.gd：随机跳场）
data/boss_scripts/shoot/  弹幕脚本（orbit_spiral.gd：环绕发射器 + 探测弹）
data/boss_scripts/enter/  入场
data/boss_scripts/exit/   退场
data/boss_scripts/bullet/ 弹丸行为（探测弹 orbit_probe.gd 等）
```

**加新 Boss 脚本 = 写 .gd 扔进对应目录，文件名即显示名，零注册。**
旧位置：`data/stages/stage01/coroutine_script/boss/`（non_01_move/shoot/bullet）。

---

## 五、难度差分

- **Boss 阶段**：`BossData` 四组 phases（E/N/H/L），协程脚本里 `diff_pick()` 按难度取
- **敌人强度**：行为脚本内 `diff_pick([1, 3, 5, 8])` 运行时取参
- **UID 规则**：真符卡全局唯一（建议 1 面 100-199、2 面 200-299…）；非符 uid=0；角色共用 UID，SpellRecordBook 主键区分

---

## 六、脚本层约定

> 全部继承 `CoroutineScript`（`scripts/coroutine/base/coroutine_script.gd`）。

### 协程返回值约定

```gdscript
return ctx.clock.wait(2.0)  # 等待 2 秒后再次调用
return true                  # 下物理帧立即再次调用
return false                 # 结束协程
```

### 脚本文件地图

```
敌人行为   data/enemy_scripts/   enemy01.gd / enemy02.gd / fly_away.gd（关卡脚本 preload 即用）
Boss 脚本   data/boss_scripts/    move/ shoot/ enter/ exit/（目录即约定，零注册）
弹丸行为   data/bullet_scripts/   gravity_bullet.gd / non_01_bullet.gd / orbit_probe.gd
关卡专属   data/stages/stage01/    stage_script(stage01.gd) + phase/ + stage_data/ + background/
```

### 行为脚本示例

```gdscript
extends CoroutineScript
## 红杂鱼: 向下减速 + 自机狙 + 散射

var target_y: float = 300
var heavy_wave: bool = true
var rate: int = 1

func _ready() -> void:
	call_deferred("_init_enemy")

func _init_enemy() -> void:
	var parent := get_parent()
	# 移动 tween + 发弹（ctx.bullets.shoot_spread / ctx.clock.wait / tl.at ...）
```

---

## 七、调试（工作台工具链）

| 工具 | 用法 |
|------|------|
| 固定种子 | 播放区开关：重跑弹幕序列可复现（调参必备） |
| 命中框 | 播放区开关：红=敌弹判定、绿=敌人、青=自机、蓝=擦弹 |
| 逐帧 | 暂停中按 F：精确走 1/60s |
| 跳转 | 点时间轴/书签/←→ = 12x 快进到目标（真实关卡无任意 seek） |
| 书签 | 时间轴右键/快捷键 B 打点；协程关卡静态提取 tl.at() 时刻 + 人工打点 |
| 幽灵玩家 | 自机狙目标（不攻击，看弹幕用） |

快捷键：`Space` 暂停/继续 · `R` 重跑 · `F` 逐帧 · `1~7` 速度 · `←/→` ±1s（Ctrl ±5s）·
`B` 书签 · `Home` 回开头

> 改代码后**重启工作台**生效（无热重载）。写代码在 Godot 编辑器，看效果在工作台。

---

## 八、挂到游戏

1. MainMenu → Start → 选难度 → 选角色 → `GameManager.change_scene("game_scene")`
2. `GameScene._ready()` → `_resolve_stage_data()` → `StageManager.load_stage(data)`
   （`data/registry/stage_registry.tres`：Stage 1 → `stage01.tres` 协程版）
3. 练习模式：从 CardDef 构建单 phase Boss，走 `_start_practice_game()`

---

## 九、符卡练习 / 菜单 / 对话

- **符卡簿**：`data/registry/spell_records.tres`，见到即记（unlock_spell），自动按 UID 记录尝试/捕获/最佳
- **符卡练习（双驱动）**：练习菜单 = 符卡簿记录（自动）决定"能练哪张" + `data/registry/spell_registry.tres`（CardDef）提供战斗配置。CardDef 手写 .tres 或由代码/脚本生成（工作台「注册练习」按钮已随编排页移除）
- **菜单页**：`scenes/ui/*_menu.tscn` 继承 BasePage（`scripts/autoload/game/menu_nav.gd` 导航）
- **对话**：`data/dialogue/` .tres（lines 数组）；关卡里 `tl.at(t).dialogue(...)` 触发

---

## 十、已知边界

- 运行时保存 .tres 依赖 res:// 可写（开发模式）；导出包只读，符卡簿保存会失败（待数据迁移方案）
- **弹丸协程脚本**（gravity_bullet.gd 等，被行为脚本 preload）与所有脚本改动都需**重启工作台**生效
- 敌人/Boss 脚本零注册：preload/直接引用即用
