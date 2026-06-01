extends Control
class_name MainMenuUI

## UI based off "Godot 3D Multiplayer Template" by devmoreir4

signal host_online_requested
signal host_local_requested
signal join_requested(address: String)
signal quit_requested

@export var loading: bool: set = set_loading
@export_subgroup("References")
@export var address_input: LineEdit
@export var color_picker: ColorPicker
@export var main_container: Control

var address: String: get = get_address

func _ready():
	visibility_changed.connect(_on_visibility_changed)
	color_picker.color_changed.connect(_on_color_changed)

func _on_visibility_changed():
	if visible: grab_focus()
	elif has_focus(): release_focus()

func show_menu():
	grab_focus()
	show()

func hide_menu():
	release_focus()
	hide()

func set_loading(value: bool) -> void:
	if loading == value: return
	loading = value
	if loading:
		main_container.mouse_behavior_recursive = Control.MOUSE_BEHAVIOR_DISABLED
		main_container.modulate.a = 0.5
	else:
		main_container.mouse_behavior_recursive = Control.MOUSE_BEHAVIOR_INHERITED
		main_container.modulate.a = 1.0

func get_address() -> String: return address_input.text.strip_edges()

func _on_color_changed(color: Color): Online.personal_player_data.color = color

func _on_host_online_pressed(): host_online_requested.emit()

func _on_host_local_pressed() -> void: host_local_requested.emit()

func _on_join_pressed(): join_requested.emit(address)

func _on_quit_pressed(): quit_requested.emit()
