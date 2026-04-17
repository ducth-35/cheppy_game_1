extends CanvasLayer

const VIEWBOX_WIDTH := 869.0
const VIEWBOX_HEIGHT := 39.0
const TRACK_X := 9.5
const TRACK_Y := 8.0
const TRACK_WIDTH := 848.0
const TRACK_HEIGHT := 22.0
const TRACK_RADIUS := 43.5
const BAR_RADIUS := 55.0
const PIN_WIDTH := 44.0
const PIN_HEIGHT := 34.0
const BOTTOM_OFFSET := 104.0
const SIDE_GAP := 66.0

const BAR_OUTER_COLOR := Color("#BF6E03")
const TRACK_BG_COLOR := Color("#FFC16F")
const FILL_COLOR := Color("#FF8612")
const FILL_BORDER_COLOR := Color("#F7931E")
const FILL_HIGHLIGHT_COLOR := Color("#FFB15B")

const PIN_TEXTURE := preload("res://assets/pin/pin.png")

@export var total_items: int = 4
@export var opened_items_count: int = 0
@export var anim_duration: float = 0.5
@export var force_show_on_start: bool = true

@onready var _container: Control = $Container
@onready var _bar_outer: Panel = $Container/BarOuter
@onready var _track_bg: Panel = $Container/TrackBg
@onready var _fill_clip: Control = $Container/FillClip
@onready var _fill_main: Panel = $Container/FillClip/FillMain
@onready var _fill_highlight: ColorRect = $Container/FillClip/FillHighlight
@onready var _pins_layer: Control = $Container/Pins


func _ready() -> void:
	layer = 100
	visible = true
	_apply_styles()
	_setup_layout_values()
	get_viewport().size_changed.connect(_layout)
	_layout()
	_rebuild_pins()
	_set_progress_visual(opened_items_count, false)

	if force_show_on_start and opened_items_count <= 0:
		_set_progress_visual(1, false)


func update_progress_from_rn(opened_count: int, total_count: int = -1) -> void:
	if total_count > 0:
		total_items = total_count
	opened_items_count = clampi(opened_count, 0, max(total_items, 1))
	_rebuild_pins()
	_set_progress_visual(opened_items_count, true)


func set_progress(opened_count: int) -> void:
	update_progress_from_rn(opened_count, -1)


func set_total_items(value: int) -> void:
	total_items = max(value, 1)
	if opened_items_count > total_items:
		opened_items_count = total_items
	_rebuild_pins()
	_set_progress_visual(opened_items_count, false)


func _setup_layout_values() -> void:
	_container.position = Vector2.ZERO
	_container.size = Vector2(VIEWBOX_WIDTH, VIEWBOX_HEIGHT)

	_bar_outer.position = Vector2.ZERO
	_bar_outer.size = Vector2(VIEWBOX_WIDTH, VIEWBOX_HEIGHT)

	_track_bg.position = Vector2(TRACK_X, TRACK_Y)
	_track_bg.size = Vector2(TRACK_WIDTH, TRACK_HEIGHT)

	_fill_clip.position = Vector2(TRACK_X, TRACK_Y)
	_fill_clip.size = Vector2(TRACK_WIDTH, TRACK_HEIGHT)
	_fill_clip.clip_contents = true

	_fill_main.position = Vector2.ZERO
	_fill_main.size = Vector2(0.0, TRACK_HEIGHT)

	_fill_highlight.position = Vector2(0.0, 1.0)
	_fill_highlight.size = Vector2(0.0, TRACK_HEIGHT - 2.0)


func _apply_styles() -> void:
	_apply_fill_style(_fill_main, FILL_COLOR, FILL_BORDER_COLOR, 2, TRACK_RADIUS)
	_fill_highlight.color = FILL_HIGHLIGHT_COLOR
	_fill_highlight.modulate.a = 0.25

	_apply_panel_style(_bar_outer, BAR_OUTER_COLOR, BAR_RADIUS)
	_apply_panel_style(_track_bg, TRACK_BG_COLOR, TRACK_RADIUS)


func _apply_fill_style(panel: Panel, fill_color: Color, border_color: Color, border_width: int, radius: float) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = fill_color
	style.border_color = border_color
	style.border_width_left = border_width
	style.border_width_top = border_width
	style.border_width_right = border_width
	style.border_width_bottom = border_width
	style.corner_radius_top_left = int(radius)
	style.corner_radius_top_right = int(radius)
	style.corner_radius_bottom_right = int(radius)
	style.corner_radius_bottom_left = int(radius)
	panel.add_theme_stylebox_override("panel", style)


func _apply_panel_style(panel: Panel, color: Color, radius: float) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = int(radius)
	style.corner_radius_top_right = int(radius)
	style.corner_radius_bottom_right = int(radius)
	style.corner_radius_bottom_left = int(radius)
	panel.add_theme_stylebox_override("panel", style)


func _layout() -> void:
	if _container == null:
		return

	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var target_width: float = minf(VIEWBOX_WIDTH, maxf(0.0, viewport_size.x - SIDE_GAP))
	var ratio: float = target_width / VIEWBOX_WIDTH
	if ratio <= 0.0:
		ratio = 1.0

	_container.scale = Vector2(ratio, ratio)
	_container.size = Vector2(VIEWBOX_WIDTH, VIEWBOX_HEIGHT)
	_container.position = Vector2((viewport_size.x - target_width) * 0.5, viewport_size.y - BOTTOM_OFFSET - VIEWBOX_HEIGHT * ratio)


func _set_progress_visual(opened_count: int, animated: bool) -> void:
	var safe_total: int = maxi(total_items, 1)
	var progress: float = clampf(float(opened_count) / float(safe_total), 0.0, 1.0)
	var target_width: float = progress * TRACK_WIDTH

	if animated:
		var tween: Tween = create_tween()
		tween.tween_property(_fill_main, "size:x", target_width, anim_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(_fill_highlight, "size:x", target_width, anim_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	else:
		_fill_main.size.x = target_width
		_fill_main.size.y = TRACK_HEIGHT
		_fill_highlight.size.x = target_width
		_fill_highlight.size.y = TRACK_HEIGHT - 2.0


func _rebuild_pins() -> void:
	if _pins_layer == null:
		return

	for child in _pins_layer.get_children():
		child.queue_free()

	if total_items <= 1:
		return

	for i in range(total_items - 1):
		var pin := TextureRect.new()
		pin.texture = PIN_TEXTURE
		pin.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		pin.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		pin.size = Vector2(PIN_WIDTH, PIN_HEIGHT)
		pin.position = Vector2(TRACK_X + (TRACK_WIDTH / float(total_items)) * float(i + 1) - PIN_WIDTH * 0.5, TRACK_Y - 4.0)
		_pins_layer.add_child(pin)
