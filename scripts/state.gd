extends Node
## Authoritative run state, language, and saving. No world geometry here.
const I18N = preload("res://scripts/i18n.gd")
# Old saves contain campaign progress and are used only to carry over settings.
const LEGACY_SAVE_FILE: String = "user://last_minute_v06.json"
const SETTINGS_FILE: String = "user://last_minute_settings_v071.json"
const HERO_IDS: Array[String] = ["yuri", "garnik", "suren"]
const CHAPTER_COUNT: int = 4
var book: Dictionary = {}
var language: String = "hy"
var volume: float = 0.6
var show_touch: bool = false
var route: String = ""
var chapter: int = 0
var selected_hero: String = "yuri"
var completed: Dictionary = {"yuri":false,"garnik":false,"suren":false}
var progress: Dictionary = {"yuri":{"chapter":0,"step":0},"garnik":{"chapter":0,"step":0},"suren":{"chapter":0,"step":0}}
var decisions: Dictionary = {}
var choice_effects: Dictionary = {}
var bonds: Dictionary = {"yuri":0,"garnik":0,"suren":0,"finale":0}
var insights: Dictionary = {"yuri":0,"garnik":0,"suren":0,"finale":0}
var clues: Dictionary = {}
var finale_done: bool = false
var audio: AudioStreamPlayer

func _ready() -> void:
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/story.json"))
    if typeof(parsed) == TYPE_DICTIONARY:
        book = parsed
    _bind("move_left", [KEY_A, KEY_LEFT])
    _bind("move_right", [KEY_D, KEY_RIGHT])
    _bind("jump", [KEY_SPACE, KEY_W, KEY_UP])
    _bind("run", [KEY_SHIFT])
    _bind("interact", [KEY_E, KEY_ENTER])
    _bind("rewind", [KEY_R])
    _bind("time_shift", [KEY_Q])
    _bind("restart", [KEY_T])
    _bind("switch_hero", [KEY_TAB])
    _bind("journal", [KEY_J])
    _bind("cancel", [KEY_ESCAPE])
    _load_save()
    audio = AudioStreamPlayer.new()
    var track: AudioStream = load("res://assets/audio/ambient.wav") as AudioStream
    if track != null:
        if track is AudioStreamWAV:
            var wav: AudioStreamWAV = track as AudioStreamWAV
            wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
        audio.stream = track
    add_child(audio)
    set_volume(volume)

func _bind(action: String, codes: Array) -> void:
    if not InputMap.has_action(action):
        InputMap.add_action(action)
    for key_code: int in codes:
        var key_event: InputEventKey = InputEventKey.new()
        key_event.physical_keycode = key_code
        if not InputMap.action_has_event(action, key_event):
            InputMap.action_add_event(action, key_event)

func word(key: String) -> String:
    return I18N.ui(key, language)

func text(value: Variant) -> String:
    return I18N.pick(value, language)

func set_language(lang: String) -> void:
    if lang in ["hy", "ru", "en"]:
        language = lang
        save_progress()

func set_volume(value: float) -> void:
    volume = clampf(value,0.0,1.0)
    if audio != null:
        audio.volume_db = -60.0 if volume < 0.015 else linear_to_db(volume) - 16.0
    save_progress()

func start_music() -> void:
    if audio != null and audio.stream != null and not audio.playing:
        audio.play()

# The story is a fresh playthrough every time the application is launched.
# We retain language, volume and touch controls, but never restore chapters,
# endings, decisions or route selection from previous launches.
func _load_save() -> void:
    var prefs_path: String = SETTINGS_FILE
    if not FileAccess.file_exists(prefs_path):
        prefs_path = LEGACY_SAVE_FILE
    if not FileAccess.file_exists(prefs_path):
        return
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(prefs_path))
    if typeof(parsed) != TYPE_DICTIONARY:
        return
    var data: Dictionary = parsed as Dictionary
    var saved_language: String = str(data.get("language", "hy"))
    if saved_language in ["hy", "ru", "en"]:
        language = saved_language
    volume = clampf(float(data.get("volume", 0.6)), 0.0, 1.0)
    show_touch = bool(data.get("show_touch", false))

# Many story events call this function to update in-memory progress. Only
# accessibility/audio preferences go to disk. Story progress stays in State
# until the game is completely closed, then starts anew at chapter 1.
func save_progress() -> void:
    var file: FileAccess = FileAccess.open(SETTINGS_FILE, FileAccess.WRITE)
    if file != null:
        file.store_string(JSON.stringify({
            "language": language,
            "volume": volume,
            "show_touch": show_touch
        }))

func start_route(hero: String, resume: bool = true) -> void:
    if not HERO_IDS.has(hero):
        return
    selected_hero = hero
    route = hero
    if resume and not bool(completed.get(hero, false)):
        chapter = int((progress[hero] as Dictionary).get("chapter",0))
    else:
        chapter = 0
        progress[hero] = {"chapter":0,"step":0}
    save_progress()
    start_music()
    get_tree().change_scene_to_file("res://scenes/game.tscn")

func current_step() -> int:
    if route == "finale":
        return 0
    if not HERO_IDS.has(route):
        return 0
    var slot: Dictionary = progress.get(route, {})
    return maxi(0, int(slot.get("step",0)))

func save_step(index: int, label: Variant) -> void:
    if HERO_IDS.has(route):
        progress[route] = {"chapter":chapter,"step":index}
        var clue_key: String = route + ":" + str(chapter)
        var arr: Array = clues.get(clue_key, [])
        if not arr.has(label):
            arr.append(label)
        clues[clue_key] = arr
        save_progress()

func restart_chapter() -> void:
    if HERO_IDS.has(route):
        progress[route] = {"chapter":chapter,"step":0}
        save_progress()
    get_tree().reload_current_scene()

func get_chapter_data() -> Dictionary:
    if route == "finale":
        return book.get("finale", {})
    if not HERO_IDS.has(route):
        return {}
    var records: Array = book.get("routes",{}).get(route,[])
    if chapter < 0 or chapter >= records.size():
        return {}
    return records[chapter]

func finish_chapter() -> void:
    if route == "finale":
        finale_done = true
        save_progress()
        get_tree().change_scene_to_file("res://scenes/ending.tscn")
        return
    if not HERO_IDS.has(route):
        return
    chapter += 1
    if chapter >= CHAPTER_COUNT:
        completed[route] = true
        progress[route] = {"chapter":CHAPTER_COUNT-1,"step":0}
        save_progress()
        get_tree().change_scene_to_file("res://scenes/ending.tscn")
    else:
        progress[route] = {"chapter":chapter,"step":0}
        save_progress()
        get_tree().change_scene_to_file("res://scenes/game.tscn")

func all_routes_done() -> bool:
    for hero: String in HERO_IDS:
        if not bool(completed.get(hero,false)):
            return false
    return true

func play_finale() -> void:
    if not all_routes_done():
        return
    route = "finale"
    chapter = 0
    start_music()
    get_tree().change_scene_to_file("res://scenes/game.tscn")

func remember(key: String, value: String, effect: Dictionary = {}) -> void:
    var identity: String = route if bonds.has(route) else "finale"
    var previous: Dictionary = choice_effects.get(key,{})
    # Undo the previous effect when replaying a chapter and changing an answer.
    if not previous.is_empty():
        var previous_hero: String = str(previous.get("hero",identity))
        bonds[previous_hero] = int(bonds.get(previous_hero,0))-int(previous.get("bond",0))
        insights[previous_hero] = int(insights.get(previous_hero,0))-int(previous.get("insight",0))
    bonds[identity] = int(bonds.get(identity,0))+int(effect.get("bond",0))
    insights[identity] = int(insights.get(identity,0))+int(effect.get("insight",0))
    choice_effects[key] = {"hero":identity,"bond":int(effect.get("bond",0)),"insight":int(effect.get("insight",0))}
    decisions[key] = value
    save_progress()

func hero_name(hero: String) -> String:
    var info: Dictionary = book.get("heroes",{}).get(hero,{})
    if language == "hy":
        return str(info.get("name",hero))
    if language == "en":
        return str(info.get("english",hero))
    return str(info.get("russian",hero))
