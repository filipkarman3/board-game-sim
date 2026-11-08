class_name LobbyScreen extends Window

@onready var player_list_container: VBoxContainer = %PlayerListContainer
@onready var connection_status_label: Label = %ConnectionStatusLabel
@onready var button_container: HBoxContainer = %ButtonContainer
@onready var start_game_button: Button = %StartGameButton

func _ready() -> void:
	if multiplayer.is_server():
		button_container.visible = true
	else:
		connection_status_label.text = "Waiting for host to start game..."
	
func add_player(_name: String, colour: Color) -> void:
	var player_label = Label.new()
	player_label.text = _name
	player_label.add_theme_color_override("font_color", colour)
	player_list_container.add_child(player_label)

func remove_player(_name: String) -> void:
	for c in player_list_container.get_children():
		if c.text==_name:
			c.queue_free()

func update_connection_status(msg: String) -> void:
	connection_status_label.text = msg

func _on_quit_button_pressed() -> void:
	NetworkHandler._close_connection()

func _on_start_game_button_pressed() -> void:
	self.update_connection_status("Starting game...")
	button_container.visible = false
	NetworkHandler.start_game()
