# 1st Touhou Star ~ Broadest and Narrowest

东方同人 STG 引擎 · Godot 4.7

---

## 📖 文档索引

| 文档 | 内容 | 适合 |
|------|------|------|
| **[SPEC.md](SPEC.md)** | 系统规格书 —— 架构、数据流、API 契约、生命周期 | 开发者 |
| **[REFACTORING_PLAN.md](REFACTORING_PLAN.md)** | 重构专项计划 —— 分阶段路线 + 已完成/待办 | 维护者 |
| **[CONTENT_GUIDE.md](CONTENT_GUIDE.md)** | 内容制作流程 —— 怎么加关卡/敌人/Boss/符卡 | 关卡设计师 |
| **[DIALOGUE.md](DIALOGUE.md)** | 对白全集 —— 各面角色台词 | 编剧 |
| **[ARCHITECTURE_ROADMAP.md](ARCHITECTURE_ROADMAP.md)** | 架构路线图 —— 已完成/计划中的改进 + 技术债 | 维护者 |

### 我在做什么？看哪份？

| 你的问题 | 打开哪份 |
|---------|---------|
| 「这个类怎么用 / 数据怎么流动」 | SPEC.md |
| 「怎么加一个新敌人 / 符卡」 | CONTENT_GUIDE.md |
| 「接下来要修什么架构问题」 | REFACTORING_PLAN.md |
| 「游戏还要做哪些功能」 | ARCHITECTURE_ROADMAP.md |
| 「某面角色说什么台词」 | DIALOGUE.md |
| 「怎么跑 / 怎么测 / 快捷键」 | README.md（本页） |

---

## ⚡ 快速开始

1. 用 Godot 4.7 打开 `project.godot`
2. 按 F5 运行 → 主菜单
3. 选 Start → 选难度 → 选角色 → 进入 Stage 1

### 跑测试（重构/改动后的安全带）

```bash
# 一键运行全部测试（163 个用例 / 29 个脚本，GUT 框架）
./test/run_tests.sh
```

### 开发常用

```bash
# 查找代码
grep -rn "关键词" --include="*.gd" scripts/ data/

# 添加新敌人 → 见 CONTENT_GUIDE.md 第二章
# 添加新符卡/Boss → 见 CONTENT_GUIDE.md 第四章
```

### 内容工作台（预览/调试沙盒）

```bash
# F6 运行 scenes/workbench.tscn —— 跑真实关卡看弹幕效果
```

- 真实运行时沙盒：跑的就是游戏代码（StageManager/BulletManager/协程），非模拟
- **写代码在 Godot 编辑器**：关卡编排 = stage01.gd（Timeline API）；Boss 弹幕 = data/boss_scripts/ 目录自动发现
- **调参工具**：固定种子（可复现）· 命中框 · 逐帧（F）· 12x 快进跳转 · 书签（静态提取 + 人工打点）
- 幽灵玩家提供自机狙目标；静音/背景开关/事件日志/实时状态；改完脚本重启工作台生效
- 创作流程见 [CONTENT_GUIDE.md](CONTENT_GUIDE.md)；架构决策见 ARCHITECTURE_ROADMAP.md「内容工作台演进」专节

---

## 🎮 操作

| 键 | 功能 |
|----|------|
| Z | 射击 / 确认 |
| X | Bomb（未实装） |
| C | 释放记忆 |
| Shift | 低速移动 |
| Esc | 暂停 |
| 方向键 / WASD | 移动 |

> 输入映射在 `project.godot` 的 `[input]` 节（可改键，勿在代码里注入）

---

## 🏗️ 技术栈

- **引擎**: Godot 4.7
- **测试**: GUT 9.7.1（`test/` 目录，163 个用例 / 29 个脚本覆盖核心系统）
- **协程框架**: CoroutineScript + Timeline（游戏逻辑） / await（UI 过渡，见 SPEC §10）
- **服务层**: StageContext（clock/bullets/player/dialogue/items/audio/effects）
- **弹幕**: BulletPool (4000) + MultiMesh
- **激光**: 生长/直线/固定路径 三种模式
- **UI**: NavPage + MenuNav 页面栈（场景化 Overlay/PageHost）
- **数据**: .tres Resource 文件（EnemyData 构造链模板 / CardRegistry / MusicRegistry）
- **常量**: GameConfig（东方框边界）/ LayerConfig（z_index）
- **Replay**: RNG 种子管理（录输入待实现）

---

## 🧭 架构速览（2026-07 重构后）

```
输入(project.godot) → Autoload 系统 → StageContext 服务 → 实体
        ↑                  ↓                 ↓
       UI  ←── 事件(GameEvents) ←── 数据(GameState) ←── 物理
```

- 依赖单向：数据类不持有场景，实体通过服务访问系统
- 信号生命周期：场景 `_exit_tree` 统一断开 autoload 连接
- 协程约定：游戏逻辑用 CoroutineRunner（可暂停/可复现），UI 用 await
- 测试保护：核心数学（碰撞/掉落/符卡判定/时间线/RNG）有回归测试
