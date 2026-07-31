# 🔧 重构专项计划 — 1st Touhou Star

> 目标：把"AI 一点点糊出来"的架构，打磨成**依赖清晰、Godot 惯用、测试保护、数据驱动**的可持续开发引擎。
> 原则：**每一步游戏都能跑**，每个阶段有测试兜底。
> 创建：2026-07-31 · 维护：YiHe + AI 助手

---

## 📊 现状诊断摘要（2026-07-31 全面审查）

### 优点（保持）
- ✅ 五层分层：Autoload → 协程 → 场景 → 实体 → 数据
- ✅ 声明式 Timeline API
- ✅ 对象池体系（子弹 4000 / 道具 64 / 激光 32 / 特效）
- ✅ RNG 集中管理（可复现，Replay 基础）
- ✅ 数据驱动（.tres Resource）
- ✅ 文档完备（SPEC / CONTENT_GUIDE / ROADMAP）

### 问题清单（按严重度）

| 编号 | 问题 | 严重度 |
|------|------|--------|
| P-01 | `EnemyData._ctx` 静态可变状态（数据类持全局） | 🔴 严重 |
| P-02 | 信号连接生命周期：38 连 / 7 断，GameScene 等 free 节点连 autoload 不清理 | 🔴 严重 |
| P-03 | 两套协程并存（原生 await 15 处 + CoroutineRunner），DialogueService 直接写 `runner.is_running` hack 桥接 | 🔴 严重 |
| P-04 | 私有访问泛滥：`GameManager._set_state()`、`GameState._restarting`、`boss._die()` 被外部调用 | 🔴 严重 |
| P-05 | 输入映射运行时注入 InputMap（应在 project.godot 定义） | 🟠 中 |
| P-06 | 实体高耦合全局：player 摸 7 个 autoload、enemy 6 个、boss 5 个 | 🟠 中 |
| P-07 | 数据层反向依赖场景层（EnemyData preload enemy.tscn + 调 StageManager） | 🟠 中 |
| P-08 | 48 处 `$X` 硬编码节点路径（`$World/Player` 等） | 🟠 中 |
| P-09 | 零测试（1 万行代码，无 GUT/gdUnit） | 🟠 中 |
| P-10 | BulletPhysics O(n×m) 全量碰撞（4000 弹） | 🟡 低 |
| P-11 | 魔法数字散落（448 / 960 / 832 等 13+ 处） | 🟡 低 |
| P-12 | GameState 职责过重（354 行管 8 件事） | 🟡 低 |
| P-13 | 冗余 API（`_add_enemy_to_scene` / `add_enemy_to_scene` 双版本） | 🟡 低 |

---

## 🗺️ 分阶段重构计划

### 阶段 0 — 测试地基 🟢 低风险
**目标：给重构装上"安全带"**

- [x] 引入 GUT 测试框架（addons/gut 9.7.1, godot_4_7 分支）
- [x] 测试骨架 + 一键脚本（`test/run_tests.sh`）
- [x] 核心系统测试：
  - `test_rng_seed`：同种子 → 同序列
  - `test_drop_table`（初版：test_data_validity）数据完整性
  - `test_timeline`：时间线事件触发顺序/重复/loop/wait/reset
  - `test_collision`：圆形/矩形判定 + 擦弹半径
- [x] 跑通一条"从命令行跑测试"的流程（25 测试 / 2249 断言全绿）
- [ ] （后续可加）test_spell_capture 符卡判定集成测试
- [ ] （后续可加）test_drop_table 掉落表精确测试

**验收**：`test/run_tests.sh` 一键跑全测试，覆盖核心系统。✅（25/25）

---

### 阶段 1 — 封装修复 🟢 低风险
**目标：消除最危险的漏洞，不动行为**

- [ ] **P-01** 消灭静态 `_ctx`：`EnemyData.spawn()` 改为显式 `spawn(ctx, ...)` 或从调用点传参
- [ ] **P-04** 私有访问封装：
  - `GameManager` 提供公开 `set_state()`（或改为仅内部 + 公开入口）
  - `GameState` 提供 `begin_practice_restart()/end_practice_restart()`
  - `Boss` 提供公开 `die()`（内部逻辑不变）
- [ ] **P-02** 信号生命周期：GameScene/DialogueBox/UI 页面统一 `_exit_tree` 断开 autoload 连接
- [ ] **P-13** 删冗余 API（合并 `_add_enemy_to_scene`）
- [ ] **P-03** CoroutineRunner 提供正式 `pause()/resume()`，DialogueService 改用它

**验收**：全测试绿 + 游戏主流程（菜单→Stage1→Boss→GAMEOVER）人工跑通。

---

### 阶段 2 — 依赖整理 🟡 中风险
**目标：把依赖图理顺成单向瀑布**

- [ ] **P-05** 输入映射移入 project.godot `[input]` 节（删 `_ensure_input_actions`）
- [ ] **P-06** 扩展 StageContext 服务（score / enemy / collision），实体改用服务访问
- [ ] **P-07** 数据层解耦：EnemyData/BulletData 移除场景依赖（spawn 移交给 StageManager 或工厂）
- [ ] **P-11** 魔法数字集中：屏幕中心/边界 → 配置常量（新 `GameConfig` 或并入 LayerConfig）
- [ ] **P-12** 拆分 GameState：SpellBook / ScoreSystem / SaveManager 子模块

**验收**：全测试绿 + 无"实体直接摸全局"残留（grep 统计下降）。

---

### 阶段 3 — Godot 特性强化 🟡 中风险
**目标：尽到 Godot 的特性**

- [ ] **P-08** `$X` 路径 → `@export` 注入 / `%UniqueName`
- [ ] 菜单系统场景化：页面用场景继承组织，减少代码构建
- [ ] SceneTransition 健壮化：检查 `change_scene_to_file` 返回值 + 错误处理
- [ ] preload 策略优化：音频/大贴图改懒加载
- [ ] 双轨协程统一策略（文档化：何时用 await，何时用 CoroutineRunner）

**验收**：全测试绿 + 改节点名不崩 + 切换关卡 100 次无错误日志。

---

### 阶段 4 — 性能与扩展 🔴 高风险（视需要）
**目标：规模化的性能与内容管线**

- [ ] **P-10** 空间哈希/网格分区碰撞（4000 弹 → O(n+k)）
- [ ] 弹幕定义进一步数据化（Boss 弹幕蓝图编辑器友好格式）
- [ ] 热重载工作流（编辑弹幕脚本 F6 即生效）
- [ ] Replay 系统落地（RNG 种子 + 输入记录）

**验收**：5000 弹同屏 60fps；新符卡从设计到可玩 < 1 小时。

---

## 📐 目标架构（完成后）

```
输入(project.godot) → 系统(Autoload) → 服务(StageContext) → 实体
       ↑                    ↓                    ↓
      UI  ←── 事件(GameEvents) ← 数据(GameState) ← 物理
```

- 依赖单向，无环
- 数据类不依赖场景
- 实体通过服务访问系统，不裸摸全局
- 全部信号生命周期有管理
- 测试保护核心数学

---

## 📝 变更日志

| 日期 | 阶段 | 内容 |
|------|------|------|
| 2026-07-31 | 审查 | 全面架构审查 + 诊断报告 + 本计划创建 |
| 2026-07-31 | 阶段0 | GUT 9.7.1 接入 + 首批测试（RNG/Timeline/碰撞/数据）25 个全绿 |
| | | |

---

## 🚦 状态图例

- [ ] 待办
- [x] 完成
- ⏳ 进行中
- 🧪 测试覆盖
