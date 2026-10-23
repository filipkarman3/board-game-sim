class_name DeckInspector extends CanvasLayer

const DECK_INSPECTOR_SCENE = preload("res://DeckInspector.tscn")
static func create(deck: Deck) -> DeckInspector:
	var insp := DECK_INSPECTOR_SCENE.instantiate()
	Helper.get_main().add_child(insp)
	insp.deck = deck
	for c in deck.cards:
		var vc: VirtualCard = VirtualCard.create(c)
		insp.card_container.add_child(vc)
		insp.cards.append(vc)
	insp.create_card_bounds()
	return insp

@onready var card_container : Node2D = %CardContainer
@onready var card_outline: Panel = %CardOutline
@onready var buttons_container: HBoxContainer = %Buttons

var deck: Deck
var cards: Array[VirtualCard]
var _start_pos: Vector2
var _end_pos:   Vector2
var _centre:    Vector2
var _width:     Vector2
var selected: int = 0

func create_card_bounds() -> void:
	var max_card_size: Vector2 = Vector2.ZERO
	for c in cards:
		max_card_size.x = max(max_card_size.x, c.get_card_size().x)
		max_card_size.y = max(max_card_size.y, c.get_card_size().y)
	
	var padding: float = 10
	self._start_pos.y = get_viewport().get_visible_rect().size.y/2
	self._start_pos.x = padding + max_card_size.x/2
	
	self._end_pos = Vector2(
		get_viewport().get_visible_rect().size.x - padding,
		self._start_pos.y)
	
	self._centre = (self._end_pos+self._start_pos) / 2
	self._width = self._end_pos - self._start_pos
	
	self.update_cards_pos()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.is_pressed():
			self.selected = min(self.selected+1, self.cards.size()-1)
			self.update_cards_pos()
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP and event.is_pressed:
			self.selected = max(self.selected-1, 0)
			self.update_cards_pos()

func update_cards_pos() -> void:
	var selected_card : VirtualCard = self.cards[self.selected]
	for i in self.cards.size():
		var c : VirtualCard = self.cards[i]
		var rel_i := i-self.selected
		c.position = self._centre + rel_i*self._width.normalized()*self.deck.get_card_size()*0.75
		c.z_index = self.cards.size()-abs(rel_i)
	card_outline.z_index = selected_card.z_index
	card_outline.size = selected_card.get_card_size()*1.05
	card_outline.position = selected_card.position-card_outline.size/2
	buttons_container.position = (selected_card.position
		+Vector2(-buttons_container.get_minimum_size().x/2, selected_card.get_card_size().y/2+10))

func _on_draw_button_pressed() -> void:
	self.deck.draw_specific_card(self.selected)
	self._on_close_button_pressed()

func _on_close_button_pressed() -> void:
	self.deck.on_deck_inspector_closed()
	self.queue_free()
