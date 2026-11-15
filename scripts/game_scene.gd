extends Node2D
## One scene for 13 authored chapters. Dialogue, evidence and puzzles are never
## mixed into physics; progress saves only after a completed interaction.
const UI = preload("res://scripts/visuals.gd")
const HERO = preload("res://scripts/player.gd")
const NPC = preload("res://scripts/npc.gd")
const MARKER = preload("res://scripts/marker.gd")
const TRAP = preload("res://scripts/trap.gd")
const WIDTH: float = 2560.0
const FLOOR: float = 432.0
var info: Dictionary = {}
var steps: Array = []
var step_index: int = 0
var hero_id: String = "yuri"
var period: String = "present"
var player
var actors: Dictionary = {}
var marker
var backgrounds: Array[Sprite2D] = []
var bridge_collision: CollisionShape2D
var bridge_floor: Sprite2D
var traps: Array[Node2D] = []
var trap_notice_time: float = 0.0
var hud: Control
var hud_portrait: TextureRect
var chapter_text: Label
var active_name: Label
var task_text: Label
var hint_text: Label
var clock_text: Label
var dialog_panel: Panel
var dialog_portrait: TextureRect
var dialog_other_portrait: TextureRect
var dialog_left_name: Label
var dialog_right_name: Label
var dialog_name: Label
var dialog_text: Label
var dialog_button: Button
var choose_panel: Panel
var choose_title: Label
var choose_buttons: Array[Button] = []
var artifact_panel: Panel
var artifact_backdrop: ColorRect
var artifact_picture: TextureRect
var artifact_paper_text: Label
var artifact_paper_header: Label
var artifact_paper_clip: Control
var artifact_caption: Label
var artifact_title: Label
var puzzle_panel: Panel
var puzzle_display: Label
var puzzle_message: Label
var notes_panel: Panel
var notes_label: Label
var notes_scroll: ScrollContainer
var pause_panel: Panel
var touch_buttons: Array[Button] = []
var dialogue_lines: Array = []
var dialogue_index: int = 0
var dialogue_page: int = 0
var dialogue_chunks: PackedStringArray = PackedStringArray()
var after_dialogue: String = ""
var current_choice: Dictionary = {}
var in_dialogue: bool = false
var in_choice: bool = false
var in_artifact: bool = false
var in_puzzle: bool = false
var in_notes: bool = false
var in_pause: bool = false
var blocked_until: float = 0.0
var puzzle_input: String = ""
var artifact_first: bool = false
var active_beats: Array = []
var beat_index: int = 0
var current_beat: Dictionary = {}
var impact_panel: Panel
var impact_label: Label
var impact_seconds: float = 0.0
var echo_gate: StaticBody2D
var echo_gate_shape: CollisionShape2D
var echo_gate_visual: ColorRect
var echo_gate_open: bool = false
var echo_gate_armed: bool = false
var exit_requested: bool = false

func _ready() -> void:
    info = State.get_chapter_data()
    if info.is_empty():
        get_tree().call_deferred("change_scene_to_file","res://scenes/menu.tscn")
        return
    steps = info.get("steps",[])
    hero_id = State.route if State.route!="finale" else "yuri"
    step_index = clampi(State.current_step(),0,steps.size())
    _create_world()
    _create_hud()
    _place_marker()
    if step_index>=2:
        # A resume after the rewind door is already past the mandatory moment.
        _open_echo_gate(false)
    if step_index==0:
        _start_lines(_intro_with_history(),"intro")
    elif step_index>=steps.size():
        _start_lines(info.get("outro",[]),"outro")
    else:
        # Resume near the next clue, not at the beginning of an empty level.
        var last_x: float = float(steps[step_index-1].get("x",150.0))
        var safe_x: float = _safe_x(last_x+45.0)
        player.position=Vector2(safe_x,FLOOR)
        player.checkpoint=player.position
        player.clear_history()
        _update_hud()

# Geometry and visuals use one shared floor height. A player at FLOOR stands
# exactly on the first visible pixel of the walkway, not in mid-air.
func _ground(center: Vector2, size: Vector2, label: String = "Surface") -> StaticBody2D:
    var body: StaticBody2D = StaticBody2D.new()
    body.name = label
    body.position = center
    body.collision_layer = 1
    body.collision_mask = 0
    var collision: CollisionShape2D = CollisionShape2D.new()
    var rectangle: RectangleShape2D = RectangleShape2D.new()
    rectangle.size = size
    collision.shape = rectangle
    body.add_child(collision)
    add_child(body)
    return body

# A single 2,560-pixel image is sliced by region rather than stretched.
# This preserves texture scale at every X and never draws across an open gap.
func _visual_floor(texture: Texture2D, left: float, right: float) -> Sprite2D:
    var surface: Sprite2D = Sprite2D.new()
    surface.name = "VisibleWalkway"
    surface.texture = texture
    surface.region_enabled = true
    surface.region_rect = Rect2(left, 0.0, right-left, 108.0)
    surface.position = Vector2((left+right)*0.5, FLOOR+54.0)
    surface.z_index = -4
    add_child(surface)
    return surface

func _floor_segment(texture: Texture2D, left: float, right: float) -> StaticBody2D:
    # The collider extends below the artwork, preventing tunneling and edge slips.
    var body: StaticBody2D = _ground(
        Vector2((left+right)*0.5, FLOOR+190.0),
        Vector2(right-left, 380.0),
        "SolidWalkway"
    )
    _visual_floor(texture, left, right)
    return body

func _world_boundary(x: float, side: String, wall_texture: Texture2D) -> void:
    # No gaps at the left/right edges, even during rewinds and high jumps.
    _ground(Vector2(x,200.0),Vector2(74.0,1500.0),side+"Boundary")
    var wall: Sprite2D = Sprite2D.new()
    wall.name = side+"VisibleBoundary"
    wall.texture = wall_texture
    wall.position = Vector2(21.0 if side=="Left" else WIDTH-21.0,270.0)
    wall.flip_h = side=="Right"
    wall.z_index = -3
    add_child(wall)

# Safe, deterministic trap spots between authored clues: never on top of an objective.
# Chapter variants prevent each route from feeling like the same corridor.
func _trap_specs() -> Array[Dictionary]:
    var route_index: int = maxi(0,State.HERO_IDS.find(hero_id))
    # Earlier conversations affect which traps time leaves behind in the next chapter.
    var previous_choices: int = int(State.bonds.get(hero_id,0))
    var variant: int = posmod(State.chapter+route_index+(1 if previous_choices>=3 else 0),3)
    if State.route=="finale":
        variant=2
    if variant==0:
        return [{"kind":"crumble","x":700.0},{"kind":"spikes","x":1830.0}]
    if variant==1:
        return [{"kind":"spikes","x":700.0},{"kind":"rising","x":1830.0}]
    return [{"kind":"crumble","x":700.0},{"kind":"rising","x":1830.0}]

func _reset_traps() -> void:
    for trap: Node2D in traps:
        if is_instance_valid(trap):
            trap.call("reset")

func _on_trap_warning() -> void:
    trap_notice_time=1.7

func _on_trap_hit() -> void:
    if player==null or not player.enabled:
        return
    player.respawn()
    trap_notice_time=2.6

func _create_world() -> void:
    var bg_name: String = str(info.get("background","street"))
    # Solid fallback behind the full panorama ensures no empty/black void.
    var atmosphere: ColorRect = ColorRect.new()
    atmosphere.name = "WorldBackdrop"
    atmosphere.position = Vector2.ZERO
    atmosphere.size = Vector2(WIDTH, 540.0)
    atmosphere.color = Color(0.045,0.065,0.105)
    atmosphere.mouse_filter = Control.MOUSE_FILTER_IGNORE
    atmosphere.z_index = -24
    add_child(atmosphere)

    var bg: Sprite2D = Sprite2D.new()
    bg.name = "ChapterPanorama"
    bg.texture = load("res://assets/panoramas/"+bg_name+".jpg") as Texture2D
    bg.position = Vector2(1440.0,270.0)
    bg.z_index = -20
    add_child(bg)
    backgrounds.append(bg)

    var floor_texture: Texture2D = load("res://assets/floors/"+bg_name+".png") as Texture2D
    var wall_texture: Texture2D = load("res://assets/floors/"+bg_name+"_boundary.png") as Texture2D
    var has_gap: bool = bool(info.get("gap",false))
    var trap_specs: Array[Dictionary] = _trap_specs()
    var holes: Array[Vector2] = []
    if has_gap:
        holes.append(Vector2(1120.0,1300.0))
    for spec: Dictionary in trap_specs:
        if str(spec.get("kind","")) == "crumble":
            var cx: float = float(spec.get("x",700.0))
            holes.append(Vector2(cx-62.0,cx+62.0))
    holes.sort_custom(func(a: Vector2,b: Vector2) -> bool: return a.x<b.x)
    var cursor: float=0.0
    for hole: Vector2 in holes:
        if hole.x>cursor:
            _floor_segment(floor_texture,cursor,hole.x)
        cursor=maxf(cursor,hole.y)
    if cursor<WIDTH:
        _floor_segment(floor_texture,cursor,WIDTH)
    if has_gap:
        var abyss: Sprite2D = Sprite2D.new()
        abyss.name = "VisibleChasm"
        abyss.texture = load("res://assets/floors/chasm.png") as Texture2D
        abyss.position = Vector2(1210.0,FLOOR+54.0)
        abyss.z_index = -5
        add_child(abyss)
        var bridge: StaticBody2D = _ground(
            Vector2(1210.0,FLOOR+190.0),Vector2(180.0,380.0),"TimeBridge"
        )
        bridge_collision = bridge.get_child(0) as CollisionShape2D
        bridge_floor = _visual_floor(floor_texture,1120.0,1300.0)
        bridge_floor.name = "VisibleTimeBridge"
        bridge_floor.modulate = Color(0.82,0.94,1.0,1.0)

    _world_boundary(-15.0,"Left",wall_texture)
    _world_boundary(WIDTH+15.0,"Right",wall_texture)
    _create_echo_gate()

    marker = MARKER.new()
    add_child(marker)
    player = HERO.new()
    player.hero_id = hero_id
    player.position = Vector2(175.0,FLOOR)
    player.checkpoint = player.position
    player.can_rewind = true
    add_child(player)
    player.respawned.connect(_reset_traps)
    # Each route has the same collision rules, but a different trap combination.
    for spec: Dictionary in trap_specs:
        var trap: Variant = TRAP.new()
        trap.kind = str(spec.get("kind","spikes"))
        trap.position = Vector2(float(spec.get("x",700.0)),FLOOR)
        trap.floor_texture = floor_texture
        trap.player = player
        add_child(trap)
        trap.player_hit.connect(_on_trap_hit)
        trap.warning.connect(_on_trap_warning)
        traps.append(trap)

    var cast: Array = info.get("cast",[])
    var index: int = 0
    for value: Variant in cast:
        var identity: String = str(value)
        if not State.HERO_IDS.has(identity) or (identity==hero_id and State.route!="finale"):
            continue
        var side_actor = NPC.new()
        side_actor.character_id = identity
        side_actor.position = Vector2(1770.0+float(index)*290.0,FLOOR)
        add_child(side_actor)
        actors[identity] = side_actor
        side_actor.visible = identity!=hero_id
        index+=1
    if State.route=="finale":
        for identity: String in State.HERO_IDS:
            if identity==hero_id or actors.has(identity):
                continue
            var friend=NPC.new()
            friend.character_id=identity
            friend.position=Vector2(1780.0+float(actors.size())*265.0,FLOOR)
            add_child(friend)
            actors[identity]=friend
    _set_period("present")

# A physical temporal lock; jumping and ordinary dialogue cannot bypass it.
# The player approaches the closed seam, then must actually rewind their
# movement to a position before its appearance. Q remains required by
# period-locked encounters and the time bridge in later chapters.
func _create_echo_gate() -> void:
    echo_gate=_ground(Vector2(1075.0,184.0),Vector2(70.0,650.0),"RewindOnlyGate")
    echo_gate_shape=echo_gate.get_child(0) as CollisionShape2D
    # The fracture is created only when the hero approaches the old timeline.
    echo_gate_shape.disabled=true
    echo_gate_visual=ColorRect.new()
    echo_gate_visual.name="TemporalSeam"
    echo_gate_visual.position=Vector2(1045.0,-95.0)
    echo_gate_visual.size=Vector2(60.0,555.0)
    echo_gate_visual.color=Color(0.56,0.39,0.21,0.64)
    echo_gate_visual.mouse_filter=Control.MOUSE_FILTER_IGNORE
    echo_gate_visual.z_index=-2
    add_child(echo_gate_visual)
    echo_gate_visual.hide()
    for i: int in range(5):
        var stripe: ColorRect=ColorRect.new()
        stripe.position=Vector2(4.0+float(i%2)*14.0,17.0+float(i)*97.0)
        stripe.size=Vector2(33.0,3.0)
        stripe.color=Color(0.94,0.73,0.45,0.84)
        stripe.mouse_filter=Control.MOUSE_FILTER_IGNORE
        echo_gate_visual.add_child(stripe)

func _open_echo_gate(show_feedback: bool=true) -> void:
    if echo_gate_open:
        return
    echo_gate_open=true
    if echo_gate_shape!=null:
        echo_gate_shape.set_deferred("disabled",true)
    if echo_gate_visual!=null:
        echo_gate_visual.hide()
    if show_feedback:
        _show_impact(State.word("gate_opened"),3.2)

func _check_echo_gate() -> void:
    if echo_gate_open or player==null:
        return
    if not echo_gate_armed and player.position.x>=900.0:
        echo_gate_armed=true
        echo_gate_shape.set_deferred("disabled",false)
        echo_gate_visual.show()
    if echo_gate_armed and player.rewinding and player.position.x<=765.0:
        _open_echo_gate()

func _intro_with_history() -> Array:
    var result: Array=info.get("intro",[]).duplicate(true)
    var branch: Dictionary=info.get("intro_branch",{})
    var stored: String=str(State.decisions.get(str(branch.get("key","")),""))
    var variations: Dictionary=branch.get("outcomes",{})
    if variations.has(stored):
        result.append_array((variations[stored] as Array).duplicate(true))
    if State.chapter!=3 or State.route=="finale":
        return result
    var entry: Dictionary={}
    if hero_id=="yuri":
        if str(State.decisions.get("yuri_family","later"))=="stay":
            entry={"speaker":"yuri","text":{"hy":"Այդ երեկո ես գոնե նստեցի մորս կողքին։ Հիշում եմ նրա ձայնը։","ru":"В тот вечер я всё-таки сел рядом с мамой. Помню её голос.","en":"I did sit with Mom that evening. I still remember her voice."}}
        else:
            entry={"speaker":"yuri","text":{"hy":"Ես նորից ասացի՝ «մի րոպեից»։ Հիմա այդ բառերը ուրիշ կերպ են հնչում։","ru":"Я опять сказал «через минуту». Теперь эти слова звучат иначе.","en":"I said 'in a minute' again. The words sound different now."}}
    elif hero_id=="garnik":
        if str(State.decisions.get("garnik_truth","hide"))=="honest":
            entry={"speaker":"garnik","text":{"hy":"Ես արդեն մի անգամ ասել եմ, որ ծանր է։ Աշխարհը չփլվեց։","ru":"Я уже однажды сказал, что мне тяжело. И мир не рухнул.","en":"I told someone I was struggling. The world didn’t end."}}
        else:
            entry={"speaker":"garnik","text":{"hy":"Ես նորից ասացի՝ «լավ եմ»։ Թե ինչու՝ մինչ հիմա չեմ հասկանում։","ru":"Я снова сказал «всё хорошо». До сих пор не знаю зачем.","en":"I said 'I'm fine' again. I still don’t know why."}}
    elif hero_id=="suren":
        if str(State.decisions.get("suren_departure","postpone"))=="tell":
            entry={"speaker":"suren","text":{"hy":"Ես ընկերներիս ասել եմ մեկնելու մասին։ Դժվար էր, բայց թեթևացա։","ru":"Я сказал друзьям об отъезде. Было трудно, но стало легче.","en":"I told my friends I was leaving. It was hard, but I felt lighter."}}
        else:
            entry={"speaker":"suren","text":{"hy":"Տոմսը ցույց չտվեցի։ Կարծես լռելով հնարավոր էր պահը կանգնեցնել։","ru":"Я не показал билет. Как будто молчание могло остановить время.","en":"I hid the ticket. As if silence could stop time."}}
    if not entry.is_empty():
        result.insert(1,entry)
    return result

func _safe_x(target: float) -> float:
    if bool(info.get("gap",false)) and target>1110.0 and target<1310.0:
        return 1060.0 if target<1210.0 else 1355.0
    return clampf(target,62.0,WIDTH-62.0)

func _create_hud() -> void:
    var layer: CanvasLayer = CanvasLayer.new()
    add_child(layer)
    hud=Control.new()
    hud.size=Vector2(960,540)
    layer.add_child(hud)
    var top_bar: ColorRect = ColorRect.new()
    top_bar.size=Vector2(960,83)
    top_bar.color=Color(0.014,0.024,0.045,0.91)
    top_bar.mouse_filter=Control.MOUSE_FILTER_IGNORE
    hud.add_child(top_bar)
    hud_portrait=UI.texture(hud,"res://assets/characters/"+hero_id+"_emotion_neutral.png",Vector2(13,6),Vector2(65,70))
    chapter_text=UI.label(hud,"",Vector2(90,7),Vector2(603,27),18,UI.GOLD)
    chapter_text.autowrap_mode=TextServer.AUTOWRAP_OFF
    chapter_text.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
    active_name=UI.label(hud,"",Vector2(90,32),Vector2(600,20),13,UI.MUTED)
    active_name.autowrap_mode=TextServer.AUTOWRAP_OFF
    active_name.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
    task_text=UI.label(hud,"",Vector2(90,55),Vector2(610,26),14,UI.PALE)
    task_text.autowrap_mode=TextServer.AUTOWRAP_OFF
    task_text.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
    hint_text=UI.label(hud,"",Vector2(90,95),Vector2(780,37),16,UI.GOLD)
    hint_text.max_lines_visible=2
    hint_text.clip_text=true
    clock_text=UI.label(hud,"03:17",Vector2(713,13),Vector2(125,31),23,UI.PALE)
    clock_text.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
    UI.button(hud,"☰",Vector2(904,15),Vector2(43,35),func() -> void: _pause_open())
    UI.button(hud,"J",Vector2(852,15),Vector2(43,35),func() -> void: _notes_open())
    if State.route=="finale":
        UI.button(hud,"TAB",Vector2(852,53),Vector2(94,29),func() -> void: _switch_hero())

    # A speaker lives on each side; the center contains only short dialogue.
    dialog_panel=UI.box(hud,Vector2(22,352),Vector2(916,176),Color(0.018,0.030,0.052,0.98),Color(0.46,0.39,0.29))
    dialog_portrait=UI.texture(dialog_panel,"res://assets/characters/yuri_emotion_neutral.png",Vector2(12,20),Vector2(95,111))
    dialog_other_portrait=UI.texture(dialog_panel,"res://assets/characters/garnik_emotion_neutral.png",Vector2(806,20),Vector2(95,111))
    dialog_left_name=UI.label(dialog_panel,"",Vector2(12,140),Vector2(149,25),13,UI.MUTED)
    dialog_right_name=UI.label(dialog_panel,"",Vector2(799,140),Vector2(101,25),12,UI.MUTED)
    dialog_right_name.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
    dialog_right_name.autowrap_mode=TextServer.AUTOWRAP_OFF
    dialog_right_name.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
    dialog_name=UI.label(dialog_panel,"",Vector2(123,15),Vector2(665,30),18,UI.GOLD)
    dialog_name.autowrap_mode=TextServer.AUTOWRAP_OFF
    dialog_text=UI.label(dialog_panel,"",Vector2(123,47),Vector2(664,88),17,UI.PALE)
    dialog_text.max_lines_visible=4
    dialog_text.clip_text=true
    # The arrow is icon-only: no long "Next / Следующий" label to overflow.
    dialog_button=UI.button(dialog_panel,"",Vector2(720,130),Vector2(64,42),func() -> void: _advance_dialogue())
    dialog_button.icon=load("res://assets/ui/next_arrow.png") as Texture2D
    dialog_button.icon_alignment=HORIZONTAL_ALIGNMENT_CENTER
    dialog_button.expand_icon=true
    dialog_button.tooltip_text=State.word("next")
    dialog_panel.hide()

    choose_panel=UI.box(hud,Vector2(139,121),Vector2(682,405),Color(0.021,0.034,0.060,0.99),UI.GOLD)
    choose_title=UI.label(choose_panel,"",Vector2(25,16),Vector2(631,75),18,UI.GOLD)
    choose_title.max_lines_visible=3
    choose_title.clip_text=true
    for idx: int in range(3):
        var chosen: int=idx
        var b: Button=UI.button(choose_panel,"",Vector2(25,102+idx*89),Vector2(632,81),func() -> void: _choose(chosen))
        b.add_theme_font_size_override("font_size",15)
        b.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
        b.clip_text=true
        b.alignment=HORIZONTAL_ALIGNMENT_LEFT
        choose_buttons.append(b)
    choose_panel.hide()

    impact_panel=UI.box(hud,Vector2(211,86),Vector2(538,42),Color(0.027,0.044,0.060,0.96),Color(0.47,0.56,0.45))
    impact_label=UI.label(impact_panel,"",Vector2(12,7),Vector2(514,30),14,UI.PALE)
    impact_label.autowrap_mode=TextServer.AUTOWRAP_OFF
    impact_label.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
    impact_panel.hide()
    # A modal document viewer: paper is CLIPPED INSIDE its own frame.
    # The dark backdrop prevents underlying HUD and scene text from appearing
    # through the document, and the caption sits OUTSIDE the document image.
    artifact_backdrop=ColorRect.new()
    artifact_backdrop.position=Vector2.ZERO
    artifact_backdrop.size=Vector2(960,540)
    artifact_backdrop.color=Color(0.008,0.013,0.024,0.83)
    artifact_backdrop.mouse_filter=Control.MOUSE_FILTER_STOP
    hud.add_child(artifact_backdrop)
    artifact_backdrop.hide()
    artifact_panel=UI.box(hud,Vector2(147,17),Vector2(666,505),Color(0.027,0.042,0.072,1.0),UI.GOLD)
    artifact_panel.clip_contents=true
    artifact_title=UI.label(artifact_panel,"",Vector2(32,17),Vector2(600,40),22,UI.GOLD)
    artifact_title.autowrap_mode=TextServer.AUTOWRAP_OFF
    artifact_title.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
    var document_border: Panel=UI.box(artifact_panel,Vector2(30,65),Vector2(606,353),Color(0.015,0.023,0.041,1.0),Color(0.45,0.39,0.33,1.0))
    document_border.clip_contents=true
    artifact_paper_clip=Control.new()
    artifact_paper_clip.position=Vector2(8,7)
    artifact_paper_clip.size=Vector2(590,338)
    artifact_paper_clip.clip_contents=true
    document_border.add_child(artifact_paper_clip)
    artifact_picture=UI.texture(artifact_paper_clip,"res://assets/memories/family_note.jpg",Vector2.ZERO,Vector2(590,338))
    artifact_picture.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
    artifact_picture.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    artifact_picture.clip_contents=true
    artifact_paper_header=UI.label(artifact_paper_clip,"",Vector2(64,24),Vector2(431,26),15,Color("#6c4532"))
    artifact_paper_header.autowrap_mode=TextServer.AUTOWRAP_OFF
    artifact_paper_header.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
    artifact_paper_header.mouse_filter=Control.MOUSE_FILTER_IGNORE
    artifact_paper_text=UI.label(artifact_paper_clip,"",Vector2(64,72),Vector2(468,234),19,Color("#3e302b"))
    artifact_paper_text.max_lines_visible=7
    artifact_paper_text.clip_text=true
    artifact_paper_text.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
    artifact_paper_text.mouse_filter=Control.MOUSE_FILTER_IGNORE
    artifact_caption=UI.label(artifact_panel,"",Vector2(31,426),Vector2(428,65),16,UI.PALE)
    artifact_caption.max_lines_visible=3
    artifact_caption.clip_text=true
    UI.button(artifact_panel,State.word("close"),Vector2(475,448),Vector2(161,43),func() -> void: _artifact_close())
    artifact_panel.hide()
    puzzle_panel=UI.box(hud,Vector2(272,112),Vector2(416,410),Color(0.026,0.043,0.077,0.99),UI.GOLD)
    UI.label(puzzle_panel,State.word("code_title"),Vector2(29,14),Vector2(362,37),22,UI.GOLD)
    puzzle_display=UI.label(puzzle_panel,"_ _ _",Vector2(35,64),Vector2(345,56),42,UI.PALE)
    puzzle_message=UI.label(puzzle_panel,State.word("code_hint"),Vector2(27,120),Vector2(355,57),17,UI.MUTED)
    for n: int in range(9):
        var digit: String=str(n+1)
        var column: int=n%3
        var row: int=int(n/3)
        UI.button(puzzle_panel,digit,Vector2(35+column*121,195+row*55),Vector2(103,46),func() -> void: _puzzle_digit(digit))
    UI.button(puzzle_panel,"0",Vector2(156,362),Vector2(103,39),func() -> void: _puzzle_digit("0"))
    puzzle_panel.hide()
    notes_panel=UI.box(hud,Vector2(178,72),Vector2(604,418),Color(0.026,0.042,0.072,0.98),UI.GOLD)
    UI.label(notes_panel,State.word("journal"),Vector2(20,17),Vector2(548,36),25,UI.GOLD)
    notes_scroll=ScrollContainer.new()
    notes_scroll.position=Vector2(21,68)
    notes_scroll.size=Vector2(557,276)
    notes_panel.add_child(notes_scroll)
    notes_label=UI.label(notes_scroll,"",Vector2.ZERO,Vector2(532,500),16,UI.PALE)
    UI.button(notes_panel,State.word("close"),Vector2(417,359),Vector2(164,41),func() -> void: _notes_close())
    notes_panel.hide()
    pause_panel=UI.box(hud,Vector2(303,160),Vector2(354,300),Color(0.027,0.043,0.075,0.99),UI.GOLD)
    UI.label(pause_panel,State.word("pause"),Vector2(35,24),Vector2(284,45),26,UI.GOLD)
    UI.button(pause_panel,State.word("continue"),Vector2(30,87),Vector2(291,45),func() -> void: _pause_close())
    UI.button(pause_panel,State.word("restart"),Vector2(30,148),Vector2(291,45),func() -> void: State.restart_chapter())
    UI.button(pause_panel,State.word("menu"),Vector2(30,209),Vector2(291,45),func() -> void: _back_to_menu())
    pause_panel.hide()
    _touch("◀","move_left",Vector2(12,476))
    _touch("▶","move_right",Vector2(72,476))
    _touch("↑","jump",Vector2(650,476))
    _touch("E","interact",Vector2(710,476))
    _touch("R","rewind",Vector2(770,476))
    _touch("Q","time_shift",Vector2(830,476))
    _set_touch_visibility()
    _set_emotion("neutral")
    _update_hud()

func _touch(label: String, action: String, pos: Vector2) -> void:
    var b: Button=UI.button(hud,label,pos,Vector2(52,49),func() -> void: pass)
    b.modulate.a=0.82
    b.button_down.connect(func() -> void: Input.action_press(action))
    b.button_up.connect(func() -> void: Input.action_release(action))
    b.mouse_exited.connect(func() -> void: Input.action_release(action))
    touch_buttons.append(b)

func _set_touch_visibility() -> void:
    var allow: bool=State.show_touch or DisplayServer.is_touchscreen_available()
    var hidden: bool=in_dialogue or in_choice or in_artifact or in_puzzle or in_notes or in_pause
    if hint_text!=null:
        hint_text.visible=not hidden and impact_seconds<=0.0
    if hidden and marker!=null:
        marker.near=false
    for button: Button in touch_buttons:
        button.visible=allow and not hidden
        if hidden:
            button.release_focus()

func _update_hud() -> void:
    var count: int=steps.size()
    var title: String=State.text(info.get("title",{}))
    var section: String=State.word("finale") if State.route=="finale" else State.word("chapter")+" "+str(State.chapter+1)+" / 4"
    chapter_text.text=section+" · "+title
    UI.fit_label(chapter_text,18,14)
    active_name.text=State.hero_name(hero_id)+"  ·  "+State.text(info.get("subtitle",{}))
    UI.fit_label(active_name,13,12)
    if step_index<count:
        var active: Dictionary=steps[step_index]
        task_text.text=State.word("scene")+" "+str(step_index+1)+" / "+str(count)+" · "+State.text(active.get("label",{}))
    else:
        task_text.text=State.word("complete")
    UI.fit_label(task_text,14,12)
    clock_text.text="03:17" if period=="present" else "03:17 ↶"

func _place_marker() -> void:
    if marker==null:
        return
    if step_index>=steps.size():
        marker.active=false
        marker.near=false
    else:
        marker.active=true
        marker.near=false
        var current: Dictionary=steps[step_index]
        marker.position=Vector2(float(current.get("x",200.0)),FLOOR-56.0)
        marker.configure(_object_kind(current))
    _update_hud()

func _object_kind(step: Dictionary) -> String:
    var caption: String=State.text(step.get("label",{})).to_lower()
    var visual_id: String=str(step.get("visual",""))
    if str(step.get("object_kind",""))=="puzzle":
        return "console"
    if step.get("kind","")=="puzzle" or "реле" in caption or "код" in caption or "mechanism" in caption:
        return "console"
    if "двер" in caption or "выход" in caption or "door" in caption:
        return "door"
    if "билет" in caption or "ticket" in caption or visual_id=="old_ticket":
        return "ticket"
    if "час" in caption or "clock" in caption:
        return "clock"
    if "телефон" in caption or "сообщ" in caption or "звон" in caption or "phone" in caption:
        return "phone"
    if "голос" in caption or "запис" in caption or "ради" in caption or "кассет" in caption or visual_id=="recorder":
        return "recorder"
    if "фото" in caption or "сним" in caption or visual_id=="three_friends":
        return "photo"
    if "письм" in caption or "записк" in caption or visual_id=="family_note":
        return "letter"
    return "keepsake"

func _process(delta: float) -> void:
    if exit_requested or info.is_empty():
        return
    blocked_until=maxf(0.0,blocked_until-delta)
    if impact_seconds>0.0:
        impact_seconds=maxf(0.0,impact_seconds-delta)
        if impact_seconds<=0.0 and impact_panel!=null:
            impact_panel.hide()
            _set_touch_visibility()
    _check_echo_gate()
    trap_notice_time=maxf(0.0,trap_notice_time-delta)
    if player!=null and player.rewinding:
        _reset_traps()
    if in_dialogue:
        if blocked_until<=0.0 and Input.is_action_just_pressed("interact"):
            _advance_dialogue()
        return
    if in_artifact:
        if blocked_until<=0.0 and (Input.is_action_just_pressed("interact") or Input.is_action_just_pressed("cancel")):
            _artifact_close()
        return
    if in_puzzle or in_choice:
        return
    if in_notes:
        if Input.is_action_just_pressed("journal") or Input.is_action_just_pressed("cancel"):
            _notes_close()
        return
    if in_pause:
        if Input.is_action_just_pressed("cancel"):
            _pause_close()
        return
    if Input.is_action_just_pressed("cancel"):
        _pause_open()
        return
    if Input.is_action_just_pressed("journal"):
        _notes_open()
        return
    if Input.is_action_just_pressed("restart"):
        State.restart_chapter()
        return
    if State.route=="finale" and Input.is_action_just_pressed("switch_hero"):
        _switch_hero()
    if bool(info.get("shift",false)) and Input.is_action_just_pressed("time_shift"):
        _set_period("past" if period=="present" else "present")
        player.clear_history()
        _reset_traps()
    if step_index>=steps.size():
        return
    var current: Dictionary=steps[step_index]
    var target_x: float=float(current.get("x",200.0))
    var near: bool=absf(player.position.x-target_x)<72.0
    var required_period: String=str(current.get("period",""))
    var required_hero: String=str(current.get("requires_hero",""))
    var period_ok: bool=required_period=="" or required_period==period
    var hero_ok: bool=required_hero=="" or required_hero==hero_id
    if marker!=null:
        marker.near=near and not (in_dialogue or in_choice or in_artifact or in_puzzle or in_notes or in_pause)
        marker.locked=not (hero_ok and period_ok)
    var old_hint: String=hint_text.text
    if not echo_gate_open and echo_gate_armed and player.position.x>770.0 and player.position.x<1235.0:
        hint_text.text=State.word("gate_rewind")
    elif trap_notice_time>0.0:
        hint_text.text=State.word("trap_tip" if player.can_rewind else "trap_tip_start")
    elif near:
        if not period_ok:
            hint_text.text=State.word("shift")+" · "+State.word(required_period)
        elif not hero_ok:
            hint_text.text=State.word("switch")+" · "+State.hero_name(required_hero)
        else:
            hint_text.text=State.word("press")+" "+State.text(current.get("label",{}))
    else:
        hint_text.text=State.text(info.get("hint",{}))
    if old_hint != hint_text.text:
        UI.fit_label(hint_text,16,13)
    if near and period_ok and hero_ok and Input.is_action_just_pressed("interact") and blocked_until<=0.0:
        _begin_step(current)
    if player.rewinding:
        clock_text.text="03:17 ◀"
    elif period=="past":
        clock_text.text="03:17 ↶"
    else:
        clock_text.text="03:17"

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo:
        var key_event: InputEventKey = event as InputEventKey
        var code: int = key_event.keycode
        if in_choice and code>=KEY_1 and code<=KEY_3:
            _choose(code-KEY_1)
            get_viewport().set_input_as_handled()
        elif in_puzzle and code>=KEY_0 and code<=KEY_9:
            _puzzle_digit(str(code-KEY_0))
            get_viewport().set_input_as_handled()

func _set_period(value: String) -> void:
    period=value
    for bg: Sprite2D in backgrounds:
        bg.modulate=Color(1.0,0.83,0.63) if period=="past" else Color.WHITE
    if bridge_collision!=null:
        bridge_collision.set_deferred("disabled",period!="past")
    if bridge_floor!=null:
        bridge_floor.visible=period=="past"
    if chapter_text!=null:
        _update_hud()

func _begin_step(current: Dictionary) -> void:
    active_beats=(current.get("beats",[]) as Array).duplicate(true)
    beat_index=0
    current_beat={}
    player.enabled=false
    _release_movement()
    artifact_first=false
    if str(current.get("visual",""))!="":
        artifact_first=true
        _artifact_open(current)
    else:
        _begin_encounter()

func _begin_encounter() -> void:
    var current: Dictionary=steps[step_index]
    var key: String=str(current.get("reacts_to",""))
    var selected: String=str(State.decisions.get(key,""))
    var reaction: Dictionary=current.get("reaction",{})
    var opening: Array=[]
    if reaction.has(selected):
        opening.append(reaction[selected])
    if not opening.is_empty():
        _start_lines(opening,"encounter_open")
    else:
        _begin_beat()

func _begin_beat() -> void:
    if beat_index>=active_beats.size():
        _complete_step()
        return
    current_beat=active_beats[beat_index]
    current_choice=current_beat.get("choice",{})
    var lines: Array=(current_beat.get("lines",[]) as Array).duplicate(true)
    var branch: Dictionary=current_beat.get("branch_response",{})
    var selected: String=str(State.decisions.get(str(branch.get("key","")),""))
    var outcomes: Dictionary=branch.get("outcomes",{})
    if outcomes.has(selected):
        lines.append_array((outcomes[selected] as Array).slice(0,1))
    _start_lines(lines,"beat")

func _beat_done() -> void:
    beat_index+=1
    _begin_beat()

func _show_impact(message: String, duration: float=4.5) -> void:
    if impact_label==null or impact_panel==null:
        return
    impact_label.text=message
    UI.fit_label(impact_label,14,12)
    impact_seconds=duration
    if hint_text!=null:
        hint_text.hide()
    impact_panel.show()
    impact_panel.move_to_front()

func _choice_impact(effect: Dictionary) -> String:
    var bond: int=int(effect.get("bond",0))
    var insight: int=int(effect.get("insight",0))
    var parts: PackedStringArray=PackedStringArray()
    if bond>0:
        parts.append(State.word("trust_up")+" +"+str(bond))
    elif bond<0:
        parts.append(State.word("trust_down")+" "+str(bond))
    if insight>0:
        parts.append(State.word("clue_up")+" +"+str(insight))
    elif insight<0:
        parts.append(State.word("clue_down")+" "+str(insight))
    if parts.is_empty():
        return State.word("choice_changes")
    return "  ·  ".join(parts)

func _start_lines(messages: Array, mode: String) -> void:
    dialogue_lines=messages.duplicate(true)
    dialogue_index=0
    dialogue_page=0
    dialogue_chunks=PackedStringArray()
    after_dialogue=mode
    if dialogue_lines.is_empty():
        _after_lines()
        return
    in_dialogue=true
    if marker != null:
        marker.near=false
    player.enabled=false
    _release_movement()
    dialog_panel.show()
    choose_panel.hide()
    _render_line()
    _set_touch_visibility()
    blocked_until=0.25

# Long speeches are split on word boundaries so the speaker stays visible.
func _page_text(text: String, max_chars: int=112) -> PackedStringArray:
    var result: PackedStringArray=PackedStringArray()
    var current: String=""
    for word: String in text.split(" ",false):
        if current.length()>0 and current.length()+word.length()+1>max_chars:
            result.append(current)
            current=word
        else:
            current=word if current=="" else current+" "+word
    if current!="":
        result.append(current)
    if result.is_empty():
        result.append("")
    return result

func _infer_emotion(text: String) -> String:
    var lower: String=text.to_lower()
    if "!" in text or "зачем" in lower or "кто это" in lower or "ո՞վ" in text:
        return "surprised"
    if "злюсь" in lower or "не трогай" in lower or "хватит" in lower or "angry" in lower:
        return "angry"
    if "прости" in lower or "потер" in lower or "стыд" in lower or "скуча" in lower or "sad" in lower or "ափսոս" in text:
        return "sad"
    if "спасибо" in lower or "рад" in lower or "together" in lower or "happy" in lower:
        return "happy"
    if "?" in text or "՞" in text:
        return "surprised"
    return "neutral"

func _portrait_texture(person: String, mood: String) -> Texture2D:
    var path: String="res://assets/characters/"+person+"_emotion_"+mood+".png"
    if not ResourceLoader.exists(path):
        path="res://assets/characters/"+person+"_emotion_neutral.png"
    return load(path) as Texture2D

func _set_emotion(mood: String) -> void:
    if hud_portrait!=null:
        var atlas: AtlasTexture=AtlasTexture.new()
        atlas.atlas=_portrait_texture(hero_id,mood)
        atlas.region=Rect2(51.0,3.0,86.0,82.0)
        hud_portrait.texture=atlas

func _render_line() -> void:
    if dialogue_index>=dialogue_lines.size():
        return
    var message: Dictionary=dialogue_lines[dialogue_index]
    var speaker: String=str(message.get("speaker","narrator"))
    var known: Dictionary={"mom":{"hy":"ՄԱՅՐԻԿ","ru":"МАМА","en":"MOM"},"narrator":{"hy":"ՀԻՇՈՂՈՒԹՅՈՒՆ","ru":"ВОСПОМИНАНИЕ","en":"MEMORY"},"voice":{"hy":"ՁԱՅՆԱԳՐՈՒԹՅՈՒՆ","ru":"ГОЛОС","en":"RECORDING"}}
    if State.HERO_IDS.has(speaker):
        dialog_name.text=State.hero_name(speaker)
    else:
        dialog_name.text=State.text(known.get(speaker, {"hy":speaker,"ru":speaker,"en":speaker}))
    var spoken: String=State.text(message.get("text",{}))
    dialogue_chunks=_page_text(spoken)
    dialogue_page=clampi(dialogue_page,0,dialogue_chunks.size()-1)
    dialog_text.text=dialogue_chunks[dialogue_page]
    UI.fit_label(dialog_text,17,14)
    var mood: String=str(message.get("emotion",_infer_emotion(spoken)))
    if speaker==hero_id:
        _set_emotion(mood)
    else:
        _set_emotion("neutral")
    dialog_left_name.text=State.hero_name(hero_id)
    dialog_portrait.texture=_portrait_texture(hero_id,mood if speaker==hero_id else "neutral")
    dialog_portrait.modulate.a=1.0 if speaker==hero_id else 0.54
    if State.HERO_IDS.has(speaker) and speaker!=hero_id:
        dialog_other_portrait.texture=_portrait_texture(speaker,mood)
    elif speaker=="mom":
        dialog_other_portrait.texture=load("res://assets/characters/mom_portrait.png") as Texture2D
    elif speaker=="voice":
        dialog_other_portrait.texture=load("res://assets/interactables/recorder.png") as Texture2D
    else:
        dialog_other_portrait.texture=load("res://assets/interactables/clock.png") as Texture2D
    dialog_right_name.text=State.text(known.get(speaker,{"hy":speaker,"ru":speaker,"en":speaker})) if speaker!=hero_id else ""
    dialog_other_portrait.modulate.a=1.0 if speaker!=hero_id else 0.35
    dialog_name.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT if speaker!=hero_id else HORIZONTAL_ALIGNMENT_LEFT
    UI.fit_label(dialog_name,18,14)
    UI.fit_label(dialog_left_name,13,12)
    UI.fit_label(dialog_right_name,12,12)
    dialog_button.tooltip_text=State.word("close") if dialogue_index>=dialogue_lines.size()-1 and dialogue_page>=dialogue_chunks.size()-1 else State.word("next")
    player.set_talking(speaker==hero_id)
    for identity: String in actors.keys():
        actors[identity].set_talking(identity==speaker)

func _advance_dialogue() -> void:
    if not in_dialogue or blocked_until>0.0:
        return
    if dialogue_page+1<dialogue_chunks.size():
        dialogue_page+=1
        dialog_text.text=dialogue_chunks[dialogue_page]
        UI.fit_label(dialog_text,17,14)
        dialog_button.tooltip_text=State.word("close") if dialogue_index>=dialogue_lines.size()-1 and dialogue_page>=dialogue_chunks.size()-1 else State.word("next")
        blocked_until=0.12
        return
    dialogue_index+=1
    dialogue_page=0
    if dialogue_index<dialogue_lines.size():
        _render_line()
        blocked_until=0.12
        return
    dialog_panel.hide()
    in_dialogue=false
    player.set_talking(false)
    for identity: String in actors.keys():
        actors[identity].set_talking(false)
    _after_lines()

func _after_lines() -> void:
    var kind: String=after_dialogue
    after_dialogue=""
    if kind=="encounter_open":
        _begin_beat()
    elif kind=="beat":
        if not current_choice.is_empty():
            _choice_open()
        elif str(current_beat.get("kind",""))=="puzzle":
            _puzzle_open()
        else:
            _beat_done()
    elif kind=="choice_result":
        _beat_done()
    elif kind=="outro":
        exit_requested=true
        State.finish_chapter()
    else:
        player.enabled=true
        _set_touch_visibility()

func _choice_open() -> void:
    in_choice=true
    player.enabled=false
    choose_panel.show()
    _set_emotion("surprised")
    choose_title.text=State.text(current_choice.get("question",{}))
    UI.fit_label(choose_title,18,15)
    var options: Array=current_choice.get("options",[])
    for i: int in range(3):
        choose_buttons[i].visible=i<options.size()
        if i<options.size():
            var option: Dictionary=options[i]
            choose_buttons[i].text=str(i+1)+". "+State.text(option.get("label",{}))+"\n"+_choice_impact(option.get("effect",{}))
    _set_touch_visibility()

func _choose(index: int) -> void:
    if not in_choice:
        return
    var options: Array=current_choice.get("options",[])
    if index<0 or index>=options.size():
        return
    var selected: Dictionary=options[index]
    State.remember(str(current_choice.get("key","choice")),str(selected.get("value","")),selected.get("effect",{}))
    _show_impact(State.word("effect_label")+" · "+_choice_impact(selected.get("effect",{})))
    _set_emotion(str(selected.get("emotion","neutral")))
    current_choice.clear()
    in_choice=false
    choose_panel.hide()
    _start_lines(selected.get("result",[]),"choice_result")

func _artifact_path(name: String) -> String:
    if name=="":
        return "res://assets/memories/family_note.jpg"
    return "res://assets/memories/"+name+".jpg"

func _artifact_open(current: Dictionary) -> void:
    in_artifact=true
    player.enabled=false
    artifact_panel.show()
    var visual_id: String=str(current.get("visual","family_note"))
    artifact_picture.texture=load(_artifact_path(visual_id)) as Texture2D
    artifact_picture.size=Vector2(590,338)
    artifact_picture.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    var is_letter: bool=visual_id=="family_note"
    artifact_title.text=State.word("letter") if is_letter else State.word("memory") if visual_id=="three_friends" else State.word("record") if visual_id=="recorder" else State.word("document")
    artifact_paper_header.visible=is_letter
    artifact_paper_text.visible=is_letter
    if is_letter:
        artifact_paper_header.text=State.word("handwritten_note")
        artifact_paper_text.text=State.text(current.get("paper_text", current.get("caption",{})))
    UI.fit_label(artifact_title,22,17)
    UI.fit_label(artifact_paper_header,15,12)
    UI.fit_label(artifact_paper_text,19,14)
    artifact_caption.text=State.text(current.get("caption",{}))
    UI.fit_label(artifact_caption,16,13)
    artifact_backdrop.show()
    artifact_panel.move_to_front()
    _set_touch_visibility()
    blocked_until=0.28

func _artifact_close() -> void:
    if not in_artifact or blocked_until>0.0:
        return
    in_artifact=false
    artifact_panel.hide()
    artifact_backdrop.hide()
    if artifact_first:
        artifact_first=false
        _begin_encounter()
    else:
        _complete_step()

func _puzzle_open() -> void:
    in_puzzle=true
    player.enabled=false
    puzzle_input=""
    puzzle_panel.show()
    puzzle_message.text=State.word("code_found") if int(State.insights.get(hero_id,0))>=2 else State.word("code_hint")
    UI.fit_label(puzzle_message,17,13)
    puzzle_display.text="_ _ _"
    _set_touch_visibility()

func _puzzle_digit(value: String) -> void:
    if not in_puzzle:
        return
    puzzle_input+=value
    puzzle_display.text = puzzle_input + " ".repeat(maxi(0, 3 - puzzle_input.length()))
    var expected: String=str(current_beat.get("code","317"))
    if puzzle_input.length()>=expected.length():
        if puzzle_input==expected:
            puzzle_panel.hide()
            in_puzzle=false
            _beat_done()
        else:
            puzzle_message.text=State.word("wrong")
            UI.fit_label(puzzle_message,17,13)
            puzzle_input=""
            puzzle_display.text="_ _ _"

func _complete_step() -> void:
    if step_index>=steps.size():
        return
    var finished: Dictionary=steps[step_index]
    step_index+=1
    State.save_step(step_index,finished.get("label",{}))
    player.checkpoint=Vector2(_safe_x(player.position.x),FLOOR)
    player.clear_history()
    blocked_until=0.30
    _place_marker()
    _set_touch_visibility()
    player.enabled=true
    if step_index>=steps.size():
        _start_lines(info.get("outro",[]),"outro")

func _notes_open() -> void:
    if in_dialogue or in_choice or in_artifact or in_puzzle:
        return
    in_notes=true
    player.enabled=false
    _release_movement()
    var key: String=State.route+":"+str(State.chapter)
    var list: Array=State.clues.get(key,[])
    var result: String=State.word("no_clues") if list.is_empty() else ""
    for i: int in range(list.size()):
        result+=str(i+1)+". "+State.text(list[i])+"\n"
    notes_label.text=result
    var height_needed: float=maxf(480.0,float(list.size())*66.0)
    # ScrollContainer measures its direct child: the safe clipping frame.
    var text_frame: Control=notes_label.get_parent() as Control
    text_frame.custom_minimum_size=Vector2(530.0,height_needed)
    text_frame.size=Vector2(530.0,height_needed)
    notes_label.custom_minimum_size=Vector2(530.0,height_needed)
    notes_label.size=Vector2(530.0,height_needed)
    notes_label.set_meta("safe_height",height_needed)
    UI.fit_label(notes_label,16,14)
    notes_panel.show()
    _set_touch_visibility()

func _notes_close() -> void:
    in_notes=false
    notes_panel.hide()
    player.enabled=true
    _set_touch_visibility()

func _pause_open() -> void:
    if in_dialogue or in_choice or in_artifact or in_puzzle or in_notes:
        return
    in_pause=true
    player.enabled=false
    _release_movement()
    pause_panel.show()
    _set_touch_visibility()

func _pause_close() -> void:
    in_pause=false
    pause_panel.hide()
    player.enabled=true
    _set_touch_visibility()

func _back_to_menu() -> void:
    _release_movement()
    get_tree().change_scene_to_file("res://scenes/menu.tscn")

func _release_movement() -> void:
    for action: String in ["move_left","move_right","jump","run","rewind","time_shift"]:
        Input.action_release(action)

func _switch_hero() -> void:
    if State.route!="finale" or in_dialogue or in_choice or in_artifact or in_puzzle:
        return
    var idx: int=State.HERO_IDS.find(hero_id)
    hero_id=State.HERO_IDS[(idx+1)%3]
    player.configure(hero_id)
    _set_emotion("neutral")
    for identity: String in actors.keys():
        actors[identity].visible=identity!=hero_id
    player.clear_history()
    _update_hud()
    blocked_until=0.20
