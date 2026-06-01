extends Control
class_name LobbyInvitePopup

signal request_handled

var request_lobby_id := 0
var request_sender_id := 0

@onready var request_timeout_timer: Timer = %RequestTimeoutTimer
@onready var sender_name_label: RichTextLabel = %SenderNameLabel

func _ready() -> void:
	Online.steam_lobby_invite_received.connect(_on_lobby_invite_received)
	request_timeout_timer.timeout.connect(_on_request_timeout)
	request_handled.connect(_on_request_handled)
	_update_request_info()
	_close_request()

func _on_lobby_invite_received(lobby_id: int, sender_id: int) -> void:
	if Online.steam_lobby_id == lobby_id: return
	request_timeout_timer.start()
	show()
	request_timeout_timer.start()
	request_lobby_id = lobby_id
	request_sender_id = sender_id
	_update_request_info()

func _accept_request() -> void:
	if Online.steam_lobby_id: Online.leave_lobby()
	Online.join_steam_lobby(request_lobby_id)
	
	_close_request()

func _close_request() -> void:
	request_lobby_id = 0
	request_sender_id = 0
	hide()
	_update_request_info()
	request_handled.emit()

func _on_request_handled() -> void: if not request_timeout_timer.is_stopped(): request_timeout_timer.stop()
func _update_request_info() -> void: sender_name_label.text = Steam.getFriendPersonaName(request_sender_id)
func _on_request_timeout() -> void: _close_request()
func _on_join_button_pressed() -> void: _accept_request()
func _on_close_button_pressed() -> void: _close_request()
