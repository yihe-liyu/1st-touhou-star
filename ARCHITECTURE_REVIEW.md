# 🏗️ 架构深度评审 v1.0

> 基于代码全量审查 + 运行时诊断 + 我们此次对话中暴露的所有问题

---

## 一、总体评价

这个架构在**同人 STG 引擎**里已经属于中上水平。CoroutineScript 统一 + Timeline 声明式 + StageContext 隔离，方向完全正确。下面的问题不是"错了"，是"可以更好"。

---

## 二、核心矛盾：高频对象 vs 重型上下文

### 现状

```
每颗子弹 = Node2D + Sprite2D + CoroutineScript(Node) + Task(RefCounted) + Callable
```

4000 颗弹 × 5 = 20000+ 对象，仅用于 `position += velocity * delta`。

### 根因

`StageContext` 是为**关卡脚本**设计的——它包含 6 个 Service、对话系统、装饰物管理器。但每颗子弹的直线移动只需要 `delta` 和 `velocity`。

**这是整个架构里唯一真正的性能瓶颈**，也是对象数膨胀的主因。

### 建议：Bullet 移动双路径

```
直线弹（95%+）     → _physics_process 原生，零额外对象
复杂弹（诱导等）   → CoroutineScript（保持现状）
```

**具体做法**：
- `bullet.gd` 的 `_physics_process` 已经存在（`if not is_ready or coroutine_script: return`），但被 CoroutineScript 覆盖了。
- 给 `BulletData` 加 `var use_coroutine: bool = false`。
- `bind()` 中：`use_coroutine == false` → 不走 CoroutineScript 路径，用原生 `_physics_process`。
- `linear_move.gd` 删掉，合并到 bullet 原生逻辑。

**收益**：
- 每颗弹省 1 个 CoroutineScript + 1 个 StageContext(7 RefCounted) + 1 个 Task + 1 个 Callable = 省 ~10 个对象
- 4000 弹省 ~40000 对象
- `_physics_process` 比 `Callable.call()` 更快（Godot 内部对直接方法调用有优化）

---

## 三、内存管理：RefCounted 泄漏的系统性防范

### 我们发现的问题

- **StageContext per bullet** — 已修复（`start_null`）
- **Laser 子节点堆积** — 已修复（`_common_init` 清理）
- **Boss 双掉落** — 已修复（`_cleared` 标记）

但这些都是**被动发现**的，不是系统性防范的。

### 建议：两条铁律

**铁律 1：任何 `add_child` 必须有对应的 `queue_free` 路径**
```
# 写一个 lint 规则（至少是 code review checklist）：
# 搜 add_child，确认其父节点被 queue_free 的时机
```

**铁律 2：高频路径（每弹/每帧）禁止创建 RefCounted**
```
# 高频路径包括：
# - bullet.bind()
# - _physics_process（弹幕碰撞）
# - _return_to_pool
# 这些路径中 new() 的 RefCounted 会导致 GC 积压
```

---

## 四、CoroutineRunner 的隐藏成本

### 每帧开销

```gdscript
for task in _tasks:
    if not task.callable.is_valid(): ...  # Callable 有效性检查
    if task.wake_time > _clock: continue  # 时间比较
    var result = task.callable.call()     # 动态调用
    # 返回值判断 + 分支
```

4000 颗弹 = 4000 次 Callable 调用 + 4000 次类型判断。这在大弹幕量时是真实的开销。

### 建议：批量子弹系统

为直线弹引入**批量更新**：

```gdscript
# BulletPool 新增：
func _physics_process(delta):
    for bullet in active_bullets:
        if bullet._move_simple:  # 标记为简单移动
            bullet.position += bullet._velocity_cache * delta
```

一个循环替代 4000 个 Callable。Godot 的 `Node._physics_process` 内联循环比 `Callable.call()` 快 3-5 倍。

**触发时机**：当观察到弹幕数量 >2000 时帧率下降。

---

## 五、菜单系统的继承问题

### 现状

`DifficultyScreen` 覆写了 `NavPage` 90% 的方法——说明基类的视觉假设不适用于所有菜单。

### 建议：MenuLogic 分离

```
NavPage (视觉) ──has-a──→ MenuLogic (逻辑，RefCounted)
                              ├── _nav_items
                              ├── navigate(delta)
                              ├── _is_locked()
                              └── accept_current()

CustomMenu ──has-a──→ MenuLogic  # 自定义视觉，复用逻辑
```

**但不要现在做。** 等出现第三个需要大量覆写 `NavPage` 的菜单时再动。过早抽象是万恶之源。

---

## 六、StageContext 的生命周期管理

### 问题

`StageContext` 现在是"谁用谁创建"——StageManager 创建一个、每个自定义弹创建一个。创建者负责释放，但释放时机不统一。

### 建议：StageContext 工厂 + 弱引用池

```gdscript
# StageManager
var _shared_ctx: StageContext  # 关卡级共享

func get_stage_context() -> StageContext:
    return _shared_ctx
```

所有关卡内对象（敌人、Boss、自定义弹）共享同一个 StageContext。只有需要独立时钟/上下文的场景（如练习模式）才创建新的。

**收益**：Stage 1 整个关卡只需要 1-2 个 StageContext，而不是 4000+。

---

## 七、Replay 系统的基础

### 现状

只有 `RNG` 是 replay-ready。但 replay 需要的远不止这些：

| 要素 | 当前状态 | 需要 |
|------|---------|------|
| RNG 种子 | ✅ RNG.set_seed() | - |
| 输入录制 | ❌ | 每帧记录 Input 状态 |
| 帧锁定 | ❌ | 固定 physics_ticks |
| 确定性 | ❌ | `_process` 和 `_physics_process` 的执行顺序可能不确定 |

### 建议：Replay 基础设施

```gdscript
# ReplayRecorder (新建)
class ReplayRecorder:
    var seed: int
    var inputs: Array[Dictionary]  # [{frame: 0, keys: ["shoot", "up"]}, ...]
    
    func record_frame(frame: int) -> void:
        inputs.append({frame = frame, keys = _pressed_actions()})
    
    func replay() -> void:
        RNG.set_seed(seed)
        # 逐帧回放输入
```

**不要现在实现完整的 replay 播放器**，只需要：
1. 在 GameManager 中加一个 `_replay_recorder`，每帧录输入
2. 在 RNG 初始化时记录种子
3. 结构上预留 replay 的入口

这样以后做 replay 时不需要重写核心逻辑。

---

## 八、数据层的 .tres 管理

### 现状

`PhaseData`、`BossData`、`StageData` 通过 `.tres` 文件配置，但这导致：
- 调数值需要重启 Godot 编辑器
- 不同难度需要 4 个 StageData 文件（实际上它们只有 `create_script` 不同）
- 没有配置校验（如 `time_limit=0` 会导致除零）

### 建议：配置校验层

```gdscript
# ConfigValidator (新建, 编辑器插件或 _ready 时检查)
func validate_stage_data(data: StageData) -> Array[String]:
    var errors: Array[String] = []
    if data.stage_id <= 0: errors.append("stage_id 无效")
    if not data.create_script: errors.append("缺少 create_script")
    # 检查所有 PhaseData 的合法性
    return errors
```

**不要迁移到 JSON/CSV。** `.tres` 的编辑器内可视化编辑是巨大优势，不要丢掉。

---

## 九、输入系统

### 现状

输入处理分散在 4 处：
- `GameManager._process` — 暂停
- `NavPage._process` — 菜单导航
- `Player._physics_process` — 移动/射击/C 键
- `MainMenu._input` — 跳过动画

### 建议：InputRouter

```gdscript
# InputRouter (新建 Autoload)
# 提供统一输入查询 + 输入抑制
var _blocked: bool = false

func is_action(action: String) -> bool:
    return not _blocked and Input.is_action_just_pressed(action)

func block_for(duration: float) -> void:
    # 场景切换/过场时抑制输入
```

**不要现在做**——分散的输入在 STG 里实际上没问题（各自有明确的上下文）。但当需要做 replay 时必须统一。

---

## 十、优先级排序

| 优先级 | 改进 | 理由 |
|--------|------|------|
| 🔴 P0 | 子弹双路径（原生 vs 协程） | 直接解决对象膨胀 + 性能 |
| 🟡 P1 | StageContext 共享 | 减少 RefCounted 创建 |
| 🟡 P1 | 高频路径禁 RefCounted 规则 | 防止回归 |
| 🟢 P2 | Replay 录输入基础设施 | 为 replay 打地基 |
| 🟢 P2 | 配置校验器 | 减少配置错误 |
| ⚪ P3 | MenuLogic 分离 | 等第三个异常菜单出现 |
| ⚪ P3 | InputRouter | 等 replay 时统一 |

---

## 十一、一句话总结

**当前架构最大的问题不是设计错误，是一个设计决策在高频路径上的意外代价：让每颗子弹创建完整的协程上下文。修好这一个，整个引擎就是同人 STG 里架构最好的那一档。**
