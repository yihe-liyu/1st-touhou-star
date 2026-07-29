# 🎮 全系统图景 + 改进路线 v4

> 2026-07-25 · 全面项目审查更新

---

## 核心设计

**所有协程脚本 = CoroutineScript。Boss = .tres。默认弹 = _physics_process 直线。**

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

---

## 🔮 计划中的改进

| 优先级 | 改进 | 说明 |
|--------|------|------|
| 🔴 P0 | **共享 StageContext** | 关卡内敌人/Boss/自定义弹共享一个 ctx，不每弹创建。减少数千 RefCounted。 |
| 🟡 P1 | **Replay 录输入基础设施** | 每帧记录 Input + RNG 种子，为 replay 打地基 |
| 🟡 P1 | **高频路径禁 RefCounted 规则** | bullet.bind() / _physics_process 碰撞 / return_bullet 禁止 new() |
| 🟢 P2 | **MenuLogic 拆分** | NavPage 逻辑与视觉分离（等第三个需要大量覆写 NavPage 的菜单出现时） |
| 🟢 P2 | **配置校验层** | PhaseData/StageData 加载时校验合法性 |
| ⚪ P3 | **批量子弹渲染优化** | 利用 MultiMesh 减少 draw call（弹幕 >3000 时考虑） |
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
| Enemy take_damage 缺 negative guard | enemy.gd | 低 | |
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
