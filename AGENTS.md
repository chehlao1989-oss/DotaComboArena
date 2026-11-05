# Development notes

Godot 4.7.2 stable. Open app/project.godot; source lives in app/scripts and hero data in app/data.

Preserve scoring independently of cosmetic animations. Each valid key scores immediately; repeated attacks use one pending latch and must not reset the current native animation. Pause freezes the world. Profiles and records must remain compatible.

Run relevant app/tests scripts after changes. For font or UI changes also run run_layout_tests.gd with graphical rendering; inspect actual screenshots. A passing logic test does not establish visual animation quality.

Do not add game automation,global input hooks,network leaderboards or game-memory access without an explicit project decision. Keep third-party attribution and font licenses. Never apply the code MIT license to Valve materials. Do not commit personal profiles,secrets,engine binaries,build caches or raw game archives.
