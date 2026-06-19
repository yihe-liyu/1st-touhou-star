# 🎨 内容创作管线 · 最终方案

> 基于提问的务实设计——不引入新资源类，不改变 Timeline 写法。

---

## 核心原则

- ✅ 保持 Timeline 写代码（你喜欢）
- ✅ 一个关卡 = 一个 stage 脚本
- ✅ 一个敌人 = 一个 EnemyData .tres + 难度脚本映射
- ✅ 不新建 WaveData / StageAsset 资源类

---

## 一、消灭复制粘贴

### 旧（3 个脚本）

```
stage01_easy.gd   ─┐
stage01_normal.gd  ├─ 除了 const ENEMY01 不同，其他一模一样
stage01_hard.gd   ─┘

enemy_easy01.tres    ─┐
enemy_normal01.tres   ├─ 除了 create_script 引用不同
enemy_hard01.tres    ─┘
```

### 新（1 + 1）

```
stage01.gd           ← 一个脚本管所有难度

enemy01.tres         ← 一个配置管所有难度
  ├── visual:  s_red.tscn
  ├── hp:      150
  ├── scripts: {
  │     0: { create: create_easy,   move: move01 },
  │     1: { create: create_normal, move: move01 },
  │     2: { create: create_hard,   move: move02 }
  │   }
  └── death_effect: death_effect.tscn
```

### stage 脚本示例

```gdscript
extends StageScript

const ENEMY01 = preload("res://data/stages/stage01/enemy/enemy01.tres")

func start_stage(p_ctx: StageContext):
    ctx = p_ctx
    var diff := GameState.selected_difficulty
    var tl := start_timeline()
    
    # 难度差异：波次数量
    var wave_counts := [6, 8, 12]
    var hp_mult := [0.7, 1.0, 1.5]
    
    tl.at(0.0).do(func():
        AudioManager.play_bgm(preload("res://assets/Music/..."), 0.0)
    )
    
    tl.at(1.0).every(0.5).times(wave_counts[diff]).do(func():
        var e := ctx.enemies.spawn_enemy(ENEMY01, Vector2(x, 0), false)
        e.move_script.target_y = 150 + i * 60
        e.start()
        x += 100; i += 1
    )
    
    # 只有 Hard 有额外敌波
    if diff >= 2:
        tl.at(5.0).every(0.3).times(6).do(func(): ...)
    
    super.start_stage(p_ctx)
```

**收益**：改波次 = 改 1 个文件。难度差异 = 数组/if。

---

## 二、EnemyData 脚本分离

### EnemyData 新字段

```gdscript
class_name EnemyData
extends Resource

@export var scripts: Dictionary = {}  # {0: {create: Script, move: Script}, 1: ...}
```

如果 `scripts` 非空，`spawn_enemy` 自动按难度选脚本。否则回退到旧 `create_script`/`move_script` 字段。

### 实现

```gdscript
# Enemy._apply_enemy_data
func _apply_enemy_data(data: EnemyData):
    var diff := GameState.selected_difficulty
    var s := data.scripts.get(diff, {})
    
    var create := s.get("create", data.create_script)
    var move := s.get("move", data.move_script)
    
    if create: ...
    if move: ...
```

**旧 `.tres` 不破坏**——没填 `scripts` 时走旧字段。

---

## 三、StageScript 辅助基类

不用建 `StageAsset`、`WaveData`，但加几个便捷方法：

```gdscript
class_name StageScript
extends CoroutineRunner

## 按难度取数组值
func diff_pick(arr: Array) -> Variant:
    return arr[GameState.selected_difficulty]

## 按难度取字典值（带默认）
func diff_get(dict: Dictionary, key: String, default = null):
    return dict.get(GameState.selected_difficulty, {}).get(key, default)
```

关卡里：

```gdscript
var counts := [6, 8, 12]
tl.at(1.0).every(0.5).times(diff_pick(counts))
```

---

## 四、弹幕和移动脚本的难度感知

### CreateScript 里访问难度

```gdscript
func start_creating(p_ctx: StageContext):
    ctx = p_ctx
    var diff := GameState.selected_difficulty
    var mult := [0.8, 1.0, 1.3][diff]
    
    tl.at(0.0).every(0.5).do(func():
        ctx.bullets.shoot_spread(BULLET, count, spread, dir, pos, SFX, mult)
    )
```

或者直接用 `EnemyData.scripts` 字典切换不同脚本——弹幕脚本本身不感知难度，选哪个脚本由 enemy .tres 决定。

---

## 五、实施清单

| # | 任务 | 工期 |
|---|------|------|
| 1 | `EnemyData.scripts` 字典字段 + `spawn_enemy` 按难度选脚本 | 30min |
| 2 | `StageScript.diff_pick()` / `diff_get()` 辅助方法 | 15min |
| 3 | 合并 `stage01_easy/normal/hard` → `stage01.gd` | 20min |
| 4 | 合并 `enemy_easy/normal/hard` → `enemy01.tres` + scripts 字典 | 15min |
| 5 | 删旧文件 | 5min |

---

## 六、不做

- ❌ WaveData / StageAsset 资源类
- ❌ 弹幕函数库
- ❌ .tres 表格替代 Timeline 代码
- ❌ 难度参数自动注入 CreateScript

**你说了 Timeline 代码写得爽，就保持。只解决复制粘贴。**

---

> ♥️ 轻量、务实、不引入新概念。开始？
