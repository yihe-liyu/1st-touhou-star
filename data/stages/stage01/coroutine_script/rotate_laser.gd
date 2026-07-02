extends CoroutineScript
## 让 target（激光）匀速旋转

var rot_speed: float = 2.0

func start(p_ctx: StageContext, p_target: Node2D = null):
	ctx = p_ctx
	if p_target:
		target = p_target
	var tl := start_timeline()
	tl.at(0.0).every(0.02).do(func():
		if is_instance_valid(target) and not target._dead:
			target.rotation += rot_speed * 0.02
	)
	super.start(ctx, target)
