extends Node2D
const SPRITES = preload("res://scripts/sprite_library.gd")
var character_id: String = "garnik"
var talking: bool = false
var actor: AnimatedSprite2D
var phase: float = 0.0
var anchor: Vector2

func _ready() -> void:
    anchor = position
    actor = AnimatedSprite2D.new()
    actor.sprite_frames = SPRITES.build(character_id)
    actor.scale = Vector2(0.41,0.41)
    actor.position = Vector2(0,-77)
    actor.play("idle")
    add_child(actor)

func _process(delta: float) -> void:
    phase += delta
    if actor == null:
        return
    var state: String = "talk" if talking else "idle"
    if actor.animation != StringName(state):
        actor.play(state)
    actor.position.y = -77.0+0.8*sin(phase*2.2)
    actor.rotation = 0.013*sin(phase*5.0) if talking else 0.008*sin(phase*1.7)

func set_talking(value: bool) -> void:
    talking = value
