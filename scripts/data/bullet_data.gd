## 子弹配置：贴图、染色、判定、阵营、雾效
extends Resource
class_name BulletData

enum Faction {PLAYER, ENEMY, BOMB}
enum HitboxShape {CIRCLE, RECTANGLE}
enum TintMode {MULTIPLY, BLEND}

var texture: Texture2D                               ## 子弹贴图（白色/浅灰底图，用 tint 染色）
var tint_mode: TintMode = TintMode.MULTIPLY          ## MULTIPLY=乘法叠加, BLEND=灰度混合
var tint: Color = Color.WHITE                        ## 贴图染色
var damage: int = 10                                 ## 基础伤害
var velocity: Vector2 = Vector2.UP                   ## 速度向量
var hit_effect: PackedScene                          ## 击中特效
var faction: Faction = Faction.PLAYER                ## 阵营
var can_be_canceled: bool = false                    ## 是否可被 Bomb 消除
var hitbox_shape: HitboxShape = HitboxShape.CIRCLE   ## 判定形状
var hitbox_offset: Vector2 = Vector2.ZERO            ## 判定偏移
var hitbox_rotation: float = 0.0                     ## 判定旋转（弧度）
var hitbox_radius: float = 4.0                       ## 判定半径
var hitbox_size: Vector2 = Vector2(8, 8)             ## 矩形判定尺寸
var spawn_fog: bool = false                          ## 是否播弹雾特效
var fog_texture: Texture2D                           ## 弹雾贴图
var movement_script: Script                          ## 移动逻辑脚本（如诱导跟踪）

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
