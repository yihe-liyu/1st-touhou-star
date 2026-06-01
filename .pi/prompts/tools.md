---
description: 列出 godotMCP 工具的完整参考文档
argument-hint: "[tool-name]"
---
# godotMCP 工具完整参考

## 🚀 编辑器 & 运行

### `godot_launch_editor(projectPath)`
启动 Godot 编辑器 GUI。
- `projectPath` (必填) — 项目目录路径

### `godot_run_project(projectPath, scene?)`
运行游戏项目，输出返回到聊天。
- `projectPath` (必填)
- `scene` (可选) — 指定要运行的场景，如 `"res://scenes/game_scene.tscn"`

### `godot_stop_project()`
停止正在运行的游戏。

### `godot_get_debug_output()`
获取游戏运行中的 debug 输出和错误信息。在 `godot_run_project` 之后调用。

---

## 📦 场景操作

### `godot_create_scene(projectPath, scenePath, rootNodeType?)`
创建新的 `.tscn` 文件。
- `scenePath` — 相对项目的路径，如 `"res://scenes/boss.tscn"`
- `rootNodeType` — 默认 `"Node2D"`

### `godot_add_node(projectPath, scenePath, parentNodePath?, nodeType, nodeName, properties?)`
向场景中添加节点。
- `parentNodePath` — 默认 `"root"`，也可用 `"root/Player"`
- `nodeType` — 如 `"Sprite2D"`, `"Area2D"`, `"CollisionShape2D"`
- `properties` — 可选属性字典，如 `{"position": Vector2(100, 100)}`

### `godot_save_scene(projectPath, scenePath, newPath?)`
保存场景修改。`newPath` 可选，用于另存为变体。

### `godot_load_sprite(projectPath, scenePath, nodePath, texturePath)`
给 Sprite2D 节点设置贴图。
- `nodePath` — 如 `"root/Player/AnimatedSprite2D"`
- `texturePath` — 如 `"res://assets/Textures/player/pl00.png"`

---

## 🔍 信息查询

### `godot_get_godot_version()`
返回引擎版本号（如 `4.6.2.stable`）。

### `godot_get_project_info(projectPath)`
返回项目名称、路径、Godot 版本、场景/脚本/素材数量。

### `godot_list_projects(directory, recursive?)`
扫描指定目录下的 Godot 项目。

---

## 🆔 UID 管理

### `godot_get_uid(projectPath, filePath)`
获取文件的 UID（Godot 4.4+）。如 `.tres` 文件中引用的 `uid://xxxxx`。

### `godot_update_project_uids(projectPath)`
刷新项目内所有资源的 UID 映射。当 .tres 文件里的 uid 失效时使用。

---

## 🧩 其他

### `godot_export_mesh_library(projectPath, scenePath, outputPath)`
将场景导出为 MeshLibrary 资源（用于 3D TileSet）。

---

## 💡 常用组合

```yaml
# 新建敌人
1. godot_create_scene → enemies/boss_a.tscn
2. godot_add_node → Area2D (root), Sprite2D, CollisionShape2D
3. godot_load_sprite → 挂贴图
4. write → 写 enemy_boss_a.gd 脚本
5. godot_run_project → 跑起来看看

# 查 UID 问题
1. godot_get_uid → 查文件 uid
2. godot_update_project_uids → 批量修复
```
