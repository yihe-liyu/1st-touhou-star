class_name BackgroundEnvPreset
extends Resource

## 背景环境预设：一套参数构建全新 Environment（雾/天空/glow）
## - build_environment() 每次返回全新实例 → 多实例/重跑零共享污染（根治"越重跑越暗"）
## - 联动内建：link_ground_to_fog=true 时天球地面水平色自动跟随雾色（防"改雾色露地平线"）
## 用途：新建关卡背景 = 新建一个 .tres 预设 + 场景拼装，不再手写环境代码

# ── 雾 ──
@export var fog_enabled: bool = true
@export var fog_color: Color = Color(0.18, 0.20, 0.23)
@export var fog_density: float = 0.15
@export var fog_sky_affect: float = 0.0

# ── 天空 ──
@export var sky_top: Color = Color(0.20, 0.24, 0.30)
@export var sky_horizon: Color = Color(0.26, 0.28, 0.31)
@export var sky_curve: float = 0.35
@export var sky_energy_multiplier: float = 1.0
@export var ground_energy_multiplier: float = 1.0

## 联动开关：天球地面水平色 = 雾色（默认开，改雾色不露地平线）
@export var link_ground_to_fog: bool = true
## 天球地面水平色（link_ground_to_fog=false 时用独立值）
@export var ground_horizon_color: Color = Color(0.18, 0.20, 0.23)
## 天球地面底色（更深，独立值——约雾色×0.75）
@export var ground_bottom_color: Color = Color(0.14, 0.15, 0.17)

# ── 泛光 ──
@export var glow_enabled: bool = true
@export var glow_intensity: float = 0.8
@export var glow_bloom: float = 0.1
@export var glow_blend_mode: Environment.GlowBlendMode = Environment.GLOW_BLEND_MODE_ADDITIVE


## 构建全新 Environment（每次 new → 实例私有，无共享污染）
func build_environment() -> Environment:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY

	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = sky_top
	sky_mat.sky_horizon_color = sky_horizon
	sky_mat.sky_curve = sky_curve
	sky_mat.sky_energy_multiplier = sky_energy_multiplier
	sky_mat.ground_energy_multiplier = ground_energy_multiplier
	sky_mat.ground_horizon_color = fog_color if link_ground_to_fog else ground_horizon_color
	sky_mat.ground_bottom_color = ground_bottom_color

	env.sky = Sky.new()
	env.sky.sky_material = sky_mat

	env.fog_enabled = fog_enabled
	env.fog_light_color = fog_color
	env.fog_density = fog_density
	env.fog_sky_affect = fog_sky_affect

	env.glow_enabled = glow_enabled
	env.glow_intensity = glow_intensity
	env.glow_bloom = glow_bloom
	env.glow_blend_mode = glow_blend_mode

	return env
