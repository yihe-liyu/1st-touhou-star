#!/usr/bin/env bash
# 自机伤害数值计算器一键运行
# 用法: ./tools/run_dps_report.sh
# 改 tools/player_dps_report.gd 顶部"数值输入"后重跑即得新表
set -e
cd "$(dirname "$0")/.."
godot --headless --path "$PWD" -s res://tools/player_dps_report.gd
