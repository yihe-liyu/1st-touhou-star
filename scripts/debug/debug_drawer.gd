# DebugDrawer.gd
# 高效的调试绘制工具 — 只在实际启用时才执行绘图逻辑
extends Node2D

var draw_enabled: bool = false

# 缓存节点引用，避免每帧字符串路径查找
@onready var bullet_manager = get_node_or_null("/root/BulletManager")
@onready var game_state = get_node_or_null("/root/GameState")

# 屏幕可见区域缓存（用于裁剪）
var viewport_rect: Rect2

# 文字更新节流
var _frame_counter: int = 0
var _bullet_count_text: String = "弹幕数: 0"

func _ready():
	# 初始时 process 禁用，等按了 debug_toggle 再开启
	set_process(false)

func _input(event):
	if event.is_action_pressed("debug_toggle"):
		draw_enabled = not draw_enabled
		set_process(draw_enabled)  # 只在启用时才跑 _process！
		if draw_enabled:
			queue_redraw()  # 开启时立即画一帧

func _process(_delta):
	# 节流：每 10 帧才更新文字，减少 draw_string 开销
	_frame_counter += 1
	if _frame_counter >= 10:
		_frame_counter = 0
		var count = bullet_manager.active_bullets.size() if bullet_manager else 0
		_bullet_count_text = "弹幕数: %d" % count
	
	queue_redraw()

func _draw():
	if not draw_enabled:
		return
	
	# 更新可见区域（用于裁剪）
	if bullet_manager:
		viewport_rect = get_viewport_rect()
	
	# ── 画所有子弹判定 ──
	if bullet_manager:
		var bullets = bullet_manager.active_bullets
		var view_center = viewport_rect.get_center()
		var view_extents = viewport_rect.size.length() * 0.8
		
		for bullet in bullets:
			if not is_instance_valid(bullet) or not bullet.visible:
				continue
			
			# 裁剪：跳过屏幕外的子弹
			if bullet_manager:
				var dist = bullet.global_position.distance_squared_to(view_center)
				if dist > view_extents * view_extents:
					continue
			
			var center = bullet.global_position
			
			match bullet.hitbox_shape:
				BulletData.HitboxShape.CIRCLE:
					var hitbox_center = center + bullet.hitbox_offset.rotated(bullet.rotation)
					var segments = 16 if bullet.hitbox_radius > 8 else 12
					draw_arc(hitbox_center, bullet.hitbox_radius, 0, TAU, segments, Color.RED, 1.0)
					draw_circle(hitbox_center, 1.5, Color.RED)
				
				BulletData.HitboxShape.RECTANGLE:
					var box_center = center + bullet.hitbox_offset.rotated(bullet.rotation)
					var half = bullet.hitbox_size / 2.0
					var angle = bullet.rotation + deg_to_rad(bullet.hitbox_rotation)
					var corners = _get_rotated_rect_corners(box_center, half, angle)
					for i in range(4):
						var next = (i + 1) % 4
						draw_line(corners[i], corners[next], Color.RED, 1.0)
					draw_circle(box_center, 1.5, Color.RED)
			
			# 子弹超过 200 发时跳过细节（方向箭头等）
			if bullets.size() <= 200:
				draw_circle(center, 2.0, Color.YELLOW)
				var vel = bullet.velocity
				if vel.length_squared() > 0.01:
					var dir = vel.normalized()
					var line_end = center + dir * 40
					draw_line(center, line_end, Color.YELLOW, 2.0)
					var arrow_size = 8.0
					var arrow_base = line_end - dir * arrow_size
					var perp = Vector2(dir.y, -dir.x) * arrow_size * 0.5
					draw_line(line_end, arrow_base + perp, Color.YELLOW, 2.0)
					draw_line(line_end, arrow_base - perp, Color.YELLOW, 2.0)
	
	# ── 画所有敌人判定 ──
	if game_state:
		var enemies = game_state.get_active_enemies()
		for enemy in enemies:
			if not is_instance_valid(enemy):
				continue
			var radius = enemy.get("hitbox_radius") if "hitbox_radius" in enemy else 8.0
			draw_arc(enemy.global_position, radius, 0, TAU, 24, Color.GREEN, 1.5)
			draw_circle(enemy.global_position, 2.0, Color.GREEN)
	
	# ── 画玩家判定 ──
	if game_state:
		var player = game_state.player
		if is_instance_valid(player):
			var r = player.get("hitbox_radius") if "hitbox_radius" in player else 2.0
			draw_arc(player.global_position, r, 0, TAU, 24, Color.CYAN, 2.0)
			draw_circle(player.global_position, 2.0, Color.CYAN)
	
	# 右上角显示弹幕计数（使用节流后的文字）
	draw_string(
		ThemeDB.fallback_font,
		Vector2(20, 40),
		_bullet_count_text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		16,
		Color.RED
	)

func _get_rotated_rect_corners(center: Vector2, half: Vector2, angle: float) -> PackedVector2Array:
	var corners = PackedVector2Array()
	corners.append(center + Vector2(-half.x, -half.y).rotated(angle))
	corners.append(center + Vector2(half.x, -half.y).rotated(angle))
	corners.append(center + Vector2(half.x, half.y).rotated(angle))
	corners.append(center + Vector2(-half.x, half.y).rotated(angle))
	return corners