extends CharacterBody3D

signal hit

@export var speed = 14
@export var fall_acceleration = 75
@export var jump_impulse = 20
@export var bounce_impulse = 30

var target_velocity = Vector3.ZERO
var bonus_points = 0
const PLAYER_ONE_COLOR := Color(0.95, 0.45, 0.1) # orange
const PLAYER_TWO_COLOR := Color(0.2, 0.45, 1.0) # blue

func _ready() -> void:
	_apply_player_color()

func _is_authority() -> bool:
	return not multiplayer.has_multiplayer_peer() or is_multiplayer_authority()

func _apply_player_color() -> void:
	var peer_id := get_multiplayer_authority()
	var player_color := _get_player_color(peer_id)
	_apply_color_to_meshes($Pivot/Character, player_color)

func _get_player_color(peer_id: int) -> Color:
	if Lobby != null and Lobby.players.size() > 0:
		var peer_ids: Array = Lobby.players.keys()
		peer_ids.sort()
		var player_index := peer_ids.find(peer_id)
		if player_index == 0:
			return PLAYER_ONE_COLOR
		if player_index == 1:
			return PLAYER_TWO_COLOR
	
	if peer_id == 1:
		return PLAYER_ONE_COLOR
	return PLAYER_TWO_COLOR

func _apply_color_to_meshes(node: Node, player_color: Color) -> void:
	if node is MeshInstance3D:
		_apply_color_to_mesh_instance(node, player_color)
	
	for child in node.get_children():
		_apply_color_to_meshes(child, player_color)

func _apply_color_to_mesh_instance(mesh_instance: MeshInstance3D, player_color: Color) -> void:
	if mesh_instance.mesh == null:
		return
	
	for surface_index in range(mesh_instance.mesh.get_surface_count()):
		var source_material := mesh_instance.get_active_material(surface_index)
		if not _is_player_body_material(source_material):
			continue
		
		if source_material is BaseMaterial3D:
			var duplicated_material := source_material.duplicate()
			duplicated_material.albedo_color = player_color
			mesh_instance.set_surface_override_material(surface_index, duplicated_material)
		else:
			var fallback_material := StandardMaterial3D.new()
			fallback_material.albedo_color = player_color
			mesh_instance.set_surface_override_material(surface_index, fallback_material)

func _is_player_body_material(source_material: Material) -> bool:
	if source_material == null:
		return false
	
	var material_name := source_material.resource_name.to_lower()
	return material_name.find("body") != -1

func _physics_process(delta: float) -> void:
	if not _is_authority():
		return
	
	var direction = Vector3.ZERO
	
	if Input.is_action_pressed("move_right"):
		direction.x += 1
	if Input.is_action_pressed("move_left"):
		direction.x -= 1
	if Input.is_action_pressed("move_back"):
		direction.z += 1
	if Input.is_action_pressed("move_forward"):
		direction.z -= 1
	
	if direction != Vector3.ZERO:
		direction = direction.normalized()
		$Pivot.basis = Basis.looking_at(direction)
		$AnimationPlayer.speed_scale = 4
	else:
		$AnimationPlayer.speed_scale = 1
		
	target_velocity.x = direction.x * speed
	target_velocity.z = direction.z * speed
	
	var collision_happened = false
	
	for index in range(get_slide_collision_count()):
		var collision = get_slide_collision(index)
		
		if collision.get_collider() == null:
			continue
		
		if collision.get_collider().is_in_group("mob"):
			var mob = collision.get_collider()
			
			if Vector3.UP.dot(collision.get_normal()) > 0.1:
				print("SQUASH! Bonus: %s" % bonus_points)
				mob.squash(1 + bonus_points)
				bonus_points += 1
				target_velocity.y = bounce_impulse
				collision_happened = true
				
				break
				
	if not is_on_floor():
		target_velocity.y = target_velocity.y - (fall_acceleration * delta)
	elif(not collision_happened and bonus_points > 0):
		print("ON FLOOR RESET BONUS")
		bonus_points = 0
	
	velocity = target_velocity 
	
	if is_on_floor() and Input.is_action_just_pressed("jump"):
		target_velocity.y = jump_impulse
	
	move_and_slide()
	$Pivot.rotation.x = PI / 6 * velocity.y / jump_impulse

func die():
	if multiplayer.has_multiplayer_peer():
		_die.rpc()
	else:
		_die()

@rpc("authority", "call_local", "reliable")
func _die() -> void:
	print("die!!!")
	hit.emit()
	queue_free()

func _on_mob_detector_body_entered(_body: Node3D) -> void:
	if not _is_authority():
		return
	die()
