extends Control
class_name SteamFriendCard

const STEAM_FRIEND_CARD_SCENE := preload("uid://bk6f6a2dc0554")

signal loaded

@export var avatar_texture_rect: TextureRect
@export var name_label: RichTextLabel
@export var status_control_node: Control
@export var control_loader_effect: ControlLoaderEffect
@export var invite_button: Button
@export var margin_container: MarginContainer
@export var h_box_container: HBoxContainer

var steam_id: int = 0
var display_name: String = "Player"
var status: Steam.PersonaState = Steam.PersonaState.PERSONA_STATE_OFFLINE
var _loading: bool = false

func show_loading_visuals() -> void:
	control_loader_effect.active = true

func hide_loading_visuals() -> void:
	control_loader_effect.active = false
	play_loaded_animations()

func read_friend_id(friend_id: int) -> void:
	if _loading: return
	show_loading_visuals()
	_loading = true
	steam_id = friend_id
	display_name = Steam.getFriendPersonaName(friend_id)
	status = Steam.getFriendPersonaState(friend_id) as Steam.PersonaState
	
	var prefix = "3" if status == Steam.PersonaState.PERSONA_STATE_AWAY else "2" if status == Steam.PersonaState.PERSONA_STATE_SNOOZE else "1" if status != Steam.PersonaState.PERSONA_STATE_OFFLINE else "9"
	self.name = "%s_%s" % [prefix,display_name]
	
	Steam.avatar_loaded.connect(_on_avatar_loaded)
	Steam.getPlayerAvatar(Steam.AVATAR_SMALL, steam_id)
	
	var disable_invite_to_offline := false # If true will disable the invite button to players that are offline on steam
	if disable_invite_to_offline and status == Steam.PersonaState.PERSONA_STATE_OFFLINE: invite_button.disabled = true
	else: invite_button.disabled = false

func _update_visuals() -> void:
	status_control_node.modulate = get_status_color(status)
	margin_container.modulate.a = 0.25 if status == Steam.PersonaState.PERSONA_STATE_OFFLINE else 1.0 if status == Steam.PersonaState.PERSONA_STATE_ONLINE else 0.7
	name_label.text = display_name

func _on_avatar_loaded(user_id: int, avatar_size: int, avatar_buffer: PackedByteArray) -> void:
	if user_id != steam_id: return
	Steam.avatar_loaded.disconnect(_on_avatar_loaded)
	var image: Image = Image.create_from_data(avatar_size, avatar_size, false, Image.FORMAT_RGBA8, avatar_buffer)
	var image_texture: ImageTexture = ImageTexture.create_from_image(image)
	avatar_texture_rect.texture = image_texture
	_update_visuals()
	_loading = false
	loaded.emit()

func play_loaded_animations() -> void:
	for child in h_box_container.get_children():
		if not child is ControlLoaderEffect:
			child.modulate.a = 1.0
			child.visible = true


var item_scene: PackedScene:
	get:
		if not item_scene: item_scene = load(self.scene_file_path) as PackedScene
		return item_scene

static func create_player_card(player_steam_id: int) -> SteamFriendCard:
	var card := STEAM_FRIEND_CARD_SCENE.instantiate()
	card.read_friend_id(player_steam_id)
	return card

func get_status_string(status_code: Steam.PersonaState) -> String:
	match status_code:
		0: return "Offline"
		1: return "Online"
		2: return "Busy"
		3: return "Away"
		4: return "Snooze"
		5: return "Looking to Trade"
		6: return "Looking to Play"
		_: return "Unknown"

func get_status_color(status_code: Steam.PersonaState) -> Color:
	match status_code:
		1: return Color.GREEN # Online
		2: return Color.DARK_RED # Busy
		3: return Color(0.0, 0.257, 0.499, 1.0) # Away
		4: return Color(0.0, 0.321, 0.0, 1.0) # Snooze
		5: return Color.LIGHT_GREEN # Looking to Trade
		6: return Color.YELLOW # Looking to Play
		_: return Color(0.2,0.2,0.2,0.5) # Offline or Unknown


func _on_invite_button_pressed() -> void: _invite_to_lobby()

func _invite_to_lobby():
	
	var lobby_id := Online.steam_lobby_id

	if lobby_id == 0:
		printerr("Invite: No active lobby found.")
		return
		
	# Send the invite directly to the target 64-bit Steam ID
	var payload := Online.DataPayload.new()
	payload.type = payload.Types.STEAM_LOBBY_INVITE
	payload.sender_steam_id = Steam.getSteamID()
	payload.target_steam_id = steam_id
	payload.lobby_id = lobby_id
	payload.send()
