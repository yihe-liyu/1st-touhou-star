#!/usr/bin/env bash
# 一键验证：真实启动零错误 + GUT 全绿 + 文件所有权恢复 + git 状态
# 用法: ./tools/verify.sh
set -e
cd "$(dirname "$0")/.."

echo "═══════════════════════════════════════"
echo "  🔧 一键验证"
echo "═══════════════════════════════════════"

echo ""
echo "== [1/4] 秒级语法检查 =="
./tools/check_syntax.sh

echo ""
echo "== [2/4] 真实启动验证（game_scene） =="
START_ERR=$(godot --headless --path "$PWD" res://scenes/game_scene.tscn --quit 2>&1 | grep -E "SCRIPT ERROR|Compile Error|^ERROR:" | grep -vE "resources still in use|RID allocations" || true)
if [ -n "$START_ERR" ]; then
	echo "❌ 启动有错误："
	echo "$START_ERR"
	exit 1
fi
echo "✅ 启动零错误"

echo ""
echo "== [3/4] GUT 全量测试 =="
if ! ./test/run_tests.sh; then
	echo "❌ GUT 测试失败"
	exit 1
fi
echo "✅ GUT 全绿"

echo ""
echo "== [4/4] 文件所有权恢复 =="
if [ "$(id -u)" = "0" ]; then
	chown -R cirno:cirno .godot/ scripts/ data/ test/ tools/ 2>/dev/null || true
	echo "✅ 已恢复 cirno 所有权（root 运行，防污染）"
else
	echo "✅ 非 root 运行，跳过 chown"
fi

echo ""
echo "== git 状态 =="
git status --short | head -15
echo "═══════════════════════════════════════"
echo "  ✅ 验证完成"
echo "═══════════════════════════════════════"
