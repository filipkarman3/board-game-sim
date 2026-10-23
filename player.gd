class_name Player extends Node2D

@onready var stickman: Line2D = %Stickman
@onready var eye: Sprite2D = %Eye

const SPEED := 5.0
const PLAYER_SCENE := preload("res://Player.tscn")

var can_move := true

static func create(parent: Node, player_data: PlayerData) -> Player:
	var p := PLAYER_SCENE.instantiate()
	parent.add_child(p)
	p.stickman.default_color = player_data.colour
	p.set_multiplayer_authority(player_data.network_id)
	return p

func _ready() -> void:
	Helper.add_player(self)

func _get_local_input() -> Dictionary:
	var input_vec = Input.get_vector('ui_left','ui_right','ui_up','ui_down')
	var input := {"input_vector": input_vec}
	return input
	
func _network_process(input: Dictionary) -> void:
	if "input_vector" in input and self.can_move:
		self.position += input["input_vector"]*SPEED
		self.stickman.move(self.position)

func _save_state() -> Dictionary:
	return { "position": self.position }

func _load_state(state: Dictionary) -> void:
	self.position = state["position"]

func _draw() -> void:
	draw_circle(Vector2.ZERO, 35, Color(0,0,0,0.4))

func _on_tree_exited() -> void:
	Helper.remove_player(self)

func set_inspecting_deck(is_inspecting: bool) -> void:
	self.can_move = not is_inspecting
	self.eye.visible = is_inspecting
	self.eye.position = self.stickman.position -Vector2(0,60)
