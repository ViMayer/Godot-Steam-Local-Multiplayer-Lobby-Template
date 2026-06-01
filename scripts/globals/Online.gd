extends Node

const MAX_PLAYERS: int = 12

enum ErrorCodes { NO_RESPONSE, SUCCESS, FAILED, CURRENTLY_BUSY, JOIN_FAILED_SAME_OWNER_ID, STEAM_CONNECTION_ERROR }

signal joined_steam_lobby
signal connection_failed
signal steam_lobby_invite_received(lobby_id: int, sender_id: int)
signal joining_lobby
signal lobby_hosting_response(error_code: ErrorCodes)
signal lobby_join_response(error_code: ErrorCodes)

var _is_busy: bool = false
var steam_lobby_id: int = 0
var is_host: bool = false
var is_joining: bool = false
var steam_multiplayer_peer: SteamMultiplayerPeer = null
var players: Dictionary[int, PlayerData]: # Uses multiplayer ids as keys
	get: players.sort(); return players

func players_to_data_dicts() -> Array[Dictionary]: # Returns an array with all the players PlayerData resource in Dictionary format
	var value: Array[Dictionary]
	for player_data: PlayerData in players.values():
		if is_instance_valid(player_data): value.append(player_data.to_dict())
	return value

@onready var personal_player_data: PlayerData: # Your PlayerData resource
	get:
		if not personal_player_data:
			personal_player_data = PlayerData.new()
			personal_player_data.steam_id = Steam.getSteamID()
			personal_player_data.display_name = Steam.getPersonaName()
		personal_player_data.multiplayer_id = 0 if not multiplayer else multiplayer.get_unique_id()
		return personal_player_data

func is_offline() -> bool: return multiplayer == null or multiplayer.multiplayer_peer == null

func _ready() -> void:
	_setup_local_hosting_signals()
	OS.set_environment("SteamAppID", str(480))
	OS.set_environment("SteamGameID", str(480))
	Steam.steamInit(false, 480)
	Steam.lobby_created.connect(_on_steam_lobby_creation_response)
	Steam.lobby_joined.connect(_on_steam_lobby_join_response)
	Steam.join_requested.connect(join_steam_lobby)


func leave_lobby() -> void:
	is_host = false
	Steam.leaveLobby(steam_lobby_id)
	if multiplayer.multiplayer_peer: multiplayer.multiplayer_peer.close()
	if steam_multiplayer_peer: steam_multiplayer_peer.close()
	steam_lobby_id = 0
	player_disconnected.emit(personal_player_data)


func host_steam_lobby() -> ErrorCodes:
	if _is_busy: return ErrorCodes.CURRENTLY_BUSY
	is_host = true
	_is_busy = true
	Steam.createLobby(Steam.LOBBY_TYPE_FRIENDS_ONLY, MAX_PLAYERS)
	var error: ErrorCodes = await lobby_hosting_response
	if error == ErrorCodes.SUCCESS: joined_steam_lobby.emit()
	else: is_host = false
	_is_busy = false
	return error


func join_steam_lobby(lobby_id: int = 0, ..._args) -> ErrorCodes:
	if _is_busy: return ErrorCodes.CURRENTLY_BUSY
	is_joining = true
	joining_lobby.emit()
	if lobby_id != steam_lobby_id and steam_lobby_id != 0: leave_lobby()
	is_host = false
	steam_lobby_id = lobby_id
	_is_busy = true
	Steam.joinLobby(lobby_id)
	var error: ErrorCodes = await lobby_join_response
	is_joining = false
	if error == ErrorCodes.SUCCESS: joined_steam_lobby.emit()
	_is_busy = false
	return error

func _on_steam_lobby_creation_response(connection_response: int, lobby_id: int) -> void:
	match connection_response:
		Steam.RESULT_OK: setup_steam_lobby(lobby_id)
		_: lobby_hosting_response.emit(ErrorCodes.FAILED)

func setup_steam_lobby(lobby_id: int) -> void:
	var my_steam_name: String = Steam.getPersonaName()
	if len(my_steam_name) > 17: my_steam_name = my_steam_name.substr(0,17) + '...'
	Steam.setLobbyData(lobby_id, "name", "%s's Lobby" % my_steam_name)
	Steam.setLobbyJoinable(lobby_id, true)
	var new_steam_multiplayer_peer := SteamMultiplayerPeer.new()
	var error := new_steam_multiplayer_peer.create_host(0)
	match error:
		OK:
			steam_multiplayer_peer = new_steam_multiplayer_peer
			steam_lobby_id = lobby_id
			multiplayer.set_multiplayer_peer(steam_multiplayer_peer)
			Steam.allowP2PPacketRelay(true)
			lobby_hosting_response.emit(ErrorCodes.SUCCESS)
			_register_player_data(personal_player_data.to_dict())
		_:
			steam_multiplayer_peer.close()
			Steam.leaveLobby(lobby_id)
			lobby_hosting_response.emit(ErrorCodes.FAILED)

func _on_steam_lobby_join_response(lobby_id: int, _permissions: int, _locked: bool, response: int) -> void:
	var lobby_owner_id: int = Steam.getLobbyOwner(lobby_id)
	if lobby_owner_id == Steam.getSteamID(): lobby_join_response.emit(ErrorCodes.JOIN_FAILED_SAME_OWNER_ID); return
	if response != Steam.RESULT_OK: lobby_join_response.emit(ErrorCodes.STEAM_CONNECTION_ERROR); return
	var new_steam_peer: SteamMultiplayerPeer = SteamMultiplayerPeer.new()
	var error := new_steam_peer.create_client(lobby_owner_id, 0)
	match error:
		OK:
			steam_lobby_id = lobby_id
			steam_multiplayer_peer = new_steam_peer
			multiplayer.set_multiplayer_peer(steam_multiplayer_peer)
			_register_player_data.call_deferred(personal_player_data.to_dict())
			lobby_join_response.emit(ErrorCodes.SUCCESS)
		_:
			new_steam_peer.close()
			Steam.leaveLobby(steam_lobby_id)
			lobby_join_response.emit(ErrorCodes.FAILED)
	

func get_error_message(error_code: ErrorCodes) -> String:
	var message: String
	match error_code:
		ErrorCodes.SUCCESS: message = "Success."
		ErrorCodes.FAILED: message = "Failed."
		ErrorCodes.JOIN_FAILED_SAME_OWNER_ID: message = "You can't join a lobby you own."
		ErrorCodes.CURRENTLY_BUSY: message = "You're already busy with something!"
		ErrorCodes.STEAM_CONNECTION_ERROR: message = "Error connecting with Steam."
		_: return "Error code %s is unknown." % error_code
	return message

func create_steam_player(multiplayer_connection_id: int) -> PlayerData:
	var player_data := PlayerData.new()
	player_data.display_name = Steam.getPersonaName()
	player_data.multiplayer_id = multiplayer_connection_id
	player_data.steam_id = Steam.getSteamID()
	return player_data


#region LOCAL HOSTING
var local_peer := ENetMultiplayerPeer.new()

const LOCAL_SERVER_ADDRESS: String = "127.0.0.1"
const LOCAL_SERVER_PORT: int = 8080

signal player_connected(player_data: PlayerData)
signal player_disconnected(player_data: PlayerData)
signal server_disconnected

func _setup_local_hosting_signals() -> void:
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server) # Only emitted on clients

func host_local_lobby() -> ErrorCodes:
	if _is_busy: return ErrorCodes.CURRENTLY_BUSY
	_is_busy = true
	is_host = true
	var peer := ENetMultiplayerPeer.new()
	local_peer = peer
	
	var error := peer.create_server(LOCAL_SERVER_PORT, MAX_PLAYERS)
	match error:
		OK:
			multiplayer.multiplayer_peer = local_peer
			_register_player_data(personal_player_data.to_dict())
			_is_busy = false
			return ErrorCodes.SUCCESS
		_:
			is_host = false
			return ErrorCodes.FAILED

func join_local_lobby() -> ErrorCodes:
	if _is_busy: return ErrorCodes.CURRENTLY_BUSY
	_is_busy = true
	var has_local_host := await check_if_host_exists(LOCAL_SERVER_ADDRESS,LOCAL_SERVER_PORT)
	_is_busy = false
	
	if not has_local_host: return ErrorCodes.FAILED
	else: return join_address(LOCAL_SERVER_ADDRESS, LOCAL_SERVER_PORT)

func join_address(address: String, port: int = LOCAL_SERVER_PORT) -> ErrorCodes:
	joining_lobby.emit()
	if _is_busy: return ErrorCodes.CURRENTLY_BUSY
	is_host = false
	var response: ErrorCodes = ErrorCodes.FAILED
	if is_host or steam_lobby_id != 0: leave_lobby()
	var new_multiplayer_peer := ENetMultiplayerPeer.new()
	var error := new_multiplayer_peer.create_client(address, port)
	_is_busy = false
	if error != OK:
		printerr("Failed to join port %s with address: %s" % [port, address])
		return response
	multiplayer.multiplayer_peer = new_multiplayer_peer
	response = ErrorCodes.SUCCESS
	_register_player_data(personal_player_data.to_dict())
	
	return response

func _on_connected_to_server() -> void:
	_register_player_data(personal_player_data.to_dict())
	_register_player_data.rpc_id(1,personal_player_data.to_dict()) ## Requests the Host to register your personal player data
	personal_player_data.multiplayer_id = multiplayer.get_unique_id()
	player_connected.emit(personal_player_data)

func _on_connection_failed() -> void:
	is_host = false
	steam_lobby_id = 0
	multiplayer.multiplayer_peer = null
	connection_failed.emit()

func _on_peer_disconnected(id: int) -> void: _handle_peer_disconnection(id)

func _on_server_disconnected() -> void:
	is_host = false
	players.clear()
	multiplayer.multiplayer_peer = null
	server_disconnected.emit()

func _get_os_user_name() -> String:
	var username := "Player"
	if OS.has_environment("USER"): username = OS.get_environment("USER")
	elif OS.has_environment("USERNAME"): username = OS.get_environment("USERNAME")
	return username

func _handle_peer_disconnection(peer_id: int) -> void:
	if not players.has(peer_id): return
	var player_data: PlayerData = players[peer_id]
	players.erase(peer_id)
	player_disconnected.emit(player_data)

@rpc("any_peer", "reliable", "call_local")
func _register_player_data(player_data_dict: Dictionary):
	var player_data := PlayerData.from_dict(player_data_dict)
	var mult_id := player_data.multiplayer_id
	if not players.has(mult_id) or is_host:
		players[player_data.multiplayer_id] = player_data
		player_connected.emit(player_data)

func _process(_delta: float) -> void:
	_process_steam_p2p_packets()

func _process_steam_p2p_packets() -> void:
	var packet_size: int = Steam.getAvailableP2PPacketSize(0)
	if packet_size == 0: return
	var packet: Dictionary = Steam.readP2PPacket(packet_size, 0)
	var packet_data: Variant = bytes_to_var(packet["data"])
	_handle_incoming_packet(packet_data)

func _handle_incoming_packet(data: Dictionary) -> void:
	match data.get("header"):
		"PAYLOAD": _handle_payload_received(DataPayload.from_dict(data))

func _handle_payload_received(payload: DataPayload) -> void:
	match payload.type:
		payload.Types.STEAM_LOBBY_INVITE:
			var invite_steam_lobby_id: int = payload.lobby_id
			var sender_id: int = payload.sender_steam_id
			steam_lobby_invite_received.emit(invite_steam_lobby_id, sender_id)

func send_steam_data_payload(payload: DataPayload) -> bool:
	var success: bool = Steam.sendP2PPacket(payload.target_steam_id, payload.packet_data, payload.send_type, payload.channel)
	if payload.type == payload.Types.STEAM_LOBBY_INVITE: ## Also invites using Steam direct messages
		Steam.inviteUserToLobby(payload.lobby_id, payload.target_steam_id)
	return success

class DataPayload extends Resource: ## Custom information payload to handle requests
	enum Types { UNDEFINED, STEAM_LOBBY_INVITE, MESSAGE }
	var header: String = "PAYLOAD"
	var lobby_id: int = -1
	var type: Types = Types.UNDEFINED
	var target_steam_id: int = -1
	var sender_steam_id: int = -1
	var send_type: Steam.P2PSend = Steam.P2PSend.P2P_SEND_RELIABLE
	var channel: int = 0
	var content: Dictionary
	var packet_data: PackedByteArray:
		get: 
			var data: Dictionary = {}
			for key in content:
				data.set(key,str(content.get(key)))
			return var_to_bytes(data)
	
	static func from_dict(dict: Dictionary) -> DataPayload:
		var new_payload := DataPayload.new()
		new_payload._apply_data(dict)
		return new_payload
	
	func _apply_data(merge_data: Dictionary = {}) -> void:
		var base_keys: Array[String] = ["header","lobby_id","target_steam_id","sender_steam_id","type","channel","send_type"]
		for key in base_keys:
			var value: Variant = self.get(key)
			if value != null: content.set(key,value)
		for key in merge_data:
			var value: Variant = merge_data.get(key)
			if value != null: content.set(key,value)
		for key in content:
			self.set(key,content.get(key))
		
	func send() -> bool:
		_apply_data()
		return Online.send_steam_data_payload(self)
	func get_header() -> String:
		match type:
			Types.STEAM_LOBBY_INVITE: return "STEAM_LOBBY_INVITE"
			_: return "UNDEFINED"



#region LOCAL HOST VALIDATION
signal _local_host_check_response(has_host: bool)

var _check_timer: Timer

func check_if_host_exists(ip_address: String, port: int) -> bool:
	var peer = ENetMultiplayerPeer.new()
	var error := peer.create_client(ip_address, port)
	if error != OK: return false
	multiplayer.multiplayer_peer = peer
	multiplayer.connected_to_server.connect(_on_host_found)
	multiplayer.connection_failed.connect(_on_host_missing)
	_check_timer = Timer.new()
	add_child(_check_timer)
	_check_timer.wait_time = 2.0
	_check_timer.one_shot = true
	_check_timer.timeout.connect(_on_host_missing)
	_check_timer.start()
	var has_host: bool = await _local_host_check_response
	peer.close()
	_local_cleanup()
	return has_host

func _on_host_found(): _local_host_check_response.emit(true)

func _on_host_missing(): _local_host_check_response.emit(false)

func _local_cleanup():
	if is_instance_valid(_check_timer): _check_timer.queue_free()
	if multiplayer.connected_to_server.is_connected(_on_host_found):
		multiplayer.connected_to_server.disconnect(_on_host_found)
	if multiplayer.connection_failed.is_connected(_on_host_missing):
		multiplayer.connection_failed.disconnect(_on_host_missing)
	multiplayer.multiplayer_peer = null
#endregion
