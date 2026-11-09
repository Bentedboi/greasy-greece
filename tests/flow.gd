extends SceneTree
## Plays the real game through real input events, from menu to card pick. Run:
## Godot.exe --headless --path <project> -s res://tests/flow.gd

var failures := 0
var main: Node


func check(ok: bool, label: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + label)
	if not ok:
		failures += 1


func _initialize() -> void:
	main = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	_run()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _key(code: Key, pressed: bool = true) -> void:
	var e := InputEventKey.new()
	e.physical_keycode = code
	e.keycode = code
	e.pressed = pressed
	Input.parse_input_event(e)
	await _frames(3)


func _mouse(at: Vector2, pressed: bool = true) -> void:
	# Real clicks arrive in window coordinates, so convert from game coordinates.
	var window_at: Vector2 = root.get_final_transform() * at
	var m := InputEventMouseMotion.new()
	m.position = window_at
	m.global_position = window_at
	Input.parse_input_event(m)
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.position = window_at
	e.global_position = window_at
	e.pressed = pressed
	Input.parse_input_event(e)
	await _frames(3)


func _run() -> void:
	await _frames(3)
	check(main.state == "menu", "the game opens on the side-select menu")

	await _key(KEY_2)
	await _key(KEY_2, false)
	var b: Battle = main.battle
	check(main.state == "play" and b.side == Data.SPARTA, "pressing 2 chooses Sparta")
	await _frames(10)

	var start_pos: Vector2 = b.hero.pos
	await _key(KEY_D)
	await _frames(20)
	await _key(KEY_D, false)
	check(b.hero.pos.x > start_pos.x + 10.0, "holding D walks the hero right (moved %d px)" % int(b.hero.pos.x - start_pos.x))

	var before_y: float = b.hero.pos.y
	await _key(KEY_W)
	await _frames(20)
	await _key(KEY_W, false)
	check(b.hero.pos.y < before_y - 10.0, "holding W walks the hero up")

	var cooldown_before: float = b.dash_cd
	await _key(KEY_SPACE)
	await _key(KEY_SPACE, false)
	check(b.dash_cd > cooldown_before, "SPACE dashes")

	# Put an enemy on the spear and swing with a real mouse button.
	var foe := b._make_soldier(b.foe, "merc", 1)
	foe.pos = b.hero.pos + Vector2(50, 0)
	b._incoming.append(foe)
	b._flush_incoming()
	var kills_before := b.kills
	var coins_before := b.coins
	await _mouse(b.hero.pos + Vector2(50, -30))
	await _frames(10)
	await _mouse(b.hero.pos + Vector2(50, -30), false)
	# In a real window the hero follows the physical cursor, which this test can't move.
	if DisplayServer.get_name() == "headless":
		check(b.input_aim.distance_to(b.hero.pos + Vector2(50, -30)) < 60.0, "the mouse aims the hero (aim is %s, hero at %s)" % [str(b.input_aim), str(b.hero.pos)])
	check(b.kills > kills_before, "left click kills a mercenary in one strike")
	check(b.coins > coins_before or b.pending_boons > 0, "the kill pays coins")

	await _key(KEY_ESCAPE)
	await _key(KEY_ESCAPE, false)
	check(main.state == "pause" and not b.running, "ESC pauses")
	var frozen: float = b.time
	await _frames(10)
	check(is_equal_approx(frozen, b.time), "the battle stands still while paused")
	await _key(KEY_ESCAPE)
	await _key(KEY_ESCAPE, false)
	check(main.state == "play" and b.running, "ESC resumes")

	b._add_coins(float(b.coins_goal()))
	await _frames(3)
	check(main.state == "choose" and main.choices.size() == 3, "enough coins pops up three cards")
	check(not b.running, "the battle pauses while you choose")
	var taken := b.boons_taken
	await _mouse(main.ui.card_rect(1).get_center())
	await _mouse(main.ui.card_rect(1).get_center(), false)
	check(b.boons_taken == taken, "a click in the first moments is ignored, so held attacks can't mis-pick")
	await create_timer(0.6).timeout
	await _mouse(main.ui.card_rect(1).get_center())
	await _mouse(main.ui.card_rect(1).get_center(), false)
	check(b.boons_taken == taken + 1, "clicking a card takes that boon")
	check(main.state == "play" or main.state == "choose", "the game carries on after the pick")

	# Power of the Gods through the real card screen: the strike must play before more cards.
	b.pending_boons = 0
	main.state = "play"
	b.running = true
	await _frames(2)
	for i in 30:
		b._spawn_enemy("merc")
	b._flush_incoming()
	b._add_coins(float(b.coins_goal()))
	await _frames(3)
	main.choices = [Data.GODS_BOON, Data.BOONS[0], Data.BOONS[1]]
	await create_timer(0.6).timeout
	await _key(KEY_1)
	await _key(KEY_1, false)
	check(b.enemies.is_empty(), "picking Power of the Gods clears the map")
	check(main.state == "play", "no card screen covers the strike")
	check(b.spawn_speed() == 0.75, "spawn speed is now 0.75")

	# Lose: burn the city and land on the defeat screen.
	b.pending_boons = 0
	b.boon_hold = 0.0
	await _frames(2)
	b._damage_city(9999999.0)
	await create_timer(4.0).timeout
	check(main.state == "lost", "losing the city ends the game")
	await _key(KEY_ENTER)
	await _key(KEY_ENTER, false)
	check(main.state == "menu", "ENTER returns to the menu")
	await _key(KEY_1)
	await _key(KEY_1, false)
	check(main.state == "play" and b.side == Data.ATHENS and b.city_hp == b.city_max and b.kills == 0, "a new game as Athens starts fresh")

	print("\n%s: %d failure(s)" % ["ALL PASSED" if failures == 0 else "FAILED", failures])
	quit(1 if failures > 0 else 0)
