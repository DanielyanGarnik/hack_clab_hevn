extends Node2D
## Interaction cues are tangible objects grounded on the floor, not yellow rings.
var active: bool = true
var near: bool = false
var locked: bool = false
var kind: String = "letter"
var phase: float = 0.0
var object_sprite: Sprite2D
var prompt: Label

func _ready() -> void:
    object_sprite = Sprite2D.new()
    object_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    object_sprite.scale = Vector2(0.85,0.85)
    add_child(object_sprite)
    prompt = Label.new()
    prompt.text = "E"
    prompt.position = Vector2(-17.0,-81.0)
    prompt.size = Vector2(34.0,29.0)
    prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    prompt.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    prompt.add_theme_font_size_override("font_size",21)
    prompt.add_theme_color_override("font_color",Color("#e9e7dd"))
    prompt.add_theme_color_override("font_shadow_color",Color("#070e1b"))
    prompt.add_theme_constant_override("shadow_offset_x",1)
    prompt.add_theme_constant_override("shadow_offset_y",2)
    prompt.visible = false
    add_child(prompt)
    configure(kind)

func configure(new_kind: String) -> void:
    kind = new_kind
    var source: String = "res://assets/interactables/"+kind+".png"
    if not ResourceLoader.exists(source):
        source = "res://assets/interactables/keepsake.png"
    if object_sprite != null:
        object_sprite.texture = load(source) as Texture2D

func _process(delta: float) -> void:
    phase += delta
    if object_sprite != null:
        object_sprite.visible = active
        object_sprite.position.y = 0.5 * sin(phase*1.3)
    if prompt != null:
        prompt.visible = active and near and not locked
