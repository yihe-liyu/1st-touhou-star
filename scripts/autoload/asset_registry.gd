extends Node
## AssetRegistry — 全项目资源注册表，改一处全局生效

const enemy_visuals := {
	"s_red":  preload("res://data/enemy_visual/s_red.tscn"),
	"death":  preload("res://data/enemy_visual/death_effect.tscn"),
}

const bullet_configs := {
	"小玉":   {tex: preload("res://assets/Textures/bullet/小玉.png"), hitbox: [4.0]},
	"小光玉": {tex: preload("res://assets/Textures/bullet/小光玉.png"), hitbox: [4.0]},
	"点弹":   {tex: preload("res://assets/Textures/bullet/点弹.png"), hitbox: [6.0]},
	"棱弹":   {tex: preload("res://assets/Textures/bullet/棱弹.png"), hitbox: [8.0]},
	"弹雾":   {tex: preload("res://assets/Textures/bullet/弹雾.png"), hitbox: [10.0]},
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
