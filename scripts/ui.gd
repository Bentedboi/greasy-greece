class_name GameUI
extends Control
## The menu, HUD, boon cards and end screens. Draws whatever state Main is in.

const CARD_W := 340.0
const CARD_H := 470.0

var main: Node = null
var battle: Battle = null
var time := 0.0
var _demo: Array[Unit] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for f: int in [Data.ATHENS, Data.SPARTA]:
		var u := Unit.new()
		u.faction = f
		u.kind = "elite"
		u.is_hero = true
		u.scale_f = 4.3
		u.moving = true
		u.face = 1.0 if f == Data.ATHENS else -1.0
		u.aim = Vector2(0.75, -0.65)
		_demo.append(u)


func _process(delta: float) -> void:
	time += delta
	queue_redraw()


func side_rect(i: int) -> Rect2:
	return Rect2(130.0 + float(i) * 720.0, 232.0, 620.0, 560.0)


func card_rect(i: int) -> Rect2:
	return Rect2(800.0 - CARD_W * 1.5 - 30.0 + float(i) * (CARD_W + 30.0), 228.0, CARD_W, CARD_H)


func _draw() -> void:
	match String(main.state):
		"menu":
			_draw_menu()
		"play":
			_draw_hud()
			_draw_banner()
		"choose":
			_draw_hud()
			_draw_cards()
		"pause":
			_draw_hud()
			_draw_pause()
		"won", "lost":
			_draw_end()


# ------------------------------------------------------------- menu

func _draw_menu() -> void:
	draw_rect(Rect2(0, 0, 1600, 900), Art.CLAY)
	draw_rect(Rect2(0, 0, 1600, 900), Color(Art.CLAY_DARK, 0.25))
	draw_rect(Rect2(0, 0, 1600, 40), Art.INK)
	Art.meander(self, 0, 1600, 8, 22, Art.CLAY_LIGHT, 2.6)
	draw_rect(Rect2(0, 860, 1600, 40), Art.INK)
	Art.meander(self, 0, 1600, 869, 22, Art.CLAY_LIGHT, 2.6)
	Art.text(self, "GREASY GREECE", Vector2(800, 136), 96, Art.INK, true)
	Art.text(self, "Athens against Sparta. Choose your side, and choose well.", Vector2(800, 190), 28, Art.INK, true)
	# A drip of olive oil off the title, because it IS Greasy Greece.
	var drip := fmod(time * 0.5, 1.0)
	var drip_at := Vector2(1192, 137 + drip * 62.0)
	Art.ellipse(self, drip_at, 4.0 + drip * 2.0, 6.0 + drip * 3.0, Color(Art.GOLD.lerp(Art.CLAY_DARK, 0.2), 1.0 - drip * drip))
	var mouse := get_local_mouse_position()
	for i: int in [Data.ATHENS, Data.SPARTA]:
		_draw_side_card(i, side_rect(i).has_point(mouse))
	Art.text(self, "WASD move   |   Mouse aim   |   Hold left click strike   |   SPACE dash   |   ESC pause   |   M mute", Vector2(800, 829), 24, Art.INK, true)


func _draw_side_card(i: int, hover: bool) -> void:
	var r := side_rect(i)
	var s: Dictionary = Data.SIDES[i]
	var team := Art.AEGEAN if i == Data.ATHENS else Art.CRIMSON
	if hover:
		r = r.grow(6.0)
	draw_rect(r.grow(5.0), Art.GOLD if hover else Art.INK)
	draw_rect(r, Art.INK)
	draw_rect(Rect2(r.position.x, r.position.y, r.size.x, 78), team)
	Art.text(self, String(s["name"]), Vector2(r.position.x + r.size.x * 0.5, r.position.y + 57), 54, Art.CREAM, true, Art.INK)
	Art.text(self, "Press %d" % (i + 1), Vector2(r.end.x - 66, r.position.y + 48), 22, Art.CREAM, true)
	# The soldier stands on a clay panel, like a figure painted on a vase.
	var u := _demo[i]
	var panel_x := r.position.x if i == Data.ATHENS else r.end.x - 226.0
	draw_rect(Rect2(panel_x, r.position.y + 78.0, 226.0, r.size.y - 136.0), Art.CLAY)
	var figure_x := r.position.x + 88.0 if i == Data.ATHENS else r.end.x - 88.0
	u.pos = Vector2(figure_x, r.position.y + 420.0)
	u.scale_f = 3.6
	draw_rect(Rect2(panel_x, r.position.y + 420.0, 226.0, 3.0), Art.INK)
	Art.meander(self, panel_x + 3.0, panel_x + 216.0, r.position.y + 442.0, 20.0, Art.INK, 2.4)
	Art.warrior(self, u, time * 0.55 + float(i))
	draw_set_transform(Vector2.ZERO)
	var col_x := r.position.x + 244.0 if i == Data.ATHENS else r.position.x + 18.0
	var bar_y := r.position.y + 118.0
	var bars: Dictionary = s["bars"]
	for key: String in bars:
		Art.text(self, key, Vector2(col_x, bar_y), 22, Art.CREAM)
		for p in 5:
			var filled: bool = p < int(bars[key])
			draw_rect(Rect2(col_x + 148.0 + float(p) * 39.0, bar_y - 18.0, 33, 20), team.lerp(Art.CREAM, 0.15) if filled else Color(Art.CREAM, 0.13))
		bar_y += 42.0
	var line_y := bar_y + 12.0
	var lines: Array = s["lines"]
	for k in lines.size():
		var col := Art.GOLD if k == 0 else (Art.FIRE if k == lines.size() - 1 else Art.CREAM)
		var font_px := 22 if k == 0 else 20
		var text_line: String = lines[k]
		Art.text(self, text_line, Vector2(col_x, line_y), font_px, col)
		line_y += 36.0
	var plan: Dictionary = Data.BOSS_PLAN[i]
	var final_boss: Dictionary = Data.BOSSES[String(plan[Data.FINAL_ROUND])]
	var name_col := Art.FIRE if hover else Art.CREAM
	Art.text(self, "FINAL BOSS: " + String(final_boss["name"]), Vector2(r.position.x + r.size.x * 0.5, r.end.y - 22.0), 28, name_col, true)


# ------------------------------------------------------------- HUD

func _bar(rect: Rect2, frac: float, col: Color) -> void:
	draw_rect(rect.grow(2.0), Art.CLAY_DARK)
	draw_rect(rect, Color(0, 0, 0, 0.6))
	draw_rect(Rect2(rect.position, Vector2(rect.size.x * clampf(frac, 0.0, 1.0), rect.size.y)), col)


func _draw_hud() -> void:
	var b := battle
	draw_rect(Rect2(0, 0, 1600, 66), Art.INK)
	var ink_text := Art.CREAM
	# City and hero
	Art.text(self, String(Data.SIDES[b.side]["name"]), Vector2(20, 26), 21, ink_text)
	_bar(Rect2(116, 9, 268, 20), b.city_hp / b.city_max, Art.CRIMSON if b.city_hp < b.city_max * 0.3 else Art.BRONZE)
	Art.text(self, "%d / %d" % [int(ceil(b.city_hp)), int(b.city_max)], Vector2(250, 26), 18, Art.CREAM, true, Art.INK, 4)
	Art.text(self, "HERO", Vector2(20, 56), 21, ink_text)
	if b.hero != null and b.hero.dead:
		_bar(Rect2(116, 37, 268, 20), 1.0 - b.respawn_t / 5.0, Color(Art.CREAM, 0.3))
		Art.text(self, "Returning in %.1f" % maxf(b.respawn_t, 0.0), Vector2(250, 54), 18, Art.CREAM, true, Art.INK, 4)
	elif b.hero != null:
		_bar(Rect2(116, 37, 268, 20), b.hero.hp / b.hero.max_hp, Art.AEGEAN_LIGHT if b.side == Data.ATHENS else Art.CRIMSON.lerp(Art.CREAM, 0.15))
		Art.text(self, "%d / %d" % [int(ceil(b.hero.hp)), int(b.hero.max_hp)], Vector2(250, 54), 18, Art.CREAM, true, Art.INK, 4)
	# Army
	Art.text(self, "ARMY", Vector2(408, 26), 21, ink_text)
	Art.text(self, str(b.allies.size()), Vector2(432, 56), 28, Art.GOLD, true)
	# Round
	var round_text := "Round %d of %d" % [maxi(b.round_num, 1), Data.FINAL_ROUND]
	Art.text(self, round_text, Vector2(620, 30), 30, Art.CREAM, true)
	Art.text(self, "%d enemies left" % b.enemies_left(), Vector2(620, 57), 20, Art.CLAY_LIGHT, true)
	# Coins, and how far to the next boon
	var goal := b.coins_goal()
	Art.coin(self, Vector2(824, 34), 18.0)
	Art.text(self, "NEXT BOON", Vector2(854, 26), 19, ink_text)
	_bar(Rect2(854, 37, 340, 20), b.coins / float(goal), Art.GOLD)
	Art.text(self, "%d / %d coins" % [int(b.coins), goal], Vector2(1024, 54), 18, Art.CREAM, true, Art.INK, 5)
	# Score
	Art.text(self, "POINTS", Vector2(1394, 26), 21, ink_text, true)
	Art.text(self, str(b.score), Vector2(1394, 57), 28, Art.GOLD, true)
	Art.text(self, "KILLS", Vector2(1532, 26), 21, ink_text, true)
	Art.text(self, str(b.kills), Vector2(1532, 57), 28, Art.CREAM, true)
	# Boss health
	if b.boss != null and not b.boss.dead:
		var boss_data: Dictionary = Data.BOSSES[b.boss.boss_id]
		var r := Rect2(360, 74, 880, 30)
		draw_rect(r.grow(5.0), Art.INK)
		_bar(r, b.boss.hp / b.boss.max_hp, Art.BLOOD.lerp(Art.FIRE, 0.25))
		Art.text(self, "%s  -  %s" % [String(boss_data["name"]), String(boss_data["title"])], Vector2(800, 97), 22, Art.CREAM, true, Art.INK, 5)
	# Power of the Gods: how much longer spawning stays slowed
	if b.round_num <= b.gods_until_round:
		var label := "POWER OF THE GODS: 0.75x spawn speed, %d more rounds" % b.gods_rounds_left()
		var at := Vector2(1262, 136 if b.boss != null else 96)
		draw_rect(Rect2(at.x - 262, at.y - 22, 590, 32), Art.INK)
		Art.text(self, label, Vector2(at.x + 33, at.y + 2), 20, Art.GOLD, true)


func _draw_banner() -> void:
	var b := battle
	if b.banner_t <= 0.0 or b.banner_text == "":
		return
	var a := clampf(b.banner_t * 2.5, 0.0, 1.0)
	var y := 300.0
	draw_rect(Rect2(0, y - 74, 1600, 118), Color(Art.INK, 0.8 * a))
	var col := Art.GOLD if b.banner_gold else Art.CREAM
	col.a = a
	Art.text(self, b.banner_text, Vector2(800, y), 62, col, true)
	if b.banner_sub != "":
		var sub_col := Color(Art.CLAY_LIGHT, a)
		Art.text(self, b.banner_sub, Vector2(800, y + 34), 25, sub_col, true)


# ------------------------------------------------------------- boon cards

func _draw_cards() -> void:
	draw_rect(Rect2(0, 66, 1600, 834), Color(Art.INK, 0.74))
	var choices: Array = main.choices
	var has_gods := false
	for i in choices.size():
		if choices[i]["id"] == Data.GODS_ID:
			has_gods = true
			# Divine rays go behind every card so all three stay readable.
			var center := card_rect(i).get_center()
			for k in 14:
				var a := time * 0.5 + TAU * float(k) / 14.0
				var p1 := center + Vector2.from_angle(a) * 900.0
				var p2 := center + Vector2.from_angle(a + 0.13) * 900.0
				draw_colored_polygon(PackedVector2Array([center, p1, p2]), Color(Art.GOLD, 0.2))
	var heading := "ZEUS HIMSELF ANSWERS" if has_gods else "THE FATES OFFER THREE BOONS"
	Art.text(self, heading, Vector2(800, 150), 56, Art.GOLD if has_gods else Art.CREAM, true)
	Art.text(self, "Click a card or press 1, 2 or 3", Vector2(800, 196), 25, Art.CLAY_LIGHT, true)
	var mouse := get_local_mouse_position()
	var can_pick: bool = main.choose_delay <= 0.0
	for i in choices.size():
		_draw_card(i, choices[i], can_pick and card_rect(i).has_point(mouse))


func _draw_card(i: int, boon: Dictionary, hover: bool) -> void:
	var r := card_rect(i)
	var intro: float = clampf(1.0 - float(main.choose_delay) / 0.4, 0.0, 1.0)
	r.position.y += (1.0 - intro) * (40.0 + float(i) * 20.0)
	if hover:
		r = r.grow(8.0)
	var rarity: String = boon["rarity"]
	var cat: String = boon["cat"]
	var divine := rarity == "divine"
	var edge := Art.GOLD if divine else (Art.GOLD if rarity == "epic" else (Art.CREAM if rarity == "rare" else Art.CLAY_DARK))
	if hover:
		edge = Art.GOLD
	draw_rect(r.grow(5.0), edge)
	draw_rect(r, Art.CLAY if not divine else Art.CREAM)
	draw_rect(Rect2(r.position, Vector2(r.size.x, 42)), Art.INK)
	var rarity_col := Art.GOLD if rarity == "epic" or divine else (Art.CREAM if rarity == "rare" else Art.CLAY_LIGHT)
	Art.text(self, rarity.to_upper(), r.position + Vector2(r.size.x * 0.5, 30), 23, rarity_col, true)
	var cat_names := {"army": "ARMY", "weapon": "WEAPON", "city": "CITY", "divine": "DIVINE"}
	Art.text(self, String(cat_names[cat]), r.position + Vector2(r.size.x * 0.5, 74), 21, Art.INK, true)
	Art.cat_icon(self, cat, r.position + Vector2(r.size.x * 0.5, 134), time, battle.side)
	draw_set_transform(Vector2.ZERO)
	var name_text: String = boon["name"]
	var name_size := 37 if name_text.length() < 16 else 31
	Art.text(self, name_text, r.position + Vector2(r.size.x * 0.5, 232), name_size, Art.INK, true)
	draw_rect(Rect2(r.position.x + 40, r.position.y + 248, r.size.x - 80, 3), Art.INK)
	Art.wrapped(self, Data.boon_text(boon, battle.side), r.position + Vector2(24, 288), r.size.x - 48.0, 24, Art.INK)
	draw_circle(Vector2(r.position.x + r.size.x * 0.5, r.end.y - 34), 22.0, Art.INK)
	Art.text(self, str(i + 1), Vector2(r.position.x + r.size.x * 0.5, r.end.y - 24), 28, Art.CREAM, true)


# ------------------------------------------------------------- pause and ending

func _draw_pause() -> void:
	draw_rect(Rect2(0, 66, 1600, 834), Color(Art.INK, 0.74))
	Art.text(self, "PAUSED", Vector2(800, 380), 84, Art.CREAM, true)
	Art.text(self, "ESC to resume   |   Q to quit to the menu   |   M to mute", Vector2(800, 450), 28, Art.CLAY_LIGHT, true)


func _draw_end() -> void:
	var won: bool = main.state == "won"
	var b := battle
	var s: Dictionary = Data.SIDES[b.side]
	var f: Dictionary = Data.SIDES[b.foe]
	draw_rect(Rect2(0, 0, 1600, 900), Art.INK if not won else Art.CLAY)
	draw_rect(Rect2(0, 0, 1600, 40), Art.INK)
	Art.meander(self, 0, 1600, 8, 22, Art.CLAY_LIGHT, 2.6)
	draw_rect(Rect2(0, 860, 1600, 40), Art.INK)
	Art.meander(self, 0, 1600, 869, 22, Art.CLAY_LIGHT, 2.6)
	var main_col := Art.INK if won else Art.CRIMSON.lerp(Art.CREAM, 0.15)
	var body_col := Art.INK if won else Art.CREAM
	var plan: Dictionary = Data.BOSS_PLAN[b.side]
	var final_boss: Dictionary = Data.BOSSES[String(plan[Data.FINAL_ROUND])]
	if won:
		Art.text(self, "%s TRIUMPHS" % String(s["name"]), Vector2(800, 270), 104, main_col, true)
		Art.text(self, "%s is dead and the %s have laid down their spears." % [String(final_boss["name"]).capitalize(), String(f["people"])], Vector2(800, 340), 32, body_col, true)
	else:
		Art.text(self, "%s HAS FALLEN" % String(s["name"]), Vector2(800, 270), 104, main_col, true)
		Art.text(self, "The %s have burned your city. You reached round %d of %d." % [String(f["people"]), b.round_num, Data.FINAL_ROUND], Vector2(800, 340), 32, body_col, true)
	Art.text(self, "POINTS: %d" % b.score, Vector2(800, 460), 54, Art.GOLD if not won else Art.INK, true)
	Art.text(self, "Enemies slain: %d     Boons taken: %d     Army left: %d" % [b.kills, b.boons_taken, b.allies.size()], Vector2(800, 520), 30, body_col, true)
	Art.text(self, "Click or press ENTER to return to the menu", Vector2(800, 660), 30, body_col, true)
	if won:
		var hero_art := _demo[b.side]
		hero_art.scale_f = 2.7
		hero_art.pos = Vector2(800, 850)
		hero_art.moving = false
		Art.warrior(self, hero_art, time)
		hero_art.moving = true
		draw_set_transform(Vector2.ZERO)
