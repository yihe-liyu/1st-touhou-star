extends CreateScript
## 自机狙散射——参数化，工厂调用

var bullet: BulletData
var count: int = 1
var spread: float = 0.0
var interval: float = 1.0
var sfx: AudioStream

func start_creating(p_ctx: StageContext):
	ctx = p_ctx
	var me := get_parent() as Node2D
	var tl := start_timeline()
	
	tl.at(0.0).every(interval).do(func():
		var p := ctx.player.get_player()
		if not p or not is_instance_valid(p): return
		var dir := (p.global_position - me.global_position).normalized()
		ctx.bullets.shoot_spread(bullet, count, spread, dir, me.global_position, sfx)
	)

	super.start_creating(p_ctx)
