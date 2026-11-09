class_name Battle
extends Node2D
## The war itself: rounds, spawning, soldier AI, bosses, boons and combat.

signal finished(won: bool)

const WALL_X := 215.0
const FIELD_TOP := 140.0
const FIELD_BOTTOM := 852.0
const FIELD_RIGHT := 1575.0
const TOWER_SLOTS: Array[float] = [190.0, 330.0, 470.0, 610.0, 750.0]
const ALLY_CAP := 60
const CITY_DAMAGE_MULT := 0.3
const ALLY_BONUS := 1.3 # your soldiers fight harder than the same soldier against you

var running := false
var autopilot := false
var side := Data.ATHENS
var foe := Data.SPARTA
var rng := RandomNumberGenerator.new()
var sfx: Node = null
var time := 0.0

var units: Array[Unit] = []
var allies: Array[Unit] = []
var enemies: Array[Unit] = []
var _incoming: Array[Unit] = []
var hero: Unit = null
var boss: Unit = null

var round_num := 0
var phase := "break"
var break_t := 0.0
var end_t := 0.0
var end_won := false
var queue: Array = []
var spawn_t := 0.0
var gods_until_round := -1

var coins := 0.0
var coin_mult := 1.0
var boons_taken := 0
var pending_boons := 0
var owned := {}
var score := 0
var kills := 0
var city_hp := 1000.0
var city_max := 1000.0

# Hero upgrades
var hero_dmg := 30.0
var hero_cd := 0.42
var hero_reach := 86.0
var hero_arc := 115.0
var hero_attack_t := 0.0
var javelins := 0
var javelin_t := 1.0
var gastraphetes := 0
var gastra_t := 2.0
var fire_tube := 0
var fire_t := 3.0
var thirst := 0.0
var dash_t := 0.0
var dash_cd := 0.0
var dash_dir := Vector2.RIGHT
var respawn_t := 0.0

# Army and city upgrades
var army_dmg := 1.0
var army_hp := 1.0
var army_armor := 0.0
var army_rate := 1.0
var regen := 0.0
var ditch_mult := 1.0
var towers: Array = []
var _reslot_t := 0.0

# Player input, filled in each frame
var input_move := Vector2.ZERO
var input_aim := Vector2(800, 450)
var input_attack := false
var input_dash := false

# Effects
var projectiles: Array = []
var hazards: Array = []
var triremes: Array = []
var particles: Array = []
var floaters: Array = []
var slashes: Array = []
var bolts: Array = []
var flash := 0.0
var shake := 0.0
var banner_text := ""
var banner_sub := ""
var banner_t := 0.0
var banner_gold := false
var boon_hold := 0.0 # keeps card screens away while the gods' strike plays out


func start(player_side: int, seed_value: int = -1) -> void:
	_clear_targets()
	if seed_value >= 0:
		rng.seed = seed_value
	else:
		rng.randomize()
	side = player_side
	foe = Data.foe_of(side)
	var s: Dictionary = Data.SIDES[side]
	units = []
	allies = []
	enemies = []
	_incoming = []
	projectiles = []
	hazards = []
	triremes = []
	particles = []
	floaters = []
	slashes = []
	bolts = []
	towers = []
	owned = {}
	boss = null
	round_num = 0
	phase = "break"
	break_t = 2.2
	queue = []
	gods_until_round = -1
	coins = 0.0
	coin_mult = 1.0
	boons_taken = 0
	pending_boons = 0
	score = 0
	kills = 0
	city_max = s["city_hp"]
	city_hp = city_max
	army_dmg = 1.0
	army_hp = 1.0
	army_armor = 0.0
	army_rate = 1.0
	regen = 0.0
	ditch_mult = 1.0
	hero_dmg = float(Data.HERO["dmg"]) * float(s["dmg_mult"])
	hero_cd = Data.HERO["cd"]
	hero_reach = Data.HERO["reach"]
	hero_arc = Data.HERO["arc"]
	javelins = int(s["start_javelins"])
	gastraphetes = 0
	fire_tube = 0
	thirst = 0.0
	respawn_t = 0.0
	dash_t = 0.0
	dash_cd = 0.0
	hero = Unit.new()
	hero.is_hero = true
	hero.team = 0
	hero.faction = side
	hero.kind = "elite"
	hero.max_hp = float(Data.HERO["hp"]) * float(s["hp_mult"])
	hero.hp = hero.max_hp
	hero.armor = 3.0
	hero.speed = Data.HERO["speed"]
	hero.scale_f = 1.42
	hero.radius = 18.0
	hero.pos = Vector2(WALL_X + 150.0, 470.0)
	units.append(hero)
	for i in 4:
		_recruit("merc")
	_flush_incoming()
	_show_banner("%s MARCHES TO WAR" % String(s["name"]), "Defend your city. Every kill earns coins.", 2.2)
	flash = 0.0
	shake = 0.0
	boon_hold = 0.0
	time = 0.0
	input_aim = hero.pos + Vector2.RIGHT * 100.0
	running = true


func _exit_tree() -> void:
	_clear_targets()


func _clear_targets() -> void:
	for u: Unit in units:
		u.target = null
	hero = null
	boss = null


func _process(delta: float) -> void:
	if running:
		_read_input()
		step(minf(delta, 0.05))
	position = Vector2(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0)) * shake
	queue_redraw()


func _read_input() -> void:
	if autopilot:
		return
	var mv := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
		mv.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
		mv.x += 1.0
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
		mv.y -= 1.0
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
		mv.y += 1.0
	input_move = mv
	input_aim = get_local_mouse_position()
	input_attack = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	input_dash = Input.is_physical_key_pressed(KEY_SPACE)


## One tick of the simulation. Tests call this directly to play whole games quickly.
func step(dt: float) -> void:
	if phase == "ending":
		dt *= 0.35
	time += dt
	_flush_incoming()
	_step_round(dt)
	if autopilot:
		_autopilot()
	_step_hero(dt)
	for u: Unit in units:
		if u.dead or u.is_hero:
			continue
		if u.is_boss:
			_step_boss(u, dt)
		else:
			_step_unit(u, dt)
	_separate(dt)
	_step_towers(dt)
	_step_projectiles(dt)
	_step_hazards(dt)
	_step_effects(dt)
	if regen > 0.0:
		for u: Unit in allies:
			if not u.dead and not u.one_shot:
				u.hp = minf(u.max_hp, u.hp + u.max_hp * regen * dt)
	_cleanup()
	_reslot_t -= dt
	if _reslot_t <= 0.0:
		_reslot_t = 1.0
		_assign_slots()


# ---------------------------------------------------------------- rounds

func _step_round(dt: float) -> void:
	match phase:
		"break":
			break_t -= dt
			if break_t <= 0.0:
				_begin_round(round_num + 1)
		"fight":
			if not queue.is_empty():
				spawn_t -= dt
				if spawn_t <= 0.0:
					_spawn_enemy(String(queue.pop_back()))
					spawn_t = Data.spawn_interval(round_num, spawn_speed())
			elif enemies.is_empty() and _incoming.is_empty():
				_end_round()
		"ending":
			end_t -= dt
			if end_t <= 0.0:
				phase = "done"
				running = false
				finished.emit(end_won)


func spawn_speed() -> float:
	return Data.GODS_SPAWN_SPEED if round_num <= gods_until_round else 1.0


func gods_rounds_left() -> int:
	return maxi(0, gods_until_round - round_num)


func enemies_left() -> int:
	return enemies.size() + queue.size() + _incoming.size()


func _begin_round(r: int) -> void:
	round_num = r
	phase = "fight"
	queue = Data.build_wave(r, side, rng)
	spawn_t = 0.4
	# The city sends fresh troops each round, so the army grows even between boons.
	if r > 1:
		for i in 2 + int(r * 0.5):
			_recruit("merc")
		if r % 2 == 0:
			_recruit("hoplite")
		if r % 3 == 0:
			_recruit("ranged")
	var boss_id := Data.boss_for_round(side, r)
	if boss_id != "":
		_spawn_boss(boss_id)
	else:
		_show_banner("ROUND %d" % r, "%d enemies approach" % queue.size(), 1.8)
		_snd("horn")
	if r == 7:
		_historic_handicap()


func _historic_handicap() -> void:
	if side == Data.ATHENS:
		_show_banner("THE PLAGUE OF ATHENS", "Disease rips through the crowded city", 3.0)
		for u: Unit in allies:
			if u.one_shot and rng.randf() < 0.3:
				_kill(u, false)
			elif not u.one_shot:
				u.hp = maxf(1.0, u.hp * 0.7)
		hero.hp = maxf(1.0, hero.hp * 0.7)
	else:
		_show_banner("THE HELOTS REVOLT", "Sparta's enslaved people rise up beside the city", 3.0)
		for i in 14:
			var u := _make_soldier(Data.SPARTA, "merc", 1)
			u.rebel = true
			u.pos = Vector2(rng.randf_range(WALL_X + 40.0, WALL_X + 340.0), FIELD_TOP if i % 2 == 0 else FIELD_BOTTOM)
			u.slot = Vector2(WALL_X + 24.0, rng.randf_range(FIELD_TOP, FIELD_BOTTOM))
			_incoming.append(u)
	_snd("horn")


func _end_round() -> void:
	if round_num >= Data.FINAL_ROUND:
		_finish(true)
		return
	phase = "break"
	break_t = 4.0
	var heal := hero.max_hp * 0.25
	if not hero.dead:
		hero.hp = minf(hero.max_hp, hero.hp + heal)
	for u: Unit in allies:
		if not u.dead and not u.one_shot:
			u.hp = minf(u.max_hp, u.hp + u.max_hp * 0.3)
	city_hp = minf(city_max, city_hp + city_max * 0.04)
	_show_banner("ROUND %d CLEARED" % round_num, "The next attack is coming...", 3.0)
	_snd("boon")


func _finish(won: bool) -> void:
	if phase == "ending" or phase == "done":
		return
	phase = "ending"
	end_won = won
	end_t = 1.1
	if won:
		for e: Unit in enemies:
			e.dead = true
			_ink_burst(e.pos, 6)
		queue = []


func _show_banner(text: String, sub: String, seconds: float, gold: bool = false) -> void:
	banner_text = text
	banner_sub = sub
	banner_t = seconds
	banner_gold = gold


func _snd(sound_name: String) -> void:
	if sfx:
		sfx.play(sound_name)


# ---------------------------------------------------------------- spawning

func _make_soldier(faction: int, kind: String, team: int) -> Unit:
	var r: Dictionary = Data.ROSTER[faction][kind]
	var s: Dictionary = Data.SIDES[faction]
	var u := Unit.new()
	u.team = team
	u.faction = faction
	u.kind = kind
	u.one_shot = r["one_shot"]
	u.ranged = r["ranged"]
	u.reach = r["reach"]
	u.cd_max = r["cd"]
	u.cd = rng.randf_range(0.0, u.cd_max)
	u.speed = float(r["speed"]) * rng.randf_range(0.92, 1.08)
	u.coins = r["coins"]
	u.scale_f = r["scale"]
	u.radius = 13.0 * u.scale_f
	u.armor = r["armor"]
	u.dmg = float(r["dmg"]) * float(s["dmg_mult"])
	u.max_hp = 1.0 if u.one_shot else float(r["hp"]) * float(s["hp_mult"])
	u.phase = rng.randf() * TAU
	u.retarget = rng.randf() * 0.3
	if team == 0:
		u.dmg *= army_dmg * ALLY_BONUS
		u.armor += army_armor
		if not u.one_shot:
			u.max_hp *= army_hp * ALLY_BONUS
		u.cd_max /= army_rate
		u.speed *= army_rate
	else:
		var grow := float(round_num - 1)
		u.dmg *= 1.0 + 0.035 * grow
		if not u.one_shot:
			u.max_hp *= 1.0 + 0.045 * grow
		u.face = -1.0
	u.hp = u.max_hp
	return u


func _spawn_enemy(kind: String) -> void:
	var u := _make_soldier(foe, kind, 1)
	var lane := rng.randf_range(FIELD_TOP, FIELD_BOTTOM)
	u.pos = Vector2(FIELD_RIGHT + 50.0, lane)
	if round_num >= 5 and rng.randf() < 0.2:
		u.pos = Vector2(rng.randf_range(850.0, 1500.0), FIELD_TOP - 30.0 if rng.randf() < 0.5 else FIELD_BOTTOM + 30.0)
	u.slot = Vector2(WALL_X + 24.0, lane)
	_incoming.append(u)


func _spawn_boss(boss_id: String) -> void:
	var b: Dictionary = Data.BOSSES[boss_id]
	var u := Unit.new()
	u.is_boss = true
	u.boss_id = boss_id
	u.team = 1
	u.faction = b["faction"]
	u.kind = "elite"
	u.max_hp = b["hp"]
	u.hp = u.max_hp
	u.armor = b["armor"]
	u.dmg = b["dmg"]
	u.speed = b["speed"]
	u.scale_f = b["scale"]
	u.radius = 18.0 * u.scale_f
	u.reach = 42.0 + 18.0 * u.scale_f
	u.cd_max = 1.15
	u.coins = b["coins"]
	u.abilities = (b["abilities"] as Array).duplicate()
	u.summons_left = (b["summons"] as Array).duplicate()
	u.pos = Vector2(FIELD_RIGHT + 60.0, 470.0)
	u.slot = Vector2(WALL_X + 40.0, 470.0)
	u.face = -1.0
	u.boss_cd = 3.5
	boss = u
	_incoming.append(u)
	_show_banner(String(b["name"]), String(b["quote"]), 3.6)
	_snd("horn")
	_snd("thunder")


func _recruit(kind: String) -> void:
	if allies.size() + _incoming.size() >= ALLY_CAP:
		return
	var u := _make_soldier(side, kind, 0)
	u.pos = Vector2(WALL_X + rng.randf_range(16.0, 60.0), rng.randf_range(FIELD_TOP + 60.0, FIELD_BOTTOM - 60.0))
	_incoming.append(u)


func _flush_incoming() -> void:
	if _incoming.is_empty():
		return
	for u: Unit in _incoming:
		units.append(u)
		if u.team == 0:
			allies.append(u)
		else:
			enemies.append(u)
	_incoming.clear()
	_assign_slots()


func _assign_slots() -> void:
	var i := 0
	for u: Unit in allies:
		if u.ranged:
			continue
		u.slot = Vector2(-60.0 - 42.0 * floorf(i / 7.0), (float(i % 7) - 3.0) * 44.0)
		i += 1
	var a := 0
	for u: Unit in allies:
		if u.ranged:
			u.slot = Vector2(-150.0 - 46.0 * floorf(a / 6.0) - 42.0 * floorf(i / 7.0), (float(a % 6) - 2.5) * 50.0)
			a += 1


# ---------------------------------------------------------------- hero

func _step_hero(dt: float) -> void:
	var h := hero
	h.hurt = maxf(0.0, h.hurt - dt * 5.0)
	h.atk = maxf(0.0, h.atk - dt * 5.0)
	if h.dead:
		respawn_t -= dt
		if respawn_t <= 0.0:
			h.dead = false
			h.hp = h.max_hp * 0.7
			h.pos = Vector2(WALL_X + 60.0, clampf(h.pos.y, FIELD_TOP, FIELD_BOTTOM))
			dash_t = 0.9 # brief invulnerability
			dash_dir = Vector2.ZERO
			units.append(h)
			_snd("boon")
		return
	dash_cd -= dt
	if input_dash and dash_cd <= 0.0 and dash_t <= 0.0:
		var d := input_move
		if d.length() < 0.1:
			d = Vector2(h.face, 0.0)
		dash_dir = d.normalized()
		dash_t = 0.2
		dash_cd = 1.8
		_snd("dash")
	var mv := input_move.limit_length(1.0)
	if dash_t > 0.0:
		dash_t -= dt
		h.pos += dash_dir * 780.0 * dt
		for i in 2:
			_particle(h.pos + Vector2(rng.randf_range(-8, 8), rng.randf_range(-40, 0)), Vector2.ZERO, 0.25, Art.INK.lerp(Art.CLAY, 0.5), 3.0)
	h.pos += mv * h.speed * dt
	h.pos += h.knock * dt
	h.knock = h.knock.move_toward(Vector2.ZERO, 1400.0 * dt)
	h.pos.x = clampf(h.pos.x, WALL_X + 22.0, FIELD_RIGHT)
	h.pos.y = clampf(h.pos.y, FIELD_TOP, FIELD_BOTTOM)
	h.moving = mv.length() > 0.1
	var to_aim := input_aim - (h.pos + Vector2(0.0, -30.0))
	if to_aim.length() > 2.0:
		h.aim = to_aim.normalized()
		if absf(h.aim.x) > 0.05:
			h.face = signf(h.aim.x)
	hero_attack_t -= dt
	if input_attack and hero_attack_t <= 0.0:
		hero_attack_t = hero_cd
		_hero_strike()
	if javelins > 0:
		javelin_t -= dt
		if javelin_t <= 0.0:
			javelin_t = 1.8
			_throw_javelins()
	if gastraphetes > 0:
		gastra_t -= dt
		if gastra_t <= 0.0:
			gastra_t = 2.4 - 0.3 * float(gastraphetes)
			_shoot(h.pos + Vector2(0, -34), h.aim, 1000.0, hero_dmg * (1.6 + 0.5 * float(gastraphetes)), 0, "bolt", 12, true)
			_snd("shoot")
	if fire_tube > 0:
		fire_t -= dt
		if fire_t <= 0.0:
			fire_t = 3.6 - 0.5 * float(fire_tube)
			_fire_cone()


func _hero_strike() -> void:
	var h := hero
	h.atk = 1.0
	_snd("swing")
	var origin := h.pos + Vector2(0.0, -24.0)
	slashes.append({"pos": origin, "ang": h.aim.angle(), "arc": deg_to_rad(hero_arc), "reach": hero_reach, "t": 0.16})
	var half := deg_to_rad(hero_arc) * 0.5
	for e: Unit in enemies:
		if e.dead:
			continue
		var to := e.pos - h.pos
		if to.length() > hero_reach + e.radius:
			continue
		if absf(h.aim.angle_to(to)) <= half or to.length() < e.radius + 18.0:
			_damage(e, hero_dmg, to.normalized() * 300.0, true)


func _throw_javelins() -> void:
	var targets := enemies.duplicate()
	targets.sort_custom(func(a: Unit, b: Unit) -> bool: return a.pos.distance_squared_to(hero.pos) < b.pos.distance_squared_to(hero.pos))
	var thrown := 0
	for e: Unit in targets:
		if thrown >= javelins or e.pos.distance_to(hero.pos) > 560.0:
			break
		if e.dead:
			continue
		var from := hero.pos + Vector2(0, -36)
		_shoot(from, (e.pos + Vector2(0, -22) - from).normalized(), 760.0, hero_dmg * 0.85, 0, "javelin", 1, true)
		thrown += 1
	if thrown > 0:
		_snd("shoot")


func _fire_cone() -> void:
	var h := hero
	var half := deg_to_rad(30.0)
	var length := 270.0
	_snd("fire")
	for i in 44:
		var a := h.aim.angle() + rng.randf_range(-half, half)
		_particle(h.pos + Vector2(0, -30), Vector2.from_angle(a) * rng.randf_range(260.0, 720.0), rng.randf_range(0.18, 0.42), Art.FIRE if rng.randf() < 0.6 else Art.GOLD, rng.randf_range(4.0, 9.0))
	for e: Unit in enemies:
		var to := e.pos - h.pos
		if not e.dead and to.length() < length and absf(h.aim.angle_to(to)) < half:
			_damage(e, hero_dmg * (1.1 + 0.5 * float(fire_tube)) + e.armor, Vector2.ZERO, true)


func _autopilot() -> void:
	input_attack = true
	input_dash = false
	if hero == null or hero.dead:
		return
	var best: Unit = null
	var best_d := INF
	for e: Unit in enemies:
		var d := e.pos.distance_squared_to(hero.pos) + (e.pos.x - WALL_X) * 180.0
		if d < best_d:
			best_d = d
			best = e
	if best == null:
		input_move = Vector2(WALL_X + 220.0, 470.0) - hero.pos
		input_move = input_move.limit_length(1.0) if input_move.length() > 10.0 else Vector2.ZERO
		return
	input_aim = best.pos + Vector2(0, -30)
	var to := best.pos - hero.pos
	input_move = to.normalized() if to.length() > hero_reach * 0.7 else Vector2.ZERO
	# Step out of telegraphed attacks, dashing if the blow is about to land.
	for h: Dictionary in hazards:
		var away := Vector2.ZERO
		if String(h["type"]) == "lane":
			var dy := hero.pos.y - float(h["y"])
			if absf(dy) < float(h["half"]) + 26.0:
				away = Vector2(0.0, signf(dy) if absf(dy) > 1.0 else 1.0)
		else:
			var from_center: Vector2 = hero.pos - (h["pos"] as Vector2)
			if from_center.length() < float(h["radius"]) + 18.0:
				away = from_center.normalized()
		if away != Vector2.ZERO:
			input_move = away
			if float(h["t"]) < 0.3:
				input_dash = true
			break
	for u: Unit in enemies:
		if u.is_boss and u.state == "charge_wind":
			var line := hero.pos - u.pos
			if line.length() < 460.0 and absf(u.dir.angle_to(line)) < 0.4:
				input_move = Vector2(-u.dir.y, u.dir.x)
				input_dash = u.state_t < 0.25


# ---------------------------------------------------------------- soldier AI

func _find_target(u: Unit) -> Unit:
	var list: Array[Unit] = allies if u.team == 1 else enemies
	var aggro := 190.0 if u.team == 1 else 430.0
	if u.ranged:
		aggro = u.reach
	var best: Unit = null
	var best_d := aggro * aggro
	for o: Unit in list:
		if o.dead:
			continue
		var d := o.pos.distance_squared_to(u.pos)
		if d < best_d:
			best_d = d
			best = o
	if u.team == 1 and hero != null and not hero.dead:
		var d := hero.pos.distance_squared_to(u.pos)
		if d < best_d:
			best = hero
	return best


func _step_unit(u: Unit, dt: float) -> void:
	u.cd -= dt
	u.atk = maxf(0.0, u.atk - dt * 4.0)
	u.hurt = maxf(0.0, u.hurt - dt * 5.0)
	u.retarget -= dt
	if u.target != null and u.target.dead:
		u.target = null
		u.retarget = 0.0
	if u.retarget <= 0.0:
		u.retarget = rng.randf_range(0.22, 0.42)
		u.target = _find_target(u)
	var move := Vector2.ZERO
	if u.target != null:
		var to := u.target.pos - u.pos
		var dist := to.length()
		if dist > 1.0:
			u.face = signf(to.x) if absf(to.x) > 1.0 else u.face
			u.aim = to / dist
		if dist <= u.reach + u.target.radius:
			if u.cd <= 0.0:
				_soldier_attack(u)
		else:
			move = to / maxf(dist, 1.0)
	elif u.team == 1:
		if u.ranged and u.pos.x <= WALL_X + u.reach * 0.8:
			if u.cd <= 0.0:
				_shoot_at_city(u)
		elif not u.ranged and u.pos.x <= u.slot.x + 4.0:
			if u.cd <= 0.0:
				_attack_city(u)
		else:
			move = (u.slot - u.pos).normalized()
			u.face = -1.0
	else:
		var goal := _ally_goal(u)
		var to_goal := goal - u.pos
		if to_goal.length() > 14.0:
			move = to_goal.normalized()
			u.face = signf(to_goal.x) if absf(to_goal.x) > 2.0 else u.face
		else:
			u.face = 1.0
			u.aim = Vector2.RIGHT
	u.moving = move != Vector2.ZERO
	u.pos += move * u.speed * dt + u.knock * dt
	u.knock = u.knock.move_toward(Vector2.ZERO, 1400.0 * dt)
	if u.team == 0:
		u.pos.x = clampf(u.pos.x, WALL_X + 16.0, FIELD_RIGHT)
	u.pos.y = clampf(u.pos.y, FIELD_TOP - 40.0, FIELD_BOTTOM + 40.0)


func _ally_goal(u: Unit) -> Vector2:
	var anchor := Vector2(WALL_X + 240.0, 470.0)
	if hero != null and not hero.dead:
		anchor = hero.pos
	var goal := anchor + u.slot
	goal.x = clampf(goal.x, WALL_X + 30.0, FIELD_RIGHT)
	goal.y = clampf(goal.y, FIELD_TOP, FIELD_BOTTOM)
	return goal


func _soldier_attack(u: Unit) -> void:
	u.cd = u.cd_max * rng.randf_range(0.9, 1.1)
	u.atk = 1.0
	if u.ranged:
		var from := u.pos + Vector2(0, -30) * u.scale_f
		var aim_at := u.target.pos + Vector2(0, -20)
		_shoot(from, (aim_at - from).normalized(), 560.0, u.dmg, u.team, "arrow", 1, false)
	else:
		_damage(u.target, u.dmg, u.aim * 120.0, false)


func _attack_city(u: Unit) -> void:
	u.cd = u.cd_max * rng.randf_range(0.9, 1.1)
	u.atk = 1.0
	_damage_city(u.dmg)


func _shoot_at_city(u: Unit) -> void:
	u.cd = u.cd_max * rng.randf_range(0.9, 1.1)
	u.atk = 1.0
	var from := u.pos + Vector2(0, -30)
	var at := Vector2(WALL_X, u.pos.y - 20.0 + rng.randf_range(-30.0, 30.0))
	_shoot(from, (at - from).normalized(), 560.0, u.dmg, 1, "arrow", 1, false)


func _damage_city(amount: float) -> void:
	# Spears are far less effective against a city than against a person.
	city_hp -= amount * CITY_DAMAGE_MULT * ditch_mult
	if rng.randf() < 0.25:
		_snd("wall")
		_ink_burst(Vector2(WALL_X + 6.0, rng.randf_range(FIELD_TOP, FIELD_BOTTOM)), 2)
	if city_hp <= 0.0:
		city_hp = 0.0
		_show_banner("%s HAS FALLEN" % String(Data.SIDES[side]["name"]), "", 2.0)
		_finish(false)


# ---------------------------------------------------------------- bosses

func _step_boss(u: Unit, dt: float) -> void:
	u.cd -= dt
	u.atk = maxf(0.0, u.atk - dt * 3.0)
	u.hurt = maxf(0.0, u.hurt - dt * 5.0)
	u.state_t -= dt
	u.retarget -= dt
	if u.target != null and u.target.dead:
		u.target = null
	if u.retarget <= 0.0 or u.target == null:
		u.retarget = 0.5
		u.target = _boss_target(u)
	u.moving = false
	var rage := 1.45 if u.hp < u.max_hp * 0.5 else 1.0
	match u.state:
		"walk":
			u.boss_cd -= dt * rage
			if u.target != null:
				var to := u.target.pos - u.pos
				var d := to.length()
				u.face = signf(to.x) if absf(to.x) > 2.0 else u.face
				u.aim = to.normalized()
				if d <= u.reach + u.target.radius:
					if u.cd <= 0.0:
						u.cd = u.cd_max / rage
						u.atk = 1.0
						_snd("swing")
						_damage(u.target, u.dmg, u.aim * 320.0, false)
				else:
					u.pos += u.aim * u.speed * rage * dt
					u.moving = true
			elif u.pos.x > u.slot.x:
				u.pos += (u.slot - u.pos).normalized() * u.speed * rage * dt
				u.moving = true
				u.face = -1.0
			elif u.cd <= 0.0:
				u.cd = u.cd_max
				u.atk = 1.0
				_damage_city(u.dmg * 3.0)
			if u.boss_cd <= 0.0 and u.pos.x < FIELD_RIGHT:
				_boss_ability(u)
		"charge_wind":
			if u.target != null and u.state_t > 0.2:
				u.dir = (u.target.pos - u.pos).normalized()
				u.face = signf(u.dir.x) if absf(u.dir.x) > 0.05 else u.face
				u.aim = u.dir
			if u.state_t <= 0.0:
				u.state = "charging"
				u.state_t = 0.46
				u.hit_ids.clear()
				_snd("dash")
		"charging":
			u.moving = true
			u.pos += u.dir * 900.0 * dt
			u.pos.x = clampf(u.pos.x, WALL_X + 40.0, FIELD_RIGHT)
			u.pos.y = clampf(u.pos.y, FIELD_TOP, FIELD_BOTTOM)
			_particle(u.pos + Vector2(rng.randf_range(-16, 16), rng.randf_range(-6, 0)), -u.dir * 80.0, 0.4, Art.INK.lerp(Art.CLAY, 0.6), 6.0)
			for a: Unit in _player_units():
				if u.hit_ids.has(a) or a.pos.distance_to(u.pos) > a.radius + u.radius + 14.0:
					continue
				u.hit_ids[a] = true
				_damage(a, u.dmg * 1.7, u.dir * 700.0, false)
				shake = maxf(shake, 7.0)
			if u.state_t <= 0.0:
				u.state = "walk"
		"slam_wind":
			if u.state_t <= 0.0:
				u.state = "walk"
				u.atk = 1.0
		"cast":
			if u.state_t <= 0.0:
				u.state = "walk"
	if not u.summons_left.is_empty() and u.hp <= u.max_hp * float(u.summons_left[0]):
		u.summons_left.pop_front()
		_boss_summon(u)


func _boss_target(u: Unit) -> Unit:
	if hero != null and not hero.dead and hero.pos.distance_to(u.pos) < 720.0:
		return hero
	var best: Unit = null
	var best_d := INF
	for a: Unit in allies:
		var d := a.pos.distance_squared_to(u.pos)
		if not a.dead and d < best_d:
			best_d = d
			best = a
	return best


func _player_units() -> Array[Unit]:
	var list: Array[Unit] = allies.duplicate()
	if hero != null and not hero.dead and dash_t <= 0.0:
		list.append(hero)
	return list


func _boss_ability(u: Unit) -> void:
	var ability: String = u.abilities[u.ability_index % u.abilities.size()]
	u.ability_index += 1
	var rage := u.hp < u.max_hp * 0.5
	u.boss_cd = rng.randf_range(2.6, 3.8) if rage else rng.randf_range(3.6, 5.0)
	var aim_pos := hero.pos if hero != null and not hero.dead else u.slot
	match ability:
		"charge":
			u.state = "charge_wind"
			u.state_t = 0.8
			u.dir = (aim_pos - u.pos).normalized()
		"slam":
			u.state = "slam_wind"
			u.state_t = 0.85
			hazards.append({"type": "slam", "pos": u.pos, "radius": 150.0 + 26.0 * u.scale_f, "t": 0.85, "tmax": 0.85, "dmg": u.dmg * 1.4, "owner": u})
		"barrage":
			u.state = "cast"
			u.state_t = 0.5
			u.atk = 1.0
			var count := 7 if rage else 5
			_snd("fire")
			for i in count:
				var spot := aim_pos + Vector2(rng.randf_range(-210.0, 210.0), rng.randf_range(-170.0, 170.0))
				if i == 0:
					spot = aim_pos
				spot.x = clampf(spot.x, WALL_X + 30.0, FIELD_RIGHT)
				spot.y = clampf(spot.y, FIELD_TOP, FIELD_BOTTOM)
				var fuse := 1.05 + 0.1 * float(i)
				hazards.append({"type": "fire", "pos": spot, "radius": 78.0, "t": fuse, "tmax": fuse, "dmg": u.dmg * 1.25})
		"ram":
			u.state = "cast"
			u.state_t = 0.4
			var lanes := 2 if rage else 1
			for i in lanes:
				var y := clampf(aim_pos.y + rng.randf_range(-90.0, 90.0) + float(i) * 240.0 * (1.0 if aim_pos.y < 470.0 else -1.0), FIELD_TOP + 44.0, FIELD_BOTTOM - 44.0)
				hazards.append({"type": "lane", "y": y, "half": 58.0, "t": 1.25, "tmax": 1.25, "dmg": u.dmg * 2.0})
			_snd("horn")


func _boss_summon(u: Unit) -> void:
	var count := 4 if round_num < Data.FINAL_ROUND else 6
	var kinds := ["elite", "hoplite", "hoplite"]
	_show_banner(String(Data.BOSSES[u.boss_id]["name"]) + " CALLS FOR AID", "Reinforcements charge in!", 2.0)
	_snd("horn")
	for i in count:
		var kind: String = kinds[i % kinds.size()]
		var e := _make_soldier(u.faction, kind, 1)
		e.pos = u.pos + Vector2.from_angle(TAU * float(i) / float(count)) * 90.0
		e.slot = Vector2(WALL_X + 24.0, e.pos.y)
		_incoming.append(e)
		_ink_burst(e.pos, 8)


# ---------------------------------------------------------------- towers

func _step_towers(dt: float) -> void:
	for t: Dictionary in towers:
		t["cd"] = float(t["cd"]) - dt
		if float(t["cd"]) > 0.0:
			continue
		var from := Vector2(WALL_X - 6.0, float(t["y"]) - 50.0)
		var best: Unit = null
		var best_d := 620.0 * 620.0
		for e: Unit in enemies:
			var d := e.pos.distance_squared_to(from)
			if not e.dead and d < best_d:
				best_d = d
				best = e
		if best == null:
			continue
		var aim := (best.pos + Vector2(0, -22) - from).normalized()
		if t["kind"] == "oxybeles":
			t["cd"] = 2.8
			_shoot(from, aim, 1050.0, 95.0, 0, "bolt", 8, false)
			shake = maxf(shake, 2.0)
		else:
			t["cd"] = 1.05
			_shoot(from, aim, 720.0, 19.0, 0, "arrow", 1, false)
		_snd("shoot")


# ---------------------------------------------------------------- projectiles and hazards

func _shoot(from: Vector2, direction: Vector2, spd: float, dmg_amount: float, team: int, kind: String, pierce: int, by_hero: bool) -> void:
	projectiles.append({"pos": from, "vel": direction * spd, "dmg": dmg_amount, "team": team, "kind": kind, "pierce": pierce, "life": 1.6, "hero": by_hero, "hit": {}})


func _step_projectiles(dt: float) -> void:
	var keep: Array = []
	for p: Dictionary in projectiles:
		var vel: Vector2 = p["vel"]
		var pos: Vector2 = p["pos"]
		pos += vel * dt
		p["pos"] = pos
		p["life"] = float(p["life"]) - dt
		var alive: bool = float(p["life"]) > 0.0 and pos.x > WALL_X - 4.0 and pos.x < 1680.0
		if int(p["team"]) == 1 and pos.x <= WALL_X + 2.0:
			_damage_city(float(p["dmg"]))
			alive = false
		var feet := pos + Vector2(0, 20)
		var list: Array[Unit] = enemies if int(p["team"]) == 0 else _player_units()
		var hits: Dictionary = p["hit"]
		for u: Unit in list:
			if not alive:
				break
			if u.dead or hits.has(u) or u.pos.distance_squared_to(feet) > pow(u.radius + 12.0, 2.0):
				continue
			hits[u] = true
			_damage(u, float(p["dmg"]), vel.normalized() * 110.0, bool(p["hero"]))
			p["pierce"] = int(p["pierce"]) - 1
			if int(p["pierce"]) <= 0:
				alive = false
		if alive:
			keep.append(p)
	projectiles = keep


func _step_hazards(dt: float) -> void:
	var keep: Array = []
	for h: Dictionary in hazards:
		h["t"] = float(h["t"]) - dt
		if h["type"] == "slam":
			var owner_unit: Unit = h["owner"]
			if owner_unit.dead:
				continue
			h["pos"] = owner_unit.pos
		if float(h["t"]) > 0.0:
			keep.append(h)
			continue
		match String(h["type"]):
			"slam":
				_explode(h["pos"], float(h["radius"]), float(h["dmg"]), 620.0, false)
				_snd("slam")
				shake = maxf(shake, 13.0)
			"fire":
				_explode(h["pos"], float(h["radius"]), float(h["dmg"]), 200.0, true)
				_snd("fire")
				shake = maxf(shake, 4.0)
			"lane":
				triremes.append({"x": FIELD_RIGHT + 240.0, "y": h["y"], "half": h["half"], "dmg": h["dmg"], "hit": {}})
				_snd("slam")
	hazards = keep
	var ships: Array = []
	for s: Dictionary in triremes:
		s["x"] = float(s["x"]) - 1500.0 * dt
		var ship_x: float = s["x"]
		var hit: Dictionary = s["hit"]
		for a: Unit in _player_units():
			if hit.has(a):
				continue
			if absf(a.pos.x - ship_x) < 110.0 and absf(a.pos.y - float(s["y"])) < float(s["half"]) + a.radius * 0.5:
				hit[a] = true
				_damage(a, float(s["dmg"]), Vector2(-500.0, signf(a.pos.y - float(s["y"])) * 500.0), false)
				shake = maxf(shake, 8.0)
		if ship_x > -260.0:
			ships.append(s)
	triremes = ships


func _explode(at: Vector2, radius: float, amount: float, knockback: float, fiery: bool) -> void:
	for a: Unit in _player_units():
		var to := a.pos - at
		if to.length() <= radius + a.radius * 0.5:
			_damage(a, amount, to.normalized() * knockback, false)
	for i in 34:
		var a := rng.randf() * TAU
		var col := (Art.FIRE if rng.randf() < 0.7 else Art.GOLD) if fiery else Art.INK.lerp(Art.CLAY, rng.randf() * 0.7)
		_particle(at, Vector2.from_angle(a) * rng.randf_range(80.0, radius * 3.2), rng.randf_range(0.25, 0.6), col, rng.randf_range(3.0, 8.0))


# ---------------------------------------------------------------- damage and death

func _damage(u: Unit, amount: float, kb: Vector2, by_hero: bool) -> void:
	if u.dead:
		return
	if u.is_hero and dash_t > 0.0:
		return
	var dealt := maxf(amount - u.armor, 1.0)
	if u.one_shot:
		dealt = u.hp
	u.hp -= dealt
	u.hurt = 1.0
	if not u.is_boss:
		u.knock += kb
	if u.armor >= 3.0:
		_snd("clang")
		for i in 3:
			_particle(u.pos + Vector2(0, -28) * u.scale_f, Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(80.0, 220.0), 0.22, Art.GOLD, 2.5)
	else:
		_snd("hit")
	if by_hero and not u.one_shot:
		_floater(u.pos + Vector2(rng.randf_range(-12, 12), -56.0 * u.scale_f), str(int(dealt)), Art.CREAM, 20)
	if u.is_hero:
		shake = maxf(shake, 4.0)
		_snd("hurt")
	if u.hp <= 0.0:
		_kill(u, by_hero)


func _kill(u: Unit, by_hero: bool) -> void:
	if u.dead:
		return
	u.dead = true
	u.target = null
	_ink_burst(u.pos + Vector2(0, -20), 7 + int(u.scale_f * 4.0))
	if u.team == 1:
		kills += 1
		score += u.coins * 10 * maxi(round_num, 1)
		_add_coins(float(u.coins))
		_floater(u.pos + Vector2(0, -50.0 * u.scale_f), "+%d" % int(round(float(u.coins) * coin_mult)), Art.GOLD, 22)
		if by_hero and thirst > 0.0 and hero != null and not hero.dead:
			hero.hp = minf(hero.max_hp, hero.hp + thirst)
		_snd("coin")
		if u.is_boss:
			_boss_died(u)
	elif u.is_hero:
		respawn_t = 5.0
		city_hp = maxf(1.0, city_hp - city_max * 0.02)
		_show_banner("YOU HAVE FALLEN", "You return in 5 seconds. Your city suffers.", 2.4)
		_snd("slam")
	else:
		_snd("hurt")


func _boss_died(u: Unit) -> void:
	shake = 18.0
	flash = 0.6
	_snd("thunder")
	var b: Dictionary = Data.BOSSES[u.boss_id]
	if boss == u:
		boss = null
	if round_num >= Data.FINAL_ROUND:
		_show_banner("%s IS DEAD" % String(b["name"]), "The war is over.", 3.0, true)
		_finish(true)
	else:
		_show_banner("%s IS DEAD" % String(b["name"]), String(b["title"]) + " has fallen.", 2.8, true)


func _add_coins(amount: float) -> void:
	coins += amount * coin_mult
	var needed := float(Data.coins_needed(boons_taken + pending_boons, side))
	while coins >= needed:
		coins -= needed
		pending_boons += 1
		needed = float(Data.coins_needed(boons_taken + pending_boons, side))


func coins_goal() -> int:
	return Data.coins_needed(boons_taken + pending_boons, side)


## Annihilates every enemy on the map, then slows spawning for the next four rounds.
func unleash_gods() -> void:
	gods_until_round = round_num + Data.GODS_SLOW_ROUNDS
	spawn_t = Data.spawn_interval(maxi(round_num, 1), Data.GODS_SPAWN_SPEED)
	var doomed: Array[Unit] = enemies.duplicate()
	doomed.append_array(_incoming.filter(func(u: Unit) -> bool: return u.team == 1))
	for e: Unit in doomed:
		_lightning(e.pos)
		_kill(e, false)
	hazards = []
	projectiles = projectiles.filter(func(p: Dictionary) -> bool: return int(p["team"]) == 0)
	flash = 1.0
	shake = 26.0
	boon_hold = 1.8
	_snd("thunder")
	_show_banner("POWER OF THE GODS", "Zeus strikes down every enemy. Spawns slowed for 4 rounds.", 3.2, true)


func _lightning(at: Vector2) -> void:
	var pts := PackedVector2Array()
	var y := FIELD_TOP - 90.0
	var x := at.x + rng.randf_range(-110.0, 110.0)
	while y < at.y - 20.0:
		pts.append(Vector2(x, y))
		y += rng.randf_range(24.0, 60.0)
		x = lerpf(x, at.x, 0.25) + rng.randf_range(-22.0, 22.0)
	pts.append(at + Vector2(0, -20))
	if pts.size() >= 2:
		bolts.append({"pts": pts, "t": rng.randf_range(0.5, 1.0)})


# ---------------------------------------------------------------- boons

func apply_boon(id: String) -> void:
	owned[id] = int(owned.get(id, 0)) + 1
	match id:
		Data.GODS_ID:
			unleash_gods()
		"hire_mercs":
			for i in 8:
				_recruit("merc")
		"recruit_ranged":
			for i in 4:
				_recruit("ranged")
		"recruit_hoplites":
			for i in 3:
				_recruit("hoplite")
		"recruit_elite":
			for i in 2:
				_recruit("elite")
		"drill":
			army_dmg *= 1.15
			for u: Unit in allies:
				u.dmg *= 1.15
		"bronze":
			army_armor += 2.0
			for u: Unit in allies:
				u.armor += 2.0
		"phalanx":
			army_hp *= 1.25
			for u: Unit in allies:
				if not u.one_shot:
					u.max_hp *= 1.25
					u.hp = u.max_hp
		"paean":
			army_rate *= 1.15
			for u: Unit in allies:
				u.speed *= 1.15
				u.cd_max /= 1.15
		"whetstone":
			hero_dmg *= 1.2
		"swift":
			hero_cd /= 1.12
		"long_spear":
			hero_reach += 16.0
		"xiphos":
			hero_arc = minf(hero_arc + 30.0, 240.0)
		"javelin":
			javelins += 1
		"corinthian":
			hero.max_hp += 45.0
			hero.hp = minf(hero.max_hp, hero.hp + 45.0)
		"thirst":
			thirst += 3.0
		"gastraphetes":
			gastraphetes += 1
		"fire_tube":
			fire_tube += 1
		"agoge":
			hero_dmg *= 1.4
			hero.max_hp += 70.0
			hero.hp = minf(hero.max_hp, hero.hp + 70.0)
		"repair":
			city_hp = minf(city_max, city_hp + city_max * 0.3)
		"raise_walls":
			var extra := city_max * 0.25
			city_max += extra
			city_hp += extra
		"ditch":
			ditch_mult *= 0.8
		"tower":
			_add_tower("tower")
		"oxybeles":
			_add_tower("oxybeles")
		"temple":
			regen += 0.006
		"laurion", "spoils":
			coin_mult *= 1.2
	_flush_incoming()


func _add_tower(kind: String) -> void:
	if towers.size() < TOWER_SLOTS.size():
		towers.append({"y": TOWER_SLOTS[towers.size()], "kind": kind, "cd": 0.5})


# ---------------------------------------------------------------- physics and effects

func _separate(dt: float) -> void:
	var grid := {}
	for u: Unit in units:
		if u.dead:
			continue
		var key := int(u.pos.x / 44.0) + int(u.pos.y / 44.0) * 4096
		if not grid.has(key):
			grid[key] = []
		grid[key].append(u)
	for u: Unit in units:
		if u.dead or u.is_hero or u.is_boss:
			continue
		var cx := int(u.pos.x / 44.0)
		var cy := int(u.pos.y / 44.0)
		var push := Vector2.ZERO
		for gx in range(cx - 1, cx + 2):
			for gy in range(cy - 1, cy + 2):
				var key := gx + gy * 4096
				if not grid.has(key):
					continue
				for o: Unit in grid[key]:
					if o == u:
						continue
					var away := u.pos - o.pos
					var min_d := u.radius + o.radius
					var d := away.length()
					if d < min_d and d > 0.01:
						push += away / d * (min_d - d)
		u.pos += push * minf(dt * 7.0, 0.5)


func _particle(pos: Vector2, vel: Vector2, life: float, col: Color, size: float) -> void:
	if particles.size() < 500:
		particles.append({"pos": pos, "vel": vel, "life": life, "max": life, "col": col, "size": size})


func _ink_burst(at: Vector2, count: int) -> void:
	for i in count:
		_particle(at, Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(40.0, 210.0), rng.randf_range(0.2, 0.5), Art.INK, rng.randf_range(2.0, 4.5))


func _floater(at: Vector2, text: String, col: Color, size: int) -> void:
	if floaters.size() < 60:
		floaters.append({"pos": at, "text": text, "col": col, "size": size, "t": 0.7})


func _step_effects(dt: float) -> void:
	var keep_p: Array = []
	for p: Dictionary in particles:
		p["life"] = float(p["life"]) - dt
		if float(p["life"]) > 0.0:
			var vel: Vector2 = p["vel"]
			p["pos"] = (p["pos"] as Vector2) + vel * dt
			p["vel"] = vel * (1.0 - 3.0 * dt)
			keep_p.append(p)
	particles = keep_p
	var keep_f: Array = []
	for f: Dictionary in floaters:
		f["t"] = float(f["t"]) - dt
		if float(f["t"]) > 0.0:
			f["pos"] = (f["pos"] as Vector2) + Vector2(0.0, -44.0 * dt)
			keep_f.append(f)
	floaters = keep_f
	var keep_s: Array = []
	for s: Dictionary in slashes:
		s["t"] = float(s["t"]) - dt
		if float(s["t"]) > 0.0:
			keep_s.append(s)
	slashes = keep_s
	var keep_b: Array = []
	for b: Dictionary in bolts:
		b["t"] = float(b["t"]) - dt
		if float(b["t"]) > 0.0:
			keep_b.append(b)
	bolts = keep_b
	flash = maxf(0.0, flash - dt * 1.3)
	shake = maxf(0.0, shake - dt * 32.0)
	banner_t = maxf(0.0, banner_t - dt)
	boon_hold = maxf(0.0, boon_hold - dt)


func _cleanup() -> void:
	var removed := false
	for u: Unit in units:
		if u.dead:
			removed = true
			break
	if not removed:
		return
	units = units.filter(func(u: Unit) -> bool: return not u.dead)
	allies = allies.filter(func(u: Unit) -> bool: return not u.dead)
	enemies = enemies.filter(func(u: Unit) -> bool: return not u.dead)
	_assign_slots()


# ---------------------------------------------------------------- drawing

func _draw() -> void:
	if hero == null:
		return
	Art.city(self, side, city_hp / city_max, time)
	for t: Dictionary in towers:
		Art.tower(self, float(t["y"]), String(t["kind"]), side)
	_draw_hazards_under()
	var order: Array[Unit] = units.duplicate()
	order.sort_custom(func(a: Unit, b: Unit) -> bool: return a.pos.y < b.pos.y)
	for u: Unit in order:
		Art.warrior(self, u, time)
	draw_set_transform(Vector2.ZERO)
	for s: Dictionary in triremes:
		Art.trireme(self, Vector2(float(s["x"]), float(s["y"])), time)
	for p: Dictionary in projectiles:
		Art.projectile(self, p)
	for s: Dictionary in slashes:
		_draw_slash(s)
	for p: Dictionary in particles:
		var col: Color = p["col"]
		col.a = clampf(float(p["life"]) / float(p["max"]) * 1.6, 0.0, 1.0)
		draw_circle(p["pos"], float(p["size"]), col)
	for f: Dictionary in floaters:
		var col: Color = f["col"]
		col.a = clampf(float(f["t"]) * 2.5, 0.0, 1.0)
		Art.text(self, String(f["text"]), f["pos"], int(f["size"]), col, true, Art.INK)
	for b: Dictionary in bolts:
		var pts: PackedVector2Array = b["pts"]
		var a := clampf(float(b["t"]) * 2.0, 0.0, 1.0)
		draw_polyline(pts, Color(1.0, 0.85, 0.3, a * 0.55), 10.0)
		draw_polyline(pts, Color(1.0, 1.0, 0.9, a), 3.5)
	if not hero.dead and input_attack == false:
		var c := input_aim
		draw_arc(c, 11.0, 0.0, TAU, 20, Color(Art.INK, 0.55), 2.0)
	if flash > 0.0:
		draw_rect(Rect2(-40, -40, 1680, 980), Color(1.0, 0.95, 0.7, flash * 0.85))


func _draw_slash(s: Dictionary) -> void:
	var a := float(s["t"]) / 0.16
	var ang: float = s["ang"]
	var arc: float = s["arc"]
	var reach: float = s["reach"]
	var sweep := ang - arc * 0.5 + arc * (1.0 - a)
	draw_arc(s["pos"], reach * 0.72, ang - arc * 0.5, sweep, 22, Color(Art.CREAM, a * 0.8), reach * 0.26)
	draw_arc(s["pos"], reach * 0.9, ang - arc * 0.5, sweep, 22, Color(Art.INK, a * 0.6), 3.0)


func _draw_hazards_under() -> void:
	for h: Dictionary in hazards:
		var prog := 1.0 - float(h["t"]) / float(h["tmax"])
		match String(h["type"]):
			"slam", "fire":
				var col := Art.BLOOD if h["type"] == "slam" else Art.FIRE
				var at: Vector2 = h["pos"]
				var r: float = h["radius"]
				Art.ellipse(self, at, r, r * 0.62, Color(col, 0.16))
				Art.ellipse(self, at, r * prog, r * 0.62 * prog, Color(col, 0.34))
				var pts := Art.ellipse_points(at, r, r * 0.62)
				pts.append(pts[0])
				draw_polyline(pts, Color(col, 0.9), 3.0)
			"lane":
				var y: float = h["y"]
				var half: float = h["half"]
				var blink := 0.2 + 0.2 * sin(time * 26.0)
				draw_rect(Rect2(WALL_X, y - half, FIELD_RIGHT - WALL_X + 25.0, half * 2.0), Color(Art.BLOOD, blink))
				draw_line(Vector2(WALL_X, y - half), Vector2(1600, y - half), Art.BLOOD, 3.0)
				draw_line(Vector2(WALL_X, y + half), Vector2(1600, y + half), Art.BLOOD, 3.0)
				Art.text(self, "<<<   RAMMING TRIREME   <<<", Vector2(1370, y + 9), 26, Art.CREAM, true, Art.INK)
	for u: Unit in enemies:
		if u.is_boss and u.state == "charge_wind":
			var from := u.pos + Vector2(0, -6)
			draw_line(from, from + u.dir * 414.0, Color(Art.BLOOD, 0.55), 30.0 + u.radius)
			draw_line(from, from + u.dir * 414.0, Art.BLOOD, 2.0)
