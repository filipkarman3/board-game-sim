"""
Register collisions with start_collision
Register collision end with end_collision
Define on_new_player_connection(p:Player)->void to specify what to do when a new player attaches to the object
Define detach_player_connection()->void to specify what to do when the player detaches from an object
	Not called if another player immediately attaches to the object
	Only called when a player detaches and no other player immediately takes their place
"""

extends Node

var attachment_tracker: Dictionary[Node, Node] = {}
var collision_queues: Dictionary[Node, Array] = {}
var blocked: Dictionary[Node, bool] = {}

func start_collision(p: Player, o: Node) -> void:
	collision_queues.get_or_add(p, []).append(o)
	collision_queues.get_or_add(o, []).append(p)
	self.update()

func on_new_player_connection_with_warning(p: Player, o: Node) -> void:
	if o.has_method('on_new_player_connection'):
		o.on_new_player_connection(p)
	else:
		assert(false, 'Node %s attempted to use CollisionHelper without having a \'on_new_player_connection\' function defined' % o)

func detach_player_connection_with_warning(p: Player, o: Node) -> void:
	if o.has_method('detach_player_connection'):
		o.detach_player_connection()
	else:
		assert(false, 'Node %s attempted to use CollisionHelper without having a \'detach_player_connection\' function defined' % o)

func end_collision(p: Player, o: Node) -> void:
	# either the player was attached to this object or not
	# if the player was attached to this object:
		# we detach the player and object on the attachment trackers
		# and also remove them from each others' collision queues
		# this means that their attachment is freed up and we can try attach em to other things
	# if the player was attached to a different object:
		# we remove the player and the object from each others' collision queues
		# but we don't do anything else as this removal doesn't affect their current attachments
	
	collision_queues.get(p,[]).erase(o)
	collision_queues.get(o,[]).erase(p)
	
	if attachment_tracker.get(p,null) == o:
		attachment_tracker[p] = null
	if attachment_tracker.get(o,null) == p:
		attachment_tracker[o] = null
	
	self.update()
	
	# detach_player_connection is only called if the item does not
	# reconnect to any other player
	if not is_instance_valid(attachment_tracker.get(o,null)):
		detach_player_connection_with_warning(p,o)

func block(o: Node) -> void:
	if is_instance_valid(attachment_tracker.get(o,null)):
		assert(false, 'attempted to block object %s that is already attached to player %s' % [o,attachment_tracker[o]])
	blocked[o] = true

func unblock(o: Node) -> void:
	if not blocked.get(o,false):
		assert(false, 'attempted to unblock an already-unblocked object %s' % o)
	blocked.erase(o)
	
	for p in collision_queues.get(o,[]):
		if not is_instance_valid(attachment_tracker.get(p,null)):
			attachment_tracker[o]=p
			attachment_tracker[p]=o
			on_new_player_connection_with_warning(p,o)
			break

func update() -> void:
	# get rid of invalid values
	for k in collision_queues.keys():
		if not is_instance_valid(k):
			collision_queues.erase(k)
		collision_queues[k] = collision_queues[k].filter(func(x): return is_instance_valid(x))
		if collision_queues[k].is_empty():
			collision_queues.erase(k)
	
	for k in attachment_tracker.keys():
		if not is_instance_valid(k) or not is_instance_valid(attachment_tracker[k]):
			attachment_tracker.erase(k)
	
	for k in blocked.keys():
		if not is_instance_valid(k):
			blocked.erase(k)
	
	# re-attach now-unattached values
	for k in collision_queues.keys():
		if is_instance_valid(attachment_tracker.get(k,null)): continue
		for v in collision_queues[k]:
			var p: Player = v if v is Player else k
			var o: Node   = k if v is Player else v
			if not is_instance_valid(attachment_tracker.get(v,null)) and not blocked.get(o,false):
				attachment_tracker[p]=o
				attachment_tracker[o]=p
				on_new_player_connection_with_warning(p,o)
				break
