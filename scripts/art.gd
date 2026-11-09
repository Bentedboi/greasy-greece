class_name Art
extends RefCounted
## All drawing, in the style of an ancient Greek black-figure vase. No image files.

const INK := Color(0.09, 0.066, 0.05)
const CLAY := Color(0.79, 0.42, 0.2)
const CLAY_LIGHT := Color(0.87, 0.53, 0.29)
const CLAY_DARK := Color(0.62, 0.3, 0.14)
const CREAM := Color(0.96, 0.89, 0.72)
const BRONZE := Color(0.85, 0.62, 0.25)
const GOLD := Color(1.0, 0.8, 0.28)
const FIRE := Color(1.0, 0.5, 0.12)
const BLOOD := Color(0.62, 0.08, 0.06)
const AEGEAN := Color(0.13, 0.42, 0.66)
const AEGEAN_LIGHT := Color(0.42, 0.73, 0.92)
const CRIMSON := Color(0.74, 0.1, 0.09)
const SHADOW := Color(0.09, 0.066, 0.05, 0.26)

static var _font: Font = null


static func font() -> Font:
	if _font == null:
		var f := SystemFont.new()
		f.font_names = PackedStringArray(["Palatino Linotype", "Book Antiqua", "Georgia", "Times New Roman"])
		f.font_weight = 700
		_font = f
	return _font


static func text(c: CanvasItem, s: String, at: Vector2, size: int, col: Color, centered: bool = false, outline: Color = Color(0, 0, 0, 0), outline_size: int = 5) -> void:
	var f := font()
	var p := at
	if centered:
		p.x -= f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x * 0.5
	if outline.a > 0.0:
		c.draw_string_outline(f, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, outline_size, outline)
	c.draw_string(f, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


## Word-wraps text inside a width, respecting \n, and returns the y below the last line.
static func wrapped(c: CanvasItem, s: String, at: Vector2, width: float, size: int, col: Color) -> float:
	var f := font()
	var y := at.y
	for para in s.split("\n"):
		var line := ""
		for word in para.split(" "):
			var attempt := word if line == "" else line + " " + word
			if f.get_string_size(attempt, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > width and line != "":
				text(c, line, Vector2(at.x + width * 0.5, y), size, col, true)
				y += float(size) * 1.32
				line = word
			else:
				line = attempt
		if line != "":
			text(c, line, Vector2(at.x + width * 0.5, y), size, col, true)
			y += float(size) * 1.32
	return y


static func ellipse_points(center: Vector2, rx: float, ry: float, n: int = 20) -> PackedVector2Array:
	var pts := PackedVector2Array()
	pts.resize(n)
	for i in n:
		var a := TAU * float(i) / float(n)
		pts[i] = center + Vector2(cos(a) * rx, sin(a) * ry)
	return pts


static func ellipse(c: CanvasItem, center: Vector2, rx: float, ry: float, col: Color) -> void:
	c.draw_colored_polygon(ellipse_points(center, rx, ry), col)


static func poly(c: CanvasItem, col: Color, pts: Array) -> void:
	c.draw_colored_polygon(PackedVector2Array(pts), col)


# ------------------------------------------------------------- soldiers

static func _team_color(faction: int) -> Color:
	return AEGEAN if faction == Data.ATHENS else CRIMSON


static func _emblem(c: CanvasItem, center: Vector2, r: float, faction: int) -> void:
	if faction == Data.SPARTA:
		# The lambda, for Lacedaemon, that Spartans painted on their shields.
		c.draw_line(center + Vector2(0, -r * 0.62), center + Vector2(-r * 0.5, r * 0.56), CREAM, r * 0.2)
		c.draw_line(center + Vector2(0, -r * 0.62), center + Vector2(r * 0.5, r * 0.56), CREAM, r * 0.2)
	else:
		# Athena's owl.
		c.draw_circle(center + Vector2(-r * 0.3, -r * 0.1), r * 0.27, CREAM)
		c.draw_circle(center + Vector2(r * 0.3, -r * 0.1), r * 0.27, CREAM)
		c.draw_circle(center + Vector2(-r * 0.3, -r * 0.1), r * 0.12, INK)
		c.draw_circle(center + Vector2(r * 0.3, -r * 0.1), r * 0.12, INK)
		poly(c, GOLD, [center + Vector2(-r * 0.12, r * 0.12), center + Vector2(r * 0.12, r * 0.12), center + Vector2(0, r * 0.42)])


static func _shield(c: CanvasItem, center: Vector2, r: float, faction: int, ink: Color) -> void:
	c.draw_circle(center, r + 1.6, ink)
	c.draw_circle(center, r, BRONZE)
	c.draw_circle(center, r * 0.82, _team_color(faction))
	_emblem(c, center, r * 0.82, faction)


static func warrior(c: CanvasItem, u: Unit, t: float) -> void:
	var s := u.scale_f
	# Ground marks: yours glow pale, the enemy's are dark, the hero's is gold.
	var mark := Color(CREAM, 0.4) if u.team == 0 else Color(INK, 0.3)
	c.draw_set_transform(Vector2.ZERO)
	ellipse(c, u.pos, 15.0 * s, 6.0 * s, mark)
	if u.is_hero:
		var pts := ellipse_points(u.pos, 25.0 + 2.0 * sin(t * 5.0), 11.0, 24)
		pts.append(pts[0])
		c.draw_polyline(pts, GOLD, 3.0)
	if u.is_boss:
		var pts := ellipse_points(u.pos, 24.0 * s, 9.0 * s, 28)
		pts.append(pts[0])
		c.draw_polyline(pts, BLOOD, 3.5)

	c.draw_set_transform(u.pos, 0.0, Vector2(s * u.face, s))
	var ink := INK.lerp(Color(1.0, 0.88, 0.75), clampf(u.hurt, 0.0, 1.0) * 0.8)
	var swing := sin(t * 11.0 + u.phase) if u.moving else 0.0
	var bob := absf(swing) * 1.2
	var hip := Vector2(0, -19.0 - bob)
	var armored := u.kind == "elite"
	var hoplite := u.kind == "hoplite"
	var team := _team_color(u.faction)
	var is_them := u.boss_id == "themistocles" or u.boss_id == "pericles" or u.boss_id == "cleon"

	# Cloak streams behind the body.
	if u.faction == Data.SPARTA and (armored or hoplite) or u.is_boss or u.is_hero:
		var flutter := sin(t * 6.0 + u.phase) * 3.0
		var cloak := (CREAM if is_them else team) if u.is_boss else team
		cloak = cloak.lerp(INK, 0.1)
		poly(c, cloak, [Vector2(-3, -34 - bob), Vector2(-9, -6 + flutter), Vector2(-16 - flutter, -3), Vector2(-7, -33 - bob)])

	# Legs, with bronze greaves on armoured soldiers.
	var foot_a := Vector2(swing * 9.0, -maxf(0.0, -swing) * 3.0)
	var foot_b := Vector2(-swing * 9.0, -maxf(0.0, swing) * 3.0)
	c.draw_line(hip, foot_b, ink, 3.6)
	c.draw_line(hip, foot_a, ink, 3.6)
	if armored or hoplite:
		c.draw_line(hip.lerp(foot_a, 0.55), foot_a, BRONZE, 2.5)
		c.draw_line(hip.lerp(foot_b, 0.55), foot_b, BRONZE, 2.5)

	# Tunic.
	var kilt := team.lerp(CREAM, 0.15) if u.kind != "merc" else CLAY_DARK.lerp(INK, 0.3)
	poly(c, kilt, [hip + Vector2(-5, -2), hip + Vector2(5, -2), hip + Vector2(8, 6), hip + Vector2(-8, 6)])

	# Body. Armour shows as a bronze cuirass with incised muscle lines.
	var top := -33.0 - bob
	var torso := [Vector2(-5.2, -19 - bob), Vector2(5.2, -19 - bob), Vector2(6.6, top), Vector2(-6.6, top)]
	if armored:
		poly(c, BRONZE.lerp(ink, clampf(u.hurt, 0.0, 1.0) * 0.5), torso)
		c.draw_line(Vector2(0, top + 1), Vector2(0, -21 - bob), INK, 1.0)
		c.draw_line(Vector2(-5, -27 - bob), Vector2(5, -27 - bob), INK, 1.0)
	else:
		poly(c, ink, torso)
		if hoplite:
			c.draw_line(Vector2(-5, -24 - bob), Vector2(5, -24 - bob), BRONZE, 1.6)

	# Head and headgear.
	var head := Vector2(0.5, -38.5 - bob)
	c.draw_circle(head, 5.3, ink)
	if u.kind == "merc":
		if u.rebel:
			c.draw_line(head + Vector2(-6, -2), head + Vector2(6, -2), BLOOD, 3.0)
		elif u.faction == Data.ATHENS:
			# Thracian fox-skin cap.
			poly(c, CLAY_DARK, [head + Vector2(-5.5, 0), head + Vector2(5, -1), head + Vector2(1, -11), head + Vector2(-5, -9)])
		else:
			# Arcadian felt cap.
			poly(c, CREAM.lerp(CLAY, 0.45), [head + Vector2(-6, -1), head + Vector2(6, -1), head + Vector2(0, -9)])
	elif u.kind == "ranged":
		if u.faction == Data.ATHENS:
			# Scythian pointed hood.
			poly(c, team, [head + Vector2(-6, 2), head + Vector2(5, -2), head + Vector2(-6, -15)])
		else:
			c.draw_line(head + Vector2(-6, -2), head + Vector2(6, -2), CREAM, 2.0)
	else:
		_helmet(c, head, armored, u, team, t)

	# Weapon arm.
	var shoulder := Vector2(3.5, -30.0 - bob)
	var aim_local := Vector2(absf(u.aim.x), u.aim.y)
	if aim_local.length() < 0.1:
		aim_local = Vector2.RIGHT
	aim_local = aim_local.normalized()
	if not u.is_hero and not u.ranged and u.atk <= 0.0:
		aim_local = Vector2(0.7, -0.7)
	var thrust := sin(clampf(u.atk, 0.0, 1.0) * PI) * 13.0
	var hand := shoulder + aim_local * (7.0 + thrust)
	if u.kind == "ranged":
		var bow_at := shoulder + aim_local * 9.0
		var ang := aim_local.angle()
		c.draw_line(shoulder, bow_at, ink, 2.6)
		if u.faction == Data.ATHENS:
			c.draw_arc(bow_at, 12.0, ang - 1.15, ang + 1.15, 12, ink, 2.0)
			c.draw_line(bow_at + Vector2.from_angle(ang - 1.15) * 12.0, bow_at + Vector2.from_angle(ang + 1.15) * 12.0, CREAM, 1.0)
		else:
			var sling := Vector2.from_angle(t * 9.0 + u.phase) * 11.0
			c.draw_line(bow_at, bow_at + sling, CREAM, 1.2)
			c.draw_circle(bow_at + sling, 2.2, ink)
	else:
		c.draw_line(shoulder, hand, ink, 2.8)
		var length := 18.0 if u.kind == "merc" else 36.0
		var butt := hand - aim_local * (length * 0.34)
		var tip := hand + aim_local * length
		c.draw_line(butt, tip, ink, 2.0)
		var side_v := Vector2(-aim_local.y, aim_local.x)
		poly(c, BRONZE, [tip + aim_local * 7.0, tip + side_v * 2.6, tip - side_v * 2.6])

	# Shield in front.
	if armored:
		_shield(c, Vector2(5.0, -26.0 - bob), 11.5, u.faction, ink)
	elif hoplite:
		_shield(c, Vector2(5.0, -25.0 - bob), 10.0, u.faction, ink)
	elif u.kind == "merc" and not u.rebel:
		c.draw_arc(Vector2(5.0, -25.0 - bob), 6.5, -1.4, 1.4, 10, CREAM.lerp(CLAY, 0.4), 3.2)

	c.draw_set_transform(Vector2.ZERO)
	# Health bars for anyone who can survive a hit.
	if not u.one_shot and not u.is_boss and u.hp < u.max_hp:
		var w := 30.0 * s
		var y := u.pos.y - 62.0 * s
		c.draw_rect(Rect2(u.pos.x - w * 0.5 - 1.0, y - 1.0, w + 2.0, 6.0), INK)
		var col := CREAM if u.team == 0 else BLOOD.lerp(FIRE, 0.4)
		c.draw_rect(Rect2(u.pos.x - w * 0.5, y, w * clampf(u.hp / u.max_hp, 0.0, 1.0), 4.0), col)


static func _helmet(c: CanvasItem, head: Vector2, armored: bool, u: Unit, team: Color, t: float) -> void:
	var metal := GOLD if u.is_hero or u.is_boss else BRONZE
	if armored:
		# Corinthian helmet with a tall horsehair crest.
		poly(c, metal, [head + Vector2(-6, -7), head + Vector2(6, -7), head + Vector2(7, 2), head + Vector2(4.5, 6.5), head + Vector2(2, 2), head + Vector2(-6, 6)])
		c.draw_circle(head + Vector2(3.4, -1.4), 1.2, INK)
		var crest := team
		if u.is_hero:
			crest = GOLD
		elif u.boss_id == "leonidas":
			crest = GOLD
		var wave := sin(t * 7.0 + u.phase) * 1.2
		poly(c, crest, [head + Vector2(5, -6), head + Vector2(3, -16), head + Vector2(-5, -18 + wave), head + Vector2(-12, -10 + wave), head + Vector2(-7, -5)])
		poly(c, INK, [head + Vector2(5, -6), head + Vector2(3, -8), head + Vector2(-6, -7), head + Vector2(-7, -5)])
		if u.is_boss:
			poly(c, INK, [head + Vector2(1, 6), head + Vector2(6, 5), head + Vector2(3.5, 11)])
	else:
		# Plain bronze helmet with a low crest.
		poly(c, metal, [head + Vector2(-6, -5), head + Vector2(6, -5), head + Vector2(6, 2), head + Vector2(-6, 3)])
		poly(c, team, [head + Vector2(4, -5), head + Vector2(0, -11), head + Vector2(-8, -8), head + Vector2(-6, -4)])


# ------------------------------------------------------------- projectiles, ships

static func projectile(c: CanvasItem, p: Dictionary) -> void:
	var pos: Vector2 = p["pos"]
	var dir: Vector2 = (p["vel"] as Vector2).normalized()
	match String(p["kind"]):
		"bolt":
			c.draw_line(pos - dir * 40.0, pos, CREAM, 6.0)
			c.draw_line(pos - dir * 40.0, pos, INK, 3.0)
			c.draw_circle(pos, 4.0, GOLD)
		"javelin":
			c.draw_line(pos - dir * 26.0, pos, INK, 2.6)
			c.draw_line(pos - dir * 6.0, pos, GOLD, 3.2)
		_:
			var col := CREAM if int(p["team"]) == 0 else INK
			c.draw_line(pos - dir * 15.0, pos, col, 2.2)
			c.draw_circle(pos, 2.0, BRONZE)


static func trireme(c: CanvasItem, at: Vector2, t: float) -> void:
	var y := at.y
	var x := at.x
	# Oars.
	for i in 8:
		var ox := x - 46.0 + float(i) * 26.0
		var sweep := sin(t * 18.0 + float(i) * 0.5) * 11.0
		c.draw_line(Vector2(ox, y + 8.0), Vector2(ox + sweep, y + 46.0), INK, 3.0)
	# Hull, with its bronze ram pointing left.
	poly(c, INK, [Vector2(x - 170, y + 16), Vector2(x - 110, y - 14), Vector2(x + 130, y - 20), Vector2(x + 180, y - 58), Vector2(x + 175, y - 18), Vector2(x + 130, y + 22), Vector2(x - 110, y + 22)])
	poly(c, BRONZE, [Vector2(x - 190, y + 15), Vector2(x - 130, y + 2), Vector2(x - 130, y + 22)])
	# The painted eye on the bow.
	c.draw_circle(Vector2(x - 92, y - 3), 9.0, CREAM)
	c.draw_circle(Vector2(x - 94, y - 3), 4.0, INK)
	c.draw_line(Vector2(x - 72, y - 11), Vector2(x + 128, y - 13), CREAM, 2.0)
	# Mast and sail.
	c.draw_line(Vector2(x + 20, y - 18), Vector2(x + 20, y - 112), INK, 5.0)
	poly(c, AEGEAN, [Vector2(x - 34, y - 106), Vector2(x + 74, y - 106), Vector2(x + 66, y - 36), Vector2(x - 26, y - 36)])
	_emblem(c, Vector2(x + 20, y - 70), 24.0, Data.ATHENS)


# ------------------------------------------------------------- the city

static func tower(c: CanvasItem, y: float, kind: String, faction: int) -> void:
	var x := Battle.WALL_X - 34.0
	var stone := CREAM.lerp(CLAY, 0.18) if faction == Data.ATHENS else CLAY_DARK.lerp(INK, 0.2)
	c.draw_rect(Rect2(x - 3, y - 76, 62, 92), INK)
	c.draw_rect(Rect2(x, y - 73, 56, 86), stone)
	for i in 4:
		c.draw_rect(Rect2(x - 2 + float(i) * 16.0, y - 86, 11, 12), INK)
	if kind == "oxybeles":
		c.draw_line(Vector2(x + 10, y - 44), Vector2(x + 64, y - 54), INK, 6.0)
		c.draw_arc(Vector2(x + 28, y - 48), 22.0, -1.3, 1.3, 12, BRONZE, 4.0)
	else:
		c.draw_rect(Rect2(x + 22, y - 54, 12, 22), INK)


static func city(c: CanvasItem, faction: int, frac: float, t: float) -> void:
	var w := Battle.WALL_X
	if faction == Data.ATHENS:
		_athens(c, w)
	else:
		_sparta(c, w)
	# The worse the damage, the more of the city burns.
	if frac < 0.72:
		var fires := 3 if frac >= 0.45 else (6 if frac >= 0.22 else 10)
		for i in fires:
			var fx := 26.0 + fmod(float(i) * 73.0, w - 40.0)
			var fy := 150.0 + fmod(float(i) * 197.0, 660.0)
			_flame(c, Vector2(fx, fy), t + float(i) * 1.7, 0.9 + fmod(float(i), 3.0) * 0.28)


static func _flame(c: CanvasItem, at: Vector2, t: float, s: float) -> void:
	var f := sin(t * 11.0) * 3.0
	poly(c, FIRE, [at + Vector2(-11, 0) * s, at + Vector2(11, 0) * s, at + Vector2(4 + f, -18) * s, at + Vector2(f, -32) * s, at + Vector2(-5, -17) * s])
	poly(c, GOLD, [at + Vector2(-5, 0) * s, at + Vector2(5, 0) * s, at + Vector2(f * 0.5, -15) * s])


static func _athens(c: CanvasItem, w: float) -> void:
	c.draw_rect(Rect2(0, 64, w, 806), CLAY_DARK.lerp(CLAY, 0.45))
	# The Acropolis and the Parthenon.
	var rock := CLAY_DARK.lerp(INK, 0.45)
	poly(c, rock, [Vector2(0, 468), Vector2(0, 322), Vector2(22, 300), Vector2(150, 296), Vector2(176, 468)])
	# Incised contour lines on the rock, and the path up to the temple.
	for k in 4:
		var ly := 330.0 + float(k) * 34.0
		c.draw_line(Vector2(0, ly), Vector2(150.0 + float(k) * 6.0, ly + 5.0), Color(CREAM, 0.26), 2.0)
	c.draw_polyline(PackedVector2Array([Vector2(112, 468), Vector2(64, 430), Vector2(120, 392), Vector2(70, 352), Vector2(100, 300)]), Color(CREAM, 0.75), 4.0)
	_house(c, Vector2(16, 552), CREAM.lerp(CLAY, 0.3))
	_house(c, Vector2(104, 530), CREAM.lerp(CLAY, 0.3))
	var x := 14.0
	var y := 296.0
	c.draw_rect(Rect2(x, y - 9, 150, 9), CREAM)
	for i in 7:
		c.draw_rect(Rect2(x + 6.0 + float(i) * 21.6, y - 64, 9, 56), CREAM)
	c.draw_rect(Rect2(x - 2, y - 76, 154, 11), CREAM)
	poly(c, CREAM, [Vector2(x - 6, y - 76), Vector2(x + 156, y - 76), Vector2(x + 75, y - 112)])
	poly(c, AEGEAN, [Vector2(x + 18, y - 80), Vector2(x + 132, y - 80), Vector2(x + 75, y - 104)])
	# Houses below the rock.
	for h: Vector2 in [Vector2(20, 660), Vector2(92, 636), Vector2(36, 760), Vector2(118, 740), Vector2(24, 190), Vector2(112, 150), Vector2(70, 830)]:
		_house(c, h, CREAM.lerp(CLAY, 0.3))
	# The Long Walls: thick stone with battlements.
	c.draw_rect(Rect2(w - 34, 64, 34, 806), INK)
	c.draw_rect(Rect2(w - 31, 64, 27, 806), CREAM.lerp(CLAY, 0.2))
	var row := 0
	var by := 64.0
	while by < 870.0:
		c.draw_line(Vector2(w - 31, by), Vector2(w - 4, by), Color(INK, 0.55), 1.5)
		var bx := w - 31.0 + (13.0 if row % 2 == 0 else 5.0)
		c.draw_line(Vector2(bx, by), Vector2(bx, by + 22.0), Color(INK, 0.55), 1.5)
		by += 22.0
		row += 1
	var cy := 72.0
	while cy < 866.0:
		c.draw_rect(Rect2(w - 2, cy, 10, 18), INK)
		cy += 36.0


static func _sparta(c: CanvasItem, w: float) -> void:
	c.draw_rect(Rect2(0, 64, w, 806), CLAY_DARK.lerp(CLAY, 0.35))
	# The Taygetus mountains behind an unwalled village.
	poly(c, INK.lerp(CLAY_DARK, 0.5), [Vector2(0, 340), Vector2(0, 120), Vector2(58, 196), Vector2(96, 110), Vector2(160, 260), Vector2(186, 340)])
	poly(c, CREAM, [Vector2(96, 110), Vector2(83, 142), Vector2(98, 134), Vector2(110, 146)])
	poly(c, CREAM, [Vector2(0, 120), Vector2(0, 160), Vector2(26, 160)])
	# The small temple of Artemis Orthia.
	var x := 44.0
	var y := 470.0
	c.draw_rect(Rect2(x - 26, y - 92, 118, 92), INK)
	for i in 4:
		c.draw_rect(Rect2(x - 18 + float(i) * 28.0, y - 72, 8, 62), CREAM.lerp(CLAY, 0.25))
	poly(c, CRIMSON, [Vector2(x - 32, y - 92), Vector2(x + 98, y - 92), Vector2(x + 33, y - 124)])
	for h: Vector2 in [Vector2(20, 590), Vector2(106, 548), Vector2(40, 690), Vector2(124, 660), Vector2(22, 800), Vector2(108, 780), Vector2(126, 390)]:
		_house(c, h, CLAY_LIGHT.lerp(INK, 0.3))
	# No real walls, famously. Only a scrappy wooden fence.
	var py := 66.0
	var i2 := 0
	while py < 866.0:
		var stake := 14.0 + fmod(float(i2) * 7.0, 11.0)
		c.draw_line(Vector2(w - 8, py), Vector2(w - 8 + stake * 0.9, py + 3.0), INK, 5.0)
		py += 24.0
		i2 += 1
	c.draw_line(Vector2(w - 8, 64), Vector2(w - 8, 868), INK, 4.0)


static func _house(c: CanvasItem, at: Vector2, wall: Color) -> void:
	c.draw_rect(Rect2(at.x, at.y - 28, 52, 28), INK)
	c.draw_rect(Rect2(at.x + 2, at.y - 26, 48, 24), wall)
	c.draw_rect(Rect2(at.x + 20, at.y - 18, 11, 16), INK)
	poly(c, INK, [at + Vector2(-5, -26), at + Vector2(57, -26), at + Vector2(26, -46)])


# ------------------------------------------------------------- ornament

## A running Greek-key frieze. The classic border of every Greek vase.
static func meander(c: CanvasItem, x0: float, x1: float, y: float, cell: float, col: Color, width: float = 3.0) -> void:
	var x := x0
	while x < x1:
		var pts := PackedVector2Array([
			Vector2(x, y + cell),
			Vector2(x, y),
			Vector2(x + cell * 0.82, y),
			Vector2(x + cell * 0.82, y + cell * 0.72),
			Vector2(x + cell * 0.28, y + cell * 0.72),
			Vector2(x + cell * 0.28, y + cell * 0.32),
			Vector2(x + cell * 0.54, y + cell * 0.32),
		])
		c.draw_polyline(pts, col, width)
		c.draw_line(Vector2(x, y + cell), Vector2(x + cell, y + cell), col, width)
		x += cell


static func coin(c: CanvasItem, at: Vector2, r: float) -> void:
	c.draw_circle(at, r + 1.5, INK)
	c.draw_circle(at, r, GOLD)
	c.draw_circle(at, r * 0.62, BRONZE)
	c.draw_circle(at + Vector2(-r * 0.2, -r * 0.1), r * 0.14, INK)
	c.draw_circle(at + Vector2(r * 0.2, -r * 0.1), r * 0.14, INK)


static func cat_color(cat: String) -> Color:
	match cat:
		"army":
			return CRIMSON
		"weapon":
			return AEGEAN
		"city":
			return CLAY_DARK
		"divine":
			return GOLD
	return INK


static func cat_icon(c: CanvasItem, cat: String, at: Vector2, t: float, faction: int) -> void:
	match cat:
		"army":
			_shield(c, at, 32.0, faction, INK)
		"weapon":
			c.draw_line(at + Vector2(-32, 32), at + Vector2(24, -24), INK, 6.0)
			poly(c, BRONZE, [at + Vector2(38, -38), at + Vector2(14, -26), at + Vector2(26, -14)])
			poly(c, INK, [at + Vector2(-38, 38), at + Vector2(-28, 22), at + Vector2(-22, 28)])
		"city":
			c.draw_rect(Rect2(at.x - 36, at.y + 22, 72, 8), INK)
			c.draw_rect(Rect2(at.x - 33, at.y - 12, 66, 7), INK)
			for i in 4:
				c.draw_rect(Rect2(at.x - 29.0 + float(i) * 18.0, at.y - 5, 8, 27), INK)
			poly(c, INK, [at + Vector2(-38, -14), at + Vector2(38, -14), at + Vector2(0, -36)])
		"divine":
			var pulse := 1.0 + sin(t * 6.0) * 0.08
			var bolt := PackedVector2Array([at + Vector2(10, -40) * pulse, at + Vector2(-16, 4) * pulse, at + Vector2(0, 4) * pulse, at + Vector2(-12, 40) * pulse, at + Vector2(20, -8) * pulse, at + Vector2(3, -8) * pulse])
			c.draw_colored_polygon(bolt, CREAM)
			var outline := bolt.duplicate()
			outline.append(bolt[0])
			c.draw_polyline(outline, INK, 3.0)
