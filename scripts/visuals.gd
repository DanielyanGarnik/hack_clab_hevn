extends RefCounted
## Small UI factory: one typographic and visual system for every scene.
const GOLD: Color = Color("#dec19a")
const PALE: Color = Color("#eee6d9")
const MUTED: Color = Color("#c7c0b6")
const INK: Color = Color("#0b1326")

static func box(parent: Node, pos: Vector2, sz: Vector2, tint: Color = Color(0.045, 0.07, 0.13, 0.92), border: Color = Color("#947b63")) -> Panel:
    var panel: Panel = Panel.new()
    panel.position = pos
    panel.size = sz
    # Never let a long localized child overflow into adjacent cards.
    panel.clip_contents = true
    var style: StyleBoxFlat = StyleBoxFlat.new()
    style.bg_color = tint
    style.border_color = border
    style.set_border_width_all(1)
    style.set_corner_radius_all(9)
    panel.add_theme_stylebox_override("panel", style)
    parent.add_child(panel)
    return panel

# All text lives in a dedicated clipping viewport. Godot can increase a
# Label's minimum size when localized text is long: that must never increase
# the visible text region or push into the neighboring card.
static func label(parent: Node, txt: String, pos: Vector2, sz: Vector2, font_size: int = 17, tint: Color = PALE) -> Label:
    var viewport: Control = Control.new()
    viewport.name = "SafeText"
    viewport.position = pos
    viewport.size = sz
    viewport.clip_contents = true
    viewport.mouse_filter = Control.MOUSE_FILTER_IGNORE
    parent.add_child(viewport)

    var item: Label = Label.new()
    item.position = Vector2.ZERO
    # Give Godot an explicit maximum width BEFORE assigning the text.
    # Otherwise long Cyrillic/Armenian lines can inflate Label's minimum width.
    item.custom_minimum_size = Vector2.ZERO
    item.custom_maximum_size = sz
    item.mouse_filter = Control.MOUSE_FILTER_IGNORE
    item.add_theme_font_size_override("font_size", font_size)
    item.add_theme_color_override("font_color", tint)
    item.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    # Do not trim a player's story with horizontal clipping / ellipses.
    # The safe container is the only clipping boundary.
    item.clip_text = false
    item.vertical_alignment = VERTICAL_ALIGNMENT_TOP
    item.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
    item.text = txt
    item.size = sz
    item.set_meta("safe_width", sz.x)
    item.set_meta("safe_height", sz.y)
    viewport.add_child(item)
    fit_label(item, font_size, maxi(12, font_size - 8))
    return item

# Re-fit after assigning any dynamic sentence (story, UI state, locale).
# Native font measurement respects Armenian, Cyrillic, English and linebreaks.
static func fit_label(item: Label, preferred: int = 17, minimum: int = 12) -> void:
    if item == null:
        return
    var font: Font = item.get_theme_font("font")
    if font == null:
        return
    var width: float = float(item.get_meta("safe_width", item.size.x))
    var height: float = float(item.get_meta("safe_height", item.size.y))
    var usable: float = maxf(8.0, width - 8.0)
    var candidate: int = preferred
    while candidate > minimum:
        var measured: Vector2
        if item.autowrap_mode == TextServer.AUTOWRAP_OFF:
            measured = font.get_string_size(item.text, HORIZONTAL_ALIGNMENT_LEFT, -1, candidate)
        else:
            measured = font.get_multiline_string_size(item.text, HORIZONTAL_ALIGNMENT_LEFT, usable, candidate)
        if measured.y <= height - 3.0 and measured.x <= usable + 1.0:
            break
        candidate -= 1
    item.add_theme_font_size_override("font_size", candidate)

static func button(parent: Node, txt: String, pos: Vector2, sz: Vector2, on_press: Callable) -> Button:
    var frame: Control = Control.new()
    frame.name = "SafeButton"
    frame.position = pos
    frame.size = sz
    frame.clip_contents = true
    parent.add_child(frame)
    var item: Button = Button.new()
    item.text = txt
    item.position = Vector2.ZERO
    item.size = sz
    item.clip_text = true
    item.add_theme_font_size_override("font_size", 16)
    item.add_theme_color_override("font_color", PALE)
    item.add_theme_color_override("font_hover_color", PALE)
    item.add_theme_constant_override("h_separation", 4)
    var style: StyleBoxFlat = StyleBoxFlat.new()
    style.bg_color = Color("#17243b")
    style.border_color = GOLD
    style.set_border_width_all(1)
    style.set_corner_radius_all(7)
    var hover: StyleBoxFlat = style.duplicate() as StyleBoxFlat
    hover.bg_color = Color("#35435e")
    item.add_theme_stylebox_override("normal", style)
    item.add_theme_stylebox_override("hover", hover)
    item.add_theme_stylebox_override("pressed", hover)
    frame.add_child(item)
    item.pressed.connect(on_press)
    return item

static func texture(parent: Node, path: String, pos: Vector2, sz: Vector2) -> TextureRect:
    var item: TextureRect = TextureRect.new()
    item.texture = load(path) as Texture2D
    item.position = pos
    item.size = sz
    item.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    item.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    item.mouse_filter = Control.MOUSE_FILTER_IGNORE
    parent.add_child(item)
    return item

static func fullscreen_image(parent: Node, path: String) -> TextureRect:
    var item: TextureRect = texture(parent, path, Vector2.ZERO, Vector2(960, 540))
    item.stretch_mode = TextureRect.STRETCH_SCALE
    return item
