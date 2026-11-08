class_name Deck extends Node2D

"""
json file contents:
{
	"position": {
		"x": <x_pos>,
		"y": <y_pos>
	},
	
	"cards": {
		<path_to_card_json>: <quantity>,
		...
	},
	
	# optional arguments: default value
	"show_number_of_cards_left": false
}
"""

const SCENE = preload("res://Deck.tscn")

static func create(_path: String, _online:bool=true) -> Deck:
	var deck : Deck = SyncManager.spawn('Deck', Helper.get_main().deck_parent, SCENE, {
		'path': _path,
	})
	Helper.add_network_object(deck)
	return deck

func _network_spawn(data: Dictionary) -> void:
	self.path = data['path']
	self.ready()

static func create_offline(_path: String) -> Deck:
	var d: Deck = SCENE.instantiate()
	Helper.get_main().deck_parent.add_child(d)
	Helper.add_network_object(d)
	d.path = _path
	d.ready()
	return d

func ready() -> void:
	self.json = Helper.json_starter(self.path)
	Helper.set_position(self, self.json)
	self.load_cards(self.json)
	self.cards_left_label.visible = self.json.get('show_number_of_cards_left', true)
	self.recalculate_position()

@onready var sprite: Sprite2D = %Sprite
@onready var deck_interact_ui: HBoxContainer = %DeckInteractUI
@onready var deck_bg: MeshInstance2D = %DeckBG
@onready var cards_left_label: Label = %CardsLeftLabel
@onready var deck_outline: Panel = %DeckOutline
@onready var card_container: Node2D = %CardContainer

var network_commands := TwoWay.from_dict({
		0: _draw_specific_card,
		1: net_start_moving,
		2: net_set_global_position,
		3: net_end_move,
		4: net_open_deck_inspector,
		5: net_on_deck_inspector_closed,
		6: net_shuffle_deck,
		7: net_flip_cards
	})

var path : String
var json : Variant
var lock : Player
var cards : Array[CardInfo] = []
var are_cards_face_up : bool = false
var card_size : Vector2
var lock_locked : bool = false

func get_card_size() -> Vector2:
	return self.card_size

func set_card_size(size: Vector2) -> Deck:
	self.card_size = size
	return self

func get_rect() -> Rect2:
	return Rect2(self.global_position-self.get_card_size()/2, self.get_card_size())

func get_player_rect() -> Rect2:
	var r := self.get_rect()
	return r.grow(Player.PLAYER_RADIUS)

func load_cards(_json) -> Deck:
	if "cards" not in _json:
		assert(false, "Attempted to create deck %s but no card information was found in the json file" % self.path)
		
	var _card_size : Vector2
	for card_path in _json["cards"]:
		for i in _json["cards"][card_path]:
			var card := CardInfo.create(card_path)
			cards.append(card)
			if not _card_size:
				_card_size = card.get_card_size()
			if not _card_size.is_equal_approx(card.get_card_size()):
				assert(false, 'Attempting to load card (path: %s) with size (%f,%f) into a deck of size (%f,%f)' % [card_path, card.get_card_size().x, card.get_card_size().y, _card_size.x, _card_size.y])
	
	self.deck_interact_ui.position.y = -_card_size.y/2 -self.deck_interact_ui.get_minimum_size().y -10
	self.deck_bg.mesh.size = _card_size
	
	self.update_sprite_texture()
	return self.set_card_size(_card_size)

func update_sprite_texture() -> void:
	if self.cards.is_empty():
		self.sprite.visible = false
	else:
		self.sprite.visible = true
		if self.are_cards_face_up:
			self.sprite.texture = self.cards[0].front_sprite_texture
		else:
			self.sprite.texture = self.cards[0].back_sprite_texture
		
		var outline_border_thickness: float = 5
		self.deck_outline.position = (-self.sprite.texture.get_size()/2-
			Vector2(outline_border_thickness,outline_border_thickness))
		self.deck_outline.size = (self.get_card_size() +
			Vector2(outline_border_thickness*2,outline_border_thickness*2))

func _update_ui_on_lock_change() -> void:
	if Helper.is_own_player(lock):
		sprite.set_instance_shader_parameter("enabled", false)
		deck_interact_ui.show()
	elif lock is Player:
		sprite.set_instance_shader_parameter("enabled", true)
		deck_interact_ui.hide()
	else:
		sprite.set_instance_shader_parameter("enabled", false)
		deck_interact_ui.hide()

func set_lock(p: Player) -> void:
	self.lock = p
	_update_ui_on_lock_change()

func _input(event: InputEvent) -> void:
	handle_deck_move(event)

var is_moving_deck := false
func handle_deck_move(event: InputEvent) -> void:
	if self.can_move_deck(event):
		get_viewport().set_input_as_handled()
		self.set_network_command(net_start_moving, [])
	
	if stopped_moving_deck(event):
		self.set_network_command(net_end_move, [])

func net_end_move() -> void:
	self.is_moving_deck = false
	self.set_lock_locked(false)
	recalculate_position()

func net_start_moving() -> void:
	self.is_moving_deck = true
	self.set_lock_locked(true)

func can_move_deck(event: InputEvent) -> bool:
	return (event is InputEventMouseButton
		and event.button_index == MOUSE_BUTTON_LEFT
		and event.pressed
		and self.is_mouse_over()
		and Helper.is_own_player(lock)
		and self.lock.can_move)

func stopped_moving_deck(event: InputEvent) -> bool:
	return (event is InputEventMouseButton
		and event.button_index == MOUSE_BUTTON_LEFT
		and not event.pressed
		and is_moving_deck)

func is_mouse_over() -> bool:
	return self.get_rect().has_point(get_viewport().get_mouse_position())

func recalculate_position() -> void:
	# make sure the centre of the sprite is on-screen
	self.global_position = Helper.vmax(Vector2.ZERO, Helper.vmin(
		self.global_position, get_viewport_rect().size))
	
	# position deck interact ui above deck
	self.deck_interact_ui.position = Vector2(
		-self.deck_interact_ui.get_minimum_size().x/2,
		-self.get_card_size().y/2-self.deck_interact_ui.get_minimum_size().y-10)
	
	# make sure deck interact ui doesn't go beyond top left of screen
	self.deck_interact_ui.global_position = Helper.vmax(
		self.deck_interact_ui.global_position,
		Vector2.ZERO)
	
	# and bottom right
	self.deck_interact_ui.global_position = Helper.vmin(
		self.deck_interact_ui.global_position,
		get_viewport_rect().size-self.deck_interact_ui.get_minimum_size())
	
	# cards left label
	update_num_cards_left_ui()

func update_num_cards_left_ui() -> void:
	self.cards_left_label.text = 'Cards left: %d' % self.cards.size()
	self.cards_left_label.position = Vector2(
		-self.cards_left_label.get_minimum_size().x/2,
		self.get_card_size().y/2)
		
	self.update_sprite_texture()

func draw_top_card() -> void:
	if self.cards.is_empty():
		return
	self.draw_specific_card(0)

func shuffle_deck() -> void:
	self.set_network_command(net_shuffle_deck, [])

func net_shuffle_deck() -> void:
	var rng: NetworkRandomNumberGenerator = Helper.get_main().rng
	for i in range(cards.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = cards[i]
		cards[i] = cards[j]
		cards[j] = tmp

func open_deck_inspector() -> void:
	self.set_network_command(net_open_deck_inspector, [])
	if Helper.is_own_player(self.lock):
		Helper.get_main().add_child(DeckInspector.create(self))

func net_open_deck_inspector() -> void:
	self.lock.set_inspecting_deck(true)

func draw_specific_card(i: int) -> void:
	self.set_network_command(_draw_specific_card, [i])

func set_network_command(f: Callable, args: Array) -> void:
	if not self.lock: assert(false, 'Attempted to set network info for a nonexistent player')
	self.lock.set_input([
		Helper.get_network_obj_id(self),
		self.network_commands.get_id(f),
		args])

func _draw_specific_card(i: int) -> void:
	var ci : CardInfo = self.cards.pop_at(i)
	self.update_num_cards_left_ui()
	var _drawn_card: Card = Card.create_from_info(ci.path, {
		'global_position': self.global_position + Vector2(20+self.get_card_size().x,0),
		'is_face_up': self.are_cards_face_up,
	})

func _save_state() -> Dictionary:
	var card_paths = self.cards.map(func(c): return c.path)
	if null in card_paths:
		var _a = 1
	
	return {
		'cards': card_paths,
		'lock': self.lock.name if is_instance_valid(self.lock) else '',
		'is_moving': self.is_moving_deck,
		'lock_locked': self.lock_locked,
		'global_position': self.global_position,
		'are_cards_face_up': self.are_cards_face_up
	}

func _load_state(state: Dictionary) -> void:
	self.cards = []
	for c_path in state.get('cards', []):
		self.cards.append(CardInfo.create(c_path))
	
	var p_name: String = state.get('lock', '')
	if p_name == '':
		self.lock = null
	else:
		self.lock = Helper.players[p_name]
	
	self.is_moving_deck = state.get('is_moving', self.is_moving_deck)
	self.lock_locked = state.get('lock_locked', self.lock_locked)
	self.global_position = state.get('global_position', self.global_position)
	self.are_cards_face_up = state.get('are_cards_face_up', self.are_cards_face_up)
	
	self.update_sprite_texture()

func run_command(f_id: int, args: Array) -> void:
	self.network_commands.get_obj(f_id).callv(args)

func on_deck_inspector_closed() -> void:
	self.set_network_command(net_on_deck_inspector_closed, [])

func net_on_deck_inspector_closed() -> void:
	self.lock.set_inspecting_deck(false)

func _physics_process(_delta: float) -> void:
	if self.is_moving_deck and Helper.is_own_player(self.lock):
		self.set_network_command(
			net_set_global_position,
			[get_viewport().get_mouse_position()])

func net_set_global_position(pos: Vector2) -> void:
	self.global_position = pos

func insert_card(c: CardInfo, i: int) -> void:
	self.cards.insert(i, c)
	self.update_num_cards_left_ui()

func _on_flip_button_pressed() -> void:
	self.set_network_command(net_flip_cards, [])

func net_flip_cards() -> void:
	self.are_cards_face_up = not self.are_cards_face_up
	self.update_sprite_texture()

func update_lock() -> void:
	if self.lock_locked: return
	
	var rect := self.get_player_rect()
	# lock is still colliding with deck
	if is_instance_valid(self.lock) and rect.has_point(lock.position): return
	
	# try and find new lock if old one not colliding with deck anymore
	for p in Helper.get_players_sorted():
		if rect.has_point(p.position):
			self.set_lock(p)
			return
	
	# no player is colliding with deck
	self.set_lock(null)

func _network_process(_inp: Dictionary) -> void:
	self.update_lock()

func set_lock_locked(b: bool) -> void:
	self.lock_locked = b
	if not b:
		self.update_lock()
