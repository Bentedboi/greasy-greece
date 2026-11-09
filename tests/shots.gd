extends SceneTree
## Opens the real game in a window and saves screenshots of every screen. Run:
## Godot.exe --path <project> -s res://tests/shots.gd
## Images land in user://shots.

var main: Node


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://shots"))
	main = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	_run()


func _shot(file_name: String) -> void:
	for i in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	var path := "user://shots/%s.png" % file_name
	root.get_texture().get_image().save_png(path)
	print("saved ", ProjectSettings.globalize_path(path))


func _fast_forward(seconds: float) -> void:
	var b: Battle = main.battle
	var left := seconds
	b.autopilot = true
	while left > 0.0:
		if b.pending_boons > 0:
			var cards := Data.roll_boons(b.side, b.rng, b.owned)
			b.pending_boons -= 1
			b.boons_taken += 1
			b.apply_boon(String(cards[b.rng.randi() % cards.size()]["id"]))
		b.step(1.0 / 30.0)
		left -= 1.0 / 30.0


func _battle_at(side: int, r: int, extra_seconds: float, recruits: Dictionary) -> void:
	main.start_game(side)
	var b: Battle = main.battle
	b.running = false
	b.autopilot = true
	for key: String in recruits:
		for i in int(recruits[key]):
			b._recruit(key)
	b._flush_incoming()
	b.round_num = r - 1
	b.break_t = 0.0
	_fast_forward(extra_seconds)
	b.pending_boons = 0


func _run() -> void:
	await _shot("1_menu")

	_battle_at(Data.ATHENS, 2, 11.0, {"ranged": 3, "hoplite": 4})
	await _shot("2_athens_battle")

	main.battle.running = false
	main.battle.owned = {}
	main.state = "choose"
	main.choices = [Data.BOONS[0], Data.BOONS[16], Data.BOONS[21]]
	main.choose_delay = 0.0
	await _shot("3_cards")
	main.choices = [Data.BOONS[3], Data.GODS_BOON, Data.BOONS[8]]
	await _shot("4_cards_gods")
	main.state = "play"

	_battle_at(Data.SPARTA, 7, 16.0, {"elite": 3, "hoplite": 6, "ranged": 3})
	await _shot("5_sparta_late")

	main.battle.running = false
	main.battle.apply_boon(Data.GODS_ID)
	main.battle.step(0.05)
	await _shot("6_gods_strike")

	_battle_at(Data.ATHENS, 12, 7.0, {"elite": 4, "hoplite": 8, "ranged": 6})
	main.battle.apply_boon("tower")
	main.battle.apply_boon("oxybeles")
	var leo: Unit = main.battle.boss
	if leo != null:
		leo.pos = Vector2(760, 470)
		main.battle._boss_ability(leo)
		main.battle.step(0.4)
	await _shot("7_leonidas")

	_battle_at(Data.SPARTA, 12, 7.0, {"elite": 4, "hoplite": 6})
	var them: Unit = main.battle.boss
	if them != null:
		them.pos = Vector2(980, 470)
		them.abilities = ["barrage"]
		main.battle._boss_ability(them)
		them.abilities = ["ram"]
		main.battle._boss_ability(them)
		main.battle.step(0.5)
	await _shot("8_themistocles")

	main.battle.running = false
	main.battle.phase = "done"
	main._on_finished(true)
	await _shot("9_victory")
	main.state = "lost"
	await _shot("10_defeat")
	quit()
