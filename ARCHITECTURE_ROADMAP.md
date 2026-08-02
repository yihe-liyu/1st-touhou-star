# 🎮 全系统图景 + 改进路线 v5

> 2026-07-31 · 架构重构（阶段 0-3 完成）更新
> 重构专项记录见 **[REFACTORING_PLAN.md](REFACTORING_PLAN.md)**

---

## 核心设计

**所有协程脚本 = CoroutineScript。Boss = .tres。默认弹 = _physics_process 直线。**

**2026-07 新增核心原则**：
- 依赖单向：数据类不持有场景（spawn 归 StageManager），实体走服务（ctx 注入）
- 信号生命周期：场景 `_exit_tree` 统一断开 autoload 连接
- 协程约定：游戏逻辑用 CoroutineRunner（可暂停/可复现），UI 用 await（SPEC §10）
- 常量集中：GameConfig（东方框边界）+ LayerConfig（z_index）
- 测试保护：GUT 34 个用例覆盖碰撞/掉落/符卡/时间线/RNG

---

## 资源层

```
AssetRegistry (autoload)
├── enemy_visuals, bullet_configs, sounds, ui_textures, enemies
BossData / PhaseData / StageData / PlayerData  ← .tres
CardDef / CardRegistry / SpellRecordBook        ← 练习/记录
```

## 运行时层

```
StageContext — 协程唯一入口
├── clock / bullets / player / dialogue / items / audio / decor

BulletManager
├── BulletPool (4000) / BulletPhysics / LaserSystem (32) / DeathClear
```

---

## ✅ 已完成的架构演进

| 变更 | 状态 |
|------|------|
| SPEC.md v2.0 系统规格文档化 | ✅ |
| CoroutineScript 统一协程脚本 | ✅ |
| BulletData 构造链 | ✅ |
| Laser 激光系统 | ✅ |
| MenuNav 统一菜单导航 | ✅ |
| Memory 值系统 + 释放记忆 | ✅ |
| 子弹池 POOL_SIZE=4000 | ✅ |
| 练习模式（符卡/关卡） | ✅ |
| BubblePanel 独立分离 | ✅ |
| Boss phase 防双重掉落 | ✅ |
| 激光子节点泄漏修复 (laser.gd) | ✅ |
| 默认弹去掉多余协程（仅 \_physics\_process） | ✅ |
| MissEffect fade_out 支持 | ✅ |
| DeathClear on_clear 回调 | ✅ |
| 暂停/GameOver 重开（含符卡练习适配） | ✅ |
| 主菜单跳过 logo/入场动画 | ✅ |
| Manual 页面（help01~06） | ✅ |
| 2026-07 重构阶段 0：GUT 测试框架 + 34 用例 | ✅ |
| 2026-07 重构阶段 1：静态 ctx 消除 / 私有封装 / 信号生命周期 / pause-resume | ✅ |
| 2026-07 重构阶段 2：输入映射入 project.godot / GameConfig / 服务层 / 数据解耦 / GameState 拆分 | ✅ |
| 2026-07 重构阶段 3：%UniqueName / SceneTransition 健壮化 / BGM 懒加载 / 协程约定 / 菜单场景化 | ✅ |
| 2026-08 工作台 v2 关卡沙盒（真实运行时预览）—— 见下方专节 | ✅ |

---

## 🛠️ 内容工作台演进（2026-08）

> 目标：弹幕的"剪辑软件"——以时间轴为总谱，预览/调试/设计关卡。

### v1 → v2 的架构转变

| | v1 模型沙盒 | v2 关卡沙盒（当前） |
|---|---|---|
| 预览方式 | LifecycleNode 纯逻辑模型**复刻**实体公式 | **直接跑真实关卡**（StageManager + BulletManager + 真实协程） |
| 一致性 | 靠"复刻"，会漂移 | 跑的就是游戏代码，100% 一致 |
| 玩家 | 无 | 幽灵玩家（GhostPlayer，固定路径 + 无敌，给自机狙当目标） |
| 运行方式 | @tool 编辑器内 | F6 运行（依赖 autoload），窗口 1600×1000 |

### 核心能力（F6 运行 `scenes/workbench.tscn`）

- 播放/暂停/重跑（真实引擎时钟，UI 独立存活）
- **快进跳转**：点时间轴/书签 → `Engine.time_scale=12` 跑到目标时刻（真实关卡不支持任意 seek，放弃"跳帧"幻想）
- 难度切换（Easy~Lunatic）/ 静音 / 背景开关 / 实时状态（时间/子弹数/敌人/Boss/FPS）+ 事件日志

### 关键决策与教训

1. **任意 seek 对协程关卡是反实际的**（自机狙依赖玩家路径、状态机依赖交互历史、音效无法倒带）——编辑器核心价值是"改参数→重跑→看"的循环，不是拖拽。
2. **快进同步**：游戏内 Tween 统一 `TWEEN_PROCESS_PHYSICS`（默认 IDLE 与协同时钟不同源，time_scale≠1 时演出 Tween 会落后）。所有游戏世界演出 Tween（背景/敌人/Boss）已统一。
3. **共享状态手雷**（重跑累积 bug 的根源）：
   - 场景 SubResource（Environment/ShaderMaterial）跨实例共享 → `duplicate()` 实例私有
   - 共享 Camera3D 被旧背景 tween 移走且不复位 → 逐次漂移画面变暗
   - **根解法：所有权随生命周期**——相机改由背景实例自建（`StageBackground._own_camera()`），重跑 = 旧相机随背景销毁、新背景拿初始相机，结构上不可能残留，零复位代码。
4. **出屏回收按东方框**（不是窗口）：工作台 1600 宽窗口下活动子弹 ↓93%（1401→101），真游戏右侧死区同样受益。
5. MultiMesh 分组 key 从字符串改 int（纹理 RID + region + faction + tint），去掉每帧每弹字符串分配。
6. 协同时钟/子弹移动/激光统一走 `get_physics_process_delta_time()`（time_scale 生效，为未来子弹时间/Replay 铺路）。

### 下一步（候选）

- **BulletBehavior 轻量行为系统**：弹丸协程（non_01_bullet 等每帧个体行为）→ 数据驱动行为元件 + Bullet 内联解释器。协程保留给"复杂且稀有"（Boss 特色弹/编排），轻量化吃掉"简单且海量"的 90%。为 5000 弹 60fps 铺路。
- 书签数据化：从 stage01.gd 的 `tl.at()` 自动读取时刻表（不再硬编码）
- 命中框半透明显示 / 形态走廊（多时刻叠影）

---

## 🔮 计划中的改进

| 优先级 | 改进 | 说明 |
|--------|------|------|
| 🔴 P0 | ~~共享 StageContext~~ | 已由阶段 2 服务层落地（Enemy/Boss/Player 注入 ctx） |
| 🟡 P1 | **Replay 录输入基础设施** | 每帧记录 Input + RNG 种子，为 replay 打地基 |
| 🟡 P1 | **高频路径禁 RefCounted 规则** | bullet.bind() / _physics_process 碰撞 / return_bullet 禁止 new() |
| 🟢 P2 | **MenuLogic 拆分** | NavPage 逻辑与视觉分离（等第三个需要大量覆写 NavPage 的菜单出现时） |
| 🟢 P2 | **配置校验层** | PhaseData/StageData 加载时校验合法性（含除零防护） |
| ⚪ P3 | ~~批量子弹渲染优化~~ | ~~利用 MultiMesh 减少 draw call~~（use_multi_mesh 已启用） |
| ⚪ P3 | **PauseMenu/GameOverMenu 去重** | 抽 OverlayPage 基类 |

---

## 🐛 已知技术债务

### 代码层面

| 问题 | 位置 | 严重度 | 状态 |
|------|------|--------|------|
| ~~激光池 clear() queue_free 池对象~~ | laser.gd | 高 | ✅ fixed |
| ~~Boss phase 同帧双掉落~~ | boss.gd | 高 | ✅ fixed |
| ~~默认弹双倍速~~ | bullet.gd | 高 | ✅ fixed |
| StageContext 每弹创建 | bullet.gd | 中 | P0 |
| 关卡退出时 RefCounted 残留 | 全局 | 低 | P0 可缓解 |
| ~~Enemy take_damage 缺 negative guard~~ | enemy.gd | 低 | ✅ 已修复（hp<=0 判定） |
| is_queued_for_deletion 检查不全 | 多处 | 低 | |
| Timeline loop 重置时间戳精度 | timeline.gd | 低 | |
| DifficultyScreen 覆写 NavPage 90% | difficulty_screen.gd | 设计 | P2 |
| layout_mode 混用 0/1/3 | 部分 UI .tscn | 低 | Godot 4 遗留 |

### 数据层面

| 问题 | 位置 |
|------|------|
| .tres 配置无校验（time_limit=0 会除零） | PhaseData 等 |
| SpellRecord @export 字段缺注释 | spell_record.gd |
| ARCHITECTURE_ROADMAP 文档残留 EnemyService（已移除） | 本文档 |

---

## 🚧 缺失功能

| 功能 | 优先级 | 说明 |
|------|--------|------|
| **Bomb 系统** | 🔴 高 | FACTION_BOMB 存在，无实现 |
| **Stage 2~6** | 🔴 高 | 只有 Stage 1 |
| **Stage Practice** | 🟡 中 | 菜单入口存在，未实现 |
| **Replay 播放器** | 🟡 中 | RNG 就绪，缺录制/回放 |
| **Continue 系统** | 🟢 低 | GameOver 只有 Retry/Title |
| **Result 结算画面** | 🟢 低 | 通关直接回菜单 |
| **Option 音量滑条** | 🟢 低 | UI 存在，未绑定 |

---

## 📊 内容完成度

| 类别 | 进度 |
|------|------|
| 引擎 | ████████████████████ 95% |
| 关卡 (6面) | ████ 20% (仅 Stage 1) |
| 美术 | ██████ 30% |
| 音效 | ██████ 30% |
| 叙事 | ██████████ 50% |
| 打磨/QoL | ██████████████ 70% |

---

## 代码风格规则

- **文件名**：核心实体可短名（boss/bullet），其余 `snake_case.gd`
- **class_name**：永远 PascalCase
- **注释**：`## 类描述` + `@export` 行内 `##`
- **章节分割**：>50 行加 `# ═══`
- **随机数**：必须走 `RNG`，禁止全局 `randf()`
- **GameState**：通过方法读写，不直接改属性
- **高频路径禁 new()**：bullet.bind() / _physics_process / return_bullet 等每弹/每帧路径禁止分配对象（StageContext 已懒加载服务）
