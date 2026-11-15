extends CharacterBody2D
signal respawned
const SPRITES = preload("res://scripts/sprite_library.gd")
const MAX_REWIND: int = 900
const WORLD_WIDTH: float = 2560.0
@export var walk_speed: float = 195.0
@export var run_speed: float = 290.0
@export var jump_strength: float = -495.0
var hero_id: String = "yuri"
var enabled: bool = true
var can_rewind: bool = false
var checkpoint: Vector2 = Vector2(175,432)
var direction_facing: int = 1
var animation: AnimatedSprite2D
var history: Array[Dictionary] = []
var rewinding: bool = false
var talk: bool = false
var time: float = 0.0

func _ready() -> void:
    collision_layer = 2
    collision_mask = 1
    floor_snap_length = 5.0
    var collision: CollisionShape2D = CollisionShape2D.new()
    var capsule: CapsuleShape2D = CapsuleShape2D.new()
    capsule.radius = 17.0
    capsule.height = 136.0
    collision.position = Vector2(0,-68)
    collision.shape = capsule
    add_child(collision)
    animation = AnimatedSprite2D.new()
    animation.position = Vector2(0,-81)
    animation.scale = Vector2(0.43,0.43)
    animation.sprite_frames = SPRITES.build(hero_id)
    animation.play("idle")
    add_child(animation)
    var camera: Camera2D = Camera2D.new()
    camera.offset = Vector2(110,-26)
    camera.limit_left = 0
    camera.limit_right = int(WORLD_WIDTH)
    camera.limit_top = 0
    camera.limit_bottom = 540
    camera.zoom = Vector2(1.05,1.05)
    camera.position_smoothing_enabled = false
    camera.position_smoothing_speed = 8.0
    add_child(camera)
    camera.make_current()
    _record()

func configure(value: String) -> void:
    hero_id = value
    if animation != null:
        animation.sprite_frames = SPRITES.build(hero_id)
        animation.play("idle")
    history.clear()
    _record()

func _physics_process(delta: float) -> void:
    time += delta
    if enabled and can_rewind and Input.is_action_pressed("rewind") and history.size()>1:
        rewinding = true
        for idx: int in range(2):
            if history.size()>1:
                var snapshot: Dictionary = history.pop_back()
                position = snapshot.get("p",position)
                position.x = clampf(position.x,62.0,WORLD_WIDTH-62.0)
                velocity = snapshot.get("v",Vector2.ZERO)
                direction_facing = int(snapshot.get("d",direction_facing))
        _animate()
        return
    rewinding = false
    if enabled:
        if not is_on_floor():
            velocity.y += 1000.0 * delta
        elif Input.is_action_just_pressed("jump"):
            velocity.y = jump_strength
        var dx: float = Input.get_axis("move_left","move_right")
        velocity.x = dx * (run_speed if Input.is_action_pressed("run") else walk_speed)
        if absf(dx)>0.1:
            direction_facing = 1 if dx > 0.0 else -1
        move_and_slide()
        position.x = clampf(position.x,62.0,WORLD_WIDTH-62.0)
        if position.y>630.0:
            respawn()
        elif can_rewind:
            _record()
    else:
        velocity.x = 0.0
    _animate()

func _record() -> void:
    history.append({"p":position,"v":velocity,"d":direction_facing})
    if history.size()>MAX_REWIND:
        history.pop_front()

func _animate() -> void:
    if animation == null:
        return
    animation.flip_h = direction_facing < 0
    animation.modulate = Color(0.67,0.87,1.0,0.86) if rewinding else Color.WHITE
    var next_name: String = "idle"
    if rewinding:
        next_name="rewind"
    elif talk:
        next_name="talk"
    elif not is_on_floor():
        next_name="jump" if velocity.y<0.0 else "fall"
    elif enabled and absf(velocity.x)>6.0:
        next_name="run" if absf(velocity.x)>walk_speed+20.0 else "walk"
    if animation.animation != StringName(next_name):
        animation.play(next_name)
    # A subdued weight shift instead of exaggerated squash & stretch.
    animation.position.y = -81.0 + (1.1*sin(time*2.1) if next_name=="idle" else 0.0)
    animation.rotation = 0.011*sin(time*2.6) if next_name=="idle" else 0.0

func set_talking(value: bool) -> void:
    talk = value
    _animate()

func respawn() -> void:
    position = checkpoint
    velocity = Vector2.ZERO
    history.clear()
    _record()
    respawned.emit()

func clear_history() -> void:
    history.clear()
    _record()

func rewind_seconds() -> float:
    return float(history.size())/60.0
