# 🎮 全系统图景 v3

> 2026-06-20 · 敌人/Bullet/EnemyData 全消计划

---

## 一、资源层（只剩这些文件）

```
AssetRegistry (autoload)
  ├── enemy_visuals    {"s_red": .tscn, "death": .tscn}
  ├── bullet_textures  {"小玉": .png, "点弹": .png, ...}
  ├── sounds           {"shoot": .wav, "item": .wav, ...}
  ├── ui_textures      {"logo": .png}
  └── patterns         {"aimed": .gd, "move_down": .gd}

patterns/               ← 通用弹幕/移动模板，参数化
  ├── aimed_burst.gd    (count, spread, interval, bullet配置)
  ├── move_down.gd      (target_y, duration)
  └── ...               (circle.gd, move_patrol.gd, etc.)

BossData / PhaseData    ← 保留 .tres（太复杂，不适合字典）
StageData               ← 保留 .tres（关卡注册用）
DecorLayer              ← 保留 .tres（背景装饰）
```

## 二、运行时层

```
StageContext
  ├── bullets:  BulletService    → shoot_spread(cfg, count, spread, dir, pos, sfx)
  │                                  cfg = {tex: "小玉", speed: 400, color: RED}
  │
  ├── enemies:  EnemyService     → spawn(visual, move_cfg, shoot_cfg, pos, opts)
  │                                  spawn_boss(boss_data, pos)
  │
  ├── decor:    DecorManager     → add_layer / batch_spawn
  ├── clock:    ClockService     → wait / frames
  ├── player:   PlayerService   → position
  ├── dialogue: DialogueService  → play / show
  └── items:    ItemService      → spawn

EnemyFactory                       ← 纯工具类，不存状态
  ├── make_bullet(cfg)            → 造子弹配置
  ├── make_move(cfg)              → new + 设字段 + start
  ├── make_shoot(cfg)             → new + 设字段 + start
  └── assemble(v, m, s, pos, opts) → 拼 Enemy 节点
```

## 三、关卡脚本

```gdscript
extends StageScript

func start_stage(ctx):
    var tl := start_timeline()
    
    # —— 没有 const preload ——
    # —— 没有 enemy .tres ——
    # —— 没有 bullet .tres ——
    
    var bgm  := AssetRegistry.sounds["bgm1"]
    var logo := AssetRegistry.ui_textures["logo"]
    var vis  := AssetRegistry.enemy_visuals["s_red"]
    var tex  := AssetRegistry.bullet_textures["小玉"]
    
    var bullet_cfg := { tex: tex, speed: 400, color: Color.RED }
    var move_cfg   := { type: "move_down", target_y: 300, duration: 1.5 }
    var shoot_cfg  := { type: "aimed", bullet: bullet_cfg, count: 3, spread: 15, every: 0.8, sfx: "shoot" }
    
    tl.at(0.0).do(func(): AudioManager.play_bgm(bgm, 0.0))
    
    tl.at(1.0).every(0.5).times(diff_pick([6, 8, 12])).do(func():
        ctx.enemies.spawn(vis, move_cfg, shoot_cfg, Vector2(x, 0))
    )
```

## 四、删掉的

| 文件类型 | 数量 | 替换 |
|----------|------|------|
| `enemy*.tres` | 全部 | `{visual, hp, drop}` 字典 |
| `bullet*.tres` | 全部 | `{tex, speed, color}` 字典 |
| `enemy_*01.gd` (CreateScript) | 全部 | `patterns/aimed_burst.gd` + 字典参数 |
| `enemy_*01.gd` (MoveScript) | 全部 | `patterns/move_down.gd` + 字典参数 |

## 五、不改的

```
BossData / PhaseData  ← .tres（对话、多阶段、背景切换太复杂）
StageData             ← .tres（stage_registry 用）
DecorLayer            ← .tres（背景装饰配置）
Timeline              ← 核心引擎
协程系统               ← 核心引擎
```

---

> 核心思想：**杂鱼 = 字典 + patterns。Boss = .tres。**
