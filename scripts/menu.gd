extends Control
const UI = preload("res://scripts/visuals.gd")
var page: String = "home"
var selected: String = "yuri"
var front: Control

func _ready() -> void:
    State.start_music()
    selected = State.selected_hero
    _build()

func _clear() -> void:
    for n: Node in get_children():
        remove_child(n)
        n.queue_free()

func _build() -> void:
    _clear()
    UI.fullscreen_image(self,"res://assets/backgrounds/street.png")
    var veil: ColorRect = ColorRect.new()
    veil.color = Color(0.012,0.024,0.05,0.69)
    veil.size = Vector2(960,540)
    veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(veil)
    front = Control.new()
    front.size = Vector2(960,540)
    add_child(front)
    if page=="home":
        _home()
    elif page=="select":
        _select_screen()
    elif page=="settings":
        _settings()
    else:
        _about()

func _go(value: String) -> void:
    page=value
    _build()

func _home() -> void:
    UI.box(front,Vector2(54,38),Vector2(488,465),Color(0.025,0.042,0.076,0.94))
    UI.label(front,"03:17",Vector2(86,69),Vector2(310,36),26,UI.GOLD)
    UI.label(front,State.word("title"),Vector2(83,119),Vector2(430,103),39,UI.PALE)
    UI.label(front,State.word("subtitle"),Vector2(84,232),Vector2(439,48),18,UI.MUTED)
    UI.button(front,State.word("start"),Vector2(86,302),Vector2(414,43),func() -> void: _go("select"))
    var continue_button: Button=UI.button(front,State.word("continue"),Vector2(86,354),Vector2(200,43),func() -> void: State.start_route(State.selected_hero,true))
    var last_slot: Dictionary=State.progress.get(State.selected_hero,{})
    continue_button.disabled=int(last_slot.get("chapter",0))==0 and int(last_slot.get("step",0))==0 and not bool(State.completed.get(State.selected_hero,false))
    var finale_button: Button = UI.button(front,State.word("finale"),Vector2(298,354),Vector2(202,43),func() -> void: State.play_finale())
    finale_button.disabled = not State.all_routes_done()
    UI.button(front,State.word("settings"),Vector2(86,411),Vector2(200,43),func() -> void: _go("settings"))
    UI.button(front,State.word("about"),Vector2(298,411),Vector2(202,43),func() -> void: _go("about"))
    UI.label(front,State.word("lock") if not State.all_routes_done() else State.word("all_done"),Vector2(583,422),Vector2(330,60),16,UI.PALE)
    # Faces are larger here for a deliberate sense of character, not generic icons.
    for idx: int in range(3):
        var who: String = State.HERO_IDS[idx]
        UI.texture(front,"res://assets/characters/"+who+"_portrait.png",Vector2(573+idx*110,214),Vector2(102,119))
    var heroes: Label=UI.label(front,State.hero_name("yuri")+"  ·  "+State.hero_name("garnik")+"  ·  "+State.hero_name("suren"),Vector2(574,350),Vector2(342,37),18,UI.GOLD)
    heroes.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
    heroes.autowrap_mode=TextServer.AUTOWRAP_OFF
    UI.fit_label(heroes,18,14)

# Three identical card layouts and short, localized hooks. The clipping
# viewport around every label makes different scripts visually consistent.
# Two complete, deliberately short lines per hero / language.
# They fit at 17 px in the 240 px content column; no ellipsis or clipped prose.
const CARD_COPY: Dictionary = {
    "yuri": {
        "hy": ["Ընտանիք · Լռութիւն", "Նա յետաձգեց զանգը։\nԺամանակը չի սպասում։"],
        "ru": ["Семья · Молчание", "Он снова отложил звонок.\nВремя не ждёт."],
        "en": ["Family · Silence", "He postponed the call.\nTime will not wait."]
    },
    "garnik": {
        "hy": ["Վախ · Վստահութիւն", "«Լաւ եմ»,— ասում էր նա։\nԲայց ո՞ւմ վստահել։"],
        "ru": ["Страх · Доверие", "Он говорил: «Всё хорошо».\nНо кому он доверится?"],
        "en": ["Fear · Trust", "He always said, “I’m fine.”\nWho can he trust?"]
    },
    "suren": {
        "hy": ["Ընկերութիւն · Մեկնում", "Գնացքը շուտով կը մեկնի։\nՆա դեռ հրաժեշտ չի տուել։"],
        "ru": ["Дружба · Отъезд", "Поезд скоро уедет.\nОн ещё не попрощался."],
        "en": ["Friendship · Goodbye", "The train leaves soon.\nHe has not said goodbye."]
    }
}

func _select_screen() -> void:
    UI.box(front,Vector2(31,23),Vector2(898,490),Color(0.028,0.046,0.084,0.96))
    var headline: Label=UI.label(front,State.word("select"),Vector2(60,44),Vector2(830,43),27,UI.GOLD)
    headline.autowrap_mode=TextServer.AUTOWRAP_OFF
    UI.fit_label(headline,27,22)
    for idx: int in range(3):
        var who: String=State.HERO_IDS[idx]
        var left: float=61.0+float(idx)*294.0
        var active: bool=who==selected
        var card: Panel=UI.box(front,Vector2(left,111),Vector2(268,331),Color(0.088,0.124,0.18,0.98) if active else Color(0.055,0.077,0.11,0.96))
        card.clip_contents=true
        UI.texture(card,"res://assets/characters/"+who+"_portrait.png",Vector2(74,7),Vector2(120,119))
        var who_name: Label=UI.label(card,State.hero_name(who),Vector2(14,128),Vector2(240,31),22,UI.GOLD)
        who_name.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
        who_name.autowrap_mode=TextServer.AUTOWRAP_OFF
        UI.fit_label(who_name,22,19)
        var copy: Array=CARD_COPY.get(who,{}).get(State.language,[])
        if copy.size()<2:
            copy=["", "\n"]
        var subtitle: Label=UI.label(card,str(copy[0]),Vector2(13,166),Vector2(242,25),16,UI.MUTED)
        subtitle.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
        subtitle.autowrap_mode=TextServer.AUTOWRAP_OFF
        UI.fit_label(subtitle,16,14)
        var separator: ColorRect=ColorRect.new()
        separator.position=Vector2(19,198)
        separator.size=Vector2(230,1)
        separator.color=Color(0.54,0.49,0.43,0.45)
        card.add_child(separator)
        # Each sentence is a real row with its own box. Never put two lines
        # in a horizontally clipped Label: that was the v0.7.2 regression.
        var lines: PackedStringArray=str(copy[1]).split("\n")
        for line_no: int in range(mini(2,lines.size())):
            var description: Label=UI.label(card,lines[line_no],Vector2(14,211+line_no*27),Vector2(240,25),17,UI.PALE)
            description.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
            description.autowrap_mode=TextServer.AUTOWRAP_OFF
            description.clip_text=false
            description.text_overrun_behavior=TextServer.OVERRUN_NO_TRIMMING
            UI.fit_label(description,17,15)
        var done: bool=bool(State.completed.get(who,false))
        var checkpoint: Dictionary=State.progress.get(who,{})
        var status: String=State.word("complete") if done else State.word("chapter")+" "+str(int(checkpoint.get("chapter",0))+1)+" / 4"
        var status_label: Label=UI.label(card,status,Vector2(14,274),Vector2(240,19),13,UI.MUTED)
        status_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
        status_label.autowrap_mode=TextServer.AUTOWRAP_OFF
        UI.fit_label(status_label,13,12)
        var resume: bool=not done and (int(checkpoint.get("chapter",0))>0 or int(checkpoint.get("step",0))>0)
        var play_button: Button=UI.button(card,State.word("resume") if resume else State.word("play"),Vector2(14,299),Vector2(240,32),func() -> void: State.start_route(who,true))
        play_button.add_theme_font_size_override("font_size",14)
    UI.button(front,State.word("back"),Vector2(661,460),Vector2(236,35),func() -> void: _go("home"))
    var finale_button: Button=UI.button(front,State.word("finale"),Vector2(61,460),Vector2(265,35),func() -> void: State.play_finale())
    finale_button.disabled=not State.all_routes_done()

func _settings() -> void:
    UI.box(front,Vector2(89,49),Vector2(782,443),Color(0.025,0.042,0.078,0.96))
    UI.label(front,State.word("settings"),Vector2(123,78),Vector2(685,48),30,UI.GOLD)
    UI.label(front,State.word("language"),Vector2(125,148),Vector2(300,33),21,UI.PALE)
    var languages: OptionButton = OptionButton.new()
    languages.position=Vector2(455,147)
    languages.size=Vector2(350,42)
    languages.add_item("Հայերեն",0)
    languages.add_item("Русский",1)
    languages.add_item("English",2)
    languages.select(["hy","ru","en"].find(State.language))
    languages.item_selected.connect(func(i: int) -> void: _language_changed(i))
    front.add_child(languages)
    UI.label(front,State.word("volume"),Vector2(125,224),Vector2(300,33),21,UI.PALE)
    var slider: HSlider = HSlider.new()
    slider.position=Vector2(455,228)
    slider.size=Vector2(340,25)
    slider.min_value=0.0
    slider.max_value=1.0
    slider.step=0.05
    slider.value=State.volume
    slider.value_changed.connect(func(value: float) -> void: State.set_volume(value))
    front.add_child(slider)
    var touch: CheckBox = CheckBox.new()
    touch.position=Vector2(125,295)
    touch.size=Vector2(675,40)
    touch.text=State.word("touch")
    touch.button_pressed=State.show_touch
    touch.toggled.connect(func(value: bool) -> void: _touch_changed(value))
    front.add_child(touch)
    UI.label(front,State.word("settings_hint"),Vector2(125,359),Vector2(680,50),17,UI.MUTED)
    UI.button(front,State.word("back"),Vector2(603,426),Vector2(203,42),func() -> void: _go("home"))

func _language_changed(i: int) -> void:
    var code: String = ["hy","ru","en"][i]
    State.set_language(code)
    _go("settings")

func _touch_changed(value: bool) -> void:
    State.show_touch=value
    State.save_progress()

func _about() -> void:
    UI.box(front,Vector2(93,47),Vector2(774,442),Color(0.029,0.049,0.09,0.96))
    UI.label(front,State.word("about"),Vector2(132,77),Vector2(683,44),29,UI.GOLD)
    UI.label(front,State.word("about_text"),Vector2(132,139),Vector2(672,154),19,UI.PALE)
    UI.label(front,State.word("tips"),Vector2(132,330),Vector2(674,85),16,UI.MUTED)
    UI.button(front,State.word("back"),Vector2(603,425),Vector2(203,39),func() -> void: _go("home"))
