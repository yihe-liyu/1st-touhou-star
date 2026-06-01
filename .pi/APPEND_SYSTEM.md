# 🎮 东方星 STG 项目 — godotMCP 工具指南

本项目使用 **godotMCP** 工具链进行 Godot 4.6.2 游戏开发。
godotMCP 工具已注册为**直接工具（Direct Tools）**，可以直接调用，无需额外配置。

## 可用工具一览

### 编辑器 & 运行
- `godot_launch_editor(projectPath)` — 打开 Godot 编辑器
- `godot_run_project(projectPath, scene?)` — 运行游戏（可选指定场景）
- `godot_stop_project()` — 停止运行中的游戏

### 场景操作
- `godot_create_scene(projectPath, scenePath, rootNodeType?)` — 新建场景
- `godot_add_node(projectPath, scenePath, parentNodePath?, nodeType, nodeName, properties?)` — 添加节点
- `godot_save_scene(projectPath, scenePath, newPath?)` — 保存场景
- `godot_load_sprite(projectPath, scenePath, nodePath, texturePath)` — 给 Sprite2D 挂贴图

### 信息查询
- `godot_get_godot_version()` — 查看引擎版本
- `godot_get_project_info(projectPath)` — 获取项目元数据
- `godot_list_projects(directory, recursive?)` — 扫描 Godot 项目
- `godot_get_debug_output()` — 获取游戏运行输错

### UID 管理
- `godot_get_uid(projectPath, filePath)` — 查文件 UID
- `godot_update_project_uids(projectPath)` — 刷新全部 UID 引用

### 其他
- `godot_export_mesh_library(projectPath, scenePath, outputPath)` — 导出 MeshLibrary

## 推荐工作流

1. **查看项目结构** → `godot_get_project_info` + `ls` 浏览文件
2. **编辑代码** → 用 `read` / `edit` / `write` 改 `.gd` 脚本
3. **编辑场景** → 用 `godot_` 场景工具操作 `.tscn`
4. **运行测试** → `godot_run_project` 并 `godot_get_debug_output` 看结果
5. **查错** → 运行后 `godot_get_debug_output` 获取报错

## 快速参考

```
项目路径: /home/cirno/Create/Learning Coding/1-st-touhou-star-~-broadest-and-narrowest
主场景:   res://scenes/ui/main_menu.tscn
游戏场景: res://scenes/game_scene.tscn
```

💡 需要详细工具文档可以输入 `/tools` 调出提示模板。
