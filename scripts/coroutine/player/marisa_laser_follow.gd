extends CoroutineScript
class_name MarisaLaserFollow
## 魔理沙非 focus 激光段：固定锚定发射口（子机）+ 贴图滚动制造流动感
## 激光根部永远在发射口，整体跟随子机，不飞走
## bullet.extra：
##   anchor_node     发射口节点（子机），无效时回退自机
##   laser_offset    相对锚点的固定偏移（(0, -i*32)）
##   segment_index   本段槽位（0..15），贴图滚动基准

const FLOW_SPEED: float = 150.0    # 贴图滚动速度（px/s，视觉流动感）
const SEG_W: float = 32.0
const SEGMENTS: int = 16

var _scroll: float = 0.0
var _segment_index: int = 0


func start(p_ctx: StageContext, p_target: Node2D = null):
	ctx = p_ctx
	if p_target:
		target = p_target
	_scroll = 0.0
	_segment_index = 0
	var extra_init: Variant = target.get("extra")
	if extra_init is Dictionary:
		_segment_index = extra_init.get("segment_index", 0)

	var tl := start_timeline()
	tl.every(0).do(func():
		if not ctx.active() or not is_instance_valid(target):
			return false
		var extra: Variant = target.get("extra")
		var off: Vector2 = Vector2.ZERO
		var anchor: Vector2 = Vector2.ZERO
		var anchor_found := false
		if extra is Dictionary:
			off = extra.get("laser_offset", Vector2.ZERO)
			var anchor_node: Variant = extra.get("anchor_node")
			if anchor_node != null and is_instance_valid(anchor_node):
				anchor = anchor_node.global_position
				anchor_found = true
		if not anchor_found:
			var player := ctx.player.get_player()
			if not is_instance_valid(player):
				return false
			anchor = player.global_position
		# 固定位置：根部永远在发射口（不漂移、不飞走）
		target.global_position = anchor + off

		# 贴图滚动：内容向上流动（几何稳定）
		_scroll += FLOW_SPEED * get_physics_process_delta_time()
		var tex_idx: int = int(_scroll / SEG_W) % SEGMENTS
		var sprite: Sprite2D = target.get_node_or_null("Sprite2D")
		if sprite:
			sprite.texture = _make_segment((_segment_index + tex_idx) % SEGMENTS)
		return true
	)
	super.start(ctx, target)


## 长贴图切片（与 cs_marisa 的切片一致）
func _make_segment(i: int) -> AtlasTexture:
	var at := AtlasTexture.new()
	at.atlas = preload("res://assets/Textures/player/marisa_option_bullet1.png")
	at.region = Rect2(i * SEG_W, 0, SEG_W, 32)
	return at
