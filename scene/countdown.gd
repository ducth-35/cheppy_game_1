extends CanvasLayer

@onready var anim: AnimationPlayer = $Control/AnimationPlayer

signal countdown_finished

func _ready():
	anim.play("countdown")


func _on_animation_player_animation_finished(anim_name):
	if anim_name == "countdown":
		countdown_finished.emit()
		queue_free()
