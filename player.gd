class_name Player extends Node2D

@onready var stickman: Line2D = %Stickman
@onready var eye: Sprite2D = %Eye

const SPEED := 5.0
const PLAYER_SCENE := preload("res://Player.tscn")
const PLAYER_RADIUS := 35.0

var can_move := true

static func create(parent: Node, player_data: PlayerData) -> Player:
	var p := PLAYER_SCENE.instantiate()
	p.name = player_data['username']
	parent.add_child(p)
	p.stickman.default_color = player_data.colour
	p.set_multiplayer_authority(player_data.network_id)
	return p

func _ready() -> void:
	Helper.add_player(self)

func _get_local_input() -> Dictionary:
	var input_vec = Input.get_vector('ui_left','ui_right','ui_up','ui_down')
	var input := {"input_vector": input_vec}
	
	input['actions'] = self.unhandled_actions
	self.unhandled_actions = []
	return input
	
func _network_process(input: Dictionary) -> void:
	if "input_vector" in input and self.can_move:
		self.position += input["input_vector"]*SPEED
		self.stickman.move(self.position)
	
	for action in input.get('actions',[]):
		if len(action) == 3:
			var function_id: int = action[1]
			var params: Array = action[2]
			if Helper.network_object_tracker.get_obj(action[0]) == null:
				print('------------------------------')
				print(action[0])
				print(action[1])
				print(action[2])
				print()
			Helper.get_network_obj_by_id(action[0]).run_command(function_id, params)
		else:
			var static_f_id: int = action[0]
			var params: Array = action[1]
			Helper.run_static_function(static_f_id, params)

func _save_state() -> Dictionary:
	return {
			'position': self.position,
			'can_move': self.can_move,
			'inspecting_deck': self.eye.visible
		}

func _load_state(state: Dictionary) -> void:
	self.position = state.get('position', self.position)
	self.can_move = state.get('can_move', self.can_move)
	self.set_inspecting_deck(state.get('inspecting_deck', self.eye.visible))

func _draw() -> void:
	draw_circle(Vector2.ZERO, PLAYER_RADIUS, Color(0,0,0,0.4))

func _on_tree_exited() -> void:
	Helper.remove_player(self)

func set_inspecting_deck(is_inspecting: bool) -> void:
	self.can_move = not is_inspecting
	self.eye.visible = is_inspecting
	self.eye.position = self.stickman.position -Vector2(0,60)

# list of [custom_node_id, custom_function_id, params_arr] | [custom_static_function, params_arr]
var unhandled_actions: Array[Array]
# takes [custom_node_id, custom_function_id, params_arr] | [custom_static_function, params_arr]
func set_input(func_info: Array) -> void:
	unhandled_actions.append(func_info)
