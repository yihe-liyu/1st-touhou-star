extends CoroutineScript
class_name MarisaLaserFollow
## 魔理沙非 focus 激光段：从发射口（子机）生成，向上漂移
## 每段 drift 从 0 开始（根部在子机），段间距 = 漂移速度 × 生成间隔（自动无缝）
## 松开射击（非 focus）时整条激光渐隐消失
## bullet.extra：
##   anchor_node   发射口节点（子机），无效时回退自机
##   laser_offset  相对锚点偏移（默认 (0,0) = 在发射口生成）
##   drift_speed   向上漂移速度

const FADE_TIME: float = 0.4   # 渐隐时长（秒）

var _drift: float = 0.0
var _fading: bool = false
var _fade_t: float = 0.0


func start(p_ctx: StageContext, p_target: Node2D = null):
	ctx = p_ctx
	if p_target:
		target = p_target
	_drift = 0.0
	_fading = false
	_fade_t = 0.0

	var tl := start_timeline()
	tl.every(0).do(func():
		if not ctx.active() or not is_instance_valid(target):
			return false
		var dt := get_physics_process_delta_time()

		# 松开射击 或 进入 focus → 开始渐隐（激光只在"非focus+按住射击"时存在）
		if not _fading and (not Input.is_action_pressed("shoot") or Input.is_action_pressed("focus")):
			_fading = true
			_fade_t = FADE_TIME

		if _fading:
			_fade_t -= dt
			var alpha := clampf(_fade_t / FADE_TIME, 0.0, 1.0)
			var sprite: Sprite2D = target.get_node_or_null("Sprite2D")
			if sprite:
				sprite.modulate.a = alpha  # MultiMesh 用 sprite.modulate 上色 → 淡出生效
			if _fade_t <= 0.0:
				BulletManager.return_bullet(target)  # 淡完回收
				return false  # 协程结束
			return true

		var extra: Variant = target.get("extra")
		var off: Vector2 = Vector2.ZERO
		var drift_speed: float = 0.0
		var anchor: Vector2 = Vector2.ZERO
		var anchor_found := false
		if extra is Dictionary:
			off = extra.get("laser_offset", Vector2.ZERO)
			drift_speed = extra.get("drift_speed", 0.0)
			var anchor_node: Variant = extra.get("anchor_node")
			if anchor_node != null and is_instance_valid(anchor_node):
				anchor = anchor_node.global_position
				anchor_found = true
		if not anchor_found:
			var player := ctx.player.get_player()
			if not is_instance_valid(player):
				return false
			anchor = player.global_position
		# 位置 = 发射口 + 偏移 + 向上漂移（drift 独立累积）
		target.global_position = anchor + off + Vector2(0, -_drift)
		_drift += drift_speed * dt
		return true
	)
	super.start(ctx, target)
