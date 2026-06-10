extends BackgroundScript
class_name TestDecor

## 需要手动拖入 Inspector 或通过代码获取
var ground: BackgroundPlane
var tree_prefab: PackedScene
var _i: int = 0

func _on_step(api: StageAPI) -> Variant:
	if _i >= 20 or not ground:
		return false
	
	api.spawn_decor(tree_prefab, Vector3(randf_range(-400, 400), 0, -50 + randf_range(-30, 0)), ground)
	_i += 1
	return api.seconds(0.3)
