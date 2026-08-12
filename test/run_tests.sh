#!/usr/bin/env bash
# 一键运行全部测试（GUT）
# 用法: ./test/run_tests.sh
set -e
cd "$(dirname "$0")/.."

echo "═══════════════════════════════════════"
echo "  🧪 1st Touhou Star — 运行测试套件"
echo "═══════════════════════════════════════"

# 测试隔离：临时 user:// 目录（XDG_DATA_HOME 重定向，save_data.cfg 等写入不碰真实存档）
TMP_USER="$(mktemp -d)"
export XDG_DATA_HOME="$TMP_USER"
# 测试是只读的：备份符卡记录，跑完恢复（测试内 unlock/record 的 save 副作用不落盘——res:// 写入不受 user 隔离影响）
RECORDS_BACKUP="$(mktemp)"
HAD_RECORDS=0
if [ -f "$PWD/data/registry/spell_records.tres" ]; then
	cp "$PWD/data/registry/spell_records.tres" "$RECORDS_BACKUP"
	HAD_RECORDS=1
fi

if ! godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gdir=res://test -gexit "$@"; then
	GUT_EXIT=1
else
	GUT_EXIT=0
fi

# 恢复必须在任何退出路径前执行（set -e 会因 GUT 失败中止，这里用 if 结构兜底）
if [ "$HAD_RECORDS" = "1" ]; then
	cp "$RECORDS_BACKUP" "$PWD/data/registry/spell_records.tres"
fi
rm -f "$RECORDS_BACKUP"
rm -rf "$TMP_USER"

echo "═══════════════════════════════════════"

echo "  ✅ 测试结束（exit=$GUT_EXIT，记录已还原）"
echo "═══════════════════════════════════════"
exit $GUT_EXIT
