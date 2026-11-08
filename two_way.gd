class_name TwoWay extends RefCounted

var id_to_obj: Dictionary[int, Variant] = {}
var obj_to_id: Dictionary[Variant, int] = {}

static func from_dict(_id_to_obj: Dictionary) -> TwoWay:
	var tw := TwoWay.new()
	for a in _id_to_obj:
		tw.write(a,_id_to_obj[a])
	return tw

func write(id: int, obj) -> void:
	id_to_obj[id] = obj
	obj_to_id[obj] = id

func get_id(obj, _default=null) -> int:
	return obj_to_id.get(obj, null)

func get_obj(id, _default=null) -> Variant:
	return id_to_obj.get(id, null)

func write_obj(obj) -> int:
	var i: int = 0
	while i in id_to_obj:
		i += 1
	id_to_obj[i] = obj
	obj_to_id[obj] = i
	return i
