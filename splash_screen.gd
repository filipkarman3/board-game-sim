class_name SplashScreen extends Window

@onready var ip_line_edit: LineEdit = %IPLineEdit
@onready var port_line_edit: LineEdit = %PortLineEdit
@onready var username_line_edit: LineEdit = %UsernameLineEdit
@onready var host_button: Button = %HostButton
@onready var join_button: Button = %JoinButton
@onready var form: VBoxContainer = %Form
@onready var error_message: Label = %ErrorMessage
@onready var connection_error_message: Label = %ConnectionErrorMessage
@onready var file_dialog: FileDialog = %FileDialog

var input_errors := {
	ip_line_edit: "",
	port_line_edit: "",
	username_line_edit: "" }

var is_server: bool

func _ready() -> void:
	Helper.splash_screen = self
	_on_ip_line_edit_text_changed(self.ip_line_edit.text)
	_on_port_line_edit_text_changed(self.port_line_edit.text)
	_on_username_line_edit_text_changed(self.username_line_edit.text)
	_update_button_enabled()
	
func _on_ip_line_edit_text_changed(new_text: String) -> void:
	self.input_errors[ip_line_edit] = (
		"Invalid IP address" if !new_text.is_valid_ip_address() else "")
	_update_button_enabled()
	
func _on_port_line_edit_text_changed(new_text: String) -> void:
	self.input_errors[port_line_edit] = (
		"Invalid port number" if !new_text.is_valid_int() else "")
	_update_button_enabled()
	
func _on_username_line_edit_text_changed(new_text: String) -> void:
	Helper.username = new_text
	self.input_errors[username_line_edit] = (
		"Empty username" if new_text.length()==0 else "")
	_update_button_enabled()
	
func _update_button_enabled() -> void:
	if self.input_errors.values().any(func(x): return !x.length()==0):
		host_button.disabled = true
		join_button.disabled = true
	else:
		host_button.disabled = false
		join_button.disabled = false
	self.error_message.text = '\n'.join(self.input_errors.values().filter(func(x): return !x.length()==0))

func _on_host_button_pressed() -> void:
	file_dialog.popup_file_dialog()
	self.is_server = true

func _on_join_button_pressed() -> void:
	file_dialog.popup_file_dialog()
	self.is_server = false

func start_connecting() -> void:
	if self.is_server:
		NetworkHandler.start_server(int(self.port_line_edit.text))
	else:
		NetworkHandler.start_client(self.ip_line_edit.text, int(self.port_line_edit.text))
	form.visible = false
	connection_error_message.visible= false
	error_message.text = "Connecting..."

func return_to_scene(err_msg: String) -> void:
	file_dialog.visible = false
	form.visible = true
	connection_error_message.visible = true
	connection_error_message.text = err_msg
	self.visible = true
	_update_button_enabled()
