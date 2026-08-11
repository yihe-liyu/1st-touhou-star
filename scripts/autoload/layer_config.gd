# LayerConfig.gd (autoload)
extends Node
## 全局图层管理 — 所有 z_index 在此定义

# ── 游戏物件 ──
const PLAYER_BULLET := -10  ## 自机子弹
const ITEM          := -5   ## 道具
const PLAYER        := 0    ## 自机
const OPTION        := 6    ## 子机（Option）
const ENEMY         := 5    ## 敌人
const ENEMY_BULLET  := 10   ## 敌弹
const BOSS          := 15   ## Boss
const BOSS_HP_RING  := 20   ## Boss 血量环
const BOSS_INDICATOR := 45  ## Boss 位置指示器（弹幕之上可见，特效之下）
const EFFECT        := 50   ## 击中/消弹等特效（弹幕之上）
const BOMB          := 100  ## 炸弹特效

# ── UI（CanvasLayer layer=32，内部 z 用 UI_* 相对排序）──
const GAME_UI   := 1000   ## UI 容器根（语义层）
const UI_TOP    := 128    ## UI 内部置顶（血条数字/提示等）
const OVERLAY   := 2000   ## 菜单/暂停遮罩
const DEBUG     := 9999
