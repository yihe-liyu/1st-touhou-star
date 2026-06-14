# LayerConfig.gd (autoload)
extends Node
## 全局图层管理 — 所有 z_index 在此定义

# ── 游戏物件 ──
const PLAYER_BULLET := -10
const ITEM          := -5
const PLAYER        := 0
const ENEMY         := 5
const ENEMY_BULLET  := 10
const BOSS          := 15
const BOSS_HP_RING  := 20
const BOMB          := 100

# ── UI ──
const GAME_UI   := 1000
const OVERLAY   := 2000
const DEBUG     := 9999
