extends Node
## AssetRegistry — 全项目资源注册表，改一处全局生效

const enemy_visuals := {
	"blue_little_fairy":  preload("res://data/enemy_visual/blue_little_fairy.tscn"),
	"red_little_fairy":  preload("res://data/enemy_visual/red_little_fairy.tscn"),
	"green_little_fairy":  preload("res://data/enemy_visual/green_little_fairy.tscn"),
	"yellow_little_fairy":  preload("res://data/enemy_visual/yellow_little_fairy.tscn"),
	"red_middle_fairy":  preload("res://data/enemy_visual/red_middle_fairy.tscn"),
	"blue_middle_fairy":  preload("res://data/enemy_visual/blue_middle_fairy.tscn"),
	"red_big_fairy":  preload("res://data/enemy_visual/red_big_fairy.tscn"),
	"blue_big_fairy":  preload("res://data/enemy_visual/blue_big_fairy.tscn"),
	"white_huge_fairy":  preload("res://data/enemy_visual/white_huge_fairy.tscn"),
	"red_YY_jade":  preload("res://data/enemy_visual/red_YY_jade.tscn"),
	"green_YY_jade":  preload("res://data/enemy_visual/green_YY_jade.tscn"),
	"blue_YY_jade":  preload("res://data/enemy_visual/blue_YY_jade.tscn"),
	"purple_YY_jade":  preload("res://data/enemy_visual/purple_YY_jade.tscn"),
	"death":  preload("res://data/enemy_visual/death_effect.tscn"),
}

const FOG_TEXTURE: Texture2D = preload("res://assets/Textures/bullet/弹雾.png")

const bullet_configs := {
	# 微型弹
	"点弹":   {"tex": preload("res://assets/Textures/bullet/点弹.png"),   "hitbox": {"circle": 4.0, "offset": {"x": 0, "y": 0}}},
	"点棱弹":   {"tex": preload("res://assets/Textures/bullet/点棱弹.png"),   "hitbox": {"circle": 4.0, "offset": {"x": 0, "y": 0}}},
	"菌弹":   {"tex": preload("res://assets/Textures/bullet/菌弹.png"),   "hitbox": {"circle": 4.0, "offset": {"x": 0, "y": 0}}},
	# 小型弹
	"小玉":   {"tex": preload("res://assets/Textures/bullet/小玉.png"),   "hitbox": {"circle": 6.0, "offset": {"x": 0, "y": 0}}},
	"星弹":   {"tex": preload("res://assets/Textures/bullet/星弹.png"),   "hitbox": {"circle": 6.0, "offset": {"x": 0, "y": 0}}},
	"枪弹":   {"tex": preload("res://assets/Textures/bullet/枪弹.png"),   "hitbox": {"circle": 6.0, "offset": {"x": 0, "y": 0}}},
	"棱弹":   {"tex": preload("res://assets/Textures/bullet/棱弹.png"),   "hitbox": {"circle": 6.0, "offset": {"x": 0, "y": 0}}},
	"滴弹":   {"tex": preload("res://assets/Textures/bullet/滴弹.png"),   "hitbox": {"circle": 6.0, "offset": {"x": 0, "y": 0}}},
	"环玉":   {"tex": preload("res://assets/Textures/bullet/环玉.png"),   "hitbox": {"circle": 6.0, "offset": {"x": 0, "y": 0}}},
	"符札":   {"tex": preload("res://assets/Textures/bullet/符札.png"),   "hitbox": {"circle": 6.0, "offset": {"x": 0, "y": 0}}},
	"米弹":   {"tex": preload("res://assets/Textures/bullet/米弹.png"),   "hitbox": {"circle": 6.0, "offset": {"x": 0, "y": 0}}},
	"苦无":   {"tex": preload("res://assets/Textures/bullet/苦无.png"),   "hitbox": {"circle": 6.0, "offset": {"x": 0, "y": 0}}},
	"长菌弹":   {"tex": preload("res://assets/Textures/bullet/长菌弹.png"),   "hitbox": {"circle": 6.0, "offset": {"x": 0, "y": 0}}},
	"鳞弹":   {"tex": preload("res://assets/Textures/bullet/鳞弹.png"),   "hitbox": {"circle": 6.0, "offset": {"x": 0, "y": 0}}},
	# 中型弹
	"小光玉": {"tex": preload("res://assets/Textures/bullet/小光玉.png"), "hitbox": {"circle": 12.0, "offset": {"x": 0, "y": 0}}},
	
	# 自机弹
	"reimu_main":     {"tex": preload("res://assets/Textures/player/reimu_main_bullet.png"),     "hitbox": {"rect": {"w": 48, "h": 24}, "offset": {"x": 0, "y": 0}}},
	"reimu_opt1":     {"tex": preload("res://assets/Textures/player/reimu_option_bullet1.png"), "hitbox": {"circle": 12.0, "offset": {"x": 0, "y": 0}}},
	"reimu_opt2":     {"tex": preload("res://assets/Textures/player/reimu_option_bullet2.png"), "hitbox": {"rect": {"w": 120, "h": 24}, "offset": {"x": 0, "y": 0}}},
}

const sounds := {
	"shoot":    preload("res://assets/Sound/bullet01.wav"),
	"player_shoot": preload("res://assets/Sound/player_shoot.wav"),
	"enemy_die": preload("res://assets/Sound/enemy_dead.wav"),
	"player_die": preload("res://assets/Sound/player_dead.wav"),
	"graze":    preload("res://assets/Sound/graze.wav"),
	"item":     preload("res://assets/Sound/item.wav"),
	"kira":     preload("res://assets/Sound/kira.wav"),
	"stage1":     preload("res://assets/Music/THq01_02.夜间漫步.mp3"),
}

func get_bullet_tex(key: String) -> Texture2D:
	var cfg: Dictionary = bullet_configs.get(key, {})
	return cfg.get("tex")
