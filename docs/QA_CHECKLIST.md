# First-play QA checklist

- [ ] Launch in Godot 4.7.2 with zero red **Parser Error** entries.
- [ ] Start in Armenian on a fresh `user://last_minute_v06.json` save.
- [ ] Change language: Russian → English → Armenian; title, tasks, choices, dialogue and photo captions change.
- [ ] Select each of Yuri, Garnik and Suren: all three genuinely move using 8-frame sprites, with `Shift` run, jump and turn.
- [ ] Watch that the player keeps its feet on the ground and cannot escape left/right boundaries or drop endlessly.
- [ ] Across the entire 2,560 px world, background never leaves a blank screen or shows repeated clock towers.
- [ ] In Yuri chapter 1, press E near the first photograph: it opens full-size before the dialogue and closes on E.
- [ ] During dialogue, only the lower panel is shown and arms/heads remain visible above it.
- [ ] In Gar/Suren speaking scenes, NPC talk gestures animate while their lines are active.
- [ ] In chapters with broken bridge, changing to the past via Q restores the bridge collision.
- [ ] Rewind R affects movement for up to 15 seconds but not choices, objectives or story events.
- [ ] Puzzle code 317 accepts correct input (keyboard or buttons) and does not advance on wrong input.
- [ ] Exit to main menu, reopen the game and resume from an autosaved step.
- [ ] Complete four chapters per hero; only then is the finale available.
- [ ] In the finale use TAB to switch characters and Q to shift time, complete all seven interactions.
- [ ] Confirm endings after both choices, and make sure no other scene can be triggered prematurely.
- [ ] Export Web and test inside itch.io's embed and fullscreen, with mobile landscape touch buttons enabled.

Keep a copy of the **first** red error line in Godot if an error occurs; later errors often cascade from one failed script.
