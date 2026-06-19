extends MoveScript

var accel := Vector2.DOWN * 150.0

func start_moving(p_ctx: StageContext, p_target: Node2D):
	ctx = p_ctx
	target = p_target
	
	var b := p_target as Bullet
	if b:
		target.global_position += b.velocity / Engine.physics_ticks_per_second
		b.rotation = b.velocity.angle()
	
	var tl := start_timeline()
	
	tl.at(0).every(1.0/60.0).do(func():
		var bullet := target as Bullet
		if bullet:
			bullet.velocity += accel / Engine.physics_ticks_per_second
			target.global_position += bullet.velocity / Engine.physics_ticks_per_second
			bullet.rotation = bullet.velocity.angle()
	)

	super.start_moving(p_ctx, target)
