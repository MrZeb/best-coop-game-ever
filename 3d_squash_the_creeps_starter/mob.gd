extends CharacterBody3D

signal squashed

@export var min_speed = 10
@export var max_speed = 18

var _squashed := false

func initialize(start_position: Vector3, target_position: Vector3, rotation_offset: float, speed_ratio: float) -> void:
	look_at_from_position(start_position, target_position, Vector3.UP)
	rotate_y(rotation_offset)
	
	var mob_speed: float = lerp(float(min_speed), float(max_speed), speed_ratio)
	velocity = Vector3.FORWARD * mob_speed
	velocity = velocity.rotated(Vector3.UP, rotation.y)
	$AnimationPlayer.speed_scale = mob_speed / float(min_speed)
	
func _physics_process(delta: float) -> void:
	move_and_slide()


func _on_visible_on_screen_notifier_3d_screen_exited() -> void:
	queue_free()

func squash(points):
	if multiplayer.has_multiplayer_peer():
		_request_squash.rpc_id(1, points)
	else:
		_apply_squash(points)

# Runs on the server: validates the squash so a mob can only be squashed once,
# then tells every peer to remove it.
@rpc("any_peer", "call_local", "reliable")
func _request_squash(points: int) -> void:
	if not multiplayer.is_server():
		return
	if _squashed:
		return
	_squashed = true
	_apply_squash.rpc(points)

@rpc("authority", "call_local", "reliable")
func _apply_squash(points: int) -> void:
	squashed.emit(points)
	queue_free()
