class_name GameMenu extends CanvasLayer

const SCENE = preload("res://GameMenu.tscn")

static func create() -> GameMenu:
	var gm: GameMenu = SCENE.instantiate()
	return gm

func _ready() -> void:
	self.visible = false

func _on_exit_button_pressed() -> void:
	self.visible = false

func _input(e: InputEvent) -> void:
	if e.is_action_pressed('open-menu'):
		self.visible = true
