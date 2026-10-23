class_name PlayerData extends RefCounted

var network_id: int
var username: String
var colour: Color
var bgsid: String

func _init(
		network_id: int,
		username: String,
		colour: Color,
		bgsid: String):
	self.network_id = network_id
	self.username = username
	self.colour = colour
	self.bgsid = bgsid

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
