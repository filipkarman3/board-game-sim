class_name VirtualCard extends Sprite2D

const VIRTUAL_CARD_SCENE := preload("res://VirtualCard.tscn")
static func create(ref: CardInfo) -> VirtualCard:
	var card := VIRTUAL_CARD_SCENE.instantiate()
	card.texture = ref.front_sprite_texture
	card.ref = ref
	return card

var ref : CardInfo

func get_card_size() -> Vector2:
	return self.texture.get_size()
