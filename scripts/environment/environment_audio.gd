class_name EnvironmentAudio
extends Node

var players: Dictionary={}
var prefs: SettingsManager
var fade: Tween

func initialize(settings: SettingsManager) -> void:
	prefs=settings

func apply(effect: String, daylight: float) -> void:
	if prefs.data.audio_enabled and players.is_empty():
		for kind in ["rain","insects","leaves"]:
			var stream=AudioStreamWAV.new()
			stream.format=AudioStreamWAV.FORMAT_16_BITS
			stream.mix_rate=22050
			stream.loop_mode=AudioStreamWAV.LOOP_FORWARD
			stream.loop_end=22050*6
			var bytes=PackedByteArray()
			bytes.resize(stream.loop_end*2)
			var rng=RandomNumberGenerator.new()
			rng.seed=kind.hash()
			var low=0.0
			for i in stream.loop_end:
				var t=float(i)/22050
				var white=rng.randf_range(-1,1)
				low=lerpf(low,white,.035)
				var value=white*.12 if kind=="rain" else low*.65
				if kind=="insects":
					value=sin(t*TAU*3400)*pow(maxf(0,sin(t*TAU*1.5)),14)*.06
				bytes.encode_s16(i*2,clampi(roundi(value*32767),-32768,32767))
			stream.data=bytes
			var player=AudioStreamPlayer.new()
			player.stream=stream
			player.volume_db=-80
			add_child(player)
			player.play()
			players[kind]=player
	if fade!=null:
		fade.kill()
	if players.is_empty():
		return
	fade=create_tween().set_parallel(true)
	for kind in players:
		var volume=float(prefs.data[kind+"_volume"])
		if not prefs.data.audio_enabled or (kind=="rain" and not effect in ["rain","storm"]) or (kind=="insects" and daylight>.4):
			volume=0
		if volume>0 and not players[kind].playing:
			players[kind].play()
		fade.tween_property(players[kind],"volume_db",linear_to_db(volume) if volume>0 else -80.0,2.0)
	fade.finished.connect(func():
		for player in players.values():
			if player.volume_db<=-79:
				player.stop())
