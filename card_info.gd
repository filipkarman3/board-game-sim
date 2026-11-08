class_name CardInfo

static func create(_path: String) -> CardInfo:
	var c: CardInfo = CardInfo.new()
	
	c.path = _path
	c.json = Helper.json_starter(Helper.get_full_path(_path))
	c.front_sprite_texture = Helper.get_texture(c.json['front'])
	c.back_sprite_texture = Helper.get_texture(c.json['back'])
	if not c.front_sprite_texture.get_size().is_equal_approx(c.back_sprite_texture.get_size()):
		assert(false, "Card (%s) front and back textures must be of same width and height" % _path)
	
	return c

var path : String
var json : Variant
var front_sprite_texture: ImageTexture
var back_sprite_texture: ImageTexture

func get_card_size() -> Vector2:
	return front_sprite_texture.get_size()
