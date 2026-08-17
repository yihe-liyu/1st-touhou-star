# 🎭 对话系统重构专项计划 — DialogueSteps

> 目标：把"内容与流程混在平铺 lines 数组"的对话模型，重构为**台词库（数据） + 舞台状态（State）+ 步骤序列（DSL）**，
> 根治 .tres 编辑不便与 event 时机缺陷，并保持"每一步能跑、每阶段有测试"。
> 创建：2026-08-17 · 维护：YiHe + AI 助手

---

## 一、现状诊断（为什么重构）

### 当前模型

```
DialogueData (.tres)
└── lines: Array[DialogueLine]          ← 唯一维度：平铺行列表
    ├── bubbles: Array[DialogueBubble]  ← 内容 + 演出属性混在一起
    │   └── speaker / text / emotion / portrait_pos / move_portrait / move_bubble / bubble_offset
    ├── skippable / auto_advance
    └── event: String                   ← 显示该行"瞬间"emit（dialogue_box.gd:197）
```

### 痛点根因

| 痛点 | 根因 |
|------|------|
| **.tres 编辑不便** | 每行嵌套 1~2 个 `DialogueBubble` 子资源，演出属性（位置/偏移/move 标记）与内容（台词/表情）混排——13 句对话 = 239 行 .tres，层层展开 |
| **event 时机缺陷** | event 在 `_show_line()` 末尾 emit，只能表达"显示这句的同时"，表达不了"**这一句说完 → 停顿/立绘变化/切BGM → 下一句**"——行与行之间没有钩子 |
| **隐式粘滞状态** | 播放器靠 `_sticky_pos` / `_sticky_bubble`（dialogue_box.gd:26-27,140-143）猜测"这行没写的属性沿用上次"，状态藏在实现里，不可预测、不可测试、不可扩展 |

### 为什么现在重构

- 存量极小：全项目仅 `stage01_begin.tres` 一个对话（13 句）在用 → 迁移成本 ≈ 0
- 未来放大：6 面 × 每面多段对话，不便会成倍放大
- 已踩痛点：`bgm_switch` 接入时暴露"对话瞬间 vs 对话之间"
- 项目哲学已定调（2026-08）：**弹幕核心是逻辑不是数据，代码直写成本 < 编辑器中间层税**——对话流程同样是逻辑

---

## 二、目标模型：台词库 + 舞台状态 + 步骤 DSL

### 分层

```
① 台词库（数据）      DialogueData.tres → { id: DialogueLine }  只存"谁说什么、什么表情"
② 舞台状态（运行时）  StageState.actors: 谁在场/位置/翻转/明暗/表情   ← 唯一真相
③ 步骤序列（流程）    DialogueSteps DSL → Array[DialogueStep]    只描述"发生了什么变化"
④ 播放器（渲染）      DialogueBox（保留现有立绘/气泡/动画/跳过，改消费步骤）
```

### 2.1 舞台状态 ActorState（新）

| 字段 | 含义 | 默认 |
|------|------|------|
| `char_name` | 角色标识 | — |
| `profile` | CharacterProfile（含表情集） | — |
| `position: Vector2` | 立绘锚点 | profile.default_pos（新增） |
| `flip_h: bool` | 水平翻转（面向说话对象） | profile.default_flip（新增） |
| `light: float`（0~1） | 明暗；1=正常，<1=暗 | 自动：说话者 1.0，沉默在场者 0.35 |
| `visible: bool` | 在场与否 | false |
| `emotion: String` | 表情 key | "通常" |
| `bubble_offset: Vector2` | 气泡偏移（粘滞位） | 默认值 |

**关键：状态是"声明即改变，不声明不动"**——旧模型的粘滞猜测机制彻底删除。

### 2.2 步骤类型表（DSL）

| 步骤 | 作用 | 例子 |
|------|------|------|
| `d.line(id, opts?)` | 显示一句（内容来自台词库）；**自动**：说话者亮 + 立绘前置 + 出气泡（同屏多气泡=多人齐声）；不改变位置/flip；`opts: {skippable, auto_advance}` | `d.line("k1")` |
| `d.enter(角色, pos?, opts?)` | 登场：visible=true + 定位 + 可带 `{flip, dim, emotion}` | `d.enter("卡摩瑞", Vector2(550,230), {"flip": true})` |
| `d.exit(角色)` | 退场：visible=false | `d.exit("卡摩瑞")` |
| `d.move(角色, pos, dur?)` | 移动立绘（可选时长，默认按过渡动画） | `d.move("卡摩瑞", Vector2(400,200), 0.8)` |
| `d.flip(角色, bool)` | 翻转 | `d.flip("卡摩瑞", false)` |
| `d.dim(角色, value)` | 手动明暗 | `d.dim("灵梦", 0.5)` |
| `d.portrait(角色, emotion)` | 换表情 | `d.portrait("卡摩瑞", "耍帅")` |
| `d.bubble(角色, offset)` | 调气泡偏移 | `d.bubble("卡摩瑞", Vector2(-650,250))` |
| `d.event(key)` | **行间事件**（时机精确，任意位置） | `d.event("bgm_switch")` |
| `d.wait(秒)` | 停顿演出（替代 auto_advance） | `d.wait(0.5)` |

### 2.3 台词库（.tres 退化）

```
DialogueData.tres
└── lines: Dictionary { String: DialogueLine }   ← id → 内容
    └── DialogueLine: bubbles[speaker, text, emotion]   ← 演出字段全部移除
```

- 编辑体验：每行 = 一个 id + speaker + text + emotion，无嵌套演出属性
- id 规范与 `docs/DIALOGUE.md` 章节对应（如 `stage1_begin/r1`），剧本即索引

### 2.4 CharacterProfile 扩展

```gdscript
@export var default_pos: Vector2 = Vector2(50, 230)   ## 首次登场默认锚点
@export var default_flip: bool = false                ## 首次登场默认翻转
```
（现有 profile .tres 补两个字段即可，向后兼容）

---

## 三、重构后战前对话示例

```gdscript
# 台词库：data/dialogue/reimu/stage01_begin.tres → { "r1": {...}, "k1": {...}, ... }
const REIMU_BEGIN_LINES = preload("res://data/dialogue/reimu/stage01_begin.tres")

tl.at(92).dialogue(func(d: DialogueSteps):
    d.enter("灵梦", Vector2(200, 200))
    d.line("r1")                       # 啊，什么线索都没有…
    d.line("r2")
    d.enter("卡摩瑞", Vector2(550, 230), {"flip": true})   # 蝙蝠右出场，面向灵梦
    d.line("k1")                       # 哦呀，弱小的人类…
    d.line("k2")
    d.flip("卡摩瑞", false)            # 转身
    d.line("k3")
    d.move("卡摩瑞", Vector2(400, 200), 0.8)   # 走近
    d.line("k4")
    d.event("bgm_switch")              # ← 行与行之间！时机精确
    d.wait(0.5)
    d.portrait("卡摩瑞", "耍帅")
    d.line("k5")
)
```

---

## 四、播放器改造（DialogueBox）

- **逻辑/渲染分离**：新增 `DialogueRunner`（RefCounted，纯逻辑）解释步骤序列 + 推进 StageState；`DialogueBox` 保留全部视觉逻辑（立绘/气泡/表情/动画/明暗/跳过/输入），改为**消费 StageState 快照 + 指令**
- 删除：`_data/_line_idx` 行索引、`_sticky_pos/_sticky_bubble`、行内 event 触发
- 保留：`[shake=N]`/BBCode 文本标记、长按关闭、`ui_accept/ui_cancel` 操作、pause/resume 集成
- 测试面：`DialogueRunner` + `StageState` 纯逻辑不进树，可直接 GUT 断言（无节点依赖）

---

## 五、分阶段实施计划

| 阶段 | 内容 | 验收 | 测试 | 状态 |
|------|------|------|------|------|
| **阶段 0** | 补现状对话测试（数据完整性 + DialogueBox 播放冒烟） | 旧行为被测试锁定 | test_dialogue.gd | ✅ |
| **阶段 1** | 实现 `StageState` + `DialogueSteps` DSL + `DialogueRunner`（纯逻辑） | DSL 步骤生成正确状态变化 | test_dialogue_steps.gd 13 用例 | ✅ |
| **阶段 2** | `DialogueBox` 改步骤驱动（视觉保留），删 sticky/行内 event | 播放冒烟通过 | test_dialogue.gd 更新 | ✅ |
| **阶段 3** | 台词库化 .tres + 迁移 `stage01_begin` + `bgm_switch` 改行间触发 | 旧字段删除，效果不变（时机更准） | 数据/时序测试 | ✅ |
| **阶段 4** | 文档同步（CONTENT_GUIDE 第九节 / SPEC §6.9 / 本计划） | 文档与代码一致 | 全量回归 184 用例 | ✅ |
| **阶段 5** | DIALOGUE.md 台词 id 标注（可选，随新内容进行） | — | — | ⏳ 后续 |

> 每阶段完成标准：**游戏能跑 + 测试全绿**（沿用 REFACTORING_PLAN 原则）

---

## 六、风险与回滚

| 风险 | 缓解 |
|------|------|
| 播放器视觉回归 | 阶段 0 先锁旧行为；阶段 3 视觉等价验收（工作台 F6 对比） |
| 台词库迁移遗漏 | 阶段 4 数据有效性测试校验所有 .tres 的 id 完整 |
| 重构期间不可玩 | 阶段 1/2 纯新增（旧路径保留），阶段 3 一次性切换 |
| 回滚 | 各阶段独立提交；回退 = revert 对应提交，旧 lines 模型保留至阶段 4 删除 |

---

## 📝 变更日志

| 日期 | 阶段 | 内容 |
|------|------|------|
| 2026-08-17 | 规划 | 方案文档创建（待审） |
| 2026-08-17 | 阶段 0-3 | ✅ 完成：test_dialogue/test_dialogue_steps（18 用例）、StageState/DialogueSteps/DialogueRunner、DialogueBox 步骤化、stage01_begin 台词库化 + bgm_switch 行间化 |
| 2026-08-17 | 阶段 4 | ✅ 文档同步：CONTENT_GUIDE 第九节 / SPEC §6.9 / 本计划状态（全量 184 用例全绿） |
