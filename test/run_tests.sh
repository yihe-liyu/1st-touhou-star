#!/usr/bin/env bash
# 一键运行全部测试（GUT）
# 用法: ./test/run_tests.sh
set -e
cd "$(dirname "$0")/.."

echo "═══════════════════════════════════════"
echo "  🧪 1st Touhou Star — 运行测试套件"
echo "═══════════════════════════════════════"
godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gdir=res://test -gexit "$@"
echo "═══════════════════════════════════════"
echo "  ✅ 测试结束"
echo "═══════════════════════════════════════"
