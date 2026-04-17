extends Node2D

@onready var camera: Camera2D = $CharacterBody2D/Camera2D
@onready var player: CharacterBody2D = $CharacterBody2D
@onready var progress_ui: CanvasLayer = $ProgressQuestions

var _start_view_snapped := false
var _js_update_progress_callback = null


func _ready() -> void:
	get_viewport().size_changed.connect(_update_camera_limits)
	_update_camera_limits()
	_snap_start_view_once()
	_setup_game_start_flow()
	_setup_js_bridge_callbacks()


func _setup_game_start_flow() -> void:
	var countdown := get_node_or_null("CountDown")
	if countdown == null:
		_start_gameplay()
		return

	countdown.countdown_finished.connect(_start_gameplay)


func _start_gameplay() -> void:
	if player.has_method("set_running"):
		player.set_running(true)
	update_progress_from_rn(1, 4)


func update_progress_from_rn(opened_count: int, total_count: int = -1) -> void:
	if progress_ui and progress_ui.has_method("update_progress_from_rn"):
		progress_ui.call("update_progress_from_rn", opened_count, total_count)


func _setup_js_bridge_callbacks() -> void:
	if not OS.has_feature("web"):
		return

	var window = JavaScriptBridge.get_interface("window")
	if window == null:
		return

	_js_update_progress_callback = JavaScriptBridge.create_callback(_on_js_update_progress)
	window.updateGodotProgress = _js_update_progress_callback


func _on_js_update_progress(args: Array) -> void:
	var opened_count := 0
	var total_count := -1

	if args.size() > 0:
		opened_count = int(args[0])
	if args.size() > 1:
		total_count = int(args[1])

	update_progress_from_rn(opened_count, total_count)


func _snap_start_view_once() -> void:
	if _start_view_snapped:
		return
	_start_view_snapped = true


func _update_camera_limits() -> void:
	var bg_bounds := _collect_background_bounds()
	if bg_bounds.size == Vector2.ZERO:
		return

	var left := int(floor(bg_bounds.position.x))
	var right := int(ceil(bg_bounds.end.x))
	var top := int(floor(bg_bounds.position.y))
	var bottom := int(ceil(bg_bounds.end.y))

	if left > right:
		var center_x := int(round((bg_bounds.position.x + bg_bounds.end.x) * 0.5))
		left = center_x
		right = center_x

	if top > bottom:
		var center_y := int(round((bg_bounds.position.y + bg_bounds.end.y) * 0.5))
		top = center_y
		bottom = center_y

	camera.limit_left = left
	camera.limit_right = right
	camera.limit_top = top
	camera.limit_bottom = bottom


func _collect_background_bounds() -> Rect2:
	var bg_nodes := get_tree().get_nodes_in_group("background_bounds")
	if bg_nodes.is_empty():
		for child in get_children():
			if child is Sprite2D and String(child.name).begins_with("Br"):
				bg_nodes.append(child)

	var has_rect := false
	var bounds := Rect2()

	for node in bg_nodes:
		if not (node is Sprite2D):
			continue
		var sprite := node as Sprite2D
		if sprite.texture == null:
			continue

		var tex_size := sprite.texture.get_size() * sprite.scale.abs()
		if tex_size == Vector2.ZERO:
			continue

		var top_left := sprite.global_position
		if sprite.centered:
			top_left -= tex_size * 0.5

		var rect := Rect2(top_left, tex_size)
		if not has_rect:
			bounds = rect
			has_rect = true
		else:
			bounds = bounds.merge(rect)

	return bounds
