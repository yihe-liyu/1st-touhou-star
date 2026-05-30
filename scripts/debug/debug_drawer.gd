# DebugDrawer.gd
# 高效的调试绘制工具 — 只在实际启用时才执行绘图逻辑
extends Node2D

var draw_enabled: bool = false

# 缓存节点引用，避免每帧字符串路径查找
@onready var bullet_manager = get_node_or_null("/root/BulletManager")
@onready var game_state = get_node_or_null("/root/GameState")

func _ready():
	set_process(false)  # 默认不开启 _process

func _input(event):
	if event.is_action_pressed("debug_toggle"):
		draw_enabled = not draw_enabled
		set_process(draw_enabled)
		# 无论是开启还是关闭，都要重绘一次！
		# 开启时：画上 debug 信息
		# 关闭时：清空画布（上一帧的残留圆圈才会消失）
		queue_redraw()

func _process(_delta):
	queue_redraw()

func _draw():
	if not draw_enabled:
		return
	
	# ── 画所有子弹判定 ──
	if bullet_manager:
		var bullets = bullet_manager.active_bullets
		for bullet in bullets:
			if not is_instance_valid(bullet) or not bullet.visible:
				continue
			
			var center = bullet.global_position
			
			match bullet.hitbox_shape:
				BulletData.HitboxShape.CIRCLE:
					var hitbox_center = center + bullet.hitbox_offset.rotated(bullet.rotation)
					draw_arc(hitbox_center, bullet.hitbox_radius, 0, TAU, 32, Color.RED, 1.0)
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
			
			# 子弹原点
			draw_circle(center, 2.0, Color.YELLOW)
			# 速度方向线 + 箭头
			var vel = bullet.velocity
			if vel.length_squared() > 0.01:
				var dir = vel.normalized()
				var line_end = center + dir * 30
				draw_line(center, line_end, Color.YELLOW, 2.0)
				# 箭头尖
				var arrow_size = 6.0
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
			var gr = player.get("graze_radius") if "graze_radius" in player else 24.0
			draw_arc(player.global_position, gr, 0, TAU, 48, Color(0.3, 0.6, 1.0, 0.6), 1.0)
			draw_arc(player.global_position, r, 0, TAU, 24, Color.CYAN, 2.0)
			draw_circle(player.global_position, 2.0, Color.CYAN)
	
	# 左上角显示弹幕计数 

	if bullet_manager:
		var count = bullet_manager.active_bullets.size()
		draw_string(                                                                              
			ThemeDB.fallback_font,                                                                 
			Vector2(64, 64),                                                                       
			"弹幕数: %d" % count,                                                                  
			HORIZONTAL_ALIGNMENT_LEFT,                                                             
			-1,                                                                                    
			32,                                                                                    
			Color.RED                                                                              
		)   

func _get_rotated_rect_corners(center: Vector2, half: Vector2, angle: float) -> PackedVector2Array:
	var corners = PackedVector2Array()
	corners.append(center + Vector2(-half.x, -half.y).rotated(angle))
	corners.append(center + Vector2(half.x, -half.y).rotated(angle))
	corners.append(center + Vector2(half.x, half.y).rotated(angle))
	corners.append(center + Vector2(-half.x, half.y).rotated(angle))
	return corners
