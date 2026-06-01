extends Node
class_name Lobby

@export var player_scene: PackedScene
@export var multiplayer_spawner: MultiplayerSpawner
@export var players_container: Node3D
@onready var lobby_info_button: Button = %LobbyInfoButton

@onready var main_menu: MainMenuUI = %MainMenuUI
@onready var exit_lobby_button: Button = %ExitLobbyButton
@onready var steam_friends_list: Panel = %SteamFriendsList
@onready var in_game_ui: Control = %InGameUI

var inventory_visible = false

var _current_lobby: String:
	get: return Online.LOCAL_SERVER_ADDRESS if not Online.steam_lobby_id else str(Online.steam_lobby_id)

func _setup_multiplayer_spawner() -> void:
	multiplayer_spawner.spawn_function = _add_player
	multiplayer_spawner.spawn_path = players_container.get_path()
	multiplayer_spawner.add_spawnable_scene(player_scene.resource_path)
	
func _ready() -> void:
	_update_lobby_info_button()

	_setup_multiplayer_spawner()
	Online.server_disconnected.connect(_handle_failed_connection)
	Online.joining_lobby.connect(_on_joining_lobby)
	Online.connection_failed.connect(_handle_failed_connection)
	update_ui(false)
	
	main_menu.host_online_requested.connect(_on_host_online_requested)
	main_menu.host_local_requested.connect(_on_host_local_requested)
	
	main_menu.join_requested.connect(_on_join_requested)
	main_menu.quit_requested.connect(_on_quit_requested)
	multiplayer.peer_disconnected.connect(_remove_player)
	Online.player_connected.connect(_on_player_connected)
	Online.player_disconnected.connect(_on_player_disconnected)


func update_ui(is_in_game: bool) -> void:
	if not is_in_game:
		main_menu.show_menu()
		in_game_ui.hide()
		steam_friends_list.hide()
	else:

		main_menu.hide_menu()


func _update_lobby_info_button() -> void:
	lobby_info_button.text = "IP/Lobby ID: \n\n%s" % _current_lobby

func _on_joining_lobby():
	main_menu.loading = true

func _handle_failed_connection(): _on_disconnected.call_deferred()

func _on_disconnected():
	_update_lobby_info_button.call_deferred()
	for child in players_container.get_children(): if not child is MultiplayerSpawner: child.queue_free()

	update_ui(false)
	main_menu.loading = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _on_player_connected(player_data: PlayerData): 
	_update_lobby_info_button()
	if not multiplayer.is_server(): return
	multiplayer_spawner.spawn(player_data.to_dict())
	
func _on_player_disconnected(player_data: PlayerData):
	var player_node: Node = players_container.get(str(player_data.multiplayer_id))
	if is_instance_valid(player_node): player_node.queue_free()

func _on_host_local_requested():
	main_menu.loading = true
	var error := Online.host_local_lobby()
	match error:
		Online.ErrorCodes.SUCCESS:
			
			update_ui(true)
			_update_lobby_info_button.call_deferred()
		_:
			main_menu.loading = false
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			update_ui(false)

func _on_host_online_requested():
	main_menu.loading = true
	var error := await Online.host_steam_lobby()
	match error:
		Online.ErrorCodes.SUCCESS:
			_update_lobby_info_button.call_deferred()
			update_ui(true)
		_:
			main_menu.loading = false
			update_ui(false)

func _on_join_requested(address: String):
	update_ui(false)
	main_menu.loading = true

	var error: Online.ErrorCodes
	if not address or address == Online.LOCAL_SERVER_ADDRESS: error = await Online.join_local_lobby()
	else: error = await Online.join_steam_lobby(address as int)
	match error:
		Online.ErrorCodes.SUCCESS:
			update_ui(true)
		_:
			main_menu.loading = false
			update_ui(false)

func _add_player(player_data_dict: Dictionary) -> Node:
	update_ui(true)
	main_menu.loading = false
	var player_data := PlayerData.from_dict(player_data_dict)
	var id: int = player_data.multiplayer_id
	if players_container.has_node(str(id)): return
	var player: PlayerCharacter = player_scene.instantiate()
	player.name = str(id)
	player.position = get_spawn_point()
	PlayerData.apply_data_to_node(player_data,player)

	return player

func get_spawn_point() -> Vector3:
	var spawn_point = Vector2.from_angle(randf() * 2 * PI) * 5 # spawn radius
	return Vector3(spawn_point.x, 0, spawn_point.y)

func _remove_player(id):
	if not multiplayer.is_server() or not players_container.has_node(str(id)):
		return
	var player_node = players_container.get_node(str(id))
	if player_node:
		player_node.queue_free()

func _on_quit_requested() -> void:
	get_tree().quit()

func _input(event: InputEvent) -> void:
	if Input.is_action_just_pressed("ui_cancel"):
		if main_menu.visible: return
		if Input.mouse_mode != Input.MOUSE_MODE_VISIBLE:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			in_game_ui.show()
			steam_friends_list.show()
		else:
			in_game_ui.hide()
	elif event.is_action_pressed("toggle_fullscreen"):
		var current_mode = DisplayServer.window_get_mode()
		if current_mode == DisplayServer.WINDOW_MODE_WINDOWED: DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		else: DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	
func _on_exit_lobby_button_pressed() -> void:
	main_menu.loading = true
	Online.leave_lobby()
	main_menu.loading = false

func _on_lobby_info_button_pressed() -> void:
	DisplayServer.clipboard_set(_current_lobby)
