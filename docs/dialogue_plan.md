# 对话系统开发计划

> 2026-06-14 定稿

## 总览

```
数据层:  DialogueCharacter → DialogueLine → DialogueData
         Resource, Inspector 可配

控制层:  StageAPI.play_dialogue(data)  ← 协程阻塞
         api.dialogue_show(name, text)  ← 逐句自由

表现层:  DialogueBox CanvasLayer
         打字机 + 立绘 + 多人同屏 + 跳过
```

## 拆分

### Phase 1: 数据 (2 文件)

| 文件 | 内容 |
|---|---|
| `scripts/data/dialogue_character.gd` | `@export var char_name, portrait` |
| `scripts/data/dialogue_line.gd` | `@export var left_chars, right_chars, text, speakers` |
| `scripts/data/dialogue_data.gd` | `@export var lines: Array[DialogueLine]` |

### Phase 2: 表现 (2 文件)

| 文件 | 内容 |
|---|---|
| `scenes/ui/dialogue_box.tscn` | CanvasLayer + 左右列 + 文本框 + 箭头 |
| `scripts/scenes/ui/dialogue_box.gd` | 打字机、立绘显隐、高亮/暗化、Z/X 输入 |

功能：
- 左右列纵向栈叠立绘 + 名字
- `speakers[]` 对应角色高亮（scale 微弹 + 亮色），其余暗半透明
- 文字逐字出现，Z 加速到完整
- 最后一句 Z → 关闭动画 → `signal finished`
- X → 跳过全部 → `signal finished`
- 遮罩半透明黑底

### Phase 3: 接入协程 (1 文件)

```gdscript
# StageAPI
func play_dialogue(data: DialogueData) -> float:
    # 弹出 DialogueBox, 等 finished 信号 → 返回
```

协程阻塞直到对话结束。

### Phase 4: 触发 (1 文件)

```gdscript
# StageData 加字段
@export var dialogue_opening: DialogueData
@export var dialogue_mid_boss: DialogueData
@export var dialogue_end_boss: DialogueData
```

StageManager 在对应时机自动 `play_dialogue()`，协程自然阻塞。

## 预计工时

| Phase | 文件数 | 量 |
|---|---|---|
| 数据 | 3 | 小 (纯 Resource) |
| 表现 | 2 | 中 (UI + 动画) |
| 接入 | 1 | 小 |
| 触发 | 1 | 小 |
| **合计** | **7** | ~400 行 |

## 复用

- 打字机逻辑 → 以后书本/教程/剧情都能用
- `DialogueBox` 是独立 CanvasLayer，菜单/关卡都能弹
