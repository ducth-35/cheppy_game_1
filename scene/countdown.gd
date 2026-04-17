extends CanvasLayer

@onready var anim: AnimationPlayer = $Control/AnimationPlayer
@onready var audio: AudioStreamPlayer = $Control/AudioStreamPlayer

signal countdown_finished

func _ready():
	if audio.stream != null:
		audio.stop()
		audio.play()
	anim.play("countdown")

func _play_sound(path):
	audio.stream = load(path)
	audio.play()
	

func _on_animation_player_animation_finished(anim_name):
	if anim_name == "countdown":
		countdown_finished.emit()
		queue_free()
