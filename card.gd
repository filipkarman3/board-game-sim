class_name Card extends Node2D

"""
json file contents:
{
	"front": <path_to_front_sprite>,
	"back": <path_to_back_sprite>
}
"""

const SCENE = preload("res://Card.tscn")

static func create_from_info(_path: String, data: Dictionary) -> Card:
	data['path'] = _path
	var c: Card = SyncManager.spawn('Card', Helper.get_main(), SCENE, data)
	Helper.add_network_object(c)
	return c

func _network_spawn(data: Dictionary) -> void:
	self.path = data['path']
	self.json = Helper.json_starter(Helper.get_full_path(path))
	
	self.front_sprite_texture = Helper.get_texture(self.json['front'])
	self.back_sprite_texture = Helper.get_texture(self.json['back'])
	if not self.front_sprite_texture.get_size().is_equal_approx(self.back_sprite_texture.get_size()):
		assert(false, "Card (%s) front and back textures must be of same width and height" % path)
	
	self.flip_card(data.get('is_face_up', false))
	self.global_position = data.get('global_position', self.global_position)

	front_sprite.texture = front_sprite_texture
	back_sprite.texture  = back_sprite_texture
	self.card_interact_ui.position.y = -self.get_card_size().y/2 -self.card_interact_ui.get_minimum_size().y -10
	
	self.outline.position = -self.get_card_size()/2-Vector2(BORDER_THICKNESS,BORDER_THICKNESS)
	self.outline.size = self.get_card_size()+Vector2(BORDER_THICKNESS*2,BORDER_THICKNESS*2)

@onready var front_sprite: Sprite2D = %Front
@onready var back_sprite: Sprite2D = %Back
@onready var card_interact_ui: HBoxContainer = %CardInteractUI
@onready var insert_into_deck_menu: CanvasLayer = %InsertIntoDeckMenu
@onready var insert_index_spinbox: SpinBox = %InsertIndexSpinbox
@onready var outline: Panel = %CardOutline
@onready var hand_button: Button = %HandButton
@onready var flip_button: Button = %FlipButton

const BORDER_THICKNESS: float = 5

var network_commands := TwoWay.from_dict({
		0: net_start_moving,
		1: net_set_global_position,
		2: net_end_move,
		3: flip_card,
		4: net_insert_into_deck,
		5: net_close_deck_menu,
		6: net_change_hand
	})

var path : String
var json : Variant
var front_sprite_texture : ImageTexture
var back_sprite_texture : ImageTexture
var lock : Player
var insert_deck : Deck
var hand: Player
var flipped: bool
var lock_locked : bool = false
var is_face_up : bool = false

func get_card_size() -> Vector2:
	return front_sprite_texture.get_size()

func _on_flip_button_pressed() -> void:
	self.set_network_command(flip_card, [not self.is_face_up])

func flip_card(toggle: bool) -> void:
	self.is_face_up = toggle
	if is_instance_valid(self.hand):
		if Helper.is_own_player(self.hand):
			front_sprite.visible = true
			back_sprite.visible = false
		else:
			front_sprite.visible = false
			back_sprite.visible = true
	else:
		front_sprite.visible = toggle
		back_sprite.visible = not toggle

func set_lock(p: Player) -> void:
	self.lock = p
	_update_ui_on_lock_change()

func _update_ui_on_lock_change() -> void:
	if Helper.is_own_player(lock):
		front_sprite.set_instance_shader_parameter("enabled", false)
		back_sprite.set_instance_shader_parameter("enabled", false)
		card_interact_ui.show()
	elif lock is Player:
		front_sprite.set_instance_shader_parameter("enabled", true)
		back_sprite.set_instance_shader_parameter("enabled", true)
		card_interact_ui.hide()
	else:
		front_sprite.set_instance_shader_parameter("enabled", false)
		back_sprite.set_instance_shader_parameter("enabled", false)
		card_interact_ui.hide()

func _input(event: InputEvent) -> void:
	handle_move(event)

var is_moving := false
func handle_move(event: InputEvent) -> void:
	if self.can_move(event):
		get_viewport().set_input_as_handled()
		self.set_network_command(net_start_moving, [])
	
	if stopped_moving(event):
		self.set_network_command(net_end_move, [])

func net_start_moving() -> void:
	self.is_moving = true
	self.set_lock_locked(true)

func net_end_move() -> void:
	recalculate_position()
	self.is_moving = false
	var overlapping_deck = Helper.get_overlapping_deck(self.get_rect(), self.lock)
	if is_instance_valid(overlapping_deck):
		self.insert_deck = overlapping_deck
		# self.lock might not be actually colliding with overlapping_deck
		# lock_locked prevents the deck from reassigning a lock as a result
		overlapping_deck.set_lock_locked(true)
		overlapping_deck.set_lock(self.lock)
		if Helper.is_own_player(self.lock):
			self.insert_index_spinbox.min_value = 0
			self.insert_index_spinbox.max_value = self.insert_deck.cards.size()-1
			self.insert_into_deck_menu.visible = true
	else:
		self.set_lock_locked(false)

func set_network_command(f: Callable, args: Array) -> void:
	if not self.lock: assert(false, 'Attempted to set network info for a nonexistent player')
	self.lock.set_input([
		Helper.get_network_obj_id(self),
		self.network_commands.get_id(f),
		args])

func can_move(event: InputEvent) -> bool:
	return (event is InputEventMouseButton
		and event.button_index == MOUSE_BUTTON_LEFT
		and event.pressed
		and self.is_mouse_over()
		and Helper.is_own_player(lock)
		and self.lock.can_move)

func stopped_moving(event: InputEvent) -> bool:
	return (event is InputEventMouseButton
		and event.button_index == MOUSE_BUTTON_LEFT
		and not event.pressed
		and is_moving)

func is_mouse_over() -> bool:
	return self.get_rect().has_point(get_viewport().get_mouse_position())

func recalculate_position() -> void:
	# make sure the centre of the sprite is on-screen
	self.global_position = Helper.vmax(Vector2.ZERO, Helper.vmin(
		self.global_position, get_viewport_rect().size))
	
	# position deck interact ui above deck
	self.card_interact_ui.position = Vector2(
		-self.card_interact_ui.get_minimum_size().x/2,
		-self.get_card_size().y/2-self.card_interact_ui.get_minimum_size().y-10)
	
	# make sure deck interact ui doesn't go beyond top left of screen
	self.card_interact_ui.global_position = Helper.vmax(
		self.card_interact_ui.global_position,
		Vector2.ZERO)
	
	# and bottom right
	self.card_interact_ui.global_position = Helper.vmin(
		self.card_interact_ui.global_position,
		get_viewport_rect().size-self.card_interact_ui.get_minimum_size())

func _physics_process(_delta: float) -> void:
	if self.is_moving and Helper.is_own_player(self.lock):
		self.set_network_command(
			net_set_global_position,
			[get_viewport().get_mouse_position()])

func net_set_global_position(pos: Vector2) -> void:
	self.global_position = pos

func _on_deck_top_pressed() -> void:
	self.insert_into_deck(0)

func _on_deck_bottom_pressed() -> void:
	self.insert_into_deck(-1)

func _on_deck_specified_pressed() -> void:
	self.insert_into_deck(self.insert_index_spinbox.value)

func insert_into_deck(insert_index: int) -> void:
	self.close_deck_menu()
	# this one has to come second because it frees this card object
	self.set_network_command(net_insert_into_deck, [insert_index])

func net_insert_into_deck(insert_index: int) -> void:
	self.insert_deck.insert_card(CardInfo.create(self.path), insert_index)
	SyncManager.despawn(self)

func close_deck_menu() -> void:
	self.set_network_command(net_close_deck_menu, [])

func net_close_deck_menu() -> void:
	self.insert_into_deck_menu.visible = false
	self.insert_deck.set_lock_locked(false)
	self.set_lock_locked(false)

func change_hand() -> void:
	self.set_network_command(net_change_hand, [])

func net_change_hand() -> void:
	self.set_hand(null if is_instance_valid(self.hand) else self.lock)

func update_change_hand_btn() -> void:
	if self.hand==null:
		self.outline.visible = false
		self.flip_button.visible = true
		self.hand_button.text = 'Add to hand'
		self.hand_button.visible = true
		self.flip_card(false)
	else:
		self.outline.visible = true
		self.change_outline_colour(self.hand.stickman.default_color)
		self.flip_button.visible = false
		if Helper.is_own_player(self.hand):
			self.hand_button.text = 'Remove from hand'
		else:
			self.hand_button.visible = false
		self.flip_card(false)

func change_outline_colour(c: Color) -> void:
	var style : StyleBoxFlat = self.outline.get_theme_stylebox('panel')
	style.bg_color = c
	self.outline.add_theme_stylebox_override('panel', style)

func _save_state() -> Dictionary:
	return {
		'lock': self.lock.name if is_instance_valid(self.lock) else '',
		'is_moving': self.is_moving,
		'lock_locked': self.lock_locked,
		'global_position': self.global_position,
		'is_face_up': self.is_face_up,
		'hand': self.hand.name if is_instance_valid(self.hand) else ''
	}

func _load_state(state: Dictionary) -> void:
	var p_name: String = state.get('lock', '')
	if p_name == '':
		self.set_lock(null)
	else:
		self.set_lock(Helper.players[p_name])
	
	self.is_moving = state.get('is_moving', self.is_moving)
	self.lock_locked = state.get('lock_locked', self.lock_locked)
	self.global_position = state.get('global_position', self.global_position)
	self.flip_card(state.get('is_face_up', self.is_face_up))
	
	var h_name: String = state.get('hand', '')
	if h_name == '':
		self.set_hand(null)
	else:
		self.set_hand(Helper.players[h_name])

func set_hand(p: Player) -> void:
	self.hand = p
	self.update_change_hand_btn()

func run_command(f_id: int, args: Array) -> void:
	self.network_commands.get_obj(f_id).callv(args)

func _network_process(_input: Dictionary) -> void:
	self.update_lock()

func update_lock() -> void:
	if self.lock_locked: return
	
	var rect := self.get_player_rect()
	# lock is still colliding with card
	if is_instance_valid(self.lock) and rect.has_point(lock.position): return
	
	# try and find new lock if old one not colliding with card anymore
	for p in Helper.get_players_sorted():
		if rect.has_point(p.position):
			self.set_lock(p)
			return
	
	# no player is colliding with card
	self.set_lock(null)

func get_rect() -> Rect2:
	return Rect2(self.global_position-self.get_card_size()/2, self.get_card_size())

func get_player_rect() -> Rect2:
	var r := self.get_rect()
	return r.grow(Player.PLAYER_RADIUS)


func set_lock_locked(b: bool) -> void:
	self.lock_locked = b
	if not b:
		self.update_lock()
