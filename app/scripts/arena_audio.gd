extends RefCounted

var player: AudioStreamPlayer
var enabled = true
var sounds = {}

func _init(parent: Node):
	player = AudioStreamPlayer.new()
	player.volume_db = -17.0
	parent.add_child(player)
	sounds["cast"] = tone(480, 0.10, 0.7)
	sounds["success"] = tone(780, 0.22, 1.5)
	sounds["error"] = tone(155, 0.075, 0.3)

func tone(hz: float, seconds: float, harmonic: float) -> AudioStreamWAV:
	var rate = 22050
	var frames = int(rate * seconds)
	var bytes = PackedByteArray()
	bytes.resize(frames * 2)
	for i in frames:
		var t = i / float(rate)
		var envelope = pow(1.0 - i / float(frames), 2) * minf(1, i / 100.0)
		var sample = (sin(TAU * hz * t) + sin(TAU * hz * harmonic * t) * 0.25) * envelope * 0.28
		bytes.encode_s16(i * 2, int(clampf(sample, -1, 1) * 32767))
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.data = bytes
	return stream

func play(cue: String):
	if not enabled or not sounds.has(cue):
		return
	player.stream = sounds[cue]
	player.play()
