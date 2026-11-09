extends Node
## Ties everything together and handles the switching between screens.

var state := "menu"
var choices: Array = []
var choose_delay := 0.0
var battle: Battle = null
var ground: Ground = null
var ui: GameUI = null
var audio: Sfx = null


func _ready() -> void:
	audio = Sfx.new()
	add_child(audio)
	ground = Ground.new()
	ground.visible = false
	add_child(ground)
	battle = Battle.new()
	battle.sfx = audio
	battle.visible = false
	battle.finished.connect(_on_finished)
	add_child(battle)
	var layer := CanvasLayer.new()
	add_child(layer)
	ui = GameUI.new()
	ui.main = self
	ui.battle = battle
	ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(ui)


func _process(delta: float) -> void:
	choose_delay = maxf(0.0, choose_delay - delta)
	if state == "play" and battle.pending_boons > 0 and battle.boon_hold <= 0.0 and battle.phase != "ending" and battle.phase != "done":
		_open_cards()


func start_game(side: int) -> void:
	audio.play("horn")
	ground.visible = true
	battle.visible = true
	battle.start(side)
	state = "play"


func _open_cards() -> void:
	state = "choose"
	battle.running = false
	choices = Data.roll_boons(battle.side, battle.rng, battle.owned)
	choose_delay = 0.45
	audio.play("boon")


func pick_card(i: int) -> void:
	if i < 0 or i >= choices.size() or choose_delay > 0.0:
		return
	var boon: Dictionary = choices[i]
	battle.pending_boons -= 1
	battle.boons_taken += 1
	battle.apply_boon(String(boon["id"]))
	audio.play("card")
	# Any further boon screens reopen from _process, once the strike has finished.
	state = "play"
	battle.running = true


func _to_menu() -> void:
	battle.running = false
	battle.visible = false
	ground.visible = false
	state = "menu"


func _on_finished(won: bool) -> void:
	battle.visible = false
	ground.visible = false
	state = "won" if won else "lost"
	audio.play("horn" if won else "thunder")


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		_on_key(event.physical_keycode)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_on_click(event.position)


func _on_key(key: Key) -> void:
	if key == KEY_M:
		audio.toggle_mute()
		return
	match state:
		"menu":
			if key == KEY_1:
				start_game(Data.ATHENS)
			elif key == KEY_2:
				start_game(Data.SPARTA)
		"play":
			if key == KEY_ESCAPE:
				state = "pause"
				battle.running = false
		"pause":
			if key == KEY_ESCAPE:
				state = "play"
				battle.running = true
			elif key == KEY_Q:
				_to_menu()
		"choose":
			if key == KEY_1:
				pick_card(0)
			elif key == KEY_2:
				pick_card(1)
			elif key == KEY_3:
				pick_card(2)
		"won", "lost":
			if key == KEY_ENTER or key == KEY_KP_ENTER or key == KEY_SPACE:
				_to_menu()


func _on_click(at: Vector2) -> void:
	match state:
		"menu":
			for i: int in [Data.ATHENS, Data.SPARTA]:
				if ui.side_rect(i).has_point(at):
					start_game(i)
					return
		"choose":
			for i in choices.size():
				if ui.card_rect(i).has_point(at):
					pick_card(i)
					return
		"won", "lost":
			_to_menu()
