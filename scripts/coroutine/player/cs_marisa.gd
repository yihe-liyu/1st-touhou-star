extends PlayerShootScript
class_name MarisaShoot

const OPTION_VISUAL = preload("res://scripts/coroutine/player/ov_marisa.gd")

const MAIN_INTERVAL: int = 3
const OPTION_INTERVAL: int = 6


func _option_setup() -> Dictionary:
	return {
		visual_script = OPTION_VISUAL,
		power_thresholds = [0, 100, 200, 300],
		counts = [1, 2, 3, 4],
		offsets_focus = [
			[Vector2(0, -40)],
			[Vector2(-10, -40), Vector2(10, -40)],
			[Vector2(-20, -30), Vector2(0, -40), Vector2(20, -30)],
			[Vector2(-30, -30), Vector2(-10, -40), Vector2(10, -40), Vector2(30, -30)],
		],
		offsets_spread = [
			[Vector2(0, -80)],
			[Vector2(-40, -80), Vector2(40, -80)],
			[Vector2(-40, -60), Vector2(0, -80), Vector2(40, -60)],
			[Vector2(-60, -60), Vector2(-20, -80), Vector2(20, -80), Vector2(60, -60)],
		],
	}


func _main_shoot(_ctx: StageContext, player: Player) -> float:
	var b := BulletData.new().tex("marisa_main").speed(2000).player()
	b.color(Color(1, 1, 1, 0.5))
	b.damage = 6
	b.hit_effect = preload("res://scenes/effect/hit_effect_marisa.tscn")
	ctx.bullets.shoot_spread(b, 1, 0.0, Vector2.UP, player.global_position + Vector2(-15, 0))
	ctx.bullets.shoot_spread(b, 1, 0.0, Vector2.UP, player.global_position + Vector2(15, 0))
	return ctx.clock.wait_frames(MAIN_INTERVAL)


func _option_shoot(_ctx: StageContext, _count: int) -> float:
	return ctx.clock.wait_frames(4)
