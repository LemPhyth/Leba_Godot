@tool
extends Node2D
const BodyGeometry = preload("res://scripts/content/body_geometry.gd")
## Editor-only view of the same ActionDefinition/atlas/windows consumed by Battle.
## No Main, audio, input, profile, collision callbacks or ResourceSaver here.
@export var action: Resource:
	set(value):
		action = value
		_refresh()
@export_range(1,2000,1) var source_frame := 1:
	set(value):
		source_frame = value
		_refresh()
@export var play := false
@export var show_body := true
@export var show_attack := true
@export var show_events := true
@export var show_displacement := true
@export_tool_button("源帧单步（25 FPS）") var step_frame = _step
@export_tool_button("回到动作首帧") var rewind_frame = _rewind
var _age := 0.0
static var _geometry_cache: Dictionary = {}

func _ready() -> void:
	if not Engine.is_editor_hint():
		visible = false
		set_process(false)
	else:_refresh()
	if Engine.is_editor_hint() and _geometry_cache.is_empty():
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/asset_catalog.json"))
		if data is Dictionary:_geometry_cache = data.get("source_geometry",{})

func _process(delta: float) -> void:
	if not Engine.is_editor_hint():return
	_age += delta
	if play and _age >= 0.04:
		_age = fmod(_age,0.04)
		_step()
	elif _age >= 0.12:
		_age = 0.0
		_refresh()

func _rewind() -> void:
	if action != null:source_frame = int(action.sequence[0]) if not action.sequence.is_empty() else 1

func _step() -> void:
	if action == null:return
	var frames: Array = Array(action.sequence)
	if frames.is_empty() and action.animation != null:
		for frame: Dictionary in action.animation.frames:frames.append(int(frame.source_frame))
	if frames.is_empty():return
	var index := frames.find(source_frame)
	source_frame = int(frames[(index+1)%frames.size()])

func _refresh() -> void:
	if not Engine.is_editor_hint() or not is_inside_tree() or action == null:return
	var visual := get_node_or_null("../Visual")
	if visual != null and action.animation != null:
		visual.configure(action.animation.to_runtime())
		var valid: bool = action.animation.frames.any(func(row: Dictionary)->bool:return int(row.source_frame) == source_frame)
		if valid:visual.set_source_frame(source_frame)
		visual.position = action.visual_offset
	queue_redraw()

func _draw() -> void:
	if not Engine.is_editor_hint() or action == null:return
	draw_line(Vector2(-5,0),Vector2(5,0),Color.YELLOW)
	draw_line(Vector2(0,-5),Vector2(0,5),Color.YELLOW)
	if show_body:
		var body: Rect2 = action.hurt_rect
		if not action.override_hurt_rect:
			if str(action.animation_key).begins_with("crt1_") and _geometry_cache.has("act03_crt1_body"):
				var body_clock := maxi(1,Array(action.sequence).find(source_frame)+1)
				body = BodyGeometry.crt1_rect(_geometry_cache,int(action.source_parent),body_clock,"몸빵")
			elif str(action.animation_key).begins_with("crt2_") and _geometry_cache.has("act04_crt2_body"):
				var body_clock := maxi(1,Array(action.sequence).find(source_frame)+1)
				body = BodyGeometry.crt2_rect(_geometry_cache,int(action.source_parent),body_clock,"몸빵")
			elif str(action.animation_key).begins_with("crt3_") and _geometry_cache.has("act05_crt3_body"):
				var body_clock := maxi(1,Array(action.sequence).find(source_frame)+1)
				body = BodyGeometry.crt3_rect(_geometry_cache,int(action.source_parent),body_clock,"몸빵")
			elif str(action.animation_key).begins_with("crt4_") and _geometry_cache.has("act06_crt4_body"):
				var body_clock := maxi(1,Array(action.sequence).find(source_frame)+1)
				body = BodyGeometry.crt4_rect(_geometry_cache,int(action.source_parent),body_clock,"몸빵")
			elif _geometry_cache.has("crt0_body"):
				var r: Array = _geometry_cache.crt0_body.rect
				body = Rect2(r[0],r[1],r[2],r[3])
		if body.has_area():draw_rect(body,Color(0.2,0.9,1,0.8),false,1)
	if show_attack:
		for window: Resource in action.windows:
			if source_frame < window.from_frame or source_frame > window.until_frame:continue
			for rect: Rect2 in window.rectangles:draw_rect(rect,Color(1,.3,.2,.9),false,1.5)
		if action.component_definition != null:
			var data: Dictionary = action.component_definition.parameters
			for rect: Rect2 in data.get("phase_helpers",{}).get(str(source_frame),{}).get("hit_windows",[]):draw_rect(rect,Color(1,.3,.2,.9),false,1.5)
			if data.has("timeline"):
				var matrix: Array = data.parent_matrix
				var transform := Transform2D(Vector2(matrix[0],matrix[1]),Vector2(matrix[2],matrix[3]),Vector2(matrix[4],matrix[5]))
				for row: Dictionary in data.timeline.get(str(source_frame),[]):
					if not row.has("rect"):continue
					var r: Array = row.rect
					draw_rect(transform*Rect2(r[0],r[1],r[2],r[3]),Color(1,.3,.2,.9),false,1.5)
	if show_events:
		var text := "%s · 源%d · 25 FPS" % [action.identifier,source_frame]
		for event: Resource in action.events:
			if event.frame == source_frame:
				text += "  "+event.kind
				draw_circle(event.offset,3,Color(1,.5,.1))
		draw_string(ThemeDB.fallback_font,Vector2(-50,-130),text,HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color.WHITE)
	if show_displacement:
		var dx := 0.0
		for event: Resource in action.events:
			if event.kind == "root_motion" and event.frame <= source_frame:dx += float(event.parameters.get("dx",0))
		for motion: Dictionary in action.extra.get("source_movement",[]):
			dx += maxi(0,mini(source_frame,int(motion.until))-int(motion.from)+1)*float(motion.per_tick)
		if action.extra.has("backstep"):dx += mini(source_frame,int(action.extra.backstep.through_source_frame))*float(action.extra.backstep.per_tick)
		if not is_zero_approx(dx):
			draw_line(Vector2.ZERO,Vector2(dx,0),Color(1,.7,.1),2)
			draw_circle(Vector2(dx,0),3,Color.ORANGE)
