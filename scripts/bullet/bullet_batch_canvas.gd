# BulletBatchCanvas — 实验性批绘制，默认关闭。
# 每帧 queue_redraw() 在动态弹幕场景下比 Sprite2D 开销更大，不适合作为主渲染路径。
# 保留此文件供未来基于 RenderingServer / MultiMeshInstance2D 方案升级时参考。
extends Node2D
class_name BulletBatchCanvas

## 是否启用批绘制。默认 false（实验性功能）
@export var enabled: bool = false

@export_group("阵营")
## 只渲染此阵营的子弹。-1=全部, 0=自机, 1=敌人, 2=Bomb
@export var faction: int = -1

func _ready():
	z_index = 10
	set_process(enabled)
	if not enabled:
		visible = false

func _process(_delta):
	queue_redraw()

func _draw():
	if not enabled:
		return
	var bullets = BulletManager.active_bullets
	for i in range(bullets.size() - 1, -1, -1):
		var b = bullets[i]
		if faction >= 0 and b.faction != faction:
			continue
		if not b.visible:
			continue
		var tex = b.batch_texture()
		if not tex:
			continue
		var size = tex.get_size()
		draw_set_transform(b.position, b.rotation, b.scale)
		draw_texture(tex, -size * 0.5)
