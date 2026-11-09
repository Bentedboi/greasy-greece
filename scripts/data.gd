class_name Data
extends RefCounted
## All the game's rules and numbers live here, so balance can be tuned in one file.

const ATHENS := 0
const SPARTA := 1
const FINAL_ROUND := 12

# --- Power of the Gods ---
const GODS_ID := "gods"
const GODS_CHANCE := 0.005 # per card slot, so roughly 1 card screen in 67
const GODS_SLOW_ROUNDS := 4
const GODS_SPAWN_SPEED := 0.75

const HERO := {"hp": 230.0, "dmg": 30.0, "cd": 0.42, "reach": 86.0, "arc": 115.0, "speed": 245.0}

# Each side's historical strengths and handicaps.
const SIDES := {
	ATHENS: {
		"name": "ATHENS", "people": "Athenians", "hp_mult": 0.88, "dmg_mult": 0.92, "city_hp": 2000.0,
		"boon_cost": 0.68, "rare_mult": 1.9, "epic_mult": 2.6, "weapon_mult": 1.6, "elite_mult": 0.7,
		"start_javelins": 2,
		"lines": [
			"Weaker soldiers, brilliant toys.",
			"Laurion silver: boons cost 32% less",
			"Better odds on rare boons and weapons",
			"Long Walls: the toughest city in Greece",
			"Handicap: the Plague strikes in round 7",
		],
		"bars": {"STRENGTH": 2, "BOONS": 5, "WEAPONS": 5, "WALLS": 5},
	},
	SPARTA: {
		"name": "SPARTA", "people": "Spartans", "hp_mult": 1.22, "dmg_mult": 1.2, "city_hp": 1400.0,
		"boon_cost": 1.1, "rare_mult": 0.8, "epic_mult": 0.6, "weapon_mult": 0.7, "elite_mult": 1.5,
		"start_javelins": 0,
		"lines": [
			"Raised for war from the age of seven.",
			"Agoge: far stronger, tougher soldiers",
			"Iron-bar money: boons cost 10% more",
			"Famously no city walls, just a fence",
			"Handicap: the Helots revolt in round 7",
		],
		"bars": {"STRENGTH": 5, "BOONS": 2, "WEAPONS": 2, "WALLS": 1},
	},
}

# Every soldier type, from one-hit mercenaries up to armoured elites.
const ROSTER := {
	ATHENS: {
		"merc": {"name": "Thracian Mercenary", "hp": 1.0, "armor": 0.0, "dmg": 5.0, "speed": 122.0, "reach": 32.0, "cd": 1.1, "coins": 2, "one_shot": true, "ranged": false, "scale": 0.92},
		"ranged": {"name": "Scythian Archer", "hp": 22.0, "armor": 0.0, "dmg": 7.0, "speed": 96.0, "reach": 390.0, "cd": 1.9, "coins": 4, "one_shot": false, "ranged": true, "scale": 0.95},
		"hoplite": {"name": "Athenian Hoplite", "hp": 75.0, "armor": 3.0, "dmg": 10.0, "speed": 88.0, "reach": 44.0, "cd": 1.15, "coins": 8, "one_shot": false, "ranged": false, "scale": 1.05},
		"elite": {"name": "Epilektos Guard", "hp": 190.0, "armor": 7.0, "dmg": 17.0, "speed": 82.0, "reach": 50.0, "cd": 1.05, "coins": 20, "one_shot": false, "ranged": false, "scale": 1.22},
	},
	SPARTA: {
		"merc": {"name": "Arcadian Mercenary", "hp": 1.0, "armor": 0.0, "dmg": 5.0, "speed": 118.0, "reach": 32.0, "cd": 1.1, "coins": 2, "one_shot": true, "ranged": false, "scale": 0.92},
		"ranged": {"name": "Helot Slinger", "hp": 20.0, "armor": 0.0, "dmg": 6.0, "speed": 100.0, "reach": 350.0, "cd": 1.9, "coins": 4, "one_shot": false, "ranged": true, "scale": 0.92},
		"hoplite": {"name": "Perioikoi Hoplite", "hp": 75.0, "armor": 3.0, "dmg": 10.0, "speed": 86.0, "reach": 44.0, "cd": 1.15, "coins": 8, "one_shot": false, "ranged": false, "scale": 1.05},
		"elite": {"name": "Spartiate Warrior", "hp": 200.0, "armor": 8.0, "dmg": 18.0, "speed": 80.0, "reach": 52.0, "cd": 1.0, "coins": 20, "one_shot": false, "ranged": false, "scale": 1.25},
	},
}

# Bosses, keyed by the side YOU are playing. Round 12 is the final boss.
const BOSS_PLAN := {
	ATHENS: {4: "brasidas", 8: "lysander", 12: "leonidas"},
	SPARTA: {4: "cleon", 8: "pericles", 12: "themistocles"},
}

const BOSSES := {
	"brasidas": {"name": "BRASIDAS", "title": "Sparta's boldest general", "faction": SPARTA, "hp": 950.0, "armor": 5.0, "dmg": 20.0, "speed": 100.0, "scale": 1.75, "coins": 70, "abilities": ["charge", "slam"], "quote": "He has come to take your allies from you.", "summons": []},
	"lysander": {"name": "LYSANDER", "title": "Victor of the Peloponnesian War", "faction": SPARTA, "hp": 1800.0, "armor": 6.0, "dmg": 21.0, "speed": 108.0, "scale": 1.95, "coins": 130, "abilities": ["ram", "charge", "slam"], "quote": "He burned Athens' fleet at Aegospotami.", "summons": [0.5]},
	"leonidas": {"name": "KING LEONIDAS", "title": "King of Sparta, Lion of Thermopylae", "faction": SPARTA, "hp": 6200.0, "armor": 9.0, "dmg": 32.0, "speed": 128.0, "scale": 2.3, "coins": 400, "abilities": ["charge", "slam", "charge", "slam"], "quote": "MOLON LABE  -  \"Come and take them.\"", "summons": [0.75, 0.5, 0.25]},
	"cleon": {"name": "CLEON", "title": "Demagogue of Athens", "faction": ATHENS, "hp": 720.0, "armor": 3.0, "dmg": 18.0, "speed": 96.0, "scale": 1.65, "coins": 70, "abilities": ["barrage"], "quote": "He promised the Assembly it would take twenty days.", "summons": []},
	"pericles": {"name": "PERICLES", "title": "First Citizen of Athens", "faction": ATHENS, "hp": 1900.0, "armor": 5.0, "dmg": 22.0, "speed": 100.0, "scale": 1.85, "coins": 130, "abilities": ["barrage", "ram"], "quote": "\"Time is the wisest counsellor of all.\"", "summons": [0.5]},
	"themistocles": {"name": "THEMISTOCLES", "title": "Architect of Athens' Navy, Victor of Salamis", "faction": ATHENS, "hp": 4300.0, "armor": 7.0, "dmg": 26.0, "speed": 122.0, "scale": 2.2, "coins": 400, "abilities": ["barrage", "ram", "barrage", "ram"], "quote": "\"The wooden wall will hold!\"", "summons": [0.75, 0.5, 0.25]},
}

const RARITY_WEIGHT := {"common": 100.0, "rare": 32.0, "epic": 9.0}

# Every boon. "max" caps stacking, "side" restricts it to one city.
const BOONS := [
	# ARMY
	{"id": "hire_mercs", "cat": "army", "rarity": "common", "name": "Hire Mercenaries", "desc": "+8 {merc}s.\nThey die in one hit, but there are lots of them."},
	{"id": "recruit_ranged", "cat": "army", "rarity": "common", "name": "Ranged Support", "desc": "+4 {ranged}s to shoot from behind your line."},
	{"id": "recruit_hoplites", "cat": "army", "rarity": "common", "name": "Levy Hoplites", "desc": "+3 {hoplite}s with bronze shields."},
	{"id": "recruit_elite", "cat": "army", "rarity": "rare", "name": "Call the Elite", "desc": "+2 {elite}s.\nHeavily armoured, very hard to kill."},
	{"id": "drill", "cat": "army", "rarity": "common", "name": "Army Drill", "desc": "Your whole army deals +15% damage."},
	{"id": "bronze", "cat": "army", "rarity": "rare", "name": "Bronze for All", "desc": "Your whole army gains +2 armour.", "max": 5},
	{"id": "phalanx", "cat": "army", "rarity": "rare", "name": "Lock Shields", "desc": "Your army gains +25% max health and heals fully."},
	{"id": "paean", "cat": "army", "rarity": "epic", "name": "Sing the Paean", "desc": "Your army moves and strikes 15% faster.", "max": 3},
	# WEAPONS
	{"id": "whetstone", "cat": "weapon", "rarity": "common", "name": "Whetstone", "desc": "Your strikes deal +20% damage."},
	{"id": "swift", "cat": "weapon", "rarity": "common", "name": "Quick Hands", "desc": "You strike 12% faster.", "max": 6},
	{"id": "long_spear", "cat": "weapon", "rarity": "common", "name": "Longer Spear", "desc": "+16 reach on your strikes.", "max": 5},
	{"id": "xiphos", "cat": "weapon", "rarity": "rare", "name": "Xiphos Sweep", "desc": "Your strikes swing 30 degrees wider.", "max": 3},
	{"id": "javelin", "cat": "weapon", "rarity": "rare", "name": "Javelin Bundle", "desc": "Automatically throw +1 extra javelin at nearby enemies.", "max": 6},
	{"id": "corinthian", "cat": "weapon", "rarity": "common", "name": "Corinthian Helmet", "desc": "+45 max health for you, and heal 45."},
	{"id": "thirst", "cat": "weapon", "rarity": "rare", "name": "Thirst of Ares", "desc": "Each enemy your strikes kill heals you for 3.", "max": 4},
	{"id": "gastraphetes", "cat": "weapon", "rarity": "epic", "name": "Gastraphetes", "desc": "A Greek belly-bow. Fires a heavy bolt through your aim line, piercing everything.", "max": 3, "side": ATHENS},
	{"id": "fire_tube", "cat": "weapon", "rarity": "epic", "name": "Delium Fire-Tube", "desc": "A flame-thrower, as used at Delium. Burns a cone in front of you and ignores armour.", "max": 3, "side": ATHENS},
	{"id": "agoge", "cat": "weapon", "rarity": "epic", "name": "Agoge Conditioning", "desc": "+40% strike damage and +70 max health.", "max": 3, "side": SPARTA},
	# CITY
	{"id": "repair", "cat": "city", "rarity": "common", "name": "Repair the City", "desc": "Restore 30% of your city's health."},
	{"id": "raise_walls", "cat": "city", "rarity": "common", "name": "Strengthen Defences", "desc": "+25% max city health, restored immediately."},
	{"id": "ditch", "cat": "city", "rarity": "common", "name": "Stake Ditch", "desc": "Enemies at your city deal 20% less damage.", "max": 3},
	{"id": "tower", "cat": "city", "rarity": "rare", "name": "Archer Tower", "desc": "Build a tower that shoots the nearest enemy.", "max": 3},
	{"id": "oxybeles", "cat": "city", "rarity": "epic", "name": "Oxybeles", "desc": "A wall-mounted bolt-thrower. Slow, savage and piercing.", "max": 2},
	{"id": "temple", "cat": "city", "rarity": "rare", "name": "Build a Temple", "desc": "You and your army slowly regenerate health.", "max": 3},
	{"id": "laurion", "cat": "city", "rarity": "rare", "name": "Laurion Silver", "desc": "Strike a new silver seam: +20% coins from kills.", "max": 3, "side": ATHENS},
	{"id": "spoils", "cat": "city", "rarity": "rare", "name": "Seize the Spoils", "desc": "Strip the fallen: +20% coins from kills.", "max": 2, "side": SPARTA},
]

const GODS_BOON := {"id": GODS_ID, "cat": "divine", "rarity": "divine", "name": "Power of the Gods", "desc": "Annihilate every enemy on the map.\nEnemies then spawn at 0.75 speed for 4 rounds."}


static func foe_of(side: int) -> int:
	return SPARTA if side == ATHENS else ATHENS


static func boss_for_round(side: int, round_num: int) -> String:
	var plan: Dictionary = BOSS_PLAN[side]
	return String(plan.get(round_num, ""))


## Coins needed for the Nth boon screen. Rises the further you get.
static func coins_needed(boons_taken: int, side: int) -> int:
	var n := float(boons_taken)
	var cost_mult: float = SIDES[side]["boon_cost"]
	return maxi(5, int(round((15.0 + 6.0 * n + 0.25 * n * n) * cost_mult)))


## Enemies in a round. Rises the further you get.
static func enemy_count(round_num: int, side: int) -> int:
	var r := float(round_num)
	var count := 10.0 + 4.0 * r + r * r / 4.0
	if boss_for_round(side, round_num) != "":
		count *= 0.55
	return int(count)


## Seconds between spawns. speed 0.75 means spawns take 1/0.75 times as long.
static func spawn_interval(round_num: int, speed: float = 1.0) -> float:
	return maxf(0.34, 1.25 - 0.08 * float(round_num)) / speed


## How likely each soldier type is in a round: mostly mercenaries at first, armour later.
static func wave_mix(round_num: int) -> Dictionary:
	var r := float(round_num)
	return {
		"merc": maxf(0.22, 0.82 - 0.055 * r),
		"ranged": 0.08 + 0.018 * r,
		"hoplite": 0.03 + 0.032 * r,
		"elite": 0.0 if round_num < 3 else 0.016 * (r - 2.0),
	}


static func build_wave(round_num: int, side: int, rng: RandomNumberGenerator) -> Array:
	var mix := wave_mix(round_num)
	var total := 0.0
	for key: String in mix:
		total += float(mix[key])
	var wave: Array = []
	for i in enemy_count(round_num, side):
		var roll := rng.randf() * total
		var picked := "merc"
		for key: String in mix:
			roll -= float(mix[key])
			if roll <= 0.0:
				picked = key
				break
		wave.append(picked)
	return wave


static func boon_weight(boon: Dictionary, side: int) -> float:
	var s: Dictionary = SIDES[side]
	var rarity: String = boon["rarity"]
	var w: float = RARITY_WEIGHT.get(rarity, 0.0)
	if rarity == "rare":
		w *= float(s["rare_mult"])
	elif rarity == "epic":
		w *= float(s["epic_mult"])
	if boon["cat"] == "weapon":
		w *= float(s["weapon_mult"])
	if boon["id"] == "recruit_elite":
		w *= float(s["elite_mult"])
	return w


## Rolls the three cards. Each slot has a tiny chance of being Power of the Gods.
static func roll_boons(side: int, rng: RandomNumberGenerator, owned: Dictionary) -> Array:
	var picks: Array = []
	var pool: Array = []
	for b: Dictionary in BOONS:
		if b.has("side") and int(b["side"]) != side:
			continue
		if b.has("max") and int(owned.get(b["id"], 0)) >= int(b["max"]):
			continue
		pool.append(b)
	for i in 3:
		if rng.randf() < GODS_CHANCE and not picks.has(GODS_BOON):
			picks.append(GODS_BOON)
			continue
		var total := 0.0
		for b: Dictionary in pool:
			total += boon_weight(b, side)
		var roll := rng.randf() * total
		var chosen: Dictionary = pool[pool.size() - 1]
		for b: Dictionary in pool:
			roll -= boon_weight(b, side)
			if roll <= 0.0:
				chosen = b
				break
		picks.append(chosen)
		pool.erase(chosen)
	return picks


## Fills in soldier names, e.g. "{merc}" becomes "Thracian Mercenary".
static func boon_text(boon: Dictionary, side: int) -> String:
	var text: String = boon["desc"]
	var roster: Dictionary = ROSTER[side]
	for key: String in roster:
		var soldier: String = roster[key]["name"]
		var plural := soldier.left(-1) + "ies" if soldier.ends_with("y") else soldier + "s"
		text = text.replace("{%s}s" % key, plural).replace("{%s}" % key, soldier)
	return text
