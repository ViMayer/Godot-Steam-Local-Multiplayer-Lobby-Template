extends Area3D

@export_range(0.0, 7.0, 0.001,"or_greater","or_less") var gravity_multiplier : float = 0.511

var _original_gravity_values: Dictionary[Node, Dictionary] = {}

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body) -> void:
	# stores body original gravity values
	if body is RigidBody3D:
		_original_gravity_values[body] = { "gravity_scale": body.gravity_scale }
		body.gravity_scale *= gravity_multiplier
	elif body.get("gravity_modifier") is float or body.get("gravity_modifier") is int:
		_original_gravity_values[body] = { "gravity_modifier": body.gravity_modifier }
		body.set("gravity_modifier",body.get("gravity_modifier") * gravity_multiplier)

func _on_body_exited(body) -> void:
	if _original_gravity_values.has(body): # restores original gravity-related values
		var body_original_values := _original_gravity_values.get(body)
		for value_name in body_original_values:
			body.set(value_name,body_original_values.get(value_name))
		_original_gravity_values.erase(body)
