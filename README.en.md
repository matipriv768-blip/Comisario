<p align="center"><img src="docs/logo.png" width="220" alt="Comisario"></p>

# Comisario

A race steward for **Assetto Corsa**: a Custom Shaders Patch Lua app that watches track limits, contact, flags and penalties, offline against the AI and online with friends.

**[Versión en español](README.md)** (the full guide and the server instructions are in Spanish)

![On-screen interface](docs/interfaz.png)

## What it does

- **Track limits**: every off, or only cuts with an advantage (if you lift and lose speed, it does not count).
- **Contact graded** by speed difference: light touch, contact and heavy crash, with the car hitting from behind at fault.
- **Incident points** in the iRacing style, with a configurable maximum and disqualification above it.
- **Penalties**: time, lift off, drive-through, stop and go and disqualification, with a deadline in laps.
- **Giving the position back** after contact, an off-track overtake or an overtake under yellow.
- **Flags**: green, yellow, blue, white, chequered and black, plus full course yellow and red called by race control.
- **Standing or rolling start**: full formation lap or a short one (cars line up near the finish line), with a speed readout against the limit and green lights.
- **Sessions**: practice only counts, qualifying only invalidates the lap, races penalise.
- **AI** is watched too and serves penalties on track, if the track allows AI control.
- **Online**: each driver is watched by their own app and the apps report to each other. A race director sets the rules and flags for the whole server.
- **Spanish and English**, chosen in the settings.

## Requirements

- Assetto Corsa on PC with Content Manager.
- Custom Shaders Patch with Lua apps enabled. Tested with version 0.2.11.

## Install

1. Download `Comisario-1.5.0.zip` from the Releases section.
2. Drag it onto the Content Manager window and press "Install".
3. On track, open "Comisario" from the apps bar. The gear icon on the window opens the settings; pick **English** at the top.

Manual install: copy the `apps` folder into the game's `assettocorsa` folder.

## Server script (optional)

`servidor/comisario_servidor.lua` is an online script that the server hands to each driver. It enforces things by cutting the throttle: the formation speed, full course yellow and red flag speeds, and it sends a disqualified driver to the pits. Add `language = 'en'` to its options for English messages. Step by step instructions (in Spanish): [`servidor/INSTRUCCIONES_SERVIDOR.txt`](servidor/INSTRUCCIONES_SERVIDOR.txt).

## Project status and known limits

- Tested in game by its author in offline races and on a private server with one or two drivers. Not tested with large grids or on public servers.
- Disqualification does not kick anyone from the server and does not change the game's own results table.
- Everything runs on each driver's PC: the administrator key stops a regular driver, not someone who edits their own copy of the app.
- Online, every driver needs the app. Drivers without it are not watched.

## Development

The logic is tested outside the game with a simulator of the CSP API (`test/harness.lua`). You need Python 3 and the `lupa` package:

```
pip install lupa
python3 test/check_i18n.py apps/lua/Comisario/Comisario.lua
python3 test/run_tests.py apps/lua/Comisario/Comisario.lua
python3 test/run_online.py apps/lua/Comisario/Comisario.lua
python3 test/run_server.py servidor/comisario_servidor.lua
```

Texts are written in Spanish inside `tr('...')`; the English table `EN` is at the end of `Comisario.lua`. Adding a language means adding one more table like it. See [CONTRIBUTING.md](CONTRIBUTING.md) (Spanish).

## Credits

Created by Matías ([matipriv768-blip](https://github.com/matipriv768-blip)). The code and icons were made with assistance from Claude, by Anthropic; the logo was generated with Canva.

Comisario is an independent project. It is not affiliated with Real Penalty, iRacing, the FIA, Kunos Simulazioni or the authors of Custom Shaders Patch or Content Manager, and uses no code or files from those projects.

## License

[MIT](LICENSE).
