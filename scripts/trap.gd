extends Node2D
## Narrative-platformer traps. All units are world-space and use the same FLOOR
## as the visible walkways. State is reset by checkpoints or rewinding.
signal warning
signal player_hit

const WIDTH: float = 124.0
var kind: String = "crumble"
var floor_texture: Texture2D
var player: Variant
var phase: int = 0  # 0 dormant, 1 warning, 2 active
var timer: float = 0.0
var t: float = 0.0
var hit_sent: bool = false
var top_sprite: Sprite2D
var platform: CollisionShape2D
var barrier: CollisionShape2D

func _ready() -> void:
    z_index=1
    if kind=="crumble":
        # The gap is cut out of the main ground by game_scene.gd.
        var pit: Sprite2D=Sprite2D.new()
        pit.texture=load("res://assets/floors/chasm.png") as Texture2D
        pit.position=Vector2(0,54)
        pit.scale=Vector2(WIDTH/180.0,1.0)
        pit.z_index=-7
        add_child(pit)
        top_sprite=Sprite2D.new()
        top_sprite.texture=floor_texture
        top_sprite.region_enabled=true
        top_sprite.region_rect=Rect2(position.x-WIDTH*0.5,0,WIDTH,108)
        top_sprite.position=Vector2(0,54)
        top_sprite.z_index=-4
        add_child(top_sprite)
        platform=_solid(Vector2(0,190),Vector2(WIDTH,380),"FragilePaving")
    elif kind=="rising":
        barrier=_solid(Vector2(0,-39),Vector2(48,78),"RisingBarrier")
        barrier.set_deferred("disabled",true)
    queue_redraw()

func _solid(center: Vector2, size: Vector2, label_name: String) -> CollisionShape2D:
    var body: StaticBody2D=StaticBody2D.new()
    body.name=label_name
    body.position=center
    body.collision_layer=1
    body.collision_mask=0
    var collider: CollisionShape2D=CollisionShape2D.new()
    var rect: RectangleShape2D=RectangleShape2D.new()
    rect.size=size
    collider.shape=rect
    body.add_child(collider)
    add_child(body)
    return collider

func reset() -> void:
    phase=0
    timer=0.0
    hit_sent=false
    if top_sprite!=null:
        top_sprite.visible=true
        top_sprite.modulate=Color.WHITE
    if platform!=null:
        platform.set_deferred("disabled",false)
    if barrier!=null:
        barrier.set_deferred("disabled",true)
    queue_redraw()

func _physics_process(delta: float) -> void:
    t+=delta
    if player==null or not is_instance_valid(player):
        return
    if player.rewinding:
        if phase!=0:
            reset()
        return
    if not player.enabled:
        return
    var distance: float=absf(player.global_position.x-global_position.x)
    var near_ground: bool=absf(player.global_position.y-global_position.y)<96.0
    if phase==0 and near_ground:
        if kind=="crumble" and distance<57.0 and player.is_on_floor():
            _arm(0.52)
        elif kind=="spikes" and distance<153.0:
            _arm(0.48)
        elif kind=="rising" and distance<174.0:
            _arm(0.43)
    if phase==1:
        timer-=delta
        if timer<=0.0:
            phase=2
            if kind=="crumble":
                platform.set_deferred("disabled",true)
                top_sprite.visible=false
            elif kind=="rising":
                barrier.set_deferred("disabled",false)
    if phase==2 and kind=="spikes" and not hit_sent:
        if distance<37.0 and absf(player.global_position.y-global_position.y)<76.0:
            hit_sent=true
            player_hit.emit()
    queue_redraw()

func _arm(seconds: float) -> void:
    phase=1
    timer=seconds
    warning.emit()

func _draw() -> void:
    if kind=="crumble":
        if phase==2:
            return
        var flash: float=0.90 if phase==1 and int(t*13.0)%2==0 else 0.37
        var edge: Color=Color(0.98,0.67,0.33,flash)
        draw_line(Vector2(-46,2),Vector2(-16,15),edge,2.0)
        draw_line(Vector2(-16,15),Vector2(1,3),edge,2.0)
        draw_line(Vector2(1,3),Vector2(31,11),edge,2.0)
        draw_line(Vector2(31,11),Vector2(48,1),edge,2.0)
    elif kind=="spikes":
        if phase==0:
            draw_rect(Rect2(-42,-5,84,5),Color(0.35,0.48,0.56,0.71))
            draw_line(Vector2(-37,-4),Vector2(34,-4),Color(0.69,0.66,0.44,0.62),1.5)
            return
        var high: float=9.0 if phase==1 else 47.0
        var tint: Color=Color(0.95,0.70,0.38,0.8) if phase==1 else Color(0.68,0.82,0.90,1.0)
        draw_rect(Rect2(-42,-8,84,9),Color(0.12,0.20,0.28))
        for i: int in range(5):
            var cx: float=-35.0+float(i)*17.0
            var points: PackedVector2Array=PackedVector2Array([
                Vector2(cx-8,-3),Vector2(cx,-high),Vector2(cx+8,-3)
            ])
            draw_colored_polygon(points,tint)
        if phase==1:
            draw_arc(Vector2(0,-24),25.0,0.0,TAU,32,Color(0.96,0.65,0.30,0.55),2.0)
    else:
        var height: float=0.0
        if phase==1:
            height=78.0*clampf(1.0-timer/0.43,0.0,1.0)
        elif phase==2:
            height=78.0
        if phase==0:
            draw_rect(Rect2(-27,-5,54,6),Color(0.47,0.39,0.28,0.75))
        else:
            draw_rect(Rect2(-24,-height,48,height),Color(0.20,0.26,0.36))
            draw_rect(Rect2(-23,-height,46,7),Color(0.73,0.62,0.42))
            draw_line(Vector2(-19,-height+8),Vector2(-19,-2),Color(0.55,0.67,0.78),3.0)
            draw_line(Vector2(19,-height+8),Vector2(19,-2),Color(0.08,0.13,0.20),3.0)
