extends Line2D

const STANCE_WIDTH : float = 40
const LEAN_BACK : float    = 50
const MAX_STRETCH : float  = 100
const A_STANDING_POS : Vector2 = Vector2(STANCE_WIDTH/2.0,0)
const B_STANDING_POS : Vector2 = Vector2(-STANCE_WIDTH/2.0,0)
const SPEED := 10.0

enum STATE  { A, B, STILL }
var state = STATE.STILL

var a := A_STANDING_POS
var b := B_STANDING_POS
var c := Vector2(0,-LEAN_BACK)
func d() -> Vector2: return Vector2.ZERO

var old_pos : Vector2
var last_angle := 0.0

func move(pos: Vector2) -> void:
	if old_pos == null or old_pos.is_equal_approx(pos):
		old_pos = pos
		state = STATE.STILL
	elif state == STATE.STILL:
		state = STATE.A

	#var delta := pos - old_pos
	var delta := Vector2(0,pos.distance_to(old_pos))
	if state == STATE.STILL:
		var a_dir := A_STANDING_POS-a
		if a_dir.length()<=SPEED*1.1:
			a = A_STANDING_POS
		else:
			a = a+a_dir/a_dir.length()*SPEED
		
		var b_dir := B_STANDING_POS-b
		if b_dir.length()<SPEED*1.1:
			b = B_STANDING_POS
		else:
			b = b+b_dir/b_dir.length()*SPEED
		
	elif state == STATE.A:
		a += delta
		b -= delta
		if a.distance_to(b) > MAX_STRETCH:
			a = b + (d()-b)*1.99
			state = STATE.B
	elif state == STATE.B:
		b += delta
		a -= delta
		if b.distance_to(a) > MAX_STRETCH:
			b = a + (d()-a)*1.99
			state = STATE.A
	
	c = Vector2(0,min(a.y,b.y)-LEAN_BACK)
	var angle = compute_angle(old_pos, pos)
	self.clear_points()
	self.add_point(a)
	self.add_point(c)
	self.add_point(b)
	
	if state == STATE.STILL:
		self.rotation = last_angle
	else:
		self.rotation = angle
		last_angle = angle
	old_pos = pos
	
func compute_angle(p1: Vector2, p2: Vector2) -> float:
	return (p2-p1).angle()-PI/2.0
