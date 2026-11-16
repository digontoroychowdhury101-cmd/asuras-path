# GitHub-assisted keyboard recovery

9 November 2026, Australia/Sydney. User explicitly requested GitHub repositories to resolve the input problem.

Repository: https://github.com/learncodebygaming/pydirectinput . Inspected its README and input implementation. Installed PyDirectInput 1.0.4 into ignored `work/roblox-input-diagnostic/vendor`, with a bounded diagnostic at `work/roblox-input-diagnostic/probe.py`. It checks that RobloxPlayerBeta.exe is foreground, allows only listed diagnostic keys, limits holds to two seconds and releases the held key in a finally block. No game scripts, process memory, drivers or security settings were changed.

Observed results:

- B held 0.25 seconds opened the equipment menu.
- B held 0.25 seconds closed it.
- S held 0.6 seconds moved the character away from the portal; portal framing receded and the interaction prompt disappeared. A contextual foe-warning caption appeared.

Keyboard control is now demonstrated. Earlier short presses through the original control API did not show these responses. This does not isolate whether scan codes or hold duration explains the difference. Camera steering, full combat controls and continuous six-hour play remain to be verified; these short diagnostics do not meet the requested playtime.

Equipment observation: upper row includes Equipment, Inventory, Quests, Map, Crafting, Settings, Status and Multiplayer. Equipment shows three equipped armour pieces at +0, four relic slots, four main-hand slots, four offhand slots, consumable grids, arrow slots and diamond quick consumables. Hair and helmet visibility toggles are present. Displayed item counts are not yet established as item capacity versus quantity.
