# Godot 4.7.1 3D 节点与环境系统学习笔记

> 学习记录：Environment / WorldEnvironment / Sky / 光照 / Camera3D / 雾系统
> 依据：本机 `godot --doctool` 导出的官方类参考 + 项目内实测验证
> 生成时间：配合 stage01 背景调试（"除了天空全暗"问题的排查与修复）期间整理

---

## 0. 一句话总览

- **WorldEnvironment** 是挂在场景树里的一个节点，作用是给**所在 Viewport** 提供一份 `Environment` 资源（环境参数集合：天空、雾、光照、后处理）。
- **Environment** 是纯数据资源（Resource），包含 100 个成员，按功能分 10 组（见 §2）。
- 渲染时每个 Viewport 最终只有**一份生效的 Environment**，解析顺序：Camera3D 自带的 `environment` > 该 Viewport 的 `WorldEnvironment` 节点 > 项目设置 `rendering/environment/defaults/default_environment`。
- 本项目的背景（`stage01_background.tscn`）就是在 Stage01Background 下挂一个 WorldEnvironment，程序化生成 Environment + ProceduralSkyMaterial（见 `stage01_decor.gd:_reset_environment()`）。

---

## 1. 3D 场景基础架构（谁管谁）

### 1.1 World3D（资源，非节点）
每个 3D 渲染的 Viewport 内部有一个 World3D，聚合了：
- `fallback_environment` / `fallback_sky`：Viewport 没找到 Environment/Sky 时兜底
- `camera`（当前激活的 Camera3D）、`direct_space`（物理空间）、`navigation_map`

### 1.2 Viewport（SubViewport / Window）
- 3D 渲染以 Viewport 为单位；本项目背景渲到 `SubViewport`（game_scene 里 768×896），再经 SubViewportContainer 显示。
- 每个 Viewport 最多一个 WorldEnvironment 生效。

### 1.3 Camera3D 要点（类参考）
| 成员 | 默认 | 说明 |
|---|---|---|
| `projection` | 0 = PERSPECTIVE | 1 = ORTHOGONAL，2 = FRUSTUM |
| `fov` | **75.0** | 透视投影 FOV（度）。注意：**本项目 tscn 里是 55.0，且用户本地改成过 90**——FOV 直接决定远处地面/地平线在屏幕上的位置，调试"远处黑块"时必须用与实机一致的 FOV |
| `keep_aspect` | 1 = KEEP_HEIGHT | 竖屏（本项目 768×896）用 KEEP_HEIGHT，fov 是垂直方向 |
| `near` / `far` | 0.05 / 4000 | 裁剪平面；本项目地面最远 z=-318，远得绰绰有余 |
| `cull_mask` | 1048575（全层） | 位掩码控制渲染哪些层 |
| `current` | false | 是否当前相机；`make_current()` / `clear_current()` |
| `environment` | 空 | **相机级 Environment 覆盖**（比 WorldEnvironment 优先） |
| `attributes` | 空 | CameraAttributes（曝光/DOF 等，见 §7） |

实用方法：`project_position(screen_pt, z_depth)`（屏幕→世界）、`unproject_position(world_pt)`（世界→屏幕）、`project_ray_origin/project_ray_normal`（屏幕点→射线，做拾取/测距）。

> ⚠️ 本项目坑（实测）：Compatibility (OpenGL) 渲染器下，fragment shader 里 `VIEW` 返回 0、`POSITION` 不可用；依赖这些内建的 shader 在两种渲染器下表现不一致。调试画面问题时必须注明渲染器（opengl3 / vulkan）。

---

## 2. Environment 资源 10 大功能组（全部成员+默认值）

### 2.1 背景 Background
| 成员 | 默认 | 说明 |
|---|---|---|
| `background_mode` | 0 = BG_CLEAR_COLOR | 1=BG_COLOR（纯色）2=BG_SKY（天空材质）3=BG_CANVAS 4=BG_KEEP 5=BG_CAMERA_FEED |
| `background_color` | Color(0,0,0,1) | BG_COLOR 模式 |
| `background_energy_multiplier` | 1.0 | **本项目 tscn 设为 2.0**：天空整体亮度 ×2 |
| `background_intensity` | 30000 | 物理单位模式下的亮度 |

### 2.2 天空 Sky（配 Sky 资源，见 §3）
| 成员 | 默认 | 说明 |
|---|---|---|
| `sky` | 空 | Sky 资源 |
| `sky_rotation` | (0,0,0) | 旋转天空 |
| `sky_custom_fov` | 0.0 | 0 = 跟随相机 FOV；>0 自定义 |

### 2.3 环境光 Ambient Light
| 成员 | 默认 | 说明 |
|---|---|---|
| `ambient_light_source` | 0 = AMBIENT_SOURCE_BG | 1=DISABLED 2=COLOR 3=SKY |
| `ambient_light_color` | (0,0,0,1) | COLOR 模式颜色 |
| `ambient_light_energy` | 1.0 | |
| `ambient_light_sky_contribution` | 1.0 | SKY 模式下天空光占比（本项目暗场景靠它提供基础照明） |

### 2.4 雾 Fog（本项目重点！）
| 成员 | 默认 | 说明 |
|---|---|---|
| `fog_enabled` | false | 总开关 |
| `fog_mode` | 0 = FOG_MODE_EXPONENTIAL | 1 = FOG_MODE_DEPTH（显式距离渐变） |
| `fog_density` | 0.01 | **指数雾密度**。实测公式：`fog = 1 - exp2(-density × depth)`（exp2 即 2^x，见 §8 实测表） |
| `fog_depth_begin` | 10.0 | DEPTH 模式：雾开始距离 |
| `fog_depth_end` | 100.0 | DEPTH 模式：雾完全距离 |
| `fog_depth_curve` | 1.0 | DEPTH 模式：中间过渡曲线（<1 缓入 >1 缓出） |
| `fog_height` | 0.0 | 高度雾基准面（仅低于该高度的物体受雾影响） |
| `fog_height_density` | 0.0 | 高度雾衰减率（越大越贴近地面，>0 开启高度雾） |
| `fog_light_color` | (0.518,0.553,0.608) | **雾色。Godot 默认是浅蓝灰！** 本项目改成暗蓝灰 (0.18,0.20,0.23) |
| `fog_light_energy` | 1.0 | 雾亮度系数 |
| `fog_sky_affect` | 1.0 | **默认雾会染天空**；本项目设 0.0 → 天空保持亮，只有地面/物体被雾化（这是"天空亮、其余暗"现象的根源） |
| `fog_aerial_perspective` | 0.0 | 空气透视（雾对天空的影响量，>0 时远处天空也会带雾色，让地平线更"连"） |
| `fog_sun_scatter` | 0.0 | 太阳光散射量（配 DirectionalLight3D，制造"雾中阳光"感） |

**两种雾模式实测对比（无屏幕雾，t20，相机抬高）：**
- 指数 0.014：y160（≈150m 处）亮度 0.51，雾 ≈86%（中远偏重，尾部长）
- DEPTH 80→260：y160 亮度 0.62，雾 ≈44%（近处更清、远处 260m 封顶全雾）
- 结论：想要"近清远糊"的**可控渐变**选 FOG_MODE_DEPTH；想要指数自然的选 EXPONENTIAL。

### 2.5 体积雾 Volumetric Fog（真体积雾，FogVolume 配合）
| 成员 | 默认 | 说明 |
|---|---|---|
| `volumetric_fog_enabled` | false | 总开关（仅 Forward+/Mobile 渲染器支持，Compatibility 不支持！） |
| `volumetric_fog_density` | 0.05 | |
| `volumetric_fog_albedo` | (1,1,1,1) | 散射反照率 |
| `volumetric_fog_emission` / `_energy` | (0,0,0) / 1.0 | 自发光（做雾中发光体） |
| `volumetric_fog_anisotropy` | 0.2 | 各向异性（阳光穿透效果） |
| `volumetric_fog_length` | 64.0 | 体积雾距离范围 |
| `volumetric_fog_sky_affect` | 1.0 | |
| `volumetric_fog_gi_inject` | 1.0 | 注入 GI |
| `volumetric_fog_temporal_reprojection_*` | true / 0.9 | 时域重投影（防闪烁） |
| `volumetric_fog_detail_spread` | 2.0 | 细节噪声尺度 |

配套 FogVolume 节点（VisualInstance3D）：`shape`（3=WORLD 等）+ FogMaterial（`density`、`albedo`、`emission`、`height_falloff`、`edge_fade`）。→ 对应 BACKGROUND_VISUAL_PLAN.md 的"彩蛋 H2 真体积雾"。

### 2.6 环境光遮蔽/反射 SSAO / SSIL / SSR / SDFGI
- `ssao_enabled` / `ssao_intensity`(2.0) / `ssao_radius`(1.0) / `ssao_power`(1.5)：屏幕空间环境遮蔽
- `ssil_enabled` / `ssil_intensity`(1.0)：屏幕空间间接光照
- `ssr_enabled` / `ssr_max_steps`(64)：屏幕空间反射
- `sdfgi_enabled`：有向距离场 GI（大场景全局光；本项目不需要）
- ⚠️ 以上大多仅 Forward+/Mobile 支持，Compatibility 部分无效。

### 2.7 泛光 Glow（本项目太阳辉光在用）
| 成员 | 默认 | 说明 |
|---|---|---|
| `glow_enabled` | false | **本项目 true** |
| `glow_blend_mode` | 1 = SCREEN | 0=ADDITIVE(本项目用这个) 2=SOFTLIGHT 3=REPLACE 4=MIX |
| `glow_intensity` | 0.3 | 本项目 0.8 |
| `glow_bloom` | 0.0 | 模糊扩散量（本项目 0.1） |
| `glow_strength` | 1.0 | |
| `glow_levels/1..7` | 0,0.8,0.4,0.1,... | 各模糊级别权重（HDR 亮斑分层） |
| `glow_hdr_threshold` | 1.0 | 只对亮度>阈值 的像素泛光（太阳用 EMISSION 超 HDR 才能触发） |
| `glow_normalized` / `glow_mix` / `glow_map` | ... | 归一化/混合/遮罩 |

### 2.8 色调映射 Tonemap（影响最终明暗！）
| 成员 | 默认 | 说明 |
|---|---|---|
| `tonemap_mode` | 0 = TONE_MAPPER_LINEAR | 1=REINHARDT 2=FILMIC 3=ACES 4=AGX |
| `tonemap_exposure` | 1.0 | 曝光 |
| `tonemap_white` | 1.0 | |
| `tonemap_agx_contrast` / `_white` | 1.25 / 16.29 | AGX 专用 |

> 注意：**本项目的 Environment 没有显式设置 tonemap_mode → 走类默认 LINEAR（0）**。线性映射下场景线性色直接显示，改色调映射器（如 ACES/AGX 更"电影感"但更暗）会影响整体观感，调试亮度时先确认这项。

### 2.9 调整 Adjustment
`adjustment_enabled` + `brightness/contrast/saturation/color_correction`：简单后处理调色（画面整体偏暗时可先试这个）。

### 2.10 相机属性 CameraAttributes（资源）
`auto_exposure_enabled` / `auto_exposure_scale(0.4)` / `auto_exposure_speed(0.5)` / `exposure_multiplier(1.0)` / `exposure_sensitivity(100)` + DOF/Bloom 相关。
挂在 WorldEnvironment.camera_attributes 或 Camera3D.attributes 上。

---

## 3. 天空材质（3 种）

### 3.1 ProceduralSkyMaterial（本项目用）
| 成员 | 默认 | 本项目 |
|---|---|---|
| `sky_top_color` | (0.385,0.454,0.55) | (0.20,0.24,0.30) 天顶暗蓝灰 |
| `sky_horizon_color` | (0.646,0.656,0.671) | (0.26,0.28,0.31) 地平线（曾 0.42 形成"亮天空→暗天球"分界，压暗后消除） |
| `sky_curve` | 0.15 | 0.35（天顶↔地平线过渡锐度） |
| `ground_horizon_color` | (0.646,...) | (0.18,0.20,0.23) = **雾色**（关键联动：地面平面边缘外的区域显示天球地面色，必须与 fog_light_color 一致才不会"露馅"） |
| `ground_bottom_color` | (0.2,0.169,0.133) | (0.14,0.15,0.17) |
| `ground_curve` | 0.02 | 默认 |
| `sun_angle_max` / `sun_curve` | 30 / 0.15 | 太阳位置由 DirectionalLight3D 决定（sky_mode=Sky.SKY_MODE_LIGHT 时） |
| `energy_multiplier` / `ground_energy_multiplier` / `sky_energy_multiplier` | 1.0 | 整体/地面/天空亮度 |

**关键理解：ProceduralSky 不是"穹顶贴图"，是实时算的。下半球（地平线下）渲染 ground 系列色——当相机抬高、地面平面盖不住远处时，屏幕下部显示的就是天球 ground 色。**（"除了天空全暗"的平板区域就是它，修复手段是加深地面平面 256→512。）

### 3.2 PhysicalSkyMaterial（物理大气）
`turbidity(10)` / `rayleigh_coefficient(2.0)` / `rayleigh_color(0.3,0.405,0.6)` / `mie_coefficient(0.005)` / `mie_color(0.69,0.729,0.812)` / `mie_eccentricity(0.8)` / `sun_disk_scale(1.0)` / `ground_color(0.1,0.07,0.034)`。适合真实天空，但不易精确调色。

### 3.3 PanoramaSkyMaterial（全景贴图）
`panorama`（纹理）+ `filter` + `energy_multiplier`。换一种画风（手绘黄昏背景）时用。

### 3.4 Sky 资源本身
`radiance_size`（默认 3 = 256px，影响反射/环境光细节）、`process_mode`、`sky_material`。

---

## 4. 光照节点

### 4.1 Light3D 基类
| 成员 | 默认 | 说明 |
|---|---|---|
| `light_color` | (1,1,1,1) | 本项目 Sun 初始为黑色，开场后 tween 回白色（"日食结束日出"） |
| `light_energy` | 1.0 | 本项目 Sun 从 0.0 tween 升（setup_sun/set_sun_energy） |
| `light_indirect_energy` | 1.0 | GI/环境光间接贡献 |
| `light_specular` | 1.0 | 高光强度 |
| `light_volumetric_fog_energy` | 1.0 | 体积雾贡献 |
| `shadow_enabled` | false | 本项目关（性能） |
| `shadow_bias` / `shadow_normal_bias` | 0.1 / 2.0 | 阴影偏移防自阴影 |

### 4.2 DirectionalLight3D（平行光=太阳）
`sky_mode`（0=SKY_MODE_LIGHT_AND_SKY：平行光同时驱动天空太阳位置+照亮物体；1=LIGHT_ONLY 2=SKY_ONLY）、`directional_shadow_mode`（2=SHADOW_PARALLEL_4_SPLITS）、`directional_shadow_max_distance`(100)、`directional_shadow_blend_splits`、`light_size`（软阴影）。注意：**太阳在天空里的位置由 DirectionalLight3D 的旋转决定**，调太阳位置改 light 的 rotation（项目里 `set_sun_rotation`）。

### 4.3 OmniLight3D / SpotLight3D
点光（`omni_range`/`omni_attenuation`）、聚光（`spot_range`/`spot_angle`/`spot_attenuation`）。暗背景里给局部补光（如树丛、神社）可用。

---

## 5. 网格 Mesh（本项目地面）

### 5.1 PlaneMesh（本项目 Ground 用）
- `size` Vector2（**本项目 (256,512)**，原 (256,256)——太浅盖不住抬高相机的视野）
- `orientation`（默认 1 = 面朝 Y 轴正方向）
- `center_offset`（默认 (0,0,0)，中心对齐；本项目节点 y=1 z=-62 定位）
- `subdivide_width/depth`（默认 0：**4 顶点平面**，与自定义 shader 的 UV 平铺配合做滚动地面）

### 5.2 QuadMesh
面向相机 Z 的矩形，做公告板/贴图（太阳精灵等）。QuadMesh 默认朝 -Z。

### 5.3 MeshInstance3D
`mesh` + 继承 GeometryInstance3D（`material_override`、`cast_shadow`、`visibility_range_*`——距离淡出/隐藏用这个！树/装饰远距离消失可考虑 `visibility_range_begin/end_margin`）。

---

## 6. 本项目环境参数速查（stage01_background.tscn + stage01_decor.gd）

```gdscript
# _reset_environment() 摘要（与 tscn 合并后的生效值）
env.background_mode = Environment.BG_SKY        # 天空背景
env.background_energy_multiplier = 2.0          # (tscn) 天空×2
sky.sky_top_color      = Color(0.20, 0.24, 0.30)
sky.sky_horizon_color  = Color(0.26, 0.28, 0.31)  # 压暗过（0.42→0.26）
sky.ground_horizon_color = Color(0.18, 0.20, 0.23) # = 雾色（联动）
sky.ground_bottom_color  = Color(0.14, 0.15, 0.17)
env.fog_enabled = true
env.fog_light_color = Color(0.18, 0.20, 0.23)   # 原纯黑→暗蓝灰
env.fog_density   = 0.15 → tween → 0.014        # 修复后目标值（原 0.04 近处也压太重）
env.fog_sky_affect = 0.0                        # 雾不染天空
env.glow_enabled = true; glow_intensity=0.8; glow_bloom=0.1
env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
# Sun: DirectionalLight3D，light_energy 0→? tween，shadow 关
```

**四色联动规则（改雾色时必须一起改，否则露馅/分界线）：**
1. `fog_light_color`（Environment）
2. `ground_horizon_color`（ProceduralSky，地面平面外露出的区域）
3. `ground_bottom_color`（同上，更深处）
4. tscn 里 Environment 的 `fog_light_color`（序列化一份）

---

## 7. 性能与兼容性备忘

- Compatibility (OpenGL) 渲染器：无体积雾、无 SDFGI、fragment 内建 `VIEW/POSITION` 异常；SSAO/SSR 部分不支持。**本项目主要跑 Compatibility**（`--rendering-driver opengl3` 验证），上真机默认 Forward+（project.godot 无渲染器设置 → 默认 forward_plus）。
- 光照上限：Compatibility 单物体最多 8 光（`rendering/limits/opengl/max_lights_per_object`）。
- 阴影贴图 4096（`rendering/lights_and_shadows/directional_shadow/size`），本项目阴影关闭。
- 全局设置项（查过的）：`rendering/environment/fog/use_legacy_blending`（默认 false，新式雾混合）、`rendering/environment/defaults/default_environment`（默认空=无全局环境）、`default_clear_color`（0.3,0.3,0.3）。

---

## 8. 实测数据备忘（防再踩坑）

### 8.1 指数雾公式实测验证
`fog = 1 - exp2(-density × depth)`，例：
- density 0.04 @ 30m → fog≈0.565（草纹可见度只剩 44%，看起来"又暗又平"）
- density 0.014 @ 30m → fog≈0.25（草纹清楚）
- density 0.014 @ 230m → fog≈0.89（远景基本融入雾色）
- density 0.15（开场）→ 全场 90%+，这就是"开场全雾/地板纯黑"的由来

### 8.2 地面平面尺寸与相机视野（几何计算）
相机抬高 y=30、俯角 -22°、FOV 68（竖屏）时，屏幕底边看到的地面距离 ≈ 300m → 平面深 256（到 z=-190）不够 → 远处露出天球 ground 色平板。**深 512（z=-318）盖住**。tiling.y 需同比例调（6→12）保持草纹密度与滚动速度（scroll 按 plane_size/tiling 换算，保持 42.7m/格）。

### 8.3 线性 vs sRGB
linear 0.18 → sRGB ≈ 0.46。用截图亮度判断"雾色是否生效"时，记得换算：地面≈sRGB(雾色) 即说明 100% 雾化。

### 8.4 FOV 敏感性
本项目相机 FOV（55/68/90）会显著改变地平线在屏幕上的 y 位置（px/deg = 屏高/fov）。排查"地平线分界/远处黑块"时，截图必须用与实机相同的 FOV。
