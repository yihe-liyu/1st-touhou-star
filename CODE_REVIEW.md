# 🔍 东方星 STG 项目全面审查报告
## 审查日期：2026-06-12
## 审查范围：全部 .gd 脚本、shader、project.godot、架构、性能、安全性
## 版本：v1.1（深度补充审查 — 2026-06-12）

**阅读了 37 个文件**，覆盖 autoload、核心系统、UI、背景、子弹、激光、敌人、玩家、协程。

---

## 🔴 P0 — 致命问题 (5)

### #1 Player.miss() 用 `await` → 函数态重叠 / 泄露
**文件：** `scripts/player/player.gd:146`
```gdscript
is_invincible = true
await get_tree().create_timer(3.0).timeout
is_invincible = false
```
- 3 秒无敌期间再中弹 → `miss()` 再次被调 → is_invincible 已 true → 提前 return。但第一个 await 还在跑！场景切换/player free 后 timer 到期 → `is_invincible = false` 写入野指针。
- **严重：碰撞回调 `_enemy_vs_player` / `laser_system.step` 中调用 `miss()`，`miss` 中 await 挂起整个 `_physics_process` 调用链。下一帧 `_physics_process` 照常运行 → 多帧重叠执行。**
- **建议：** `miss()` 不能有 await。无敌改用 Tween 或 _process 手动倒计时。

### #2 EnemyVisual 巡逻端点动画抖闪
**文件：** `scripts/enemy/enemy_visual.gd`
- SINE EASE_IN_OUT 巡逻，端点 speed≈0 < 30 → IDLE，下帧翻向 speed>30 → RIGHTING → RIGHT。无限来回切换。
- **建议：** 退出 moving 加 0.2s 延迟（hysteresis），或提高阈值。

### #3 RNG autoload 形同虚设 → replay 不可行
**文件：** `scripts/autoload/rng.gd` + 全文搜索
- `bullet_physics.gd:66` `stage01_decor.gd:40` `test_decor.gd:13` `enemy_bullet_clear.gd:30` 全用全局 `randf()`，不走 `RNG.randf()`。
- **建议：** 全局替换 `randf(` → `RNG.randf(` `randf_range(` → `RNG.randf_range(`。

### #4 场景切换时 BulletManager._physics_process 仍在碰撞
**文件：** `scripts/autoload/bullet_manager.gd`
- `scene_transition.change_scene` → `change_scene_to_file()` → `BulletManager.clear_all()`。但 `_physics_process` 在 autoload 上照常跑。
- **建议：** 加 `_paused` flag，transition 期间跳过。

### #5 碰撞链路中 `player.miss()` 调用 await → `_physics_process` 函数态重叠
**文件：** `scripts/autoload/bullet/bullet_physics.gd:55` `scripts/autoload/bullet/laser_system.gd:85`
```gdscript
# bullet_physics._enemy_vs_player
player.miss()              # ← 内部 await 3 秒，挂起 _physics_process
_pool.return_bullet(bullet) # ← 3 秒后执行，bullet 可能已被他处回收

# laser_system.step
if hit: player.miss()      # 同样问题
```
- 3 秒后 resume 时 bullet/player 可能已 free 或状态不一致。
- **建议：** 同 #1——`miss()` 去 await。

---

## 🟠 P1 — 高优先级 (6)

### #6 GameUI 碎片图标入场 X 坐标偏移 +30px
**文件：** `scripts/scenes/ui/game_ui.gd:146`
- 16 个 Sprite2D 碎片已有绝对坐标，入场动画对所有非特殊节点 `position.x += 30`。Bug！

### #7 GameUI `entry_finished` total 计算偏小
**文件：** `scripts/scenes/ui/game_ui.gd:143`
- `total = queue.size * ENTRY_INTERVAL`，但 Title logo (1.5s) + diffculty (1s) 远超 ENTRY_INTERVAL。entry_finished 可能在其他元素未入场完时 emit。

### #8 Bomb 输入 action 未定义 + 无 bomb 功能
- `project.godot` 无 `bomb` action。`Player` 无 `bomb()` 方法。`GameState` 有 `bomb_count` 但无法用。

### #9 `range` 变量名遮蔽内置 `range()`
**文件：** `scripts/coroutine/stages/move_stage1_enemy1.gd:24`
- `@export var range: float` → Warning。脚本内无法再调用 `range(10)`。

### #10 难度/角色选择界面硬编码 keycode，不走 InputMap
**文件：** `scripts/scenes/main/difficulty_screen.gd` `character_screen.gd`
- 用 `KEY_UP` `KEY_Z` 裸码。GameManager 注册的 `ui_accept` 等 input actions 无效。手柄不可用。

### #11 SceneTransition 切换场景只等一帧
**文件：** `scripts/autoload/game/scene_transition.gd:30`
```gdscript
await _parent.get_tree().process_frame
```
- 新场景 `_ready()` 可能未全部执行完。应等 scene 就绪信号。

---

## 🟡 P2 — 性能/技术债 (12)

### #12 GameState._process 非游戏中也在跑
- `memory_value` 每帧 +0.05，主菜单也跑。加 `if not PLAYING: return`。

### #13 EnemyVisual 每帧 `get_parent() as Node2D`
- 30 敌人 = 30 次 get_parent/帧。缓存到 `@onready var _parent`。

### #14 BulletPool 动态扩容无上限
- POOL_SIZE=4000 不够时动态创建，没 cap。加 max 或用 LRU。

### #15 BulletMultiMesh._sync 每帧 `is_instance_valid` 扫描全部子弹
- 200 bullets = 200 次 is_instance_valid。回收时应从 active list 移除。

### #16 HitEffectPool.spawn 每帧 `Engine.get_main_loop().current_scene`
- 高频调用时缓存 World 引用。

### #17 StageBackground._process_events O(n) 扫描
- 用排序列表 + 摘到期事件，免每帧全扫。

### #18 StageAPI 持 runner (Node) 强引用 → 语义混乱
- RefCounted 持 Node。改 WeakRef。

### #19 `return_bullet` disconnect fog 信号可能报错
**文件：** `scripts/autoload/bullet/bullet_pool.gd:65`
- CONNECT_ONE_SHOT 的 fog_finished 会自动断，`return_bullet` 再 disconnect 虽被 is_connected 保了，但代码脆弱。应抽成 `bullet.reset()`。

### #20 BulletMultiMesh._groups 从不清理
- 多种纹理 + faction 累积 MMI 节点。场景切换时 clean。

### #21 CurvedLaser 池复用逻辑错误
**文件：** `scripts/autoload/bullet/laser_system.gd:25`
```gdscript
for l in _active_lasers:
    if l.phase == CurvedLaserClass.DEAD:
        l.init(data, origin, guide_curve, rot_speed)
        return l   # ← 找到第一个 DEAD 就复用
```
- 复用后激光处于 ALIVE 但可能残留旧 shader 参数、旧 fog_sprite。`init()` 重置了大部分状态，但 `_seg_lines` 的 `Line2D.width` / `width_curve` 未重置。

### #22 BulletFog.play 相同 texture 直接 emit finished
```gdscript
if texture == p_texture:
    fog_finished.emit()  # 跳过动画，但 fog 可能还在上次的 tween 中
    return
```
- 如果上次 fog 的 tween 没完（create_tween 在 Sprite2D 上），新 play 跳过动画但旧 tween 继续跑，可能 interfere。

### #23 CoroutineRunner._tasks 类型注解无效
- `Array[Task]` → Godot 4 不识。改 `Array`。

---

## 🟢 P3 — 代码质量 (6)

### #24 子弹挂 BulletManager，敌人挂 World → 坐标系不一致
- `BulletManager` 是 autoload Node2D，`World` 在 GameScene 下。如有摄像机偏移，坐标系不对。

### #25 GameScene._blur_rect 语义混乱
- `_blur_rect` 是当前 blur 的 ColorRect，但不是 @onready 也不常驻。

### #26 BackgroundScript._on_init 与 start_background 时序不文档化
- `_on_init` 无协程能力，但 api 对象存在。易误用。

### #27 菜单/UI 输入不统一
- BaseMenu / MenuScreen 用不同输入体系（action vs keycode）。

### #28 `@export` 变量全无注释
- `range`, `period`, `entrance_y` 等含义依赖猜测。

### #29 无统一日志系统
- print / push_error / push_warning 混用。

---

## 🔵 Feature — 缺失功能 (8)

### #30 无 Item/道具系统
- `collect_life_fragment()` / `collect_bomb_fragment()` 存在但无调用入口。

### #31 无 Boss / Spell Card 系统
- 无对应数据结构。

### #32 无 Replay 系统（基础条件不满足）
- 随机数不走 RNG、输入不录制。

### #33 关卡结束无结算流程
- `stage_cleared` 信号发出后无 UI 响应。

### #34 暂停菜单只有"继续"（正常模式）+ game_over 时有"返回标题/退出"
- 正常暂停缺"重开"和"返回标题"。

### #35 StageData 缺 bgm 字段
- StageScript 手动调 AudioManager.play_bgm，不标准。

### #36 无手柄支持
- 菜单硬编码 keycode，不可扩展。

### #37 Await 深度污染
- `player.miss()` (await), `audio_manager.play_bgm` (await), `base_menu._accept_current` (await), `scene_transition.change_scene` (await). 多处非协程函数用 await，状态管理脆弱。

---

## 📊 统计

| 类别 | 数量 |
|------|------|
| 🔴 P0 致命 | 5 |
| 🟠 P1 高优 | 6 |
| 🟡 P2 性能/债 | 12 |
| 🟢 P3 风格 | 6 |
| 🔵 缺失功能 | 8 |
| **总计** | **37** |

---

## 💡 十大改进建议（排名不分先后）

1. **`player.miss()` 去 await** — 影响所有碰撞逻辑
2. **RNG 统一化** — 为 replay 打底
3. **场景切换 safe guard** — BulletManager 暂停
4. **EnemyVisual hysteresis** — 去动画闪烁
5. **Bomb 系统** — 输入 + 功能
6. **菜单统一走 InputMap** — 键位自定义/手柄
7. **GameUI 坐标/时序 fix** — 碎片偏移 + entry_finished 时机
8. **Item 系统** — 碎片/完整道具拾取
9. **StageData + bgm** — 标准关卡初始化
10. **BulletMultiMesh 优化** — active list 清理 + groups 回收
