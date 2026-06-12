# 🔍 东方星 STG 项目全面审查报告
## 审查日期：2026-06-12

---

## 🔴 P0 — 致命问题 (5)

### #1 Player.miss() 用 `await` → 函数态重叠 / 泄露 ✅

### #2 EnemyVisual 巡逻端点动画抖闪 ✅

### #3 RNG autoload 形同虚设 → replay 不可行 ✅

### #4 场景切换时 BulletManager._physics_process 仍在碰撞 ✅

### #5 碰撞链路中 `player.miss()` 调用 await → `_physics_process` 函数态重叠 ✅（同 #1）


## 🟠 P1 — 高优先级 (6)

### #6 GameUI 碎片图标入场 X 坐标偏移 +30px ✅

### #7 GameUI `entry_finished` total 计算偏小 ✅

### #8 Bomb 输入 action 未定义 + 无 bomb 功能
- `project.godot` 无 `bomb` action。`Player` 无 `bomb()` 方法。`GameState` 有 `bomb_count` 但无法用。

### #9 `range` 变量名遮蔽内置 `range()` ✅

### #10 难度/角色选择界面硬编码 keycode，不走 InputMap ✅

### #11 ~ SceneTransition 只等一帧 → 不成立（tree.paused 已上锁）

---

## 🟡 P2 — 性能/技术债 (12)

### #12 GameState._process 非游戏中也在跑
- `memory_value` 每帧 +0.05，主菜单也跑。加 `if not PLAYING: return`。

### #13 EnemyVisual 每帧 `get_parent()` ✅

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
### #25 GameScene._blur_rect 语义混乱
### #26 BackgroundScript._on_init 与 start_background 时序不文档化
### #27 菜单/UI 输入不统一
### #28 `@export` 变量全无注释
### #29 无统一日志系统

---

## 🔵 Feature — 缺失功能 (8)

### #30 无 Item/道具系统
### #31 无 Boss / Spell Card 系统
### #32 无 Replay 系统
### #33 关卡结束无结算流程
### #34 暂停菜单缺"重开"和"返回标题"
### #35 StageData 缺 bgm 字段
### #36 无手柄支持
### #37 Await 深度污染（多处非协程用 await）
