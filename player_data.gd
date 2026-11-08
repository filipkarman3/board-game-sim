class_name PlayerData extends RefCounted

var network_id: int
var username: String
var colour: Color
var bgsid: String

func _init(
		_network_id: int,
		_username: String,
		_colour: Color,
		_bgsid: String):
	self.network_id = _network_id
	self.username = _username
	self.colour = _colour
	self.bgsid = _bgsid

func to_dictionary() -> Dictionary:
	return {
		"network_id": network_id,
		"username": username,
		"colour": colour,
		"bgsid": bgsid
	}
	
static func from_dictionary(d: Dictionary) -> PlayerData:
	return PlayerData.new(
		d.network_id,
		d.username,
		d.colour,
		d.bgsid)
