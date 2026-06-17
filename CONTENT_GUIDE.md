# 🛠️ 东方星 STG 引擎 — 内容制作流程

> 版本：2026-06-17 · 基于菜单重构 + uid 架构

---

## 一、总体流程

```
创建资源文件 (.tres)          编写协程脚本 (.gd)
        ↓                            ↓
  PhaseData ─→ BossData       StageScript / CreateScript / MoveScript
                  ↓                            ↓
             StageData  ←──────────────────────┘
                  ↓
              挂到场景 (GameScene.tscn 的 stage_data)
                  ↓
              F1 生成符卡记录（调试用）
```

---

## 二、资源文件清单

| 步骤 | 文件类型 | 位置 | 说明 |
|------|----------|------|------|
| 1 | `PhaseData` | `data/phase_data/` | 单个 phase 的配置（符卡/非符） |
| 2 | `BossData` | `data/boss_data/` | 一个 Boss 的所有 phase 列表 |
| 3 | `StageData` | `data/stages/` | 一个关卡（含难度），绑定背景+Boss+脚本 |
| 4 | `StageScript` | `scripts/coroutine/stages/` | 关卡脚本（敌人波次/BGM 等） |
| 5 | `CreateScript` | `scripts/coroutine/examples/` | 敌机弹幕脚本 |
| 6 | `MoveScript` | `scripts/coroutine/stages/` | 敌机移动脚本 |

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
| `move_script` | Script | 移动脚本（Boss 移动模式） |
| `shoot_script` | Script | 弹幕脚本（`.gd` 文件，继承 CreateScript） |
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
shoot_script = preload("res://scripts/coroutine/examples/boss_ex_shoot.gd")
move_script = preload("res://scripts/coroutine/stages/move_patrol.gd")
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

## 六、协程脚本

### 6.1 StageScript（关卡脚本）

> 继承 `scripts/coroutine/base/stage_script.gd`

**职责**：控制关卡流程 — 生成敌人波次、播放 BGM、触发 Boss。

**核心 API**（通过 `StageAPI` 调用）：

```gdscript
# 等待：返回 >0 秒数或 true（下帧）
return api.seconds(2.0)
return true

# 生成敌人
api.spawn_enemy(data, pos)

# 发射弹幕
api.shoot_spread(bullet_data, count, angle, dir, pos)

# 获得玩家位置
var player = api.get_player()

# 检查是否清场
if api.all_defeated(): return false  # 结束关卡
```

### 6.2 CreateScript（弹幕脚本）

> 继承 `scripts/coroutine/base/create_script.gd`

**职责**：定义弹幕模式。在 PhaseData 的 `shoot_script` 里引用。

### 6.3 MoveScript（移动脚本）

> 继承 `scripts/coroutine/base/move_script.gd`

**职责**：控制敌机/Boss 的移动路径。在 EnemyData 或 PhaseData 的 `move_script` 里引用。

---

## 七、挂到游戏

1. 编辑器打开 `scenes/game_scene.tscn`
2. 在 Inspector 里把 `StageData` 资源拖到 `stage_data` 属性
3. 或者用 MainMenu → Start 流程（会在 CharacterScreen 后自动加载）

---

## 八、符卡练习

### 自动生成记录

1. 确保所有 StageData 文件已创建并填好 `bosses`
2. 进游戏 → 主菜单按 **F1**
3. Spell Practice 解锁，自动填充所有符卡

### 符卡记录规则

| 角色 | 存储 |
|------|------|
| 共用符卡 | 同一 uid，两个角色各存一条，独立统计 |
| 专属符卡 | 不同 uid，自然分开 |
| 非符 | uid=0，**不记入符卡簿**，仅练习模式可用 |

**运行时记录**：`boss.gd` 调用 `GameState.record_spell(uid=phase.uid)`。非符（uid=0）自动跳过。

---

## 九、菜单页面

### 已有的可复用模板

| 页面 | 基类 | 特点 |
|------|------|------|
| 难度/角色选择 | `NavPage` | 单列选项 + 渐显 + 脉冲 + 闪烁 |
| 符卡练习 | `BasePage` | 自定义三列布局 |
| 其他（Replay等） | `BasePage` | 标题贴图 + 黑底 + X 返回 |

### 添加新页面

1. 场景根节点 `type="Control"`，设置 `anchors_preset = 15`
2. 子节点：`Overlay`（ColorRect, 50%黑）+ `TitleTexture`（TextureRect）
3. 脚本继承 `BasePage` 或 `NavPage`
4. 在主菜单 `_on_item_selected` 里加 `_open_page("res://scenes/ui/xxx.tscn")`

---

## 十、常见问题

| 问题 | 解决 |
|------|------|
| 符卡练习显示"No records" | 按 F1 生成数据，或确保 StageData 有 `bosses` |
| uid 冲突 | 真符卡保证 uid 全局唯一（建议按关卡预留号段：1面 100-199, 2面 200-299...） |
| 非符在符卡练习里排列不对 | 排列跟随 `phases` 数组顺序，不依赖 uid 数字 |
| 不同难度符卡不同 | 各难度用不同 StageData 文件，各自引用不同 BossData |
