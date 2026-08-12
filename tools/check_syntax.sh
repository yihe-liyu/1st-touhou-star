#!/usr/bin/env bash
# 秒级全项目 .gd 编译检查（场景启动：autoload 完整，无假错误）
# 用法: ./tools/check_syntax.sh [额外目录...]
set -e
cd "$(dirname "$0")/.."

# godot 退出码非 0（有失败）不能让 set -e 吞掉后续输出，用 || true 兜底
OUT=$(timeout 120 godot --headless --path "$PWD" res://tools/check_syntax_scene.tscn 2>&1 || true)
echo "$OUT" | grep -E "SCRIPT ERROR|SYNTAX FAIL|check_syntax:" || true

# 信号：SYNTAX FAIL（load 现场编译失败，非 class_name 脚本）或 SCRIPT ERROR
# （引擎启动预编译 class_name 失败 + 依赖连锁）——场景模式下都是真错误，无 -s 模式假象
if echo "$OUT" | grep -qE "SYNTAX FAIL|SCRIPT ERROR"; then
	echo "❌ 语法检查有失败（见上方 SYNTAX FAIL / SCRIPT ERROR 行）"
	exit 1
fi
echo "✅ 语法检查全过"
