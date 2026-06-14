# 对话系统设计 v2 — 气泡式

> 2026-06-14 修订

## 数据结构

```
CharacterProfile  — 名字 + 表情集
DialoguePosition  — 人物 + 站位(左/右)
DialogueBubble    — 谁说 + 说什么 + 什么表情
DialogueLine      — 一帧: positions[] + bubbles[]
DialogueData      — 序列: lines[]
```

### CharacterProfile

```gdscript
@export var name: String
@export var portraits: Dictionary = {"通常":..., "笑":..., "怒":...}
```

纯角色数据，不绑站位。

### DialoguePosition

```gdscript
@export var character: CharacterProfile
@export var side: int = 0  # 0=左列, 1=右列
```

站位由对话定义，同一角色可在不同场景站不同位置。

### DialogueBubble

```gdscript
@export var speaker: CharacterProfile
@export var text: String
@export var emotion: String = "通常"
```

### DialogueLine

```gdscript
@export var positions: Array[DialoguePosition]
@export var bubbles: Array[DialogueBubble]
```

一条 = 屏幕同一帧。`positions` 决定谁在场、站哪。
`bubbles` 可多个 → 多人同时说。

### DialogueData

```gdscript
@export var lines: Array[DialogueLine]
```

## 表现

```
┌──────────────────────────────────┐
│ [灵梦]                          │
│   ▎「前面前面！」               │
│       ← 左人气泡在右边          │
│                                  │
│          「看到了！」▕ [魔理沙]  │
│                ← 右人气泡在左边  │
│                                  │
│ [灵梦]          「上——！」       │
│   ▎               ▕ [魔理沙]    │
│ ← 双人气泡同时出现              │
└──────────────────────────────────┘
```

- 左列角色 → 气泡在人物右侧
- 右列角色 → 气泡在人物左侧
- 气泡带三角尾巴指向说话者
- 同 line 多个 bubble → 同时显示
- Z → 下一 line  /  X → 全跳
- 新 line 不在 `positions` 里的角色 → 立绘暗/消失

## 用法示例

```
line 0: positions=[灵梦(左), 魔理沙(右)], bubbles=[灵梦:"前面前面！"]
line 1: positions=[灵梦(左), 魔理沙(右)], bubbles=[魔理沙:"看到了！"]
line 2: positions=[灵梦(左), 魔理沙(右)], bubbles=[灵梦:"上！", 魔理沙:"来！"]
```

## 预计

7 文件 ~350 行
