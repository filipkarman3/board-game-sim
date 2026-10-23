extends Node

const SERVER_ID = 1
const LOBBY_SCREEN_SCENE = preload("res://LobbyScreen.tscn")
const PLAYER_SCENE = preload("res://Player.tscn")

var peer : ENetMultiplayerPeer
var lobby_screen : LobbyScreen
# indexed by client id, returns username
var players : Dictionary[int, PlayerData] = {}

func _ready() -> void:
	multiplayer.connected_to_server.connect(_join_lobby)
	multiplayer.connection_failed.connect(_close_connection)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	SyncManager.sync_started.connect(_on_sync_manager_sync_started)
	SyncManager.sync_stopped.connect(_on_sync_manager_sync_stopped)
	SyncManager.sync_lost.connect(_on_sync_manager_sync_lost)
	SyncManager.sync_regained.connect(_on_sync_manager_sync_regained)
	
func start_server(port: int) -> void:
	self.peer = ENetMultiplayerPeer.new()
	var err = self.peer.create_server(port)
	if err != OK:
		_close_connection("Could not create server: %s" % error_string(err))
		return
	multiplayer.multiplayer_peer = self.peer
	_start_lobby_screen()
	add_player(PlayerData.new(
			SERVER_ID,
			Helper.username,
			Helper.colour,
			Helper.bgsid
		).to_dictionary())

@rpc('call_local')
func add_player(player_data_dict: Dictionary) -> void:
	var player_data := PlayerData.from_dictionary(player_data_dict)
	self.players[player_data.network_id] = player_data
	Helper.lobby_screen.add_player(player_data.username, player_data.colour)
	Player.create(Helper.get_main(), player_data)
	if player_data.network_id != self.peer.get_unique_id():
		SyncManager.add_peer(player_data.network_id)

func start_client(ip: String, port: int) -> void:
	self.peer = ENetMultiplayerPeer.new()
	var err := self.peer.create_client(ip, port)
	if err != OK:
		_close_connection("Could not start client: %s" % error_string(err))
		return
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	multiplayer.multiplayer_peer = self.peer

func _join_lobby() -> void:
	_start_lobby_screen()
	on_new_peer_server.rpc_id(SERVER_ID, PlayerData.new(
		self.peer.get_unique_id(),
		Helper.username,
		Helper.colour,
		Helper.bgsid).to_dictionary())

func _start_lobby_screen() -> void:
	Helper.splash_screen.hide()
	Helper.colour = Color(randf(),randf(),randf())
	Helper.lobby_screen = LOBBY_SCREEN_SCENE.instantiate()
	Helper.lobby_screen.name = "LobbyScreen"
	get_tree().root.get_node("Main").add_child(Helper.lobby_screen)

@rpc('any_peer')
func on_new_peer_server(player_data_dict: Dictionary) -> void:
	var player_data := PlayerData.from_dictionary(player_data_dict)
	if player_data.username in self.players.values().map(func(p):p.username):
		_close_connection.rpc_id(player_data.network_id, "Username taken")
		return
	elif player_data.bgsid != Helper.bgsid:
		_close_connection.rpc_id(player_data.network_id, "Wrong bgsid. Need: %s" % Helper.bgsid)
		return
	add_players.rpc_id(player_data.network_id, _serialise_players())
	add_player.rpc(player_data.to_dictionary())

@rpc
func add_players(ps: Dictionary[int, Dictionary]) -> void:
	for p in ps.values():
		add_player(p)

func _serialise_players() -> Dictionary[int, Dictionary]:
	var sd : Dictionary[int, Dictionary] = {}
	for k in self.players.keys():
		sd[k] = self.players[k].to_dictionary()
	return sd

func _on_peer_disconnected(id: int) -> void:
	if multiplayer.is_server():
		remove_player(id)
		remove_player.rpc(id)

@rpc
func remove_player(id: int) -> void:
	if id in self.players.keys():
		Helper.lobby_screen.remove_player(self.players[id].username)
		self.players.erase(id)
		for n in self.get_nodes_mastered_by(id):
			n.queue_free()

func get_nodes_mastered_by(id: int) -> Array:
	return Helper.get_main().get_children().filter(func(x): return x.get_multiplayer_authority() == id)

func _on_server_disconnected() -> void:
	_close_connection("Disconnected from server")

@rpc
func _close_connection(error_msg: String="") -> void:
	if multiplayer.server_disconnected.connect(_on_server_disconnected):
		multiplayer.server_disconnected.disconnect(_on_server_disconnected)
	if is_instance_valid(Helper.lobby_screen):
		Helper.lobby_screen.queue_free()
	SyncManager.stop()
	SyncManager.clear_peers()
	self.peer.close()
	self.players = {}
	Helper.splash_screen.return_to_scene(error_msg)

func _on_sync_manager_sync_started() -> void:
	Helper.lobby_screen.hide()
	Helper.start_game()

func _on_sync_manager_sync_stopped() -> void:
	#lobby_screen.update_connection_status("Session stopped")
	pass

func _on_sync_manager_sync_lost() -> void:
	#lobby_screen.update_connection_status("Lost sync, waiting...")
	pass

func _on_sync_manager_sync_regained() -> void:
	#lobby_screen.update_connection_status("Regained sync!")
	pass

func start_game() -> void:
	# allows clients to sync up
	await get_tree().create_timer(2.0).timeout
	_start_game.rpc()

@rpc("call_local")
func _start_game() -> void:
	SyncManager.start()
