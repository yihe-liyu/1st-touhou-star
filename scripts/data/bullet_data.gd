## 子弹配置：贴图、染色、判定、阵营、雾效
extends Resource
class_name BulletData

enum Faction {PLAYER, ENEMY, BOMB}
enum HitboxShape {CIRCLE, RECTANGLE}
enum TintMode {MULTIPLY, BLEND}

var texture: Texture2D
var tint_mode: TintMode = TintMode.MULTIPLY
var tint: Color = Color.WHITE
var damage: int = 10
var velocity: Vector2 = Vector2.UP
var hit_effect: PackedScene
var faction: Faction = Faction.PLAYER
var can_be_canceled: bool = false
var hitbox_shape: HitboxShape = HitboxShape.CIRCLE
var hitbox_offset: Vector2 = Vector2.ZERO
var hitbox_radius: float = 4.0
var hitbox_size: Vector2 = Vector2(8, 8)
var hitbox_rotation: float = 0.0
var spawn_fog: bool = false
var fog_texture: Texture2D

## ---- 构造链方法 ----
func tex(key: String) -> BulletData:
	texture = AssetRegistry.get_bullet_tex(key)
	var cfg: Dictionary = AssetRegistry.bullet_configs.get(key, {})
	var hb: Dictionary = cfg.get("hitbox", {})
	if hb.has("circle"):
		hitbox_shape = HitboxShape.CIRCLE
		hitbox_radius = hb["circle"]
	elif hb.has("rect"):
		hitbox_shape = HitboxShape.RECTANGLE
		var r: Dictionary = hb["rect"]
		hitbox_size = Vector2(r.get("w", 48), r.get("h", 24))
		hitbox_rotation = r.get("rotation", 0.0)
	var off: Dictionary = hb.get("offset", {"x": 0, "y": 0})
	hitbox_offset = Vector2(off.get("x", 0), off.get("y", 0))
	fog_texture = AssetRegistry.FOG_TEXTURE
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
	spawn_fog = true
	hitbox_shape = HitboxShape.CIRCLE
	hitbox_radius = 4.0
	return self

func player() -> BulletData:
	faction = Faction.PLAYER
	can_be_canceled = false
	damage = 10
	return self
