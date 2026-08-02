# DebugDrawer.gd
# 高效的调试绘制工具 — 只在实际启用时才执行绘图逻辑
# 性能要点：判定圈 12 段（32 段白费）、矩形用 draw_set_transform（一次调用）、
# 速度线默认关闭（每颗 3 图元是大头）
extends Node2D

var draw_enabled: bool = false
var draw_velocity_lines: bool = false  # 速度线（每颗子弹 3 图元，默认关）

# 缓存节点引用，避免每帧字符串路径查找
@onready var bullet_manager: BulletManager = get_node_or_null("/root/BulletManager")
@onready var game_state: GameState = get_node_or_null("/root/GameState")

func _ready():
	set_process(false)  # 默认不开启 _process

func _input(event):
	if event.is_action_pressed("debug_toggle"):
		draw_enabled = not draw_enabled
		set_process(draw_enabled)
		# 无论是开启还是关闭，都要重绘一次！
		queue_redraw()

func _process(_delta):
	queue_redraw()

func _draw():
	if not draw_enabled:
		return
	
	# ── 画所有子弹判定 ──
	if bullet_manager:
		for bullet in bullet_manager.active_bullets:
			if not is_instance_valid(bullet) or not bullet.visible or not bullet.is_ready:
				continue
			_draw_bullet_hitbox(bullet)
	
	# ── 画所有敌人判定 ──
	if game_state:
		for enemy in game_state.get_active_enemies():
			if not is_instance_valid(enemy):
				continue
			var radius: float = enemy.get("hitbox_radius") if "hitbox_radius" in enemy else 8.0
			draw_arc(enemy.global_position, radius, 0, TAU, 12, Color.GREEN, 1.5)
			draw_circle(enemy.global_position, 2.0, Color.GREEN)
	
	# ── 画玩家判定 ──
	if game_state:
		var player = game_state.player
		if is_instance_valid(player):
			var r: float = player.get("hitbox_radius") if "hitbox_radius" in player else 2.0
			var gr: float = player.get("graze_radius") if "graze_radius" in player else 24.0
			draw_arc(player.global_position, gr, 0, TAU, 24, Color(0.3, 0.6, 1.0, 0.6), 1.0)
			draw_arc(player.global_position, r, 0, TAU, 12, Color.CYAN, 2.0)
			draw_circle(player.global_position, 2.0, Color.CYAN)
	
	# 左上角显示弹幕计数
	if bullet_manager:
		draw_string(
			ThemeDB.fallback_font,
			Vector2(64, 64),
			"弹幕数: %d" % bullet_manager.active_bullets.size(),
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			32,
			Color.RED
		)


## 单颗子弹判定（工作台命中框与 debug_drawer 共用此绘制逻辑的轻量版）
func _draw_bullet_hitbox(bullet: Bullet) -> void:
	var center: Vector2 = bullet.global_position + bullet.hitbox_offset.rotated(bullet.rotation)
	match bullet.hitbox_shape:
		BulletData.HitboxShape.CIRCLE:
			draw_arc(center, bullet.hitbox_radius, 0, TAU, 12, Color.RED, 1.0)
			draw_circle(center, 1.5, Color.RED)
		BulletData.HitboxShape.RECTANGLE:
			# draw_set_transform + draw_rect：一次调用，不用拼 4 条线 + 角点数组
			draw_set_transform(center, bullet.rotation + deg_to_rad(bullet.hitbox_rotation), Vector2.ONE)
			draw_rect(Rect2(-bullet.hitbox_size / 2.0, bullet.hitbox_size), Color.RED, false, 1.0)
			draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
			draw_circle(center, 1.5, Color.RED)
	
	# 速度方向线（可选：每颗 3 图元，密集弹幕时开销大）
	if draw_velocity_lines:
		var vel: Vector2 = bullet.velocity
		if vel.length_squared() > 0.01:
			var dir := vel.normalized()
			var line_end: Vector2 = center + dir * 30
			draw_line(center, line_end, Color.YELLOW, 2.0)
			var arrow_size := 6.0
			var arrow_base := line_end - dir * arrow_size
			var perp := Vector2(dir.y, -dir.x) * arrow_size * 0.5
			draw_line(line_end, arrow_base + perp, Color.YELLOW, 2.0)
			draw_line(line_end, arrow_base - perp, Color.YELLOW, 2.0)
