#!/usr/bin/env bash
# 一键运行全部测试（GUT）
# 用法: ./test/run_tests.sh
set -e
cd "$(dirname "$0")/.."

echo "═══════════════════════════════════════"
echo "  🧪 1st Touhou Star — 运行测试套件"
echo "═══════════════════════════════════════"

# 测试是只读的：备份符卡记录，跑完恢复（测试内 unlock/record 的 save 副作用不落盘）
RECORDS_BACKUP="$(mktemp)"
cp "$PWD/data/registry/spell_records.tres" "$RECORDS_BACKUP"

godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gdir=res://test -gexit "$@"
GUT_EXIT=$?

cp "$RECORDS_BACKUP" "$PWD/data/registry/spell_records.tres"
rm -f "$RECORDS_BACKUP"

echo "═══════════════════════════════════════"
echo "  ✅ 测试结束（exit=$GUT_EXIT，记录已还原）"
echo "═══════════════════════════════════════"
