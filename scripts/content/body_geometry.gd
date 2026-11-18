@tool
extends RefCounted
## Pure source-local body geometry shared by editor preview and the real actor.
static func crt1_rect(geometry: Dictionary, parent: int, clock: int, kind: String, x_override := INF) -> Rect2:
	var bodies: Dictionary = geometry.act03_crt1_body
	var placement: Variant = bodies.parents.get(str(parent),{}).get(kind)
	if placement == null:return Rect2()
	var clip: Dictionary = bodies.clips.get(str(int(placement.source_id)),{})
	var rectangles: Array = []
	if clip.is_empty():
		var shape: Dictionary = geometry.act03_crt1_hit_windows.hit_shapes.get(str(int(placement.source_id)),{})
		if shape.has("rect"):rectangles.append(shape.rect)
	else:
		var frame_number := 1 if int(placement.source_id) in [4546,4547] else mini(clock,int(clip.frame_count))
		rectangles = clip.rects_by_source_frame.get(str(frame_number),[])
	if rectangles.is_empty():return Rect2()
	var r: Array = rectangles[0]
	var m: Array = placement.matrix
	return Rect2(r[0]+(float(m[4]) if is_inf(x_override) else x_override),r[1]+m[5],r[2],r[3])

static func crt2_rect(geometry: Dictionary, parent: int, clock: int, kind: String) -> Rect2:
	return timeline_rect(geometry.act04_crt2_body,parent,clock,kind)

static func crt3_rect(geometry: Dictionary, parent: int, clock: int, kind: String) -> Rect2:
	return timeline_rect(geometry.act05_crt3_body,parent,clock,kind)

static func crt4_rect(geometry: Dictionary, parent: int, clock: int, kind: String, selector := 1) -> Rect2:
	var bodies:Dictionary=geometry.act06_crt4_body
	var placement:Variant=bodies.parents.get(str(parent),{}).get(kind)
	if placement==null:return Rect2()
	if int(placement.source_id)!=6407:return timeline_rect(bodies,parent,clock,kind)
	var rows:Array=bodies.clips["6407"].rects_by_source_frame.get(str(selector),[])
	if rows.is_empty():return Rect2()
	var r:Array=rows[0];var m:Array=placement.matrix
	return Transform2D(Vector2(m[0],m[1]),Vector2(m[2],m[3]),Vector2(m[4],m[5]))*Rect2(r[0],r[1],r[2],r[3])

static func timeline_rect(bodies: Dictionary, parent: int, clock: int, kind: String) -> Rect2:
	var placement: Variant = bodies.parents.get(str(parent),{}).get(kind)
	if placement == null:return Rect2()
	var clip: Dictionary = bodies.clips.get(str(int(placement.source_id)),{})
	var frame_number := mini(clock,int(clip.get("stop_source_frame",clip.get("frame_count",1))))
	var rectangles: Array = clip.get("rects_by_source_frame",{}).get(str(maxi(1,frame_number)),[])
	if rectangles.is_empty():return Rect2()
	var r: Array = rectangles[0]
	var m: Array = placement.matrix
	var transform := Transform2D(Vector2(m[0],m[1]),Vector2(m[2],m[3]),Vector2(m[4],m[5]))
	return transform*Rect2(r[0],r[1],r[2],r[3])
