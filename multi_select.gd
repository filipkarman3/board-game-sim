class_name MultiSelect extends Control

const SCENE = preload("res://MultiSelect.tscn")

static func create() -> MultiSelect:
	var ms: MultiSelect = SCENE.instantiate()
	return ms

@onready var menu_button: MenuButton = %MenuButton

func _ready():
	var popup := menu_button.get_popup()
	popup.hide_on_checkable_item_selection = false  # keep menu open while ticking
	for p_name in Helper.players:
		if not Helper.is_own_player(Helper.players[p_name]):
			popup.add_check_item(p_name)
	popup.id_pressed.connect(_on_item_pressed)

func _on_item_pressed(id: int):
	var popup := menu_button.get_popup()
	var idx := popup.get_item_index(id)
	popup.toggle_item_checked(idx)

func get_selected() -> Array[String]:
	var result: Array[String] = []
	var popup := menu_button.get_popup()
	for i in popup.item_count:
		if popup.is_item_checked(i):
			result.append(popup.get_item_text(i))
	return result
