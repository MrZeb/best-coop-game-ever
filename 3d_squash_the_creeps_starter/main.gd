extends Node

@export var mob_scene: PackedScene
@export var mob_corpse_scene: PackedScene

func _ready() -> void:
	$UserInterface/Retry.hide()
	
func _on_mob_timer_timeout() -> void:
	var mob = mob_scene.instantiate()
	
	var mob_spawn_location = get_node("SpawnPath/SpawnLocation")
	mob_spawn_location.progress_ratio = randf()
	
	var player_position = $Player.position
	mob.initialize(mob_spawn_location.position, player_position)
	
	add_child(mob)
	
	mob.squashed.connect($UserInterface/ScoreLabel._on_mob_squashed.bind())
	mob.squashed.connect(_on_mob_squashed.bind(mob))

func _on_mob_squashed(_points, mob: CharacterBody3D) -> void:
	if mob_corpse_scene == null:
		return
	
	var mob_corpse = mob_corpse_scene.instantiate()
	if mob_corpse is Node3D:
		mob_corpse.global_transform = mob.global_transform
	
	add_child(mob_corpse)

func _on_player_hit() -> void:
	$MobTimer.stop()
	$UserInterface/Retry.show()
	
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept") and $UserInterface/Retry.visible:
		get_tree().reload_current_scene()
