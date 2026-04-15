extends CharacterBody2D

const SPEED = 300.0
const BOOST_SPEED = 500.0
const JUMP_VELOCITY = -600.0

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D

var is_running = true
var is_locked = false
var is_falling = false
var current_speed = SPEED


func _ready():
	add_to_group("player")


# =========================
# 🎮 CONTROL FROM RN
# =========================

func set_running(state: bool):
	is_running = state
	if not state:
		play_anim("idle")


func on_answer(correct: bool):
	is_locked = false
	
	if correct:
		jump_over_gap()
	else:
		fall_down()


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
	
	await freeze_game(0.5)


# =========================
# 🎯 ACTIONS
# =========================

func jump_over_gap():
	is_falling = false
	play_anim("jump")
	velocity.y = JUMP_VELOCITY
	is_running = true


func fall_down():
	is_falling = true
	is_running = false
	is_locked = true
	
	velocity = Vector2.ZERO
	play_anim("fall")

	# 👉 cho animation hiện ra
	await get_tree().create_timer(0.2).timeout
	
	await freeze_game(0.5)


# ✅ freeze chuẩn (không bị treo)
func freeze_game(duration):
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
		else:
			play_anim("fall")
	else:
		play_anim("run")

	move_and_slide()


# =========================
# 🎬 ANIMATION HELPER
# =========================

func play_anim(name: String):
	if anim.animation != name:
		anim.play(name)
