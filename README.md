# 1st Touhou Star ~ Broadest and Narrowest

东方同人 STG 引擎 · Godot 4.7

---

## 📖 文档索引

| 文档 | 内容 | 适合 |
|------|------|------|
| **[SPEC.md](SPEC.md)** | 系统规格书 —— 架构、数据流、API 契约、生命周期 | 开发者 |
| **[CONTENT_GUIDE.md](CONTENT_GUIDE.md)** | 内容制作流程 —— 怎么加关卡/敌人/Boss/符卡 | 关卡设计师 |
| **[DIALOGUE.md](DIALOGUE.md)** | 对白全集 —— 各面角色台词 | 编剧 |
| **[ARCHITECTURE_ROADMAP.md](ARCHITECTURE_ROADMAP.md)** | 架构路线图 —— 已完成/计划中的改进 + 技术债 | 维护者 |

---

## ⚡ 快速开始

1. 用 Godot 4.7 打开 `project.godot`
2. 按 F5 运行 → 主菜单
3. 选 Start → 选难度 → 选角色 → 进入 Stage 1

### 开发常用

```bash
# 查找代码
grep -rn "关键词" --include="*.gd" scripts/ data/

# 添加新敌人 → 见 CONTENT_GUIDE.md 第三章
# 添加新符卡 → 见 CONTENT_GUIDE.md 第四章
```

---

## 🎮 操作

| 键 | 功能 |
|----|------|
| Z | 射击 / 确认 |
| X | Bomb（未实装） |
| C | 释放记忆 |
| Shift | 低速移动 |
| Esc | 暂停 |
| 方向键 | 移动 |

---

## 🏗️ 技术栈

- **引擎**: Godot 4.7
- **协程框架**: CoroutineScript + Timeline
- **弹幕**: BulletPool (4000) + MultiMesh
- **激光**: 生长/直线/固定路径 三种模式
- **UI**: NavPage + MenuNav 页面栈
- **数据**: .tres Resource 文件
- **Replay**: RNG 种子管理（录输入待实现）
