class_name Unit
extends RefCounted
## One soldier on the field. Plain data: Battle simulates it and Art draws it.

var team := 0 # 0 = the player's side, 1 = the enemy
var faction := 0
var kind := "merc"
var pos := Vector2.ZERO
var knock := Vector2.ZERO
var hp := 1.0
var max_hp := 1.0
var armor := 0.0
var dmg := 1.0
var speed := 100.0
var reach := 30.0
var cd_max := 1.0
var cd := 0.0
var ranged := false
var one_shot := false
var coins := 1
var scale_f := 1.0
var radius := 14.0
var face := 1.0
var phase := 0.0
var moving := false
var atk := 0.0
var hurt := 0.0
var aim := Vector2.RIGHT
var dead := false
var is_hero := false
var is_boss := false
var rebel := false
var boss_id := ""
var abilities: Array = []
var target: Unit = null
var retarget := 0.0
var slot := Vector2.ZERO
var state := "walk"
var state_t := 0.0
var boss_cd := 3.0
var dir := Vector2.RIGHT
var hit_ids := {}
var summons_left: Array = []
var ability_index := 0
