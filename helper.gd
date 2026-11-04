extends Node

var splash_screen : SplashScreen
var lobby_screen : LobbyScreen

var username : String = ""
var colour : Color
var bgsid : String
var asset_dir : String
var _loaded_textures : Dictionary[String, ImageTexture]
var players : Dictionary[String, Player]
var network_object_tracker: TwoWay = TwoWay.new()

# z-index guide - TODO implement the below consts
const CARD_Z : int = 1
const DECK_Z : int = 0

var path_db: Dictionary[String, int] = {}
var texture_db: Dictionary[int, Texture2D] = {}
var json_db: Dictionary[String, Variant] = {}

static func get_full_path(path: String) -> String:
	return Helper.asset_dir.path_join(path)

static func json_starter(node, fpath: String) -> Variant:
	var outp = Helper.json_db.get(fpath, null)
	if outp != null: return outp
	
	var json := JSON.new()
	var err := json.parse(FileAccess.open(fpath, FileAccess.READ).get_as_text())
	if err != OK:
		assert(false, "Failed extracting JSON data from file %s" % fpath)
	var json_data = json.data
	
	Helper.json_db[fpath] = json_data
	return json_data

static func set_position(node: Node2D, json) -> void:
	if "position" in json:
		if "x" not in json["position"]:
			assert(false, "Incorrect json position formatting, missing x-value. Json dump:\n%s" % json)
		if "y" not in json["position"]:
			assert(false, "Incorrect json position formatting, missing y-value. Json dump:\n%s" % json)
		node.position = Vector2(json["position"]["x"], json["position"]["y"])

static func is_own_player_hitbox(hitbox: Area3D) -> bool:
	return Helper.is_own_player(hitbox.get_owner())

func is_own_player(node: Node) -> bool:
	return node is Player and node.get_multiplayer_authority() == multiplayer.multiplayer_peer.get_unique_id()

static func load_texture(path: String) -> ImageTexture:
	if path not in Helper._loaded_textures:
		Helper._loaded_textures[path] = (ImageTexture.create_from_image(
										Image.load_from_file(path)))
	return Helper._loaded_textures[path]

static func start_game() -> void:
	var main_node := Helper.get_main()
	var gm : GameMenu = GameMenu.create()
	main_node.add_child(gm)

func get_main() -> Node:
	return get_tree().root.get_node("Main")

static func load_assets() -> void:
	var deck_path := Helper.asset_dir.path_join('decks')
	if DirAccess.open(deck_path):
		for deck_file_dir in (Helper.get_files_from_nested_directory(
							  Helper.asset_dir.path_join('decks'))
							 .filter(func(f:String): return f.get_extension()=='json')):
			Deck.create_offline(deck_file_dir)

# https://forum.godotengine.org/t/how-to-get-all-files-from-nested-directory/105827
static func get_files_from_nested_directory(dir_path: String) -> Array[String]:
	var files : Array[String] = []
	var item : String
	var item_path : String
	
	var dir := DirAccess.open(dir_path)
	
	dir.list_dir_begin()
	item = dir.get_next()
	while item != "":
		item_path = dir_path.path_join(item)
		if dir.dir_exists(item_path):
			files += get_files_from_nested_directory(item_path)
		if dir.file_exists(item_path):
			files.append(item_path)
		item = dir.get_next()
	dir.list_dir_end()
	
	return files

func vmax(a: Vector2, b: Vector2) -> Vector2:
	var x : float = max(a.x, b.x)
	var y : float = max(a.y, b.y)
	return Vector2(x,y)

func vmin(a: Vector2, b: Vector2) -> Vector2:
	var x : float = min(a.x, b.x)
	var y : float = min(a.y, b.y)
	return Vector2(x,y)

func add_player(p: Player) -> void:
	if p.name not in self.players:
		self.players[p.name] = p

func remove_player(p: Player) -> void:
	self.players.erase(p.name)

func add_network_object(n: Node) -> void:
	self.network_object_tracker.write_obj(n)

func get_network_obj_by_id(i: int) -> Node:
	var n: Node = network_object_tracker.get_obj(i,null)
	if n == null:
		assert(false, 'Attempted to get object with id %d, which is invalid' % i)
	return n

func get_network_obj_id(obj) -> int:
	var id: int = network_object_tracker.get_id(obj, null)
	if id == null:
		assert(false, 'Attempted to get unregistered object')
	return id

var static_function_ids: Dictionary[int,Callable] = {
		0: Deck.create,
		1: Card.create_from_info
	}

func run_static_function(f_id: int, params: Array) -> void:
	static_function_ids[f_id].call(params)

func get_texture_id(path: String) -> int:
	var next_id: int = path_db.get(path, -1)
	if path not in path_db:
		next_id = path_db.size()
		path_db[path] = next_id
		texture_db[next_id] = Helper.load_texture(path)
	return next_id

func get_texture_from_path(path: String) -> Texture2D:
	var id: int = Helper.get_texture_id(path)
	return texture_db[id]
