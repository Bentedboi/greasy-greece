extends SceneTree
## A bot plays whole games to check balance and catch crashes. Run:
## Godot.exe --headless --path <project> -s res://tests/sim.gd -- <games per side>


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var games := int(args[0]) if args.size() > 0 else 3
	var battle := Battle.new()
	root.add_child(battle)
	var picker := RandomNumberGenerator.new()
	for side: int in [Data.ATHENS, Data.SPARTA]:
		var wins := 0
		for g in games:
			battle.start(side, 1000 + g)
			battle.running = false
			battle.autopilot = true
			picker.seed = 2000 + g
			var game_time := 0.0
			var best_allies := 0
			var deaths := 0
			var was_dead := false
			var hits_at_round := []
			var last_round := 0
			var started := Time.get_ticks_msec()
			while battle.phase != "done" and game_time < 3600.0:
				while battle.pending_boons > 0 and battle.phase != "ending":
					var cards := Data.roll_boons(side, battle.rng, battle.owned)
					var pick: Dictionary = cards[picker.randi() % cards.size()]
					battle.pending_boons -= 1
					battle.boons_taken += 1
					battle.apply_boon(String(pick["id"]))
				battle.step(1.0 / 30.0)
				game_time += 1.0 / 30.0
				best_allies = maxi(best_allies, battle.allies.size())
				if battle.hero.dead and not was_dead:
					deaths += 1
				was_dead = battle.hero.dead
				if battle.round_num != last_round:
					last_round = battle.round_num
					hits_at_round.append("%d:%d%%" % [last_round, int(battle.city_hp / battle.city_max * 100.0)])
			var won := battle.phase == "done" and battle.end_won
			if won:
				wins += 1
			print("%s game %d: %s round=%d time=%dm%02ds boons=%d kills=%d hero_deaths=%d peak_army=%d city=%d%% (ran in %.1fs)" % [
				Data.SIDES[side]["name"], g, "WON " if won else "LOST", battle.round_num, int(game_time) / 60, int(game_time) % 60,
				battle.boons_taken, battle.kills, deaths, best_allies, int(battle.city_hp / battle.city_max * 100.0),
				float(Time.get_ticks_msec() - started) / 1000.0])
			print("    city at start of each round: ", " ".join(PackedStringArray(hits_at_round)))
		print("%s wins: %d of %d\n" % [Data.SIDES[side]["name"], wins, games])
	battle.free()
	quit()
