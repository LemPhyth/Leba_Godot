@tool
extends BaseButton
## Editable native hit rectangle; ArtworkLayout is the persistent visual offset.
## Only Artwork's texture/source-frame offset changes with native button state.
@export var normal_texture: Texture2D
@export var hover_texture: Texture2D
@export var pressed_texture: Texture2D
@export var normal_pivot := Vector2.ZERO
@export var hover_pivot := Vector2.ZERO
@export var pressed_pivot := Vector2.ZERO
@export var intent_action := ""
@export var intent_payload: Dictionary = {}
var artwork: Sprite2D
var visual_state := "up"

func _ready() -> void:
	artwork = get_node_or_null("ArtworkLayout/Artwork") as Sprite2D
	for signal_: Signal in [mouse_entered,mouse_exited,button_down,button_up]:
		if not signal_.is_connected(refresh_art):signal_.connect(refresh_art)
	refresh_art()

func _draw() -> void:
	refresh_art()

func refresh_art() -> void:
	if not is_instance_valid(artwork):artwork = get_node_or_null("ArtworkLayout/Artwork") as Sprite2D
	if artwork == null:return
	visual_state = "up"
	if not disabled:
		if get_draw_mode() in [DRAW_PRESSED,DRAW_HOVER_PRESSED]:visual_state = "down"
		elif get_draw_mode() == DRAW_HOVER:visual_state = "over"
	var selected := normal_texture
	var pivot := normal_pivot
	if visual_state == "over" and hover_texture != null:
		selected = hover_texture
		pivot = hover_pivot
	elif visual_state == "down" and pressed_texture != null:
		selected = pressed_texture
		pivot = pressed_pivot
	artwork.visible = selected != null
	artwork.texture = selected
	artwork.position = normal_pivot-pivot
	artwork.modulate.a = 0.45 if disabled else 1.0
