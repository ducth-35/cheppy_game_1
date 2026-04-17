extends CharacterBody2D

const SPEED = 300.0
const BOOST_SPEED = 500.0
const JUMP_VELOCITY = -600.0

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var run_sfx_player: AudioStreamPlayer = get_node_or_null("AudioPlayerRun") as AudioStreamPlayer
@onready var state_ui: CanvasLayer = get_node_or_null("AnswerStateUI") as CanvasLayer
@onready var state_true_char = get_node_or_null("AnswerStateUI/StateTrueChar")
@onready var state_false_char = get_node_or_null("AnswerStateUI/StateFalseChar")
@onready var state_text = get_node_or_null("AnswerStateUI/StateText")
@onready var audio_try_again: AudioStreamPlayer = get_node_or_null("AudioTryAgain") as AudioStreamPlayer
@onready var audio_perfect: AudioStreamPlayer = get_node_or_null("AudioPerfect") as AudioStreamPlayer

var is_running = false
var is_locked = false
var is_falling = false
var current_speed = SPEED
var is_answer_processing = false


func _ready():
	add_to_group("player")
	if state_ui:
		state_ui.layer = 200
	if run_sfx_player:
		run_sfx_player.volume_db = 8.0
	_hide_answer_state_immediate()


# =========================
# 🎮 CONTROL FROM RN
# =========================

func set_running(state: bool):
	is_running = state
	if not state:
		play_anim("idle")


func on_answer(correct: bool):
	if is_answer_processing:
		return

	is_answer_processing = true
	is_locked = true
	velocity = Vector2.ZERO

	if correct:
		_show_answer_state(true)
		await _play_audio_and_wait(audio_perfect, 1.0)
		await _hide_answer_state_animated()
		is_locked = false
		jump_over_gap()
		notify_next_question()
	else:
		_show_answer_state(false)
		await _play_audio_and_wait(audio_try_again, 1.0)
		await _hide_answer_state_animated()
		is_locked = true

	is_answer_processing = false


# =========================
# 🧱 GAME EVENTS
# =========================

func on_reach_stop(gap):
	if is_locked or is_falling:
		return
		
	is_locked = true
	velocity = Vector2.ZERO
	play_anim("idle")

	JavaScriptBridge.eval("""
		window.dispatchEvent(new CustomEvent('onStop', { detail: { status: true } }))
	""")


func on_reach_gap(gap):
	if is_falling:
		return
	
	fall_down()


func on_reach_finish():
	current_speed = BOOST_SPEED
	
	await get_tree().create_timer(1.0).timeout
	
	await freeze_game(2.5)


# =========================
# 🎯 ACTIONS
# =========================

func jump_over_gap():
	is_falling = false
	play_anim("jump")
	velocity.y = JUMP_VELOCITY
	is_running = true


func fall_down():
	#is_falling = true
	#is_running = true
	#is_locked = true
	#
	#velocity = Vector2.ZERO
	play_anim("fall")

	# 👉 cho animation hiện ra
	await get_tree().create_timer(1.5).timeout
	
	await freeze_game(2)


# ✅ freeze chuẩn (không bị treo)
func freeze_game(duration):
	if run_sfx_player and run_sfx_player.playing:
		run_sfx_player.stop()
	if audio_try_again and audio_try_again.playing:
		audio_try_again.stop()
	if audio_perfect and audio_perfect.playing:
		audio_perfect.stop()

	Engine.time_scale = 0.0
	
	await get_tree().create_timer(duration, true).timeout
	
	Engine.time_scale = 1.0
	get_tree().reload_current_scene()


# =========================
# 🔁 MAIN LOOP
# =========================

func _physics_process(delta):

	# 🔥 FALL (priority cao nhất)
	if is_falling:
		velocity.x = 0
		velocity += get_gravity() * delta
		move_and_slide()
		return

	# 🔒 LOCK (đứng im)
	if is_locked:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	# ⛔ chưa chạy
	if not is_running:
		play_anim("idle")
		return

	# 👉 AUTO RUN
	velocity.x = current_speed

	# gravity
	if not is_on_floor():
		velocity += get_gravity() * delta

	# animation
	if not is_on_floor():
		if velocity.y < 0:
			play_anim("jump")
		#else:
			#play_anim("run")
	else:
		play_anim("run")

	move_and_slide()


# =========================
# 🎬 ANIMATION HELPER
# =========================

func play_anim(name: String):
	if anim.animation != name:
		anim.play(name)

	update_run_sfx(name)


func update_run_sfx(anim_name: String):
	var should_play = anim_name == "run" and is_running and not is_locked and not is_falling

	if should_play:
		if run_sfx_player and run_sfx_player.stream and not run_sfx_player.playing:
			run_sfx_player.play()
	else:
		if run_sfx_player and run_sfx_player.playing:
			run_sfx_player.stop()


func _hide_answer_state_immediate():
	if state_ui:
		state_ui.visible = false
	if state_true_char:
		state_true_char.modulate.a = 1.0
		state_true_char.scale = Vector2.ONE
		state_true_char.visible = false
	if state_false_char:
		state_false_char.modulate.a = 1.0
		state_false_char.scale = Vector2.ONE
		state_false_char.visible = false
	if state_text:
		state_text.visible = false


func _show_answer_state(correct: bool):
	if state_ui:
		state_ui.visible = true
	if state_true_char:
		state_true_char.visible = correct
	if state_false_char:
		state_false_char.visible = not correct
	if state_text:
		state_text.visible = true

	var target = state_true_char if correct else state_false_char
	if target:
		target.modulate.a = 0.0
		target.scale = Vector2(0.88, 0.88)

		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(target, "modulate:a", 1.0, 0.24).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tween.tween_property(target, "scale", Vector2.ONE, 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _hide_answer_state_animated() -> void:
	var has_target := false
	var tween := create_tween()
	tween.set_parallel(true)

	if state_true_char and state_true_char.visible:
		has_target = true
		tween.tween_property(state_true_char, "modulate:a", 0.0, 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		tween.tween_property(state_true_char, "scale", Vector2(0.92, 0.92), 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

	if state_false_char and state_false_char.visible:
		has_target = true
		tween.tween_property(state_false_char, "modulate:a", 0.0, 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		tween.tween_property(state_false_char, "scale", Vector2(0.92, 0.92), 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

	if has_target:
		await tween.finished

	_hide_answer_state_immediate()


func _play_audio_and_wait(player: AudioStreamPlayer, fallback_seconds: float) -> void:
	if player and player.stream:
		if player.playing:
			player.stop()
		player.play()
		await player.finished
		return

	await get_tree().create_timer(fallback_seconds).timeout


func notify_next_question():
	if not OS.has_feature("web"):
		return

	JavaScriptBridge.eval("""
		window.dispatchEvent(new CustomEvent('onNextQuestion', { detail: { status: true } }))
	""")


func _on_button_pressed():
	set_running(true)


func _on_button_2_pressed():
	on_answer(true)


func _on_button_3_pressed():
	on_answer(false)
