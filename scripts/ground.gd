class_name Ground
extends Node2D
## The battlefield, painted once like the curved clay body of a vase.


func _draw() -> void:
	# Soft vertical shading, as if the field wraps around a vase.
	var bands := 26
	for i in bands:
		var f := float(i) / float(bands - 1)
		var shade := Art.CLAY_DARK.lerp(Art.CLAY_LIGHT, 1.0 - absf(f - 0.45) * 1.9)
		draw_rect(Rect2(0, 64.0 + float(i) * 31.0, 1600, 32), shade)
	var rng := RandomNumberGenerator.new()
	rng.seed = 490 # the year of Marathon
	# Grit and brush marks in the clay.
	for i in 900:
		var p := Vector2(rng.randf_range(0, 1600), rng.randf_range(66, 868))
		var col := Art.CLAY_DARK if rng.randf() < 0.6 else Art.CLAY_LIGHT.lerp(Art.CREAM, 0.25)
		col.a = rng.randf_range(0.1, 0.34)
		draw_line(p, p + Vector2(rng.randf_range(3, 16), rng.randf_range(-1, 1)), col, rng.randf_range(1.0, 2.2))
	# Olive trees and rocks, in faint ink so soldiers stay readable.
	for i in 12:
		_olive(Vector2(rng.randf_range(300, 1570), rng.randf_range(110, 850)), rng.randf_range(0.8, 1.25))
	for i in 14:
		var p := Vector2(rng.randf_range(260, 1590), rng.randf_range(90, 860))
		Art.ellipse(self, p, rng.randf_range(8, 19), rng.randf_range(4, 8), Color(Art.INK, 0.15))
	# Ink bands and friezes at the top and bottom.
	draw_rect(Rect2(0, 64, 1600, 6), Art.INK)
	draw_rect(Rect2(0, 862, 1600, 38), Art.INK)
	Art.meander(self, 0, 1600, 870, 22, Art.CLAY_LIGHT, 2.6)


func _olive(at: Vector2, s: float) -> void:
	var ink := Color(Art.INK, 0.17)
	draw_line(at, at + Vector2(3, -30) * s, ink, 6.0 * s)
	draw_circle(at + Vector2(3, -46) * s, 22.0 * s, ink)
	draw_circle(at + Vector2(-13, -35) * s, 13.0 * s, ink)
	draw_circle(at + Vector2(19, -35) * s, 14.0 * s, ink)
