# Browser release checklist — Godot 4.7.2 → itch.io

1. Open `project.godot` in the **standard non-.NET** Godot 4.7.2 editor, using **Compatibility (OpenGL)**.
2. Test all three routes in the editor, including a restart, the photo popup, code `317`, switching a time layer, save and re-open, and the shared finale.
3. Install export templates: **Editor → Manage Export Templates → Download and Install** for 4.7.2.
4. Go to **Project → Export → Web**. The included `export_presets.cfg` has `variant/thread_support=false`, the simplest choice for itch.io embedded frames.
5. Export to a directory with the main file named `index.html`, for example `export/web/index.html`. **Do not rename just the HTML file afterwards**; the engine's dependent filenames need to match.
6. Package all generated export files together in a ZIP, with `index.html` at the ZIP root. Don't upload the project's GDScript source ZIP as an HTML game.
7. On itch.io create/edit a game page → **Kind of project: HTML** → upload this *web build ZIP* → **This file will be played in the browser**.
8. For the embed set **960 × 540** at a minimum and provide fullscreen/expand, ideally with a responsive frame. On phones landscape is recommended. Test in Chrome/Firefox desktop and at least one phone browser.
9. In Settings inside the game, change language to Russian and English, close/reopen and confirm the language persists. The first launch of a clean browser begins in Armenian.
10. Test that no image, `.pck`, or save data is blocked by browser storage or mixed-content security.

Godot 4 browser exports use WebGL 2 and require the Compatibility renderer. The Web version is not a native mobile export and should be tested on real browsers. Screen adaptivity is through fixed 960x540 canvas scaled by Godot's canvas-items stretch and adaptive web canvas policy.
