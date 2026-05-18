# DebugDrawer.gd
extends Node2D

var draw_enabled: bool = false

func _input(event):
	if event.is_action_pressed("debug_toggle"):
		draw_enabled = not draw_enabled

func _process(_delta):
	queue_redraw()

func _draw():
	if not draw_enabled:
		return
	
	# ── 画所有子弹判定 ──
	var bullets = get_node("/root/BulletManager").active_bullets if has_node("/root/BulletManager") else []
	for bullet in bullets:
		if not is_instance_valid(bullet) or not bullet.visible:
			continue
		
		match bullet.hitbox_shape:
			BulletData.HitboxShape.CIRCLE:
				var center = bullet.global_position + bullet.hitbox_offset.rotated(bullet.rotation)
				_draw_circle(center, bullet.hitbox_radius, Color.RED, false, 1.0)
				_draw_circle(center, 1.0, Color.RED, true) # 中心点
			
			BulletData.HitboxShape.RECTANGLE:
				var box_center = bullet.global_position + bullet.hitbox_offset.rotated(bullet.rotation)
				var half = bullet.hitbox_size / 2.0
				var angle = bullet.rotation + deg_to_rad(bullet.hitbox_rotation)
				var corners = _get_rotated_rect_corners(box_center, half, angle)
				_draw_polygon(corners, Color.RED, false, 1.0)
				_draw_circle(box_center, 1.0, Color.RED, true)
		
		# 画子弹原点
		_draw_circle(bullet.global_position, 2.0, Color.YELLOW, true)
		# 画速度方向线
		var dir = bullet.velocity.normalized()
		var line_start = bullet.global_position
		var line_end = bullet.global_position + dir * 40 # 从 20 改成 40，更长
		draw_line(line_start, line_end, Color.YELLOW, 3.0) # 线宽从 1.0 改成 3.0

		# 画箭头尖（三角形）
		var arrow_size = 8.0
		var arrow_base = line_end - dir * arrow_size
		var arrow_left = arrow_base + Vector2(dir.y, -dir.x) * arrow_size * 0.5
		var arrow_right = arrow_base + Vector2(-dir.y, dir.x) * arrow_size * 0.5
		draw_line(line_end, arrow_left, Color.YELLOW, 3.0)
		draw_line(line_end, arrow_right, Color.YELLOW, 3.0)
	
	# ── 画所有敌人判定 ──
	var enemies = get_node("/root/GameState").get_active_enemies() if has_node("/root/GameState") else []
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		
		var radius = enemy.hitbox_radius if "hitbox_radius" in enemy else 8.0
		_draw_circle(enemy.global_position, radius, Color.GREEN, false, 1.5)
		_draw_circle(enemy.global_position, 2.0, Color.GREEN, true)
	
	# ── 画玩家判定 ──
	var player = get_node("/root/GameState").player if has_node("/root/GameState") else null
	if is_instance_valid(player):
		var r = player.get("hitbox_radius") if "hitbox_radius" else 2.0
		_draw_circle(player.global_position, r, Color.CYAN, false, 2.0)
		_draw_circle(player.global_position, 2.0, Color.CYAN, true)
		
	var count = bullets.size()
	# 在屏幕左上角画红色文字
	draw_string(
		ThemeDB.fallback_font,
		Vector2(20, 40),
		"弹幕数: %d" % count,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		16,
		Color.RED
	)

# ── 辅助：画圆形边框 ──

func _draw_circle(center: Vector2, radius: float, color: Color, filled: bool = false, width: float = 1.0):
	if filled:
		draw_circle(center, radius, color)
	else:
		draw_arc(center, radius, 0, TAU, 32, color, width)

# ── 辅助：画旋转矩形 ──

func _get_rotated_rect_corners(center: Vector2, half: Vector2, angle: float) -> PackedVector2Array:
	var corners = PackedVector2Array()
	corners.append(center + Vector2(-half.x, -half.y).rotated(angle))
	corners.append(center + Vector2(half.x, -half.y).rotated(angle))
	corners.append(center + Vector2(half.x, half.y).rotated(angle))
	corners.append(center + Vector2(-half.x, half.y).rotated(angle))
	return corners

func _draw_polygon(corners: PackedVector2Array, color: Color, filled: bool, width: float):
	if filled:
		draw_polygon(corners, [color])
	else:
		for i in range(corners.size()):
			var next = (i + 1) % corners.size()
			draw_line(corners[i], corners[next], color, width)
