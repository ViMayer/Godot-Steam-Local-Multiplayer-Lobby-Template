extends Panel

@export var friend_item_scene: PackedScene
@export var cards_container: Node

var _has_loaded: bool = false
var _load_queue: Array[int]

func _ready() -> void:
	if not _has_loaded: _load_friends.call_deferred()

func _load_friends() -> void:
	if _has_loaded: return
	_has_loaded = true

	var friend_count: int = Steam.getFriendCount()
	
	for child in cards_container.get_children(): child.queue_free()
	_load_queue = []
	for i in range(friend_count):
		var steam_id: int = Steam.getFriendByIndex(i, Steam.FRIEND_FLAG_IMMEDIATE)
		if steam_id == 0: continue
		_load_queue.append(steam_id)
	for steam_id in _load_queue:
		var item: SteamFriendCard = SteamFriendCard.create_player_card(steam_id)
		cards_container.add_child(item)
		item.loaded.connect(_on_steam_id_added.bind(steam_id))

func _on_steam_id_added(steam_id: int) -> void:
	_load_queue.erase(steam_id)
	if _load_queue.is_empty(): call_deferred("_on_loading_finished")

func _on_loading_finished() -> void:
	await get_tree().create_timer(0.5).timeout
	sort_children_alphabetically(cards_container)
	for node: SteamFriendCard in cards_container.get_children():
		node.hide_loading_visuals()

func sort_children_alphabetically(node: Node) -> void:
	var children: Array[Node] = node.get_children()
	children.sort_custom( func(a: Node, b: Node) -> bool: return a.name.to_lower() < b.name.to_lower())
	for i in children.size(): node.move_child(children[i], i)
