class_name Card extends Node2D

"""
json file contents:
{
	"front": <path_to_front_sprite>,
	"back": <path_to_back_sprite>
}
"""

const SCENE = preload("res://Card.tscn")

static func create_from_info(path: String, data: Dictionary) -> Card:
	data['path'] = path
	var c: Card = SyncManager.spawn('Card', Helper.get_main(), SCENE, data)
	Helper.add_network_object(c)
	return c

func _network_spawn(data: Dictionary) -> void:
	self.path = data['path']
	self.json = Helper.json_starter(self, path)
	
	self.front_sprite_texture = Helper.get_texture_from_path(Helper.get_full_path(self.json['front']))
	self.back_sprite_texture = Helper.get_texture_from_path(Helper.get_full_path(self.json['back']))
	if not self.front_sprite_texture.get_size().is_equal_approx(self.back_sprite_texture.get_size()):
		assert(false, "Card (%s) front and back textures must be of same width and height" % path)
	
	self.flip_card(data.get('is_face_up', false))
	self.global_position = data.get('global_position', self.global_position)

	front_sprite.texture = front_sprite_texture
	back_sprite.texture  = back_sprite_texture
	self.card_interact_ui.position.y = -self.get_card_size().y/2 -self.card_interact_ui.get_minimum_size().y -10
	self.hitbox_shape.shape.size = self.get_card_size()
	
	var border_thickness: float = 5
	self.outline.position = -self.get_card_size()/2-Vector2(BORDER_THICKNESS,BORDER_THICKNESS)
	self.outline.size = self.get_card_size()+Vector2(BORDER_THICKNESS*2,BORDER_THICKNESS*2)

@onready var front_sprite: Sprite2D = %Front
@onready var back_sprite: Sprite2D = %Back
@onready var card_interact_ui: HBoxContainer = %CardInteractUI
@onready var hitbox_shape: CollisionShape2D = %HitboxShape
@onready var hitbox_area: Area2D = %HitboxArea
@onready var insert_into_deck_menu: CanvasLayer = %InsertIntoDeckMenu
@onready var insert_index_spinbox: SpinBox = %InsertIndexSpinbox
@onready var outline: Panel = %CardOutline
@onready var hand_button: Button = %HandButton
@onready var flip_button: Button = %FlipButton

const BORDER_THICKNESS: float = 5

var path : String
var json : Variant
var front_sprite_texture : ImageTexture
var back_sprite_texture : ImageTexture
var lock : Player
var insert_deck : Deck
var pre_move_pos : Vector2
var hand: Player
var flipped: bool

func get_card_size() -> Vector2:
	return front_sprite_texture.get_size()

func _on_flip_button_pressed() -> void:
	front_sprite.visible = not front_sprite.visible
	back_sprite.visible = not back_sprite.visible

func flip_card(toggle: bool) -> void:
	front_sprite.visible = toggle
	back_sprite.visible = not toggle

func _on_card_area_area_entered(area: Area2D) -> void:
	var obj = area.get_owner()
	if obj is Player and obj != self.lock:
		CollisionHelper.start_collision(obj, self)

func _on_card_area_area_exited(area: Area2D) -> void:
	var obj = area.get_owner()
	if obj is Player and not self.is_moving:
		CollisionHelper.end_collision(obj, self)

func on_new_player_connection(p: Player) -> void:
	self.lock = p
	_update_ui_on_lock_change()

func detach_player_connection() -> void:
	self.lock = null
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
		self.is_moving = true
		self.pre_move_pos = self.global_position
	
	if stopped_moving(event):
		recalculate_position()
		
		var post_recompute = func():
			self.is_moving = false
			var exists_overlapped_deck: bool = self.overlapping_deck()
			if not self.is_colliding_with_lock() and not exists_overlapped_deck:
				CollisionHelper.end_collision(self.lock, self)
		post_recompute.call_deferred()

func is_colliding_with_lock() -> bool:
	for area in self.hitbox_area.get_overlapping_areas():
		if area.get_owner() == self.lock:
			return true
	return false

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
	var hitbox_pos: Vector2 = self.hitbox_shape.global_position
	var hitbox_size: Vector2 = self.get_card_size()
	var hitbox_rect: Rect2 = Rect2(hitbox_pos-hitbox_size/2.0,hitbox_size)
	return hitbox_rect.has_point(get_viewport().get_mouse_position())

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

func _physics_process(delta: float) -> void:
	if self.is_moving:
		self.global_position = get_viewport().get_mouse_position()

func _on_deck_top_pressed() -> void:
	self.insert_into_deck(0)
	
func _on_deck_bottom_pressed() -> void:
	self.insert_into_deck(-1)

func _on_deck_specified_pressed() -> void:
	self.insert_into_deck(self.insert_index_spinbox.value)

func insert_into_deck(insert_index: int) -> void:
	self.insert_deck.insert_card(CardInfo.create(self.path), insert_index)
	CollisionHelper.unblock(self.insert_deck)
	CollisionHelper.end_collision(self.lock, self)
	SyncManager.despawn(self)

func close_deck_menu() -> void:
	self.insert_into_deck_menu.visible = false
	CollisionHelper.unblock(self.insert_deck)
	if not self.is_colliding_with_lock():
		CollisionHelper.end_collision(self.lock, self)

func overlapping_deck() -> bool:
	if Helper.is_own_player(self.lock): return true
	var found_new_deck: bool = false
	for area in self.hitbox_area.get_overlapping_areas():
		var possible_deck = area.get_owner()
		if possible_deck is Deck and not is_instance_valid(possible_deck.lock):
				self.insert_deck = possible_deck
				found_new_deck = true
				break
	
	if not found_new_deck: return false
	self.insert_index_spinbox.min_value = 0
	self.insert_index_spinbox.max_value = self.insert_deck.cards.size()-1
	CollisionHelper.block(self.insert_deck)
	self.insert_into_deck_menu.visible = true
	return true

func change_hand() -> void:
	if is_instance_valid(self.hand):
		self.hand = null
		self.outline.visible = false
		self.flip_button.visible = true
		self.hand_button.text = 'Add to hand'
		self.hand_button.visible = true
		self.flip_card(false)
	else:
		self.hand = self.lock
		self.outline.visible = true
		self.change_outline_colour(self.hand.stickman.default_color)
		self.flip_button.visible = false
		if Helper.is_own_player(self.hand):
			self.hand_button.text = 'Remove from hand'
			self.flip_card(true)
		else:
			self.hand_button.visible = false
			self.flip_card(false)

func change_outline_colour(c: Color) -> void:
	var style : StyleBoxFlat = self.outline.get_theme_stylebox('panel')
	style.bg_color = c
	self.outline.add_theme_stylebox_override('panel', style)
