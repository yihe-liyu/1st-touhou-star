# autoload/game_events.gd
extends Node

# 信号命名规则：[主体]_[事件] 或 [事件]_[附加信息]

signal enemy_killed(score: int, position: Vector2)
signal player_damaged(current_hp: int)
signal player_death()
signal graze()           # 擦弹
signal bomb_used()       # Bomb 释放
signal boss_intro()
