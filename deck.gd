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

static func create(path: String, online:bool=true) -> Deck:
	var deck : Deck = SyncManager.spawn('Deck', Helper.get_main(), SCENE, {
		'path': path,
	})
	Helper.add_network_object(deck)
	return deck

func _network_spawn(data: Dictionary) -> void:
	self.path = data['path']
	self.ready()

static func create_offline(path: String) -> Deck:
	var d: Deck = SCENE.instantiate()
	Helper.get_main().add_child(d)
	Helper.add_network_object(d)
	d.path = path
	d.ready()
	return d

func ready() -> void:
	self.json = Helper.json_starter(self, self.path)
	Helper.set_position(self, self.json)
	self.load_cards(self.json)
	self.cards_left_label.visible = self.json.get('show_number_of_cards_left', true)
	self.recalculate_position()


@onready var hitbox_shape: CollisionShape2D = %HitboxShape
@onready var hitbox_area: Area2D = %HitboxArea
@onready var sprite: Sprite2D = %Sprite
@onready var deck_interact_ui: HBoxContainer = %DeckInteractUI
@onready var deck_bg: MeshInstance2D = %DeckBG
@onready var cards_left_label: Label = %CardsLeftLabel
@onready var deck_outline: Panel = %DeckOutline
@onready var card_container: Node2D = %CardContainer

var network_commands := TwoWay.from_dict({
		0: _draw_specific_card
	})

var path : String
var json : Variant
var lock : Player
var cards : Array[CardInfo] = []
var are_cards_face_up : bool = false

func get_card_size() -> Vector2:
	return self.hitbox_shape.shape.size
	
func set_card_size(size: Vector2) -> Deck:
	self.hitbox_shape.shape.size = size
	return self
	
func load_cards(json) -> Deck:
	if "cards" not in json:
		assert(false, "Attempted to create deck %s but no card information was found in the json file" % self.path)
		
	var card_size : Vector2
	for card_path in json["cards"]:
		for i in json["cards"][card_path]:
			var card := CardInfo.create(Helper.get_full_path(card_path))
			cards.append(card)
			if not card_size:
				card_size = card.get_card_size()
			if not card_size.is_equal_approx(card.get_card_size()):
				assert(false, 'Attempting to load card (path: %s) with size (%f,%f) into a deck of size (%f,%f)' % [card_path, card.get_card_size().x, card.get_card_size().y, card_size.x, card_size.y])
	
	self.deck_interact_ui.position.y = -card_size.y/2 -self.deck_interact_ui.get_minimum_size().y -10
	self.deck_bg.mesh.size = card_size
	
	self.update_sprite_texture()
	return self.set_card_size(card_size)

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

func _on_hitbox_area_area_entered(area: Area2D) -> void:
	var obj = area.get_owner()
	if obj is Player and obj != self.lock:
		CollisionHelper.start_collision(obj, self)

func on_new_player_connection(p: Player) -> void:
	self.lock = p
	_update_ui_on_lock_change()

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

func _on_hitbox_area_area_exited(area: Area2D) -> void:
	var obj = area.get_owner()
	if obj is Player:
		if not (obj==self.lock and self.is_moving_deck):
			CollisionHelper.end_collision(obj, self)

func detach_player_connection() -> void:
	self.lock = null
	_update_ui_on_lock_change()

func _input(event: InputEvent) -> void:
	handle_deck_move(event)

var is_moving_deck := false
func handle_deck_move(event: InputEvent) -> void:
	if self.can_move_deck(event):
		self.is_moving_deck = true
	
	if stopped_moving_deck(event):
		self.is_moving_deck = false
		recalculate_position()
		if not self.is_colliding_with_lock():
			CollisionHelper.end_collision(self.lock, self)

func is_colliding_with_lock() -> bool:
	for area in self.hitbox_area.get_overlapping_areas():
		if area.get_owner() == self.lock:
			return true
	return false

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
	var hitbox_pos: Vector2 = self.hitbox_shape.global_position
	var hitbox_size: Vector2 = self.get_card_size()
	var hitbox_rect: Rect2 = Rect2(hitbox_pos-hitbox_size/2.0,hitbox_size)
	return hitbox_rect.has_point(get_viewport().get_mouse_position())

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
	cards.shuffle()

func open_deck_inspector() -> void:
	self.lock.set_inspecting_deck(true)
	#revoke ability to press other buttons - this is automatically done by the canvaslayer
	if Helper.is_own_player(self.lock):
		Helper.get_main().add_child(DeckInspector.create(self))

func draw_specific_card(i: int) -> void:
	self.lock.set_input([
		Helper.get_network_obj_id(self),
		self.network_commands.get_id(_draw_specific_card),
		[i]])

func _draw_specific_card(i: int) -> void:
	var ci : CardInfo = self.cards.pop_at(i)
	self.update_num_cards_left_ui()
	var drawn_card: Card = Card.create_from_info(ci.path, {
		'global_position': self.global_position + Vector2(20+self.get_card_size().x,0),
		'is_face_up': self.are_cards_face_up,
	})

func _save_state() -> Dictionary:
	return {
		'cards': self.cards.map(func(c): return c.path),
		'lock': self.lock.name if is_instance_valid(self.lock) else null
	}

func _load_state(state: Dictionary) -> void:
	self.cards = []
	for c_path in state.get('cards', []):
		self.cards.append(CardInfo.create(path))
	
	var p_name: String = state.get('lock', null)
	if p_name == null:
		self.lock = null
	else:
		self.lock = Helper.players[p_name]
	
	self.update_sprite_texture()

func run_command(f_id: int, args: Array) -> void:
	self.network_commands.get_obj(f_id).callv(args)

func on_deck_inspector_closed() -> void:
	self.lock.set_inspecting_deck(false)

func _physics_process(delta: float) -> void:
	if self.is_moving_deck:
		self.global_position = get_viewport().get_mouse_position()

func insert_card(c: CardInfo, i: int) -> void:
	self.cards.insert(i, c)
	self.update_num_cards_left_ui()

func _on_flip_button_pressed() -> void:
	self.are_cards_face_up = not self.are_cards_face_up
	self.update_sprite_texture()
