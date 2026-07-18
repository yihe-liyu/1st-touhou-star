# 🎮 全系统图景 v3

> 2026-06-21 · 代码打磨全部完成 · SPEC v1.2 已对齐

---

## 核心设计

**所有协程脚本 = CoroutineScript（auto_stop + target 参数化）。Boss = .tres。**

---

## 资源层

```
AssetRegistry (autoload) — 所有资源中心注册
├── enemy_visuals          {"s_red": .tscn, "death": .tscn}
├── bullet_configs         {"小玉": {tex, hitbox}, ...}
├── sounds                 {"shoot": .wav, "item": .wav, ...}
├── ui_textures            {"logo1": .png}
└── enemies                {"red_soldier": .gd}

BossData / PhaseData       ← .tres
StageData                  ← .tres
DecorLayer                 ← .tres
CardDef / CardRegistry     ← .tres（练习模式）
```

## 运行时层

```
StageContext — 协程唯一入口
├── clock      ClockService     → wait / wait_frames
├── bullets    BulletService   → shoot_spread / fire_*_laser
├── enemies    EnemyService    → spawn / spawn_boss / all_defeated
├── player     PlayerService   → get_player / get_position
├── dialogue   DialogueService → play / show
├── items      ItemService     → spawn
├── audio      AudioService    → play_bgm / play_sfx / stop_bgm
└── decor      DecorManager    → add_layer / spawn / batch_spawn
```

## 关卡脚本风格

```gdscript
extends CoroutineScript

func start(ctx, target = null):
    var tl := start_timeline()
    tl.at(0.0).do(func(): ctx.audio.play_bgm(bgm))
    tl.at(1.0).every(0.5).times(6).do(func():
        ctx.enemies.spawn("red_soldier", pos, {target_y: 200})
    )
```

## 架构变更记录

| 变更 | 状态 |
|------|------|
| SPEC.md v2.0（系统规格文档化）| ✅ |
| `StageAPI` → `StageContext`（含 8 个 Service）| ✅ |
| `CoroutineScript` 统一协程脚本（替代 5 个基类）| ✅ |
| `BulletData` 构造链 `.tex().speed().enemy()` | ✅ |
| `Laser` 激光系统（3 种模式 + 贴图 + 碰撞 + 擦弹）| ✅ |
| `CardDef`/`CardRegistry`/`PhaseIdentity` 符卡系统 | ✅ |
| `MenuNav` 统一菜单导航 | ✅ |
| `MissEffectManager` / Memory 值系统 | ✅ |
| 子弹池 POOL_SIZE=4000 | ✅ |
| 练习模式（符卡/关卡）| ✅ |
| 代码风格规则（snake_case / class_name / 注释约定）| ✅ |
| 目录整理（coroutine 拆 services+timeline / data/registry/）| ✅ |
| 废弃代码清理（9 文件删除 + 1 改名）| ✅ |
| `BubblePanel` 从 `dialogue_box.gd` 分离为独立文件 | ✅ |
| 文档更新（CONTENT_GUIDE v2.0 对齐 CoroutineScript 架构）| ✅ |

### 🔮 计划中的架构改进

| 改进 | 优先级 | 说明 |
|------|--------|------|
| **MenuLogic 拆分** | 中 | NavPage 中「导航逻辑」与「视觉呈现」分离为两个类。`DifficultyScreen` 覆写了 NavPage 90% 的方法，说明基类视觉假设不适用所有菜单。抽 `MenuLogic`（纯逻辑 RefCounted）后，NavPage 和自定义菜单各持有一个实例。**触发时机**：出现第三个需要大量覆写 NavPage 的菜单时。 |
| 子弹池硬上限检查 | 高 | `_request_bullet()` 缺少 MAX_TOTAL=5000 的上限检查 |
| 激光池 clear() 修复 | 高 | `LaserSystem.clear()` 不应 queue_free 池对象 |
| Enemy/Item queue_free 守卫 | 中 | `die()` 后同帧内可能被回调触发，需加 `is_queued_for_deletion()` 检查 |
| PauseMenu/GameOverMenu `_on_leave` 去重 | 低 | 出现第三个覆盖层菜单时抽 `OverlayPage` 基类 |

## 代码风格规则

- **文件名**：核心实体（boss/bullet/enemy/item/player/rng/timeline）可短名，其余 `详细的_snake_case.gd`
- **class_name**：永远是 PascalCase
- **注释**：新文件统一 `## 类描述` + `@export` 行内 `##`；旧文件随改随补
- **章节分割**：超过 50 行的文件建议加 `# ═══`
