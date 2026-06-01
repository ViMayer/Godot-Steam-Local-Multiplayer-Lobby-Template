extends Control
class_name ControlLoaderEffect

@export var active := true:
	set(value): if active != value: active = value; set_process(active); call_deferred("_update_visuals")
@export_storage var loader_rect: CanvasItem
@export var reference_node: Control

var _tween: Tween
func _enter_tree() -> void: set_process(active); call_deferred("_update_visuals")
func _ready() -> void: _update_visuals.call_deferred()

func _process(_delta: float) -> void:
	if not active: return
	if not is_instance_valid(reference_node): return


func _fit_reference() -> void:
	if not is_instance_valid(reference_node): return
	if reference_node is CanvasItem:
		self.size = reference_node.size
	if reference_node.get("global_position") != null: self.global_position = reference_node.global_position
	else: self.custom_minimum_size = Vector2.ZERO
	self.set_anchors_preset(Control.PRESET_FULL_RECT)
	loader_rect.set_anchors_preset(Control.PRESET_FULL_RECT)

func _update_visuals() -> void:
	_fit_reference()
	if active: self.visible = true
	if is_instance_valid(_tween): _tween.stop()
	var current_material: ShaderMaterial = material
	if not current_material: return
	_tween = create_tween()
	_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_tween.tween_property(current_material,"shader_parameter/alpha_multiplier",int(active), 0.3).from(current_material.get_shader_parameter("alpha_multiplier"))
	_tween.finished.connect(func(): if is_instance_valid(self) and not active: self.visible = false)
