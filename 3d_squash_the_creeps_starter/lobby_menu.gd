extends Control

const GAME_SCENE_PATH := "res://main.tscn"

@onready var player_name_input: LineEdit = $PlayerNameInput
@onready var server_ip_input: LineEdit = $ServerIpInput
@onready var host_button: Button = $HostButton
@onready var join_button: Button = $JoinButton
@onready var start_button: Button = $StartButton
@onready var players_list: ItemList = $PlayersList
@onready var status_label: Label = $StatusLabel

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	Lobby.player_connected.connect(_on_player_connected)
	Lobby.player_disconnected.connect(_on_player_disconnected)
	Lobby.server_disconnected.connect(_on_server_disconnected)
	
	host_button.pressed.connect(_on_host_pressed)
	join_button.pressed.connect(_on_join_pressed)
	start_button.pressed.connect(_on_start_pressed)
	
	start_button.disabled = false
	server_ip_input.text = "127.0.0.1"
	_refresh_players()

func _on_host_pressed() -> void:
	Lobby.player_info.name = player_name_input.text.strip_edges()
	var error = Lobby.create_game()
	
	if error != OK:
		status_label.text = "Host failed %s" % error
	
	status_label.text = "Hosting..."
	start_button.disabled = Lobby.players.size() < 2
	
func _on_join_pressed() -> void:
	Lobby.player_info.name = player_name_input.text.strip_edges()
	var ip := server_ip_input.text.strip_edges()
	var error = Lobby.join_game(ip)
	
	if error != OK:
		status_label.text = "Join failed %s" % error
	
	status_label.text = "Joining..."

func _on_start_pressed() -> void:
	if not multiplayer.is_server():
		return
	#if Lobby.players.size() < 2:
		#status_label.text = "Need at least 2 players"
		#return
	Lobby.load_game.rpc(GAME_SCENE_PATH)
	
func _on_player_connected(_peer_id: int, _player_info: Dictionary) -> void:
	_refresh_players()
	if multiplayer.is_server():
		start_button.disabled = Lobby.players.size() < 2
	
func _on_player_disconnected(_peer_id: int) -> void:
	_refresh_players()
	if multiplayer.is_server():
		start_button.disabled = Lobby.players.size() < 2

func _on_server_disconnected() -> void:
	status_label.text = "Server disconnected"
	_refresh_players()
	start_button.disabled = true
	
func _refresh_players() -> void:
	players_list.clear()
	for peer_id in Lobby.players.keys():
		var info: Dictionary = Lobby.players[peer_id]
		var name := str(info.get("name", "Player"))
		players_list.add_item("%s (%s)" % [name, peer_id])

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
