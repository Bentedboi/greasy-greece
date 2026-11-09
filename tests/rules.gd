extends SceneTree
## Checks the rules from the game's brief. Run:
## Godot.exe --headless --path <project> -s res://tests/rules.gd

var failures := 0


func check(ok: bool, label: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + label)
	if not ok:
		failures += 1


func _initialize() -> void:
	# The price of boons and the number of enemies must both keep rising.
	var rising := true
	for n in range(0, 40):
		if Data.coins_needed(n + 1, Data.SPARTA) <= Data.coins_needed(n, Data.SPARTA):
			rising = false
	check(rising, "boon cost rises every time")
	var more := true
	for r in range(1, 12):
		var a := r
		var b := r + 1
		# Compare non-boss rounds only, since boss rounds trade numbers for the boss.
		if Data.boss_for_round(Data.ATHENS, a) == "" and Data.boss_for_round(Data.ATHENS, b) == "":
			if Data.enemy_count(b, Data.ATHENS) <= Data.enemy_count(a, Data.ATHENS):
				more = false
	check(more, "enemy count rises every round")

	# Athens gets boons more cheaply, and better ones more often.
	check(Data.coins_needed(5, Data.ATHENS) < Data.coins_needed(5, Data.SPARTA), "Athens' boons cost less than Sparta's")
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var tally := {Data.ATHENS: {"weapon": 0, "epic": 0}, Data.SPARTA: {"weapon": 0, "epic": 0}}
	for s: int in [Data.ATHENS, Data.SPARTA]:
		for i in 4000:
			for b: Dictionary in Data.roll_boons(s, rng, {}):
				if b["cat"] == "weapon":
					tally[s]["weapon"] += 1
				if b["rarity"] == "epic":
					tally[s]["epic"] += 1
	check(tally[Data.ATHENS]["weapon"] > tally[Data.SPARTA]["weapon"], "Athens is offered more weapons (%d vs %d)" % [tally[Data.ATHENS]["weapon"], tally[Data.SPARTA]["weapon"]])
	check(tally[Data.ATHENS]["epic"] > tally[Data.SPARTA]["epic"], "Athens is offered more epic boons (%d vs %d)" % [tally[Data.ATHENS]["epic"], tally[Data.SPARTA]["epic"]])

	# Power of the Gods is super rare, and never appears twice on one screen.
	var gods := 0
	var dupes := 0
	var screens := 40000
	for i in screens:
		var picks := Data.roll_boons(Data.ATHENS, rng, {})
		var ids := {}
		for b: Dictionary in picks:
			if ids.has(b["id"]):
				dupes += 1
			ids[b["id"]] = true
		if ids.has(Data.GODS_ID):
			gods += 1
	var rate := float(gods) / float(screens)
	check(rate > 0.005 and rate < 0.03, "Power of the Gods shows on %.2f%% of card screens" % (rate * 100.0))
	check(dupes == 0, "the three cards are always different")

	# Spartans are stronger; mercenaries die in one hit from either hero.
	var battle := Battle.new()
	root.add_child(battle)
	battle.running = false
	battle.start(Data.ATHENS, 7)
	battle.running = false
	var athens_dmg := battle.hero_dmg
	var athens_hp := battle.hero.max_hp
	var athens_city := battle.city_max
	var merc := battle._make_soldier(Data.SPARTA, "merc", 1)
	battle._incoming.append(merc)
	battle._flush_incoming()
	battle._damage(merc, 1.0, Vector2.ZERO, true)
	check(merc.dead, "a mercenary dies in one hit, even a weak one")
	var elite := battle._make_soldier(Data.SPARTA, "elite", 1)
	var hits := 0
	while elite.hp > 0.0 and hits < 500:
		elite.hp -= maxf(athens_dmg - elite.armor, 1.0)
		hits += 1
	check(hits >= 8, "an armoured Spartiate takes %d hits from the Athenian hero" % hits)
	battle.start(Data.SPARTA, 7)
	battle.running = false
	check(battle.hero_dmg > athens_dmg and battle.hero.max_hp > athens_hp, "the Spartan hero is stronger than the Athenian")
	check(battle.city_max < athens_city, "Sparta has the weaker city, since it had no walls")

	# Every enemy gets a coin value, and enough coins open the card screen.
	battle.start(Data.ATHENS, 7)
	battle.running = false
	var need := battle.coins_goal()
	battle._add_coins(float(need))
	check(battle.pending_boons == 1, "reaching the coin goal queues a boon screen")
	check(battle.coins_goal() > need, "the next boon costs more")

	# The right final boss for each side.
	check(Data.boss_for_round(Data.ATHENS, Data.FINAL_ROUND) == "leonidas", "Athens' final boss is King Leonidas")
	check(Data.boss_for_round(Data.SPARTA, Data.FINAL_ROUND) == "themistocles", "Sparta's final boss is Themistocles")

	# Power of the Gods: kill everything, then 0.75 spawn speed for four more rounds.
	battle.start(Data.ATHENS, 11)
	battle.running = false
	battle._begin_round(2)
	for i in 25:
		battle._spawn_enemy("elite")
	battle._flush_incoming()
	var queued := battle.queue.size()
	check(battle.enemies.size() >= 25, "the map is full of enemies before the gods act")
	battle.apply_boon(Data.GODS_ID)
	battle._cleanup()
	check(battle.enemies.is_empty(), "Power of the Gods kills every enemy on the map")
	check(battle.queue.size() == queued, "enemies still to come keep coming")
	var expected := Data.spawn_interval(2) / 0.75
	check(is_equal_approx(Data.spawn_interval(2, battle.spawn_speed()), expected), "spawns take 1/0.75 as long while the gods' power lasts")
	var slowed: Array[int] = []
	for r in range(2, 10):
		battle.round_num = r
		if battle.spawn_speed() < 1.0:
			slowed.append(r)
	check(slowed == [2, 3, 4, 5, 6], "slowed rounds are the rest of round 2 plus the next four: %s" % str(slowed))

	# Power of the Gods on the final round ends the war.
	battle.start(Data.ATHENS, 3)
	battle.running = false
	battle._begin_round(Data.FINAL_ROUND)
	battle._flush_incoming()
	check(battle.boss != null and battle.boss.boss_id == "leonidas", "round 12 summons Leonidas for Athens")
	battle.unleash_gods()
	check(battle.phase == "ending" and battle.end_won, "the gods can even slay the final boss")

	# Every boon applies without error, on both sides.
	for s: int in [Data.ATHENS, Data.SPARTA]:
		battle.start(s, 5)
		battle.running = false
		battle._begin_round(1)
		for b: Dictionary in Data.BOONS:
			battle.apply_boon(String(b["id"]))
		for i in 60:
			battle.step(1.0 / 30.0)
	check(true, "every boon can be applied and the game keeps running")

	print("\n%s: %d failure(s)" % ["ALL PASSED" if failures == 0 else "FAILED", failures])
	battle.free()
	quit(1 if failures > 0 else 0)
