extends Node

var splash_screen : SplashScreen
var lobby_screen : LobbyScreen

var username : String = ""
var colour : Color
var bgsid : String
var asset_dir : String
var players : Dictionary[String, Player]
var sorted_players : Array[Player]

# z-index guide - TODO implement the below consts
const CARD_Z : int = 1
const DECK_Z : int = 0

var texture_db: Dictionary[String, Texture2D] = {}
var json_db: Dictionary[String, Variant] = {}
var network_object_tracker: TwoWay = TwoWay.new()
var next_network_id: int = 0

func get_full_path(path: String) -> String:
	return Helper.asset_dir.path_join(path)

func json_starter(fpath: String) -> Variant:
	var outp = Helper.json_db.get(fpath, null)
	if outp != null: return outp
	
	var json := JSON.new()
	var err := json.parse(FileAccess.open(fpath, FileAccess.READ).get_as_text())
	if err != OK:
		assert(false, "Failed extracting JSON data from file %s" % fpath)
	var json_data = json.data
	
	Helper.json_db[fpath] = json_data
	return json_data

func set_position(node: Node2D, json) -> void:
	if "position" in json:
		if "x" not in json["position"]:
			assert(false, "Incorrect json position formatting, missing x-value. Json dump:\n%s" % json)
		if "y" not in json["position"]:
			assert(false, "Incorrect json position formatting, missing y-value. Json dump:\n%s" % json)
		node.position = Vector2(json["position"]["x"], json["position"]["y"])

static func is_own_player_hitbox(hitbox: Area3D) -> bool:
	return Helper.is_own_player(hitbox.get_owner())

func is_own_player(node: Node) -> bool:
	return is_instance_valid(node) and node is Player and node.get_multiplayer_authority() == multiplayer.multiplayer_peer.get_unique_id()

func start_game() -> void:
	var main_node := Helper.get_main()
	var gm : GameMenu = GameMenu.create()
	main_node.add_child(gm)
	self.sort_players()

func sort_players() -> void:
	self.sorted_players = []
	for p in players.values():
		var p_: Player = p
		self.sorted_players.append(p_)
	self.sorted_players.sort_custom(func(a,b): return a.name>b.name)

func get_main() -> Node:
	return get_tree().root.get_node("Main")

func load_assets() -> void:
	var deck_path := Helper.asset_dir.path_join('decks')
	if DirAccess.open(deck_path):
		var full_dir: String = Helper.asset_dir.path_join('decks')
		var files = Helper.get_files_from_nested_directory(full_dir)
		var json_files = files.filter(func(f:String): return f.get_extension()=='json')
		json_files.sort()
		for deck_file_dir in json_files:
			Deck.create_offline(deck_file_dir)

# https://forum.godotengine.org/t/how-to-get-all-files-from-nested-directory/105827
func get_files_from_nested_directory(dir_path: String) -> Array[String]:
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
	self.network_object_tracker.write(self.next_network_id, n)
	self.next_network_id += 1

func _ready() -> void:
	self.add_to_group('network_sync')

func _save_state() -> Dictionary:
	return {
		'next_network_id': self.next_network_id
	}

func _load_state(data: Dictionary) -> void:
	self.next_network_id = data.get('next_network_id', 0)

var static_function_ids: Dictionary[int,Callable] = {
		0: Deck.create,
		1: Card.create_from_info
	}

func run_static_function(f_id: int, params: Array) -> void:
	static_function_ids[f_id].call(params)

func get_texture(path: String) -> Texture2D:
	if path not in texture_db:
		var fullpath := Helper.get_full_path(path)
		var img = Image.load_from_file(fullpath)
		self.texture_db[path] = ImageTexture.create_from_image(img)
	return texture_db[path]

func get_network_obj_id(obj: Variant) -> int:
	return network_object_tracker.get_id(obj)

func get_network_obj_by_id(id: int) -> Variant:
	return network_object_tracker.get_obj(id)

func get_players_sorted() -> Array:
	return self.sorted_players

func get_overlapping_deck(r: Rect2, card_lock: Player) -> Deck:
	for d in Helper.get_main().deck_parent.get_children():
		if (d.lock==null or d.lock==card_lock) and r.intersects(d.get_rect()):
			return d
	return null
