extends Node
## AssetRegistry — 全项目资源注册表，改一处全局生效

const enemy_visuals := {
	"s_red":  preload("res://data/enemy_visual/s_red.tscn"),
	"death":  preload("res://data/enemy_visual/death_effect.tscn"),
}

static func _circle_tex(path: String, r: float) -> Dictionary:
	return {"tex": preload(path), "shape": "circle", "size": r}

static func _rect_tex(path: String, w: float, h: float, ox: float = 0, oy: float = 0, rot: float = 0) -> Dictionary:
	return {"tex": preload(path), "shape": "rect", "size": {"w": w, "h": h}, "offset": Vector2(ox, oy), "rotation": rot}

var _bullet_configs: Dictionary
var bullet_configs: Dictionary:
	get:
		if _bullet_configs.is_empty():
			_bullet_configs = _build_bullet_configs()
		return _bullet_configs

func _build_bullet_configs() -> Dictionary:
	return {
		"小玉":   _circle_tex("res://assets/Textures/bullet/小玉.png", 4.0),
		"小光玉": _circle_tex("res://assets/Textures/bullet/小光玉.png", 4.0),
		"点弹":   _circle_tex("res://assets/Textures/bullet/点弹.png", 6.0),
		"棱弹":   _circle_tex("res://assets/Textures/bullet/棱弹.png", 8.0),
		"弹雾":   _circle_tex("res://assets/Textures/bullet/弹雾.png", 10.0),
	}

const sounds := {
	"shoot":    preload("res://assets/Sound/bullet01.wav"),
	"player_shoot": preload("res://assets/Sound/player_shoot.wav"),
	"enemy_die": preload("res://assets/Sound/enemy_dead.wav"),
	"player_die": preload("res://assets/Sound/player_dead.wav"),
	"graze":    preload("res://assets/Sound/graze.wav"),
	"item":     preload("res://assets/Sound/item.wav"),
	"bgm1":     preload("res://assets/Music/THq01_02.夜间漫步.mp3"),
}

const ui_textures := {
	"logo1": preload("res://assets/Textures/front/logo/logo1.png"),
}

const enemies := {
	"red_soldier": preload("res://data/enemies/red_soldier.gd"),
}

func get_bullet_tex(key: String) -> Texture2D:
	var cfg: Dictionary = bullet_configs.get(key, {})
	return cfg.get("tex")
