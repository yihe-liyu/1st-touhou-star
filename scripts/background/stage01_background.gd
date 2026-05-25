extends StageBackground
class_name Stage01Background

func _on_setup():
	set_camera_size(6)
	#set_camera_pos(Vector3(0, 0, 10))

	schedule(5.0, _on_five_seconds)
	schedule(10.0, _on_ten_seconds)

func _on_five_seconds():
	set_camera_size(7)

func _on_ten_seconds():
	set_camera_size(8)
	move_camera(Vector3(0, 1, 12), 2.0)
