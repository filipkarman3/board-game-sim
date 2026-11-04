class_name CardInfo

static func create(path: String) -> CardInfo:
	var c: CardInfo = CardInfo.new()
	
	c.path = path
	c.json = Helper.json_starter(c, path)
	c.front_sprite_texture = Helper.get_texture_from_path(Helper.get_full_path(c.json['front']))
	c.back_sprite_texture = Helper.get_texture_from_path(Helper.get_full_path(c.json['back']))
	if not c.front_sprite_texture.get_size().is_equal_approx(c.back_sprite_texture.get_size()):
		assert(false, "Card (%s) front and back textures must be of same width and height" % path)
	
	return c

var path : String
var json : Variant
var front_sprite_texture: ImageTexture
var back_sprite_texture: ImageTexture

func get_card_size() -> Vector2:
	return front_sprite_texture.get_size()
