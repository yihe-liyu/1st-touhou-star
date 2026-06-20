# BulletData.gd
extends Resource
class_name BulletData

enum Faction {PLAYER, ENEMY, BOMB}
enum HitboxShape {CIRCLE, RECTANGLE}
enum TintMode {MULTIPLY, BLEND}

## 子弹贴图（白色/浅灰底图，用 tint 染色）
var texture: Texture2D

@export_group("Tint")
## MULTIPLY=乘法叠加, BLEND=灰度混合（白色保持不变）
var tint_mode: TintMode = TintMode.MULTIPLY
## 贴图染色
var tint: Color = Color.WHITE
@export_group("", "")

## 基础伤害值
var damage: int = 10
## 速度向量（方向+速率，会被 speed_mult 缩放）
var velocity: Vector2 = Vector2.UP
## 击中时创建的特效 PackedScene
var hit_effect: PackedScene
## 子弹阵营：自机(0) / 敌人(1) / Bomb(2)
var faction: Faction = Faction.PLAYER
## 是否可被 Bomb 消除（敌弹通常为 true）
var can_be_canceled: bool = false

@export_group("Hitbox")
## 判定形状：圆形 / 矩形
var hitbox_shape: HitboxShape = HitboxShape.CIRCLE
## 判定中心相对于子弹原点的偏移
var hitbox_offset: Vector2 = Vector2.ZERO
## [仅圆形] 判定半径
var hitbox_radius: float = 4.0
## [仅矩形] 判定宽高
var hitbox_size: Vector2 = Vector2(8, 8)
## [仅矩形] 相对子弹朝向的额外旋转（弧度）
var hitbox_rotation: float = 0.0
## 移动逻辑脚本。留空则默认直线飞行
var movement_script: Script

## ---- 构造链方法 ----
func tex(key: String) -> BulletData:
	texture = AssetRegistry.bullet_textures.get(key, texture)
	match key:
		"小玉", "小光玉":
			hitbox_shape = HitboxShape.CIRCLE
			hitbox_radius = 4.0
		"点弹":
			hitbox_shape = HitboxShape.CIRCLE
			hitbox_radius = 6.0
		"棱弹":
			hitbox_shape = HitboxShape.CIRCLE
			hitbox_radius = 8.0
		"弹雾":
			hitbox_shape = HitboxShape.CIRCLE
			hitbox_radius = 10.0
	return self

func speed(v: float) -> BulletData:
	velocity.y = v
	return self

func dir(x: float, y: float) -> BulletData:
	velocity = Vector2(x, y)
	return self

func color(c: Color) -> BulletData:
	tint = c
	return self

func blend(b: bool) -> BulletData:
	tint_mode = TintMode.BLEND if b else TintMode.MULTIPLY
	return self

func enemy() -> BulletData:
	faction = Faction.ENEMY
	can_be_canceled = true
	hitbox_shape = HitboxShape.CIRCLE
	hitbox_radius = 4.0
	return self

func player() -> BulletData:
	faction = Faction.PLAYER
	can_be_canceled = false
	damage = 10
	return self
