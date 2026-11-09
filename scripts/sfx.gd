class_name Sfx
extends Node
## Every sound and the music are synthesized when the game starts. No audio files.

const RATE := 22050
const VOICES := 14

var _streams := {}
var _last := {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _music: AudioStreamPlayer = null
var muted := false
var _enabled := false


func _ready() -> void:
	_enabled = DisplayServer.get_name() != "headless"
	if not _enabled:
		return
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	_streams["hit"] = _make(0.1, _s_hit)
	_streams["clang"] = _make(0.28, _s_clang)
	_streams["swing"] = _make(0.13, _s_swing)
	_streams["coin"] = _make(0.14, _s_coin)
	_streams["hurt"] = _make(0.16, _s_hurt)
	_streams["boon"] = _make(0.6, _s_boon)
	_streams["horn"] = _make(1.1, _s_horn)
	_streams["thunder"] = _make(2.0, _s_thunder)
	_streams["slam"] = _make(0.55, _s_slam)
	_streams["fire"] = _make(0.5, _s_fire)
	_streams["shoot"] = _make(0.11, _s_shoot)
	_streams["dash"] = _make(0.2, _s_dash)
	_streams["wall"] = _make(0.18, _s_wall)
	_streams["card"] = _make(0.1, _s_card)
	_music = AudioStreamPlayer.new()
	_music.stream = _make_music()
	_music.volume_db = -9.0
	add_child(_music)
	_music.play()


func play(sound_name: String) -> void:
	if not _enabled or muted or not _streams.has(sound_name):
		return
	var now := Time.get_ticks_msec()
	if now - int(_last.get(sound_name, -1000)) < 55:
		return
	_last[sound_name] = now
	var p := _players[_next]
	_next = (_next + 1) % VOICES
	p.stream = _streams[sound_name]
	p.pitch_scale = randf_range(0.92, 1.08)
	p.volume_db = -7.0
	p.play()


func toggle_mute() -> void:
	muted = not muted
	if _music:
		_music.volume_db = -80.0 if muted else -9.0


func _make(seconds: float, gen: Callable) -> AudioStreamWAV:
	var n := int(seconds * RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var t := float(i) / RATE
		var v: float = gen.call(t, t / seconds)
		data.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 30000.0))
	return _wav(data)


func _wav(data: PackedByteArray) -> AudioStreamWAV:
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	return w


func _s_hit(t: float, u: float) -> float:
	return (randf_range(-1, 1) * 0.5 + sin(TAU * 150.0 * t)) * pow(1.0 - u, 3.0) * 0.8


func _s_clang(t: float, u: float) -> float:
	var v := sin(TAU * 1340.0 * t) + sin(TAU * 2110.0 * t) * 0.7 + sin(TAU * 3170.0 * t) * 0.45
	return (v * 0.32 + randf_range(-1, 1) * maxf(0.0, 0.4 - u * 4.0)) * pow(1.0 - u, 3.2)


func _s_swing(_t: float, u: float) -> float:
	return randf_range(-1, 1) * sin(u * PI) * 0.34


func _s_coin(t: float, u: float) -> float:
	var f := 1500.0 if u < 0.35 else 2010.0
	return sin(TAU * f * t) * pow(1.0 - u, 2.0) * 0.26


func _s_hurt(t: float, u: float) -> float:
	return sin(TAU * lerpf(190.0, 60.0, u) * t) * pow(1.0 - u, 2.0) * 0.8


func _s_boon(t: float, u: float) -> float:
	var notes := [293.66, 349.23, 440.0, 587.33]
	var f: float = notes[mini(int(u * 4.0), 3)]
	return _pluck(f, fmod(t, 0.15)) * 0.7


func _s_horn(t: float, u: float) -> float:
	var f := 146.83 + sin(t * 30.0) * 1.4
	var v := sin(TAU * f * t) + sin(TAU * f * 2.0 * t) * 0.6 + sin(TAU * f * 3.0 * t) * 0.35 + sin(TAU * f * 4.0 * t) * 0.15
	return v * minf(u * 8.0, 1.0) * pow(1.0 - u, 0.7) * 0.34


var _thunder_low := 0.0


func _s_thunder(_t: float, u: float) -> float:
	_thunder_low = lerpf(_thunder_low, randf_range(-1, 1), 0.06)
	var crack := randf_range(-1, 1) * maxf(0.0, 1.0 - u * 12.0)
	return clampf(_thunder_low * 3.6 * pow(1.0 - u, 1.4) + crack * 0.7, -1.0, 1.0)


func _s_slam(t: float, u: float) -> float:
	return (sin(TAU * lerpf(100.0, 36.0, u) * t) + randf_range(-1, 1) * maxf(0.0, 0.5 - u)) * pow(1.0 - u, 2.0)


var _fire_low := 0.0


func _s_fire(_t: float, u: float) -> float:
	_fire_low = lerpf(_fire_low, randf_range(-1, 1), 0.25)
	return _fire_low * 1.6 * sin(minf(u * 8.0, 1.0) * PI * 0.5) * pow(1.0 - u, 1.1)


func _s_shoot(t: float, u: float) -> float:
	return (sin(TAU * lerpf(620.0, 240.0, u) * t) * 0.36 + randf_range(-1, 1) * 0.1) * pow(1.0 - u, 2.0)


func _s_dash(_t: float, u: float) -> float:
	return randf_range(-1, 1) * sin(u * PI) * 0.26


func _s_wall(t: float, u: float) -> float:
	return (sin(TAU * 92.0 * t) * 0.7 + randf_range(-1, 1) * 0.3) * pow(1.0 - u, 3.0)


func _s_card(t: float, u: float) -> float:
	return sin(TAU * 880.0 * t) * pow(1.0 - u, 3.0) * 0.3


func _pluck(f: float, t: float) -> float:
	var v := sin(TAU * f * t) + sin(TAU * f * 2.0 * t) * 0.45 + sin(TAU * f * 3.01 * t) * 0.2
	return v * exp(-t * 6.5) * 0.46


## A looping march for lyre and frame drum, in the D Dorian mode.
func _make_music() -> AudioStreamWAV:
	var beat := 60.0 / 104.0 / 2.0
	var dorian: Array[float] = [146.83, 164.81, 174.61, 196.0, 220.0, 246.94, 261.63, 293.66, 329.63, 349.23, 392.0, 440.0]
	var melody: Array[int] = [
		7, -1, 7, 9, 10, 9, 7, -1, 6, -1, 4, 6, 7, -1, -1, -1,
		7, -1, 9, 10, 11, 10, 9, -1, 10, 9, 7, 6, 7, -1, -1, -1,
		4, -1, 4, 6, 7, 6, 4, 3, 2, -1, 3, 4, 3, 2, 0, -1,
		4, 6, 7, 9, 10, -1, 9, 7, 6, 4, 6, 7, 7, -1, -1, -1,
	]
	var bass: Array[int] = [0, 0, 3, 0, 0, 0, 4, 0, 3, 3, 0, 0, 3, 4, 0, 0]
	var total := int(float(melody.size()) * beat * RATE)
	var mix := PackedFloat32Array()
	mix.resize(total)
	for i in melody.size():
		var start := int(float(i) * beat * RATE)
		if melody[i] >= 0:
			_add_note(mix, start, dorian[melody[i]], 0.75, 0.42)
		if i % 4 == 0:
			var root := dorian[bass[int(i * 0.25)]] * 0.5
			_add_note(mix, start, root, 1.3, 0.34)
			_add_note(mix, start, root * 1.5, 1.0, 0.18)
		if i % 4 == 0 or i % 8 == 3 or i % 8 == 6:
			_add_drum(mix, start, 0.85 if i % 8 == 0 else 0.5)
	var data := PackedByteArray()
	data.resize(total * 2)
	for i in total:
		data.encode_s16(i * 2, int(clampf(mix[i], -1.0, 1.0) * 26000.0))
	var w := _wav(data)
	w.loop_mode = AudioStreamWAV.LOOP_FORWARD
	w.loop_begin = 0
	w.loop_end = total
	return w


func _add_note(mix: PackedFloat32Array, start: int, f: float, seconds: float, vol: float) -> void:
	var n := mini(int(seconds * RATE), mix.size() - start)
	for j in n:
		var t := float(j) / RATE
		mix[start + j] += _pluck(f, t) * vol


func _add_drum(mix: PackedFloat32Array, start: int, vol: float) -> void:
	var n := mini(int(0.16 * RATE), mix.size() - start)
	for j in n:
		var t := float(j) / RATE
		mix[start + j] += sin(TAU * (92.0 - t * 200.0) * t) * exp(-t * 26.0) * vol * 0.55
