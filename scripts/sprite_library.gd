extends RefCounted
## Frame atlas construction: fixed regions preserve feet placement across poses.
static func build(character_id: String) -> SpriteFrames:
    var frames: SpriteFrames = SpriteFrames.new()
    for animation_name: String in ["idle","walk","run","jump","fall","talk","rewind"]:
        frames.add_animation(animation_name)
    var base: String = "res://assets/characters/" + character_id
    var still: Texture2D = load(base + "_idle.png") as Texture2D
    if still == null:
        return frames
    var jump_texture: Texture2D = still
    if ResourceLoader.exists(base + "_jump.png"):
        jump_texture = load(base + "_jump.png") as Texture2D
    for n: int in range(4):
        frames.add_frame("idle", still)
    frames.set_animation_speed("idle", 2.0)
    frames.set_animation_loop("idle", true)
    var atlas: Texture2D = load(base + "_walk_8.png") as Texture2D
    if atlas != null:
        for i: int in range(8):
            var region: AtlasTexture = AtlasTexture.new()
            region.atlas = atlas
            region.region = Rect2(float(i*256),0.0,256.0,380.0)
            frames.add_frame("walk",region)
            frames.add_frame("run",region)
            frames.add_frame("rewind",region)
    else:
        frames.add_frame("walk",still)
        frames.add_frame("run",still)
        frames.add_frame("rewind",still)
    frames.set_animation_speed("walk",10.0)
    frames.set_animation_speed("run",16.0)
    frames.set_animation_speed("rewind",16.0)
    for animation_name: String in ["walk","run","rewind"]:
        frames.set_animation_loop(animation_name,true)
    frames.add_frame("jump",jump_texture)
    frames.add_frame("fall",jump_texture)
    frames.set_animation_loop("jump",false)
    frames.set_animation_loop("fall",false)
    var talk_path: String = base + "_talk_4.png"
    if ResourceLoader.exists(talk_path):
        var talk_atlas: Texture2D = load(talk_path) as Texture2D
        for j: int in range(4):
            var region: AtlasTexture = AtlasTexture.new()
            region.atlas = talk_atlas
            region.region = Rect2(float(j*256),0.0,256.0,380.0)
            frames.add_frame("talk",region)
    else:
        frames.add_frame("talk",still)
    frames.set_animation_speed("talk",5.0)
    frames.set_animation_loop("talk",true)
    return frames
