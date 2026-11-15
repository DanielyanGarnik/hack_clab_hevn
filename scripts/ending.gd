extends Control
const UI = preload("res://scripts/visuals.gd")
func _ready() -> void:
    var final: bool = State.route=="finale"
    UI.fullscreen_image(self,"res://assets/backgrounds/rooftop.png" if final else "res://assets/backgrounds/street.png")
    var shade: ColorRect = ColorRect.new()
    shade.color=Color(0.017,0.029,0.057,0.8)
    shade.size=Vector2(960,540)
    add_child(shade)
    UI.box(self,Vector2(78,48),Vector2(803,445),Color(0.035,0.058,0.096,0.96))
    if final:
        _final_ending()
    else:
        _route_ending()

func _route_ending() -> void:
    UI.label(self,State.word("ending")+" · "+State.hero_name(State.route),Vector2(119,82),Vector2(701,59),29,UI.GOLD)
    var bond: int=int(State.bonds.get(State.route,0))
    var insight: int=int(State.insights.get(State.route,0))
    var lines: Dictionary = {
        "yuri": {
            "open":{"ru":"Юрий набрал мамин номер, а потом ответил друзьям. День не стал идеальным, зато больше не нужно было угадывать, когда найдётся время друг для друга.","en":"Yuri called his mother and then replied to his friends. The day was not perfect, but they stopped waiting for the right minute.","hy":"Յուրին զանգեց մայրիկին, հետո պատասխանեց ընկերներին։ Օրը կատարյալ չէր, բայց նրանք այլևս ճիշտ պահին չէին սպասում։"},
            "careful":{"ru":"Юрий собрал доказательства и восстановил хронику ночи. Но главным открытием оказался не архив: он всё-таки научился спрашивать, как дела у близких.","en":"Yuri pieced the night together. The most important discovery was learning to ask the people he loved how they felt.","hy":"Յուրին վերականգնեց գիշերվա դեպքերը։ Սակայն ամենակարևոր բացահայտումն այն էր, որ նա սովորեց լսել հարազատներին։"},
            "silent":{"ru":"Юрий вернулся домой, не исправив ни одного старого разговора. Он увидел непрочитанное сообщение и на этот раз не отложил ответ.","en":"Yuri came home without repairing old conversations. He found an unread message and chose not to delay the reply.","hy":"Յուրին տուն վերադարձավ՝ առանց հին զրույցները փոխելու։ Նա տեսավ չկարդացված հաղորդագրությունը և այս անգամ անմիջապես պատասխանեց։"}
        },
        "garnik": {
            "open":{"ru":"Гарник открыл письмо и попросил помощи. Его не оценивали и не перебивали. Исправлять всё в одиночку больше не было нужно.","en":"Garnik opened the letter and asked for help. No one judged him or interrupted. He no longer had to fix everything alone.","hy":"Գառնիկը բացեց նամակն ու օգնություն խնդրեց։ Նրան չդատեցին։ Այլևս ամեն ինչ միայնակ լուծելու կարիք չկար։"},
            "careful":{"ru":"Гарник проверил каждую запись и нашёл неисправность часов. А потом признал вслух, что даже точный расчёт не заменяет дружеского разговора.","en":"Garnik checked every record and found the fault in the clock. Then he admitted that even perfect calculations cannot replace a conversation.","hy":"Գառնիկը ստուգեց գրառումները և գտավ ժամացույցի անսարքությունը։ Ապա հասկացավ, որ նույնիսկ ճշգրիտ հաշվարկը չի փոխարինում զրույցին։"},
            "silent":{"ru":"Гарник снова сказал, что всё хорошо. Но дома он открыл черновик письма и впервые написал честно, что его беспокоит.","en":"Garnik said he was fine again. Back home, he opened his draft and finally wrote what had been troubling him.","hy":"Գառնիկը նորից ասաց՝ ամեն ինչ լավ է։ Բայց տանը բացեց նամակի սևագիրն ու առաջին անգամ անկեղծ գրեց իր մտահոգությունների մասին։"}
        },
        "suren": {
            "open":{"ru":"Сурен уехал, но друзья проводили его. В новом городе телефон зазвонил почти сразу: это был Юрий. Гарник уже предлагал встретиться на выходных.","en":"Suren left, but his friends saw him off. In the new city, Yuri called almost immediately, and Garnik was already planning a visit.","hy":"Սուրենը մեկնեց, բայց ընկերները ճանապարհեցին նրան։ Նոր քաղաքում Յուրին անմիջապես զանգեց, իսկ Գառնիկն արդեն հանդիպում էր պլանավորում։"},
            "careful":{"ru":"Сурен договорился о встрече перед отъездом. Они не давали вечных обещаний, просто решили поддерживать связь — и начали с первого звонка.","en":"Suren arranged one meeting before leaving. They made no grand promises, only a plan to stay in touch, starting with one call.","hy":"Սուրենը մեկնելուց առաջ հանդիպեց ընկերներին։ Նրանք մեծ խոստումներ չտվեցին, պարզապես պայմանավորվեցին կապը պահել։"},
            "silent":{"ru":"Сурен сел в поезд один. Он долго смотрел на старую фотографию, а потом отправил друзьям сообщение, которого раньше боялся.","en":"Suren boarded the train alone. He studied the old photo, then sent his friends the message he had feared writing.","hy":"Սուրենը միայնակ նստեց գնացք։ Նա երկար նայեց լուսանկարին, ապա ընկերներին ուղարկեց այն հաղորդագրությունը, որից վախենում էր։"}
        }
    }
    var arc: String="silent"
    if bond>=4:
        arc="open"
    elif insight>=4:
        arc="careful"
    var selected: Dictionary=(lines.get(State.route,{}) as Dictionary).get(arc,{})
    UI.label(self,State.text(selected),Vector2(119,157),Vector2(680,150),21,UI.PALE)
    UI.label(self,State.word("ending_sub"),Vector2(119,313),Vector2(571,63),18,UI.MUTED)
    var mood: String="sad"
    if arc=="open":
        mood="happy"
    elif arc=="careful":
        mood="surprised"
    UI.texture(self,"res://assets/characters/"+State.route+"_emotion_"+mood+".png",Vector2(710,289),Vector2(112,103))
    UI.button(self,State.word("ending_next"),Vector2(119,421),Vector2(440,45),func() -> void: get_tree().change_scene_to_file("res://scenes/menu.tscn"))
    var final_button: Button = UI.button(self,State.word("play_finale"),Vector2(579,421),Vector2(246,45),func() -> void: State.play_finale())
    final_button.disabled = not State.all_routes_done()

func _final_ending() -> void:
    var finish_type: String = str(State.decisions.get("final_decision","forward"))
    var forward: bool = finish_type=="forward"
    var together: bool = finish_type=="listen"
    UI.label(self,State.word("finale_a") if forward or together else State.word("finale_b"),Vector2(119,80),Vector2(689,73),34,UI.GOLD)
    var hopeful: Dictionary = {"hy":"Քաղաքում նորից լույս վառվեց։ Յուրին զանգեց տուն։ Գառնիկն ասաց, որ օգնություն է ուզում։ Սուրենը նստեց գնացք։\n\nՆրանցից ոչ մեկը չկարողացավ երեկը դարձնել կատարյալ։ Բայց երեքն էլ համաձայնեցին վաղը նորից խոսել։", "ru":"В городе снова загорелся свет. Юрий позвонил домой. Гарник попросил помощи. Сурен сел в поезд.\n\nНикто не сделал вчера идеальным. Зато все трое договорились завтра снова поговорить.", "en":"The city lights returned. Yuri called home. Garnik asked for help. Suren boarded his train.\n\nNone of them made yesterday perfect. But they agreed to talk again tomorrow."}
    var loop: Dictionary = {"hy":"Ժամացույցը նորից ցույց տվեց 03:17։ Քաղաքը լռեց։ Կամրջի քարերի վրա դարձյալ գրպանի ժամացույց կար։\n\nՍա արդեն ծանոթ սկիզբ էր։", "ru":"Часы снова показали 03:17. Город замолчал. На камнях у моста снова лежали карманные часы.\n\nЭто начало уже было знакомо.", "en":"The clock showed 03:17 again. The city fell silent. The pocket watch was back beside the bridge.\n\nThey knew this beginning by heart."}
    var together_text: Dictionary={"ru":"Никто не решает за всех. Они выходят из башни и сначала разговаривают — о семье, страхах и поезде, который Сурен ещё успеет поймать.\n\nЧасы продолжают идти. Ответов на все вопросы нет, но теперь никто не остаётся один.","en":"No one decides for the others. They leave the tower and finally talk about family, fear and Suren’s train.\n\nTime keeps moving. They do not have all the answers, but no one has to face them alone.","hy":"Ոչ ոք չի որոշում բոլորի փոխարեն։ Նրանք դուրս են գալիս աշտարակից ու վերջապես խոսում ընտանիքի, վախերի և Սուրենի գնացքի մասին։\n\nԺամանակն առաջ է գնում։ Բոլոր պատասխանները դեռ չկան, բայց նրանք միասին են։"}
    var ending_text: Dictionary=loop
    if together:
        ending_text=together_text
    elif forward:
        ending_text=hopeful
    UI.label(self,State.text(ending_text),Vector2(119,188),Vector2(691,191),22,UI.PALE)
    UI.button(self,State.word("menu"),Vector2(119,421),Vector2(346,45),func() -> void: get_tree().change_scene_to_file("res://scenes/menu.tscn"))
    UI.button(self,State.word("reset"),Vector2(486,421),Vector2(341,45),func() -> void: State.play_finale())
