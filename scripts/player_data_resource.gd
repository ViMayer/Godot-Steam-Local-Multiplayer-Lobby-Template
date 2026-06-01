extends Resource
class_name PlayerData

@export var instance_id: int = 0
@export var multiplayer_id: int = 0
@export var display_name: String = "Player"
@export var steam_id: int = -1
@export var color: Color = Color.WHITE

static var base_dict := {
		"instance_id": 0,
		"multiplayer_id": 0,
		"display_name": "Player",
		"steam_id": -1,
}

static func from_dict(dict: Dictionary) -> PlayerData:
	var player_data := PlayerData.new()
	for key in dict:
		player_data.set(key,dict[key])
	return player_data

static func apply_data_to_node(data: PlayerData, node: Node) -> void:
	if not data: return
	var id := data.multiplayer_id
	node.name = str(id)
	node.set_multiplayer_authority(id)
	if node.get("player_data") is PlayerData:
		node.set("player_data", data)

func to_dict() -> Dictionary:
	var dict := {}
	for key in base_dict:
		var value: Variant = self.get(key)
		if value == null: value = base_dict.get(key)
		dict[key] = value
	return dict
