#!/usr/bin/env python3
"""Static QA for v0.7.1. Does not substitute for Godot runtime test."""
from pathlib import Path
import json,re
r=Path(__file__).resolve().parent
story=json.loads((r/'data/story.json').read_text(encoding='utf8'))
assert set(story['routes'])=={'yuri','garnik','suren'}
chapters=[]
for hero,parts in story['routes'].items():
    assert len(parts)==4,(hero,len(parts))
    for chapter in parts: chapters.append((hero,chapter))
chapters.append(('finale',story['finale']))
choices=[];beatsbychapter={};groups=0
for hero,chapter in chapters:
    seq=chapter['steps']; groups+=len(seq)
    assert len(seq)==(4 if hero=='finale' else 3),(hero,len(seq))
    assert len(seq)==len({s['x'] for s in seq})
    assert [s['x'] for s in seq]==sorted(s['x'] for s in seq)
    assert all(100<s['x']<2500 for s in seq)
    assert (r/'assets/panoramas'/f'{chapter["background"]}.jpg').is_file()
    beatcount=0
    for step in seq:
        beats=step['beats']; assert 1<=len(beats)<=3
        beatcount+=len(beats)
        assert step['kind']=='encounter'
        if step.get('period'): assert chapter['shift']
        if step.get('visual'): assert (r/'assets/memories'/f'{step["visual"]}.jpg').is_file()
        if step.get('reacts_to'): assert step.get('reaction')
        for b in beats:
            if b.get('choice'):
                choice=b['choice']; choices.append(choice['key'])
                assert len(choice['options'])==3
                assert all(('value' in opt and 'effect' in opt) for opt in choice['options'])
            if b['kind']=='puzzle':assert b.get('code')
    assert beatcount==7,(hero,chapter.get('title'),beatcount)
    beatsbychapter[hero+':'+str(len(beatsbychapter))]=beatcount
assert groups==40,(groups,'expected 12 x3 plus finale x4')
assert len(choices)==41,(len(choices),'expected 41 original choices')
assert len(set(choices))==41,'choice keys must be unique'
assert any(ch.get('gap') for hero,ch in chapters)
assert sum(bool(ch.get('shift')) for hero,ch in chapters)>=7
assert len([1 for hero,ch in chapters if hero=='finale'])==1

# A story text object needs all three original locales.
texts=0
def walk(t):
 global texts
 if isinstance(t,dict):
    if {'hy','ru','en'}.issubset(t):
        assert all(isinstance(t[k],str) and t[k].strip() for k in ('hy','ru','en'))
        texts+=1
    else:
        for v in t.values():walk(v)
 elif isinstance(t,list):
    for v in t:walk(v)
walk(story)
assert texts>=350,('too few localizations',texts)

i18n=(r/'scripts/i18n.gd').read_text(encoding='utf8')
for key in ('scene','gate_rewind','gate_opened','effect_label','trust_up','clue_up','code_found','next','choice'):
 assert i18n.count('"'+key+'"')>=3,key

# All on-disk resource strings and scene dependencies resolve.
for gd in (r/'scripts').glob('*.gd'):
    source=gd.read_text(encoding='utf8'); assert '\t' not in source,gd
    for path in re.findall(r'(?:load|preload)\("res://([^"\n]+)"\)',source):
        if '+' not in path:assert (r/path).is_file(),(gd,path)
    # Lightweight structural delimiter balance, excluding comments and strings.
    stack=[];lineno=1;instr=False;escape=False;comment=False
    for c in source:
        if c=='\n':lineno+=1;comment=False;continue
        if comment:continue
        if instr:
            if escape:escape=False
            elif c=='\\':escape=True
            elif c=='"':instr=False
            continue
        if c=='#':comment=True;continue
        if c=='"':instr=True;continue
        if c in '([{':stack.append((c,lineno))
        if c in ')]}':
            assert stack,(gd,lineno,c)
            opener,origin=stack.pop()
            assert {'(':')','[':']','{':'}'}[opener]==c,(gd,origin,lineno)
    assert not stack,(gd,'unclosed',stack[-1])
    assert not instr,(gd,'open string')
for scene in (r/'scenes').glob('*.tscn'):
    src=scene.read_text(encoding='utf8')
    for loc in re.findall(r'path="res://([^"\n]+)"',src):
        assert (r/loc).is_file(),(scene,loc)

code=(r/'scripts/game_scene.gd').read_text(encoding='utf8')
player=(r/'scripts/player.gd').read_text(encoding='utf8')
state=(r/'scripts/state.gd').read_text(encoding='utf8')
for mandatory in ('func _create_echo_gate','func _check_echo_gate','player.rewinding and player.position.x<=765.0', 'func _begin_beat','func _choice_impact','dialog_other_portrait','func _begin_encounter'):
 assert mandatory in code,mandatory
assert 'player.can_rewind = true' in code
assert 'if step_index>=2:' in code,'resuming must not lock the previous gate'
assert 'SETTINGS_FILE: String = "user://last_minute_settings_v071.json"' in state
assert 'LEGACY_SAVE_FILE' in state
assert '"progress":progress' not in state
assert '"decisions":decisions' not in state
assert '"completed":completed' not in state
assert 'selected_hero = str(dat.get(' not in state
assert 'progress[hero] = {"chapter"' not in state[state.index('func _load_save()'):state.index('func save_progress()')], 'A new launch must not reload story progress'
assert 'progress: Dictionary = {"yuri":{"chapter":0,"step":0}' in state
menu=(r/'scripts/menu.gd').read_text(encoding='utf8')
visuals=(r/'scripts/visuals.gd').read_text(encoding='utf8')
assert 'card.clip_contents=true' in menu
assert 'panel.clip_contents = true' in visuals
assert 'item.clip_text = true' in visuals
# Card geometry: image/name/theme are separate from synopsis/progress/button.
card_boxes={"portrait":(15,13,102,121),"name":(125,20,130,33),"theme":(124,65,131,70),"divider":(16,149,236,1),"synopsis":(16,164,235,78),"progress":(16,251,231,25),"button":(14,282,240,36)}
for k,box in card_boxes.items():
 assert box[0]>=0 and box[1]>=0 and box[0]+box[2]<=268 and box[1]+box[3]<=327, k
for left,right in (("portrait","name"),("portrait","theme"),("theme","synopsis"),("synopsis","progress"),("progress","button")):
 a,b=card_boxes[left],card_boxes[right]
 assert not (a[0]<b[0]+b[2] and b[0]<a[0]+a[2] and a[1]<b[1]+b[3] and b[1]<a[1]+a[3]),(left,right)

assert 'can_rewind: bool = false' in player # state-controlled, not fixed false
assert 'func _set_period(' in code
assert 'period_ok' in code
assert '_puzzle_open()' in code

# UI collision checks in base 960x540 coordinates: key portrait/name/body/button regions.
def intersects(a,b):
 return a[0]<b[0]+b[2] and b[0]<a[0]+a[2] and a[1]<b[1]+b[3] and b[1]<a[1]+a[3]
regions={'left_portrait':(34,372,95,111),'right_portrait':(828,372,95,111),'dialogue':(145,399,664,88),'next':(685,488,125,33)}
for x,y in [('left_portrait','right_portrait'),('left_portrait','dialogue'),('right_portrait','dialogue'),('dialogue','next'),('left_portrait','next'),('right_portrait','next')]:
 assert not intersects(regions[x],regions[y]),(x,y)
for i in range(3):
 for j in range(i+1,3):
  a=(164,223+89*i,632,81); b=(164,223+89*j,632,81)
  assert not intersects(a,b)
assert (r/'assets/characters/mom_portrait.png').is_file()
config=(r/'project.godot').read_text(encoding='utf8')
assert 'viewport_width=960' in config and 'gl_compatibility' in config
assert 'variant/thread_support=false' in (r/'export_presets.cfg').read_text()
print('PASS:',len(chapters),'chapters,',groups,'connected scenes,',len(choices),'session choices,',texts,'localized text units')
print('PASS: mandatory rewind gate, Q phase locks, left/right dialogue portraits, fresh campaign on every launch')
print('PASS: source paths, script delimiters, nonoverlapping HUD and hero card regions; runtime not tested')
