extends Node

@export var mob_scene: PackedScene
@export var mob_corpse_scene: PackedScene
@export var player_scene: PackedScene

@onready var retry_screen: Node = $UserInterface/Retry
@onready var retry_label: Label = $UserInterface/Retry/Label

const PLAYER_SPAWN_POSITIONS := [
	Vector3(-3, 0, 0),
	Vector3(3, 0, 0),
	Vector3(0, 0, -3),
	Vector3(0, 0, 3),
]

@onready var players_container: Node3D = $Players
@onready var mobs_container: Node3D = $Mobs

var _mob_counter := 0
var _alive_player_ids := {}

func _ready() -> void:
	$UserInterface/Retry.hide()
	$MobTimer.stop()
	Lobby.all_players_loaded.connect(_on_all_players_loaded)
	
	if multiplayer.has_multiplayer_peer():
		Lobby.player_loaded.rpc_id(1)
	else:
		start_game()

func _on_all_players_loaded() -> void:
	if multiplayer.is_server():
		start_game.rpc()

@rpc("call_local", "reliable")
func start_game() -> void:
	if players_container.get_child_count() > 0:
		return
	_spawn_players()
	if (not multiplayer.has_multiplayer_peer()) or multiplayer.is_server():
		if $MobTimer.is_stopped():
			$MobTimer.start()

func _spawn_players() -> void:
	var peer_ids: Array = []
	if multiplayer.has_multiplayer_peer() and Lobby.players.size() > 0:
		peer_ids = Lobby.players.keys()
	else:
		peer_ids = [1]
	peer_ids.sort()
	for index in range(peer_ids.size()):
		_spawn_player(peer_ids[index], index)

func _spawn_player(peer_id: int, index: int) -> void:
	if players_container.has_node(str(peer_id)):
		return
	_alive_player_ids[peer_id] = true
	var player = player_scene.instantiate()
	player.name = str(peer_id)
	player.position = PLAYER_SPAWN_POSITIONS[index % PLAYER_SPAWN_POSITIONS.size()]
	player.set_multiplayer_authority(peer_id)
	player.hit.connect(_on_player_hit.bind(player))
	players_container.add_child(player)

func _on_mob_timer_timeout() -> void:
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return
	
	var mob_spawn_location = get_node("SpawnPath/SpawnLocation")
	mob_spawn_location.progress_ratio = randf()
	
	var spawn_position: Vector3 = mob_spawn_location.global_position
	var target_position: Vector3 = _get_random_player_position()
	var rotation_offset: float = randf_range(-PI / 4, PI / 4)
	var speed_ratio: float = randf()
	
	_mob_counter += 1
	var mob_name := "Mob_%d" % _mob_counter
	
	if multiplayer.has_multiplayer_peer():
		spawn_mob.rpc(mob_name, spawn_position, target_position, rotation_offset, speed_ratio)
	else:
		spawn_mob(mob_name, spawn_position, target_position, rotation_offset, speed_ratio)

@rpc("authority", "call_local", "reliable")
func spawn_mob(mob_name: String, spawn_position: Vector3, target_position: Vector3, rotation_offset: float, speed_ratio: float) -> void:
	var mob = mob_scene.instantiate()
	mob.name = mob_name
	mob.initialize(spawn_position, target_position, rotation_offset, speed_ratio)
	mobs_container.add_child(mob)
	
	mob.squashed.connect($UserInterface/ScoreLabel._on_mob_squashed.bind())
	mob.squashed.connect(_on_mob_squashed.bind(mob))

func _get_random_player_position() -> Vector3:
	var nodes := players_container.get_children()
	if nodes.is_empty():
		return Vector3.ZERO
	return nodes[randi() % nodes.size()].position

func _on_mob_squashed(_points, mob: CharacterBody3D) -> void:
	if mob_corpse_scene == null:
		return
	
	var mob_corpse = mob_corpse_scene.instantiate()
	if mob_corpse is Node3D:
		mob_corpse.global_transform = mob.global_transform
	
	add_child(mob_corpse)

func _on_player_hit(player: Node) -> void:
	# player.gd broadcasts death to every peer, so this runs everywhere. Only the
	# server (or a solo game) tallies deaths; the fixed camera lets dead players
	# spectate the survivors until the whole party is wiped out.
	if (not multiplayer.has_multiplayer_peer()) or multiplayer.is_server():
		_register_player_death(player.get_multiplayer_authority())

func _register_player_death(peer_id: int) -> void:
	_alive_player_ids.erase(peer_id)
	if _alive_player_ids.is_empty():
		_end_game()

func _end_game() -> void:
	$MobTimer.stop()
	if multiplayer.has_multiplayer_peer():
		show_game_over.rpc()
	else:
		show_game_over()

@rpc("authority", "call_local", "reliable")
func show_game_over() -> void:
	if not multiplayer.has_multiplayer_peer() or multiplayer.is_server():
		retry_label.text = "Press Space or Enter to retry"
	else:
		retry_label.text = "Waiting for noob host"
	
	retry_screen.show()
	
func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_accept"):
		return
	if not $UserInterface/Retry.visible:
		return
	# Only the host may retry; clients ignore the key and wait for the restart.
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return
	if multiplayer.has_multiplayer_peer():
		restart_game.rpc()
	else:
		get_tree().reload_current_scene()

# Broadcast from the host so every peer reloads and the round starts again for all.
@rpc("authority", "call_local", "reliable")
func restart_game() -> void:
	get_tree().reload_current_scene()
