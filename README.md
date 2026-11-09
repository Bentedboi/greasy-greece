# Greasy Greece

Athens against Sparta, painted like an ancient Greek black-figure vase. Made in Godot 4.7, and everything is drawn and synthesized in code, so there are no image or audio files.

Choose your side and defend your city through 12 rounds. Every kill earns coins. Reach the coin goal and the Fates offer three boons, to grow your army, upgrade your weapons or strengthen your city. Each boon costs more than the last, and each round brings more enemies.

- **Athens:** weaker soldiers, but cheaper boons, better weapons and the Long Walls. Final boss: **King Leonidas**.
- **Sparta:** much stronger soldiers, but pricier boons and no real walls. Final boss: **Themistocles**.
- Enemies range from one-hit mercenaries to heavily armoured elites, and there are mini-bosses in rounds 4 and 8.
- One super rare boon, **Power of the Gods**, wipes every enemy off the map and slows spawning to 0.75 speed for 4 rounds.

## Controls

| Action | Key |
| --- | --- |
| Move | WASD or arrow keys |
| Aim | Mouse |
| Strike | Hold left click |
| Dash | Space |
| Pick a boon | Click, or press 1, 2 or 3 |
| Pause | Esc |
| Mute | M |

## Running

Open the folder in Godot 4.7 and press F5.

Tests (run from the command line):

```
godot --headless --path . -s res://tests/rules.gd      # the game's rules
godot --headless --path . -s res://tests/flow.gd       # real keyboard and mouse input
godot --headless --path . -s res://tests/sim.gd -- 10  # a bot plays 10 games per side
godot --path . -s res://tests/shots.gd                 # screenshots of every screen
```

Balance numbers are all in `scripts/data.gd`.
